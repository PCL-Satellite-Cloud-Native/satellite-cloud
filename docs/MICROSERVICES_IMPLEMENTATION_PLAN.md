# 微服务化与 K8s 多星协同 — 实施方案（归档）

> **文档用途**：后续开发、评审、第三方测试、答辩对照的**单一事实来源（SSOT）**。  
> **最后更新**：2026-06-15  
> **关联文档**：
> - [REMOTE_SENSING_K8S_DEPLOYMENT.md](./REMOTE_SENSING_K8S_DEPLOYMENT.md) — 当前单 Pod 部署
> - [REMOTE_SENSING_MINUTE_LEVEL_ROADMAP.md](./REMOTE_SENSING_MINUTE_LEVEL_ROADMAP.md) — 性能优化与队列化阶段
> - [Object-Detection/K8S_RUNTIME_PREP.md](../../Object-Detection/K8S_RUNTIME_PREP.md) — 检测运行时
> - [Satellite-Remote-Sensing/K8S_RUNTIME_PREP.md](../../Satellite-Remote-Sensing/K8S_RUNTIME_PREP.md) — 遥感运行时

---

## 1. 背景与目标

### 1.1 业务目标

| 目标 | 说明 |
|------|------|
| **一星多用** | 单颗虚拟卫星的一次观测数据，串行/并行跑多种载荷应用（遥感预处理 → 融合预览 → 目标识别 → 后续拓扑关联） |
| **多星协同** | 多颗虚拟卫星同时处理不同 task，突出并行吞吐与协同调度 |
| **研究成果落地** | 容器编排（分域自治、扩缩、迁移、调度）与微服务治理（轻量拆分、资源占用）在真实业务上可测、可演示 |

### 1.2 技术指标导向

- **第三方测试机构**指标为主（可脚本化、可复现、有 P50/P95）。
- **答辩现场**展示为指标的子集（建议 3～5 颗星实时任务 + 架构图 + 测试摘要表）。

---

## 2. 基础设施现状与规划

### 2.1 物理与虚拟化

| 项 | 现状/规划 |
|----|-----------|
| 物理服务器 | **40 台**，同机房相邻 **3 机柜**，光纤 + 交换机互联 |
| 虚拟化 | 40 台形成 **算力池**，在其上创建虚拟 K8s 节点 |
| 虚拟卫星节点 | 目标 **120 个**（**1 虚拟卫星 = 1 K8s Node**） |
| 虚拟路由节点 | **120 个**，规格 **1C2G**，用于 **星间网络控制** |
| 当前集群 | **15 Node**（已按「卫星 + 路由」思路完成小规模验证） |
| 单节点规格（算力） | 约 **8C16G**（卫星载荷节点） |
| GPU | 当前无；规划约 **20 个 GPU 节点**（型号待定） |

### 2.2 存储策略（分阶段）

| 阶段 | 方案 | 说明 |
|------|------|------|
| **现阶段（15 Node 微服务 v1～v2）** | **NFS** | 已有 PV/PVC、`persist_output_preprocessing`、`output_detection`；实现成本最低 |
| **并行压测 / 第三方测试前** | **引入 MinIO**（S3 API） | 新 task 产物走对象存储；Worker 无状态扩缩更自然 |
| **120 Node 长期** | MinIO 集群扩容；**Ceph 可选** | 有块存储/统一存储需求时再评估，**不与微服务 v1 绑定** |

### 2.3 网络与分域

- 单集群、单机房：**暂不做多集群联邦**。
- **逻辑分域**（namespace + ResourceQuota + 独立 HPA）对应「分域自治」研究叙述：
  - `satellite-control` — API、Redis、配置
  - `satellite-compute-rs` — 遥感 Worker / Argo Workflow Pod
  - `satellite-compute-od` — 检测 Worker（未来 GPU 节点池）
  - `satellite-network` — 虚拟路由相关 workload（1C2G）
  - `satellite-data` — NFS / 未来 MinIO 客户端挂载策略

---

## 3. 目标架构

### 3.1 服务拆分（三仓库映射）

```
┌─────────────────────────────────────────────────────────────────┐
│  satellite-api (satellite-cloud)                                 │
│  · REST / SSE  · 任务/阶段/产物/检测统计  · 拓扑 API（后续）      │
│  · 创建 Workflow / 入队  · 不写 GDAL、不跑 yolov8s               │
└───────────────┬─────────────────────────────────────────────────┘
                │ Redis Stream          │ Argo Workflow CR
                ▼                       ▼
┌───────────────────────┐   ┌───────────────────────┐
│  rs-worker × N        │   │  Argo Workflow        │
│  (Satellite-RS 镜像)  │   │  阶段 DAG + 阶段内并行 │
│  阶段 1～9            │   │  (如 PAN RPC 4 路)    │
└───────────┬───────────┘   └───────────┬───────────┘
            │ 融合 .dat 就绪              │
            ▼                             │
┌───────────────────────┐                 │
│  od-worker × M        │◄────────────────┘
│  (Object-Detection)   │   阶段 10 或独立 od.jobs
│  yolov8s + 内嵌字体   │
└───────────┬───────────┘
            ▼
     NFS / MinIO  ·  PostgreSQL（状态）
```

| 服务 | 仓库 | 镜像要点 |
|------|------|----------|
| `satellite-api` | satellite-cloud | 仅 Go 二进制，**无** GDAL/Python/yolov8s |
| `rs-worker` | Satellite-Remote-Sensing + 薄 Go 入口 | Python venv + GDAL；可选同镜像内 Argo `executor` |
| `od-worker` | Object-Detection + 薄 Go 入口 | ONNX Runtime、`fetch_font.sh`、内嵌字体 |

**现有可复用代码**（无需推倒重来）：

- `internal/remotesensing` 阶段定义与 `stageDefinitions`
- `internal/objectdetection.Runner`（已抽离，便于独立 Pod）
- `CollectArtifactEntries` / `GetDetectionStats` / `detection-tiles.zip`
- GitLab CI：`remote-sensing-src` + `object-detection-src` 克隆与 `detection-builder`
- Istio Gateway / VirtualService（已存在）

### 3.2 虚拟卫星与调度亲和

**模型**：`satellite_id` ∈ [1..120] 与 **K8s Node 标签** `satellite.io/id=<id>` 一一对应。

| 概念 | 行为 |
|------|------|
| 创建 task | 指定 `satellite_id`（必填或默认） |
| RS/OD Worker Pod | `nodeAffinity`：优先调度到该 `satellite_id` 节点 → **一星多用（计算落在对应星上）** |
| 多星协同 | 不同 `satellite_id` 的 task 并行 → 不同 Node 同时跑 |
| 资源不足 | 队列排队；指标记录 **排队时延**（第三方测试项） |

> **注意**：120 个卫星 Node 上**不会**同时跑满 120 路重 RS；并发度由 **队列 + Worker 限额 + 节点 CPU** 决定。UI 仍展示 120 颗星，**活跃星高亮**即可。

### 3.3 120 颗虚拟卫星的可视化策略

| 层级 | 策略 |
|------|------|
| **数据** | 预置 120 颗 `satellite_id` + 名称；task 绑定 `satellite_id` |
| **Cesium** | **LOD + 聚合**：拉远显示星座/点簇，拉近显示单星；**有 task/产物的星高亮** |
| **答辩** | 主屏 3～5 颗实时任务；副屏或缩略图展示「共 120 颗，活跃 k 颗」 |
| **实现分期** | v1：列表 + 高亮；v2：120 轨道/点位；v3：footprint 挂接 |

---

## 4. 技术选型（已定）

| 组件 | 选择 | 备注 |
|------|------|------|
| 消息队列 | **Redis Stream + Consumer Group** | 轻量、HPA 友好、Go 生态好 |
| 工作流 | **Argo Workflows** | 阶段 DAG、PAN RPC 并行、多 task 多 Workflow |
| 服务网格 | **Istio**（已有） | 治理研究、mTLS、金丝雀 |
| 数据库 | **PostgreSQL** | 任务/阶段/产物索引 |
| 大文件 | **NFS → MinIO** | 见 §2.2 |
| GPU | **od-worker 独立节点池** | `nodeSelector` + `nvidia.com/gpu` |

---

## 5. 分阶段实施计划

### 阶段 0 — 基线固化（3～5 天）

**状态**：本地 + 15 Node 单 Pod 流水线已基本完成。

| 项 | 内容 |
|----|------|
| 固定输入 | `GF2_PMS1_E118.6_N37.4_20160826_L1A0001792619` |
| 记录 | 总时长、各阶段耗时、检测「图/目标数」、产物完整性 |
| 产出 | `artifacts/benchmarks/<run-id>/report.txt`（可沿用现有 benchmark 脚本） |

**验收**：连续 3 次总时长波动 ≤15%。

---

### 阶段 1 — API 与 RS 计算分离（1～2 周）【优先开发】

| 项 | 内容 |
|----|------|
| 目标 | API 不跑 Python；多 task 可并行 RS |
| 新增 | Redis；`rs-worker` Deployment；`cmd/rs-worker` 或独立 repo 入口 |
| API 变更 | `CreateTask` 写 DB + `XADD rs.jobs`；移除进程内 `runPipeline`（feature flag 保留回滚） |
| 并行 | `rs-worker replicas=3`（15 Node 环境），多 `satellite_id` 多 task 同时消费 |
| K8s | namespace `satellite-control` / `satellite-compute-rs` |

**验收**：

- API 在 RS 重任务运行时 P99 延迟 < 200ms（健康检查除外）
- 3 个 task、3 个不同 `satellite_id` 同时运行并成功

**回滚**：`SATELLITE_USE_INPROCESS_PIPELINE=true` 切回单 Pod。

---

### 阶段 2 — OD 独立 Pod（1～2 周）

| 项 | 内容 |
|----|------|
| 目标 | 检测与 API/RS 隔离；预留 GPU 池 |
| 新增 | `od-worker` Deployment；队列 `od.jobs` |
| 触发 | RS 阶段 9 成功 → 发 `od.jobs`（或 API 监听阶段完成） |
| 镜像 | 已有 `detection-builder` + 字体 + ORT CPU；GPU 仅改节点池与 env |
| 指标 | 拆分前后 **API Pod CPU 占用**（治理研究对照） |

**验收**：检测阶段仅在 `od-worker` 日志中出现；GPU 节点加入后仅改调度不改代码。

---

### 阶段 3 — Argo Workflows DAG（2～3 周）

| 项 | 内容 |
|----|------|
| 目标 | 一星多用 — **阶段内并行**（PAN RPC 4 分块） |
| 实现 | 每 task 一个 Workflow；Template 映射 10 阶段 |
| PAN RPC | `parallelism: 4` 或 4 个独立 step |
| 与 Redis | Argo 负责编排；Redis 可选做全局并发限流 |

**验收**：单 task PAN RPC 墙钟时间较串行下降 ≥25%（同输入同参数）。

---

### 阶段 4 — 多星协同与可观测（1 周）

| 项 | 内容 |
|----|------|
| Prometheus | `task_duration_seconds`、`queue_depth`、`worker_active` |
| Grafana | 并发 3/5/10 task 仪表盘 |
| HPA | `rs-worker` / `od-worker` 按 CPU 或自定义指标（队列深度） |

**验收**：第三方脚本可一键提交 N 路 task 并导出 CSV 报告。

---

### 阶段 5 — 拓扑关联（后续，非阻塞）

| 项 | 内容 |
|----|------|
| DB | `remote_sensing_tasks.satellite_id`、`scenario_id`（迁移） |
| 事件 | `task.completed` → 拓扑服务 / 前端 Cesium 高亮 + footprint |
| 复杂度 | v1 仅高亮 + 产物链接；v2 footprint |

---

### 阶段 6 — MinIO 与 120 Node 扩容（与测试对齐）

| 触发条件 | 动作 |
|----------|------|
| 并行 task ≥5 且 NFS 成为瓶颈 | MinIO 试点 |
| 第三方正式压测前 | MinIO 作为主产物存储 |
| 扩至 40 主机 / 120 卫星 Node | MinIO 扩容；HPA max 上调；Argo 全局 parallelism 配置 |

---

## 6. Redis 消息约定（阶段 1 起）

### 6.1 Stream：`rs.jobs`

```json
{
  "task_id": 12,
  "satellite_id": 3,
  "file_prefix": "GF2_PMS1_...",
  "input_directory": "input",
  "enable_detection": true,
  "detection_classes": "1,5",
  "detection_draw_labels": true,
  "enqueued_at": "2026-06-15T12:00:00Z"
}
```

- Consumer Group：`rs-workers`
- ACK：Worker 领取后 `XACK`；失败重试 + 死信 stream `rs.jobs.dlq`

### 6.2 Stream：`od.jobs`（阶段 2）

```json
{
  "task_id": 12,
  "satellite_id": 3,
  "fusion_dat_rel": "persist_output_preprocessing/fusion_envi/...-MSS1-fusion.dat",
  "detection_classes": "",
  "detection_draw_labels": true
}
```

### 6.3 环境变量（示例）

```bash
SATELLITE_REDIS_ADDR=redis:6379
SATELLITE_REDIS_STREAM_RS=rs.jobs
SATELLITE_REDIS_STREAM_OD=od.jobs
SATELLITE_RS_WORKER_CONCURRENCY=1
SATELLITE_USE_INPROCESS_PIPELINE=false
```

---

## 7. K8s 资源清单（目标态）

### 7.1 Namespace

| Namespace | 用途 |
|-----------|------|
| `satellite-control` | api、redis |
| `satellite-compute-rs` | rs-worker、argo（若按域部署） |
| `satellite-compute-od` | od-worker |
| `satellite-network` | 虚拟路由 1C2G 相关 |
| `gitlab-runner` | 现有 CI 部署（可逐步迁移） |

### 7.2 Deployment 摘要

| 工作负载 | 副本（15 Node） | 副本（120 Node 参考） | 资源 request/limit |
|----------|-----------------|------------------------|---------------------|
| `satellite-api` | 2 | 3～5 | 500m/1Gi |
| `rs-worker` | 1～3 (HPA) | 10～40 (HPA) | 4Gi～8Gi，CPU 4～8 |
| `od-worker` | 1 (HPA) | 15～20 (GPU 池) | CPU 模式 4Gi；GPU 1× |
| `redis` | 1 | 3 sentinel 或云托管 | 1Gi |

### 7.3 节点标签（虚拟卫星）

```yaml
labels:
  satellite.io/role: payload
  satellite.io/id: "42"          # 1-120
  node.kubernetes.io/workload: rs-od   # 可选
```

虚拟路由节点：

```yaml
labels:
  satellite.io/role: router
  satellite.io/id: "42"
resources:
  cpu: "1"
  memory: 2Gi
```

---

## 8. 第三方测试指标模板（建议稿）

> 无官方模板时，建议与测试机构确认后**签字冻结**本表。所有项应提供 **自动化脚本**（`scripts/third_party/`）。

### 8.1 功能符合性

| 编号 | 测试项 | 方法 | 通过标准 |
|------|--------|------|----------|
| F-01 | 单 task 端到端 | 提交 1 个含检测 task | 10 阶段 success；融合 preview 存在 |
| F-02 | 检测产物 | 检查 NFS/MinIO | 每类 detections.txt；zip 可下载 |
| F-03 | 检测统计 | GET `/detection-stats` | 瓦片数 ≤ 实际 jpg；目标数 = detections.txt 解析 |
| F-04 | 多星绑定 | 3 task 不同 `satellite_id` | Pod 调度到对应 Node（或日志记录亲和） |

### 8.2 性能

| 编号 | 测试项 | 方法 | 通过标准（示例，可谈判） |
|------|--------|------|--------------------------|
| P-01 | 单 task 总时长 | 固定输入，跑 5 次 | P50 ≤ 基线×1.0；P95 ≤ 基线×1.15 |
| P-02 | PAN RPC 阶段 | 阶段 3 前后对比 | Argo 并行后 P50 下降 ≥25% |
| P-03 | 检测阶段 | 仅 OD 计时 | P95 ≤ 配置超时 14400s 内 |

### 8.3 并发与协同

| 编号 | 测试项 | 方法 | 通过标准（示例） |
|------|--------|------|------------------|
| C-01 | 3 星并行 | 同时提交 3 task | 全部 success；无 DB 死锁 |
| C-02 | 5 星并行 | 同时提交 5 task | 成功率 ≥95%；失败可重试成功 |
| C-03 | 排队时延 | 提交数 > Worker 数 | 记录 enqueue→start 时间并出报告 |

### 8.4 资源与治理

| 编号 | 测试项 | 方法 | 通过标准（示例） |
|------|--------|------|------------------|
| G-01 | API CPU | Prometheus 对比拆分前后 | API Pod CPU 较单 Pod 下降 ≥50% |
| G-02 | 弹性 | 压测触发 HPA | 副本数在 T 分钟内增至目标 |
| G-03 | 故障恢复 | 杀 rs-worker Pod | task 最终 success 或明确 failed+可重跑 |

### 8.5 交付物

- 测试输入数据包路径说明
- `scripts/third_party/run_all.sh` 一键执行
- 原始日志 + CSV 汇总 + 环境版本表（镜像 tag、Node 数、存储类型）

---

## 9. 研究成果与工程映射

| 研究方向（简述） | 本项目的工程落点 | 可采集证据 |
|------------------|------------------|------------|
| 镜像简化、减小部署粒度 | API / RS / OD 三镜像 | 镜像大小、拉取时间、节点磁盘 |
| 分域自治 | 多 namespace + 域内 HPA | 域间故障注入实验 |
| 分布式扩缩模型 | HPA + Redis 队列深度指标 | 扩缩决策日志、Grafana |
| 模型压缩降复杂度 | 扩缩/调度推理 sidecar（后期） | 推理延迟、CPU |
| 容器状态低开销同步 | DB 权威 + Redis 快照 + Node 注解 | 同步 QPS、带宽 |
| 分布式迁移 | NFS/MinIO 共享态 + Pod 优雅退出 | 迁移中断时间 |
| DRL 调度 | Scheduler extender（后期） | 对比默认 scheduler 完工时间 |
| 微服务轻量拆分 | API↔RS↔OD 拆分 | CPU↓50%、调用链图 |

---

## 10. 当前仓库 → 目标态迁移对照

| 现状 | 目标 | 涉及路径/动作 |
|------|------|---------------|
| 单 `satellite-backend` Pod 跑 API+RS+OD | 三 Deployment | `k8s/backend/deployment.yaml` 拆分 |
| 内存队列 `RemoteSensingService.queue` | Redis Stream | `internal/remotesensing/service.go` |
| `go run ./cmd/server` 本地 | api + worker 分开启动 | 新增 `cmd/rs-worker`、`cmd/od-worker` |
| WSL `wsl-python.cmd` / `wsl-detection.cmd` | 仅本地 Windows 开发 | K8s 不用 wsl-*.cmd |
| NFS 产物 | 保持；后迁 MinIO | `ArtifactAbsolutePath` 抽象 storage backend |
| 前端单页 RS | 增加 `satellite_id`、120 星 LOD | `RemoteSensing.vue` + 拓扑 |
| Istio 仅入口 | 可选 mTLS 服务间 | `PeerAuthentication` 后期 |

---

## 11. 开发优先级（Next Actions）

1. **DB 迁移**：`remote_sensing_tasks` 增加 `satellite_id`（uint, 1～120）、可选 `scenario_id`。
2. **Redis**：Helm/bitnami 部署到 `satellite-control`；API 配置 `SATELLITE_REDIS_*`。
3. **`cmd/rs-worker`**：从现有 `runPipeline` 抽出，消费 `rs.jobs`。
4. **Feature flag**：`SATELLITE_USE_INPROCESS_PIPELINE` 默认 `true`，K8s 设为 `false`。
5. **K8s**：`k8s/rs-worker/deployment.yaml`、`k8s/redis/` 初版。
6. **文档**：CI 增加 `rs-worker` 镜像 build（RS 仓库或 cloud 多阶段 Dockerfile）。
7. **脚本**：`scripts/third_party/run_all.sh` 骨架。

---

## 12. 待确认项（不阻塞阶段 1）

| 项 | 说明 |
|----|------|
| 120 卫星 Node 与 120 路由 Node 是否 **同一 K8s 集群** 内 | 当前按「是」撰写 |
| 第三方测试 **必须通过项** 的硬性数字 | 本文 §8 为建议值，需机构确认 |
| GPU 型号与驱动 / device plugin | 影响 od-worker 资源声明 |
| MinIO 是否与现有 NFS 同机 | 影响网络规划 |

---

## 13. 版本记录

| 版本 | 日期 | 说明 |
|------|------|------|
| v1.0 | 2026-06-15 | 初版归档：基础设施、分阶段计划、Redis 约定、测试模板、研究映射 |

---

**维护约定**：每完成一个阶段，在本表 §5 对应小节追加 **「已落地 commit/PR」** 与 **实测数据链接**，并与 [REMOTE_SENSING_K8S_DEPLOYMENT.md](./REMOTE_SENSING_K8S_DEPLOYMENT.md) 保持部署细节一致。
