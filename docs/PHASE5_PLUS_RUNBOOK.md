# Phase 5+ 运维手册（路径隔离 → 按星 rs-worker）

> **状态（2026-07-03）**：P5-05 **已验收**；P5-06b **代码就绪，待部署验收**  
> **前置**：[PHASE5_RUNBOOK.md](./PHASE5_RUNBOOK.md)（Phase 5 已闭合）  
> **P5-05 归档**：[archives/2026-07-03_phase5-05-closure.md](./archives/2026-07-03_phase5-05-closure.md)  
> **方案 SSOT**：[MICROSERVICES_IMPLEMENTATION_PLAN.md](./MICROSERVICES_IMPLEMENTATION_PLAN.md)

---

## 0. 路线图

| ID | 内容 | 优先级 | 状态 |
|----|------|--------|------|
| **P5-05** | NFS 按 `task_id` 隔离中间产物 | **先** | ✅ **已验收**（p5-path-v4-0703） |
| **P5-06b** | 每节点 rs-worker + 卫星感知消费 + required affinity | 后 | 🔄 代码就绪 |
| P5-07 | STK 对齐、移除 +5 星历桥接 | STK 就绪后 | ⏸ |
| P5-08 | `phase5_acceptance.sh` 回归脚本 | 可选 | ⏸ |
| Phase 6 | MinIO + 120 Node | P5-05 后 | ⏸ |

用户决议：**6b 方案**，顺序 **先 P5-05 再 P5-06**。

---

## 1. P5-05 — task 路径隔离 ✅

> **验收定稿**：run_id **`p5-path-v4-0703`**，task 220/221/222 均 `completed`。详见 [2026-07-03_phase5-05-closure.md](./archives/2026-07-03_phase5-05-closure.md)。

### 1.1 动机

同 `filePrefix` 多 task 并行时，legacy 全局目录（如 `output_preprocessing/pan_warp_quarters/workers/`）会互相 `RemoveAll`，导致 NFS 冲突。P5-05 在 scratch 与 persist 根下插入 `tasks/{task_id}/` 段。

### 1.2 路径规则

| 根 | Legacy（`isolation=false`） | 隔离（默认 `true`） |
|----|----------------------------|---------------------|
| scratch | `output_preprocessing/{stage}/...` | `persist_output_preprocessing/tasks/{id}/{stage}/...`（**NFS，非 emptyDir**） |
| persist | `persist_output_preprocessing/{stage}/...` | `persist_output_preprocessing/tasks/{id}/{stage}/...` |
| Argo 参数 | `task_path_prefix=""` | `task_path_prefix="tasks/{id}/"` |

### 1.3 配置

| 环境变量 | 默认 | 说明 |
|----------|------|------|
| `SATELLITE_RS_TASK_PATH_ISOLATION` | `true` | rs-worker / backend 均需一致 |

代码 SSOT：`backend/internal/remotesensing/taskpaths.go`

### 1.5 验收（已通过）

```bash
bash scripts/submit_multi_satellite_tasks.sh \
  --run-id p5-path-v4-$(date +%m%d) \
  --api-base http://127.0.0.1:8080 \
  --scenario-id 2 \
  --satellite-ids 4,26,48
```

**通过标准**：3/3 `completed`；NFS 上 `persist_output_preprocessing/tasks/{task_id}/` 独立目录。

### 1.6 NFS 扩容（方案 C）

P5-05 压测前若 NFS ~98G 满盘，须先扩容。运维脚本：`scripts/ops/expand_remote_sensing_nfs.sh`（2T vdb 已上线）。

---

## 2. P5-06b — 按节点 rs-worker

### 2.1 目标

- 每带 `satellite.io/id` 标签的节点运行 rs-worker（DaemonSet）
- Redis 消费：**仅处理** `satellite_id` 对应 `satellites.sat_id` 与本节点标签匹配的任务；不匹配则 ACK + 重新入队
- Argo PAN RPC：**required** nodeAffinity（`SATELLITE_ARGO_REQUIRED_NODE_AFFINITY=true`）
- `executed_sat_id` 与 `satellite_id` 指定星对齐率提升

### 2.2 配置

| 环境变量 | 默认（API） | DaemonSet | 说明 |
|----------|-------------|-----------|------|
| `SATELLITE_RS_SATELLITE_AWARE_QUEUE` | `false` | `true` | 卫星感知 Redis 过滤 |
| `SATELLITE_ARGO_REQUIRED_NODE_AFFINITY` | `false` | `true` | PAN RPC Workflow required affinity |
| `NODE_NAME` | — | downward API | 读节点 `satellite.io/id` |

代码 SSOT：

| 路径 | 说明 |
|------|------|
| `backend/cmd/rs-worker/main.go` | 消费过滤 + 交还非本星 job |
| `backend/internal/remotesensing/worker_satellite.go` | 匹配逻辑 |
| `backend/internal/argo/client.go` | required / preferred affinity |
| `k8s/phase5/rs-worker-daemonset.yaml` | DaemonSet manifest |

### 2.3 部署步骤

#### 方式 A — GitLab CI（推荐，master 无需代码仓库）

**一次性前置（master / cluster-admin，CI 无 nodes 权限）**：

```bash
# 开发机：拷贝部署包到 master（4 个文件）
scp scripts/phase5_label_nodes.sh \
    backend/internal/pilotcluster/pilot-map.json \
    k8s/phase5/worker-node-reader.yaml \
    k8s/gitlab-runner-ci-rbac-phase5.yaml \
    pcl@k8s-master:~/code/p5-deploy/

# master
cd ~/code/p5-deploy
bash phase5_label_nodes.sh --apply          # 自动读同目录 pilot-map.json
kubectl apply -f worker-node-reader.yaml
kubectl apply -f gitlab-runner-ci-rbac-phase5.yaml
kubectl get nodes -L satellite.io/id
```

**Pipeline 步骤**：

1. **开发机** `git push origin main`
2. GitLab → **CI/CD → Pipelines** → 等待 **`build-backend`** 绿
3. 手动点击 **`deploy-phase5-plus-pilot`**
4. Job 绿后，在 **master** 仅做验收（见 §2.4）

CI job 会自动：WorkflowTemplate → 停 Deployment → 上 DaemonSet → 更新镜像（**不含**节点打标 / ClusterRole）。

| 前置（一次性，cluster-admin） | 说明 |
|-------------------------------|------|
| `phase5_label_nodes.sh --apply` | 15 节点 `satellite.io/id` |
| `k8s/phase5/worker-node-reader.yaml` | rs-worker 读 Node 标签 |
| `k8s/gitlab-runner-ci-rbac-phase5.yaml` | CI 可 apply DaemonSet |

**回滚 CI 路径**：删除 DaemonSet → 恢复 Deployment（§2.4 回滚命令）。

#### 方式 B — master 手动 kubectl（备选）

```bash
export BACKEND_IMAGE=192.168.10.238/satellite/backend:<SHA>   # Pipeline 短 SHA

bash scripts/phase5_label_nodes.sh --apply
kubectl apply -f k8s/phase5/worker-node-reader.yaml
kubectl apply -f k8s/phase3/workflows/workflowtemplate-pan-rpc.yaml
kubectl -n gitlab-runner scale deployment/rs-worker --replicas=0
kubectl -n gitlab-runner patch hpa rs-worker -p '{"spec":{"minReplicas":0,"maxReplicas":0}}' 2>/dev/null || true
kubectl apply -k k8s/phase5/
kubectl -n gitlab-runner set image daemonset/rs-worker rs-worker="$BACKEND_IMAGE"
kubectl -n gitlab-runner set env daemonset/rs-worker SATELLITE_RS_WORKFLOW_IMAGE="$BACKEND_IMAGE"
kubectl -n gitlab-runner rollout status daemonset/rs-worker --timeout=600s
kubectl -n gitlab-runner get pods -l app=rs-worker -o wide
```

**Pilot 子集验收**（仅 3 星节点时）：可临时给无关节点打 `satellite.io/rs-worker=disabled` 并 patch DaemonSet `nodeAffinity` 排除；或接受 15 Pod 全量运行。

### 2.4 验收

```bash
kubectl -n gitlab-runner port-forward svc/satellite-backend 8080:8080 &

bash scripts/submit_multi_satellite_tasks.sh \
  --run-id p5-6b-$(date +%m%d) \
  --api-base http://127.0.0.1:8080 \
  --scenario-id 2 \
  --satellite-ids 4,26,48
```

**通过标准**：

| 项 | 标准 |
|----|------|
| 完成率 | 3/3 `completed` |
| 对齐 | `executed_sat_id` 与指定星 **sat-1-1 / sat-2-1 / sat-3-1** 一致（对应 satellite_id 4/26/48） |
| 落点 | `host_node_name` 为 worker11 / worker21 / worker31（pilot-map） |
| Argo | PAN RPC step Pod 调度在对应节点（`kubectl get pods -l satellite.io/stage=pan_rpc_warp_quarters -o wide`） |

**回滚**：

```bash
kubectl -n gitlab-runner delete daemonset/rs-worker --ignore-not-found
kubectl -n gitlab-runner scale deployment/rs-worker --replicas=1
kubectl -n gitlab-runner set env deployment/rs-worker \
  SATELLITE_RS_SATELLITE_AWARE_QUEUE=false \
  SATELLITE_ARGO_REQUIRED_NODE_AFFINITY=false
```

### 2.5 前置

- ✅ P5-05 验收通过
- `scripts/phase5_label_nodes.sh --apply` 已执行
- `k8s/phase5/worker-node-reader.yaml` 已 apply

---

## 3. 相关路径

| 路径 | 说明 |
|------|------|
| `backend/internal/remotesensing/taskpaths.go` | P5-05 路径 helper |
| `backend/internal/remotesensing/worker_satellite.go` | P5-06b 队列过滤 |
| `k8s/phase5/rs-worker-daemonset.yaml` | P5-06b DaemonSet |
| `.gitlab-ci.yml` → `deploy-phase5-plus-pilot` | CI 一键部署 |
| [archives/2026-07-03_phase5-05-closure.md](./archives/2026-07-03_phase5-05-closure.md) | P5-05 收口 |
| [archives/2026-06-26_phase5-closure.md](./archives/2026-06-26_phase5-closure.md) | Phase 5 收口 |

---

*P5-06b 验收通过后更新 §2 状态并新建归档。*
