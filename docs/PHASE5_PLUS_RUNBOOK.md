# Phase 5+ 运维手册（路径隔离 → 按星 rs-worker）

> **状态（2026-06-11）**：P5-05 已实现待部署验收；P5-06b 待实施  
> **前置**：[PHASE5_RUNBOOK.md](./PHASE5_RUNBOOK.md)（Phase 5 已闭合）  
> **方案 SSOT**：[MICROSERVICES_IMPLEMENTATION_PLAN.md](./MICROSERVICES_IMPLEMENTATION_PLAN.md)

---

## 0. 路线图

| ID | 内容 | 优先级 | 状态 |
|----|------|--------|------|
| **P5-05** | NFS 按 `task_id` 隔离中间产物 | **先** | ✅ 代码就绪 |
| **P5-06b** | 每节点 rs-worker + 卫星感知消费 + required affinity | 后 | ⏸ 待做 |
| P5-07 | STK 对齐、移除 +5 星历桥接 | STK 就绪后 | ⏸ |
| P5-08 | `phase5_acceptance.sh` 回归脚本 | 可选 | ⏸ |
| Phase 6 | MinIO + 120 Node | P5-05 后 | ⏸ |

用户决议：**6b 方案**，顺序 **先 P5-05 再 P5-06**。

---

## 1. P5-05 — task 路径隔离

### 1.1 动机

同 `filePrefix` 多 task 并行时，legacy 全局目录（如 `output_preprocessing/pan_warp_quarters/workers/`）会互相 `RemoveAll`，导致 NFS 冲突。P5-05 在 scratch 与 persist 根下插入 `tasks/{task_id}/` 段。

### 1.2 路径规则

| 根 | Legacy（`isolation=false`） | 隔离（默认 `true`） |
|----|----------------------------|---------------------|
| scratch | `output_preprocessing/{stage}/...` | `output_preprocessing/tasks/{id}/{stage}/...` |
| persist | `persist_output_preprocessing/{stage}/...` | `persist_output_preprocessing/tasks/{id}/{stage}/...` |
| Argo 参数 | `task_path_prefix=""` | `task_path_prefix="tasks/{id}/"` |

### 1.3 配置

| 环境变量 | 默认 | 说明 |
|----------|------|------|
| `SATELLITE_RS_TASK_PATH_ISOLATION` | `true` | rs-worker / backend 均需一致 |

代码 SSOT：`backend/internal/remotesensing/taskpaths.go`

### 1.4 部署步骤

```bash
# 1) 构建并推送 backend 镜像（含 rs-worker 同镜像）
# 2) 更新 WorkflowTemplate（新增 task_path_prefix 参数）
kubectl apply -f k8s/phase3/workflows/workflowtemplate-pan-rpc.yaml

# 3) 更新 rs-worker
kubectl -n gitlab-runner set image deployment/rs-worker rs-worker="$BACKEND_IMAGE"
kubectl -n gitlab-runner set env deployment/rs-worker \
  SATELLITE_RS_TASK_PATH_ISOLATION=true
kubectl -n gitlab-runner rollout status deployment/rs-worker --timeout=300s
```

`k8s/phase1/rs-worker/deployment.yaml` 已内置 `SATELLITE_RS_TASK_PATH_ISOLATION=true`。

### 1.5 验收

```bash
bash scripts/submit_multi_satellite_tasks.sh \
  --run-id p5-path-$(date +%m%d) \
  --api-base http://127.0.0.1:8080 \
  --scenario-id 2 \
  --satellite-ids 4,26,48
```

**通过标准**：

- 3/3 `completed`
- NFS 上存在独立目录，例如：
  - `persist_output_preprocessing/tasks/{task_id}/fusion_envi/`
  - scratch（emptyDir）侧 `output_preprocessing/tasks/{task_id}/`
- 多 task 不再因 PAN RPC / Pansharpen `workers/` 清理互相干扰

**回滚**：`SATELLITE_RS_TASK_PATH_ISOLATION=false` + legacy WorkflowTemplate（无 `task_path_prefix`）。

---

## 2. P5-06b — 按节点 rs-worker（待实施）

### 2.1 目标

- 每 worker 节点（或 Pilot 子集）运行 rs-worker，读取本节点 `satellite.io/id`
- Redis 消费侧：**仅处理** `satellite_id` 与本节点标签匹配的任务
- Argo PAN RPC：**required** nodeAffinity（替代当前 preferred）
- `executed_sat_id` 与 `satellite_id` 对齐率提升（仍允许软调度失败时的 mismatch 观测）

### 2.2 预期改动（概要）

| 组件 | 改动 |
|------|------|
| `cmd/rs-worker` | 启动时读 `NODE_NAME` → 节点标签 `satellite.io/id` |
| `queue_dispatch.go` | dequeue 后过滤 / ACK 非本星任务 |
| `k8s/phase1/rs-worker` | replicas 或 DaemonSet；required affinity |
| `argo/client.go` | preferred → required（可配置） |
| `placement.go` | 可选从 Argo Pod node 反查 executed_sat_id |

### 2.3 前置

- P5-05 验收通过（避免多 task 路径冲突掩盖调度问题）
- `scripts/phase5_label_nodes.sh --apply` 已执行
- `k8s/phase5/worker-node-reader.yaml` 已 apply

---

## 3. 相关路径

| 路径 | 说明 |
|------|------|
| `backend/internal/remotesensing/taskpaths.go` | 路径 helper |
| `backend/internal/remotesensing/pan_rpc_argo.go` | Argo 集成 + 隔离 workers |
| `k8s/phase3/workflows/workflowtemplate-pan-rpc.yaml` | PAN RPC Template |
| `k8s/phase1/rs-worker/deployment.yaml` | rs-worker 环境变量 |
| [archives/2026-06-26_phase5-closure.md](./archives/2026-06-26_phase5-closure.md) | Phase 5 收口 |

---

*P5-05 部署验收通过后更新本文 §1 状态；P5-06b 实施时扩展 §2 为逐步 Runbook。*
