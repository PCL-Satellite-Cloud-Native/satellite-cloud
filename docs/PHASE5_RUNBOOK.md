# Phase 5 运维手册（拓扑关联）

> **状态（2026-06-24）**：**P5-01 实施中** — DB/API/Redis/SSE 已落地；前端高亮与调度亲和待 P5-02～04。  
> **前置**：[Phase 4 归档](./archives/2026-06-24_phase4-closure.md)  
> **方案 SSOT**：[MICROSERVICES_IMPLEMENTATION_PLAN.md](./MICROSERVICES_IMPLEMENTATION_PLAN.md) §5 阶段 5

---

## 0. Phase 5 目标

| 维度 | Phase 4（已闭合） | Phase 5（本阶段） |
|------|-------------------|-------------------|
| 可观测 | Prometheus / Grafana / HPA | 任务 ↔ 卫星 / 场景绑定 |
| 多 task | 同 prefix 串行 10 路 | **不同 satellite_id** 多 task 并行（调度试点） |
| 前端 | 遥感任务页 | 拓扑页 **卫星高亮** + 产物链接 |
| 存储 | NFS | 仍 NFS；**task 级路径隔离**（P5-05 可选）→ MinIO Phase 6 |

---

## 1. 实施路线图

```mermaid
flowchart LR
    P501["P5-01 DB+API+Redis"]
    P502["P5-02 前端绑定+高亮"]
    P503["P5-03 nodeAffinity 试点"]
    P504["P5-04 多星压测脚本"]
    P505["P5-05 task 路径隔离"]

    P501 --> P502 --> P503 --> P504
    P504 --> P505
```

| ID | 内容 | 状态 | 产出 |
|----|------|------|------|
| **P5-01** | `scenario_id` / `satellite_id` 入库 + API + Redis + SSE | ✅ 代码 | migration `000008` |
| **P5-02** | 遥感创建表单选星；拓扑页 completed 高亮 | ⏳ | `RemoteSensing.vue` / `SatTopology` |
| **P5-03** | rs-worker `nodeAffinity`（`satellite.io/id`） | ⏳ | k8s patch / Helm |
| **P5-04** | 3 task × 3 不同 satellite 压测 | ⏳ | `submit_multi_satellite_tasks.sh` |
| **P5-05** | NFS 按 `task_id` 隔离中间产物 | ⏳ 可选 | 解锁同 prefix 并行 |

---

## 2. P5-01 已交付（backend）

### 2.1 数据库

迁移 `backend/migrations/000008_remote_sensing_task_topology.up.sql`：

- `remote_sensing_tasks.scenario_id` → `scenarios(id)`
- `remote_sensing_tasks.satellite_id` → `satellites(id)`

部署后 backend 启动时自动 migrate，或：

```bash
# 由 satellite-backend rollout 触发；手动确认：
kubectl -n gitlab-runner logs deploy/satellite-backend --tail=30 | grep -i migrat
```

### 2.2 创建任务 API

```http
POST /api/remote-sensing/tasks
Content-Type: application/json

{
  "name": "p5-test-sat-3",
  "filePrefix": "GF2_PMS1_E118.6_N37.4_20160826_L1A0001792619",
  "inputDirectory": "input",
  "sensor": "GF2",
  "enableDetection": true,
  "scenarioId": 1,
  "satelliteId": 42
}
```

- `scenarioId` / `satelliteId` **可选**（兼容旧客户端）
- 若同时提供：校验 satellite 属于 scenario
- `satelliteId` 为 **`satellites.id`（表主键）**，非 `sat_id` 字符串

### 2.3 列表过滤

```http
GET /api/remote-sensing/tasks?satellite_id=42
GET /api/remote-sensing/tasks?scenario_id=1&status=completed
```

### 2.4 Redis / SSE

- `rs.jobs` / `od.jobs` payload 含 `satellite_id`（与方案 §6 一致）
- SSE `task.completed` 事件含 `satellite_id`、`scenario_id`（供前端高亮）

### 2.5 验收 P5-01

```bash
# 查场景与卫星 id（示例）
curl -s http://127.0.0.1:8080/api/scenarios | jq '.[0].id'
curl -s 'http://127.0.0.1:8080/api/satellites?scenario_id=1' | jq '.[0] | {id,sat_id}'

# 创建带绑定的任务
curl -s -X POST http://127.0.0.1:8080/api/remote-sensing/tasks \
  -H 'Content-Type: application/json' \
  -d '{"filePrefix":"GF2_PMS1_E118.6_N37.4_20160826_L1A0001792619","inputDirectory":"input","scenarioId":1,"satelliteId":42,"enableDetection":true}' | jq '{id,satellite_id,scenario_id}'

# 完成后 GET task 应仍含 satellite_id
```

---

## 3. P5-02 前端（待实施）

| 项 | 说明 |
|----|------|
| `RemoteSensing.vue` | 场景下拉 + 卫星下拉（`GET /api/satellites?scenario_id=`） |
| 任务列表 | 展示 `satellite_id` / 卫星名称 |
| `SatTopology.vue` / `SatelliteViewer.vue` | 监听 SSE 或轮询 completed task → **高亮对应 sat** |
| v1 范围 | 高亮 + 点击跳转遥感产物；**不做 footprint  polygon（v2）** |

---

## 4. P5-03 调度亲和（待实施）

目标：task 绑定 `satellite_id` 后，rs-worker Pod 带：

```yaml
affinity:
  nodeAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        preference:
          matchExpressions:
            - key: satellite.io/id
              operator: In
              values: ["<sat_id 或 satellites 表映射>"]
```

**Pilot**：15 Node 环境可先 **preferred**（软亲和），日志记录实际 `hostNodeName`。

---

## 5. P5-04 多星压测（待实施）

不同于 Phase 4「同 prefix 串行 10 路」：

- **3 个 task、3 个不同 `satelliteId`、同一 filePrefix**
- 预期：3 路 **running 重叠** 且无 NFS path 冲突（仍共享 prefix 时有风险 → 配合 P5-05 或不同 prefix）

脚本草案：`scripts/submit_multi_satellite_tasks.sh`

---

## 6. P5-05 task 路径隔离（可选，建议 Phase 5 内完成）

Phase 4 结论：同 `filePrefix` 并行必冲突。隔离方案：

```
persist_output_preprocessing/tasks/{task_id}/pan_warp_quarters/...
output_preprocessing/tasks/{task_id}/...
```

改动面：`service.go` 各 stage 路径、Argo Workflow 参数、`pan_rpc_argo.go` 不再全局 `RemoveAll(workers/)`。

完成后：`max-in-flight>1` 同景压测可重测。

---

## 7. 与 Phase 6（MinIO）关系

| 先做 | 后做 |
|------|------|
| P5-01～04 拓扑绑定 + 多星调度叙事 | MinIO 对象存储 |
| P5-05 task 路径（仍在 POSIX 路径上） | `ArtifactStorage` 抽象 → S3 |

MinIO **不替代** task 隔离设计；二者正交。

---

## 8. 相关路径

| 路径 | 说明 |
|------|------|
| `backend/migrations/000008_*` | 拓扑字段迁移 |
| `backend/internal/remotesensing/service.go` | CreateTask / SSE |
| `frontend/src/view/SatTopology.vue` | 拓扑主视图 |
| [PHASE4_RUNBOOK.md](./PHASE4_RUNBOOK.md) | Phase 4（只读） |

---

*P5-01 合并并部署 backend 后，按 §2.5 验收；随后实施 P5-02 前端。*
