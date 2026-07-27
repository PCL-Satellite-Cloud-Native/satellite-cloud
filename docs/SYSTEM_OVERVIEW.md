# 系统概览（当前 Baseline）

> 本文说明 **项目是什么、现网怎么跑、关键约束是什么**。  
> 详细操作见索引：[DOCUMENTATION_INDEX.md](./DOCUMENTATION_INDEX.md)。  
> **当前准出**：cluster-120 上 **60 星** Post-P5（2026-07-23～24）。

---

## 1. 项目是做什么的

本仓库（`satellite-cloud`）是云原生 **卫星网络可视化 + 遥感/检测业务编排** 中心：

| 能力 | 说明 |
|------|------|
| 星座可视化 | Vue + Cesium：场景、卫星、拓扑（时延/路由展示） |
| 遥感流水线 | 任务阶段 **1～9**（预处理/融合等，Python/GDAL，`Satellite-Remote-Sensing`） |
| 目标识别 | 阶段 **10**（YOLOv8/ONNX，`Object-Detection`） |
| 多星调度 | 任务绑定 `satelliteId`，优先在对应 K8s 节点（虚拟星）上执行 |
| 产物访问 | 融合预览、检测统计等；60 星现网读路径走 **MinIO**（D0） |

关联算法仓由 CI 打进 backend 镜像（或本地联调），本仓负责 API、Worker、K8s 清单与运维文档。

---

## 2. 现网架构（读代码时按此理解）

```text
用户 / 前端 (Vue)
    │
    ▼
satellite-backend (Go API)     namespace: gitlab-runner
    │  写 DB + XADD Redis Stream (rs.jobs)
    ▼
rs-worker DaemonSet            按卫星亲和消费队列
    │  阶段 1～9（遥感）
    │  阶段 10：默认进程内 OD（USE_OD_WORKER=false）
    ▼
产物：锚点 hostPath 写入 + MinIO 上传（预览/统计可读）
```

| 组件 | 角色 | 现网注意 |
|------|------|----------|
| `satellite-backend` | REST/SSE、入队、读产物元数据 | 创建任务 **必须** 带 `satelliteId` |
| Redis Stream `rs.jobs` | 本星感知队列（XCLAIM） | 任务应落到所选卫星节点 |
| `rs-worker` DS | 真正跑 RS（+ in-process OD） | 60 星锚点 sat1/sat21/sat41 等 |
| `od-worker` Deployment | 独立检测 Worker | **replicas=0**（见决策文） |
| PostgreSQL | 场景/卫星/任务/拓扑元数据 | |
| MinIO | 输入与产物对象存储 | 60 星 Console/API 与 Pilot 地址不同 |
| 前端 | 遥感页、拓扑页、监控入口 | 执行卫星必选 |

入口示例（验收时）：API `http://192.168.12.67:30080`；场景 `Scenario60_3x20`（scenario_id=3）。

---

## 3. 业务怎么跑通（最短路径）

1. 确认集群健康：`bash scripts/ops_patrol_60.sh --expect-digest <现网 digest>`  
2. 前端或 API 创建遥感任务：**选择卫星** + 输入数据 +（可选）开启检测  
3. 在对应锚点 `rs-worker` 上看阶段日志；任务状态进 DB / SSE  
4. 完成后打开预览 / detection-stats（MinIO 读路径）  

部署与数据准备：

- 总步骤：[CLUSTER120_SAT10_STEPS.md](./CLUSTER120_SAT10_STEPS.md)  
- MinIO / 输入上传：[CLUSTER120_DEPLOY.md](./CLUSTER120_DEPLOY.md)、[D0_MINIO_ARTIFACT_UPLOAD_60.md](./D0_MINIO_ARTIFACT_UPLOAD_60.md)  
- 环境变量与挂载：[REMOTE_SENSING_K8S_DEPLOYMENT.md](./REMOTE_SENSING_K8S_DEPLOYMENT.md)  
- 早期 15 节点全链路说明（仍有参考价值）：[K8S_BASELINE_RUNBOOK.md](./K8S_BASELINE_RUNBOOK.md)

---

## 4. 现网必须遵守的约束

| 约束 | 说明 |
|------|------|
| 强制选星 | API/UI 无 `satelliteId` → 拒绝（HTTP 400） |
| OD in-process | `SATELLITE_USE_OD_WORKER=false`；勿把 Pilot 的 od-worker 扩副本套到 60 星 |
| Argo PAN | 现网默认 `SATELLITE_USE_ARGO_PAN_RPC=false` |
| 本星执行 | 队列 XCLAIM / fail-closed；任务应在绑定星上跑 |
| 镜像更新 | 使用真实 tag 或 `@sha256:`；勿把 digest 字符串当作 tag |
| Pilot ≠ 60 星 | 15 节点 Pilot 与 cluster-120 地址、存储、开关不同，勿混用 |

决策原文：[decisions/2026-07-24_od-worker-60node.md](./decisions/2026-07-24_od-worker-60node.md)  
准出事实：[archives/2026-07-23_post-p5-60node-closure.md](./archives/2026-07-23_post-p5-60node-closure.md)

---

## 5. 仓库目录怎么读

| 路径 | 含义 |
|------|------|
| `backend/cmd/server` | API 入口 |
| `backend/cmd/rs-worker` | 遥感 Worker 入口 |
| `backend/cmd/od-worker` | 独立 OD Worker（60 星默认不启用） |
| `backend/internal/remotesensing` | 阶段流水线 |
| `backend/internal/objectdetection` | 检测调用 |
| `backend/internal/queue` | Redis 队列 |
| `backend/internal/storage` | NFS / MinIO 抽象 |
| `backend/internal/topology` | 拓扑导入 |
| `frontend/` | 可视化与遥感 UI |
| `k8s/` | 各阶段清单；60 星看 `k8s/phase5/*60*` 等 |
| `scripts/` | 巡检、验收、镜像辅助 |
| `docs/` | 运维与收口文档 |

---

## 6. 文档怎么读（推荐顺序）

1. **本文** — 建立心智模型  
2. [archives/2026-07-23_post-p5-60node-closure.md](./archives/2026-07-23_post-p5-60node-closure.md) — 现网已验收什么  
3. [decisions/2026-07-24_od-worker-60node.md](./decisions/2026-07-24_od-worker-60node.md) — OD 为何 in-process  
4. [CLUSTER120_SAT10_STEPS.md](./CLUSTER120_SAT10_STEPS.md) + [CLUSTER120_DEPLOY.md](./CLUSTER120_DEPLOY.md) — 怎么部署/操作  
5. [REMOTE_SENSING_K8S_DEPLOYMENT.md](./REMOTE_SENSING_K8S_DEPLOYMENT.md) — env / 卷 / 排障  
6. 需要历史背景时再查 [archives/ARCHIVE_INDEX.md](./archives/ARCHIVE_INDEX.md) 与各 `PHASE*_RUNBOOK.md`（**以现网开关为准**，Pilot 配置勿直接套 60 星）

完整索引：[DOCUMENTATION_INDEX.md](./DOCUMENTATION_INDEX.md)
