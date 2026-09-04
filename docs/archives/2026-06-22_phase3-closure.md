# 归档：Phase 3 收口（Argo PAN RPC 功能 Pilot）

> **归档日期**：2026-06-22  
> **阶段**：Phase 3 — Argo Workflows 阶段 4 PAN RPC 4 路并行（Pilot）  
> **状态**：**功能 Pilot 已闭合**（P3-03 task 144）；性能定稿见 [2026-06-23_phase3-performance-closure.md](./2026-06-23_phase3-performance-closure.md)  
> **活跃运维**：[PHASE3_RUNBOOK.md](../PHASE3_RUNBOOK.md)  
> **前置**：[2026-06-22_phase2-production-validation.md](./2026-06-22_phase2-production-validation.md)（task 143 基线）

---

## 1. 架构（收口后）

```text
backend ──rs.jobs──► rs-worker
                         ├─ 阶段 1～3、5～9（runPython，不变）
                         └─ 阶段 4 ──► Argo Workflow（4× pan_rpc step Pod）
                                    └── rs-worker 合并产物 → 5～9
                         └── od.jobs ──► od-worker（阶段 10，Phase 2 不变）

argo namespace          … workflow-controller（Harbor 镜像 v3.5.12）
WorkflowTemplate        … rs-pan-rpc-parallel（gitlab-runner）
ServiceAccount          … rs-worker（提交 WF）、argo-workflow（step Pod）
```

- 集群生产开关：`SATELLITE_USE_ARGO_PAN_RPC=true`（验收 task 144 时启用）
- 镜像：`192.168.10.238/satellite/backend:690fe2dc`
- 手动安装包（master 无 git 时）：`k8s/phase3/bundle/`

---

## 2. 部署时间线（摘要）

| 步骤 | 动作 | 结果 |
|------|------|------|
| 1 | CRD + `phase3-manual-install.yaml` + executor RBAC | ✅ controller Running |
| 2 | ConfigMap 修正（v3.5 移除 `containerRuntimeExecutor` / `workflowNamespaces`） | ✅ |
| 3 | `--managed-namespace=gitlab-runner` + hello workflow | ✅ Succeeded |
| 4 | WorkflowTemplate + `USE_ARGO_PAN_RPC=true` | ✅ |
| 5 | task 144 全链路验收 | ✅ 功能 / ⚠️ 性能 |

---

## 3. 首条 Argo PAN RPC 全链路（task 144）

**benchmark**：`artifacts/benchmarks/phase3-test1/report.txt`（k8s-master）

| 项 | 值 |
|----|-----|
| task_id | **144** |
| Workflow | `rs-pan-rpc-144-n8d8m` **Succeeded**（init-dirs + area1～4） |
| 并行节点 | k8s-worker31/33/35/12 |
| 端到端 | **1535.5 s (~25.6 min)** |
| stage 4 `pan_rpc_warp_quarters` | **212.7 s** |
| status | **completed** |

**Argo 路径验证（rs-worker）**：

```text
Argo PAN RPC enabled
Argo PAN RPC：同步 pan_rad_toa 至 NFS
已提交 Argo Workflow: rs-pan-rpc-144-n8d8m
Argo Workflow 完成: rs-pan-rpc-144-n8d8m
RPC 分块完成（Argo 4 路并行） mode=argo_workflow_parallel
```

**Phase 2 路径（od-worker）**：检测入队 `od.jobs` → yolov8s → **completed**（与 task 143 一致）。

---

## 4. P3-03 验收判定

| 项 | 标准 | task 144 | 判定 |
|----|------|----------|------|
| Workflow | Succeeded；4 step 完成 | ✅ 5/5 节点 | **通过** |
| rs-worker | Argo 驱动 stage 4 | ✅ `argo_workflow_parallel` | **通过** |
| od-worker | 阶段 10 独立检测 | ✅ | **通过** |
| 端到端 | 10 阶段 completed | ✅ | **通过** |
| **stage 4 性能** | **≤131 s**（相对 143 的 174.6 s ↓25%） | **212.7 s** | **未通过** |

### 4.1 与 Phase 2 基线对比（同输入 GF2）

| 指标 | task 143（Phase 2） | task 144（Phase 3 Argo） | 变化 |
|------|---------------------|--------------------------|------|
| stage 4 `pan_rpc_warp_quarters` | **174.6 s** | **212.7 s** | **+22%（变慢）** |
| 端到端 | ~25.6 min | ~25.6 min | 接近 |
| stage 4 执行方式 | rs-worker 进程内 goroutine | 4 Argo step Pod + NFS 同步/合并 | 架构切换 |

**stage 4 耗时粗分（task 144）**：

| 段 | 约 s | 说明 |
|----|------|------|
| NFS 同步 pan_rad_toa | ~16 | Argo 提交前 |
| Argo Workflow 墙钟 | ~189 | 含 init-dirs + 4 并行 step |
| 合并产物回 scratch | ~7 | Workflow 完成后 |
| **DB stage 合计** | **~213** | 与 report 一致 |

> **结论**：Phase 3 **验证了 Argo 编排可行**，但当前 NFS + 多 Pod 开销使 stage 4 **未优于** Phase 2 进程内并行；性能优化单列 **P3-04**。

---

## 5. 固化项（代码仓）

| 路径 | 说明 |
|------|------|
| `backend/internal/argo/client.go` | 提交 / 等待 Workflow |
| `backend/internal/remotesensing/pan_rpc_argo.go` | NFS 同步、合并、Argo 分支 |
| `k8s/phase3/workflows/workflowtemplate-pan-rpc.yaml` | 4 路 Template |
| `k8s/phase3/argo/` | controller（空 ConfigMap + `--managed-namespace`） |
| `k8s/phase3/bundle/` | master 手动 scp 安装包 |
| `k8s/phase3/argo/rbac/gitlab-runner-workflow-executor.yaml` | step Pod SA |
| `.gitlab-ci.yml` | `deploy-phase3-pilot`（manual） |

**集群一次性 RBAC**（管理员）：`k8s/gitlab-runner-ci-rbac-phase3.yaml`、`gitlab-runner-ci-rbac-argo-ns.yaml`

---

## 6. 后续（已转至性能归档）

P3-04 性能优化与定稿见 **[2026-06-23_phase3-performance-closure.md](./2026-06-23_phase3-performance-closure.md)**（task 146 / P3-04b 定稿；stretch ≤131 s 未达）。

---

## 7. 回滚快照

```bash
# 关闭 Argo PAN RPC，回到 Phase 2 进程内并行
kubectl -n gitlab-runner set env deployment/rs-worker SATELLITE_USE_ARGO_PAN_RPC=false
kubectl -n gitlab-runner rollout status deployment/rs-worker

# 可选：保留 argo namespace / controller，仅停止调用
```

详见 [PHASE3_RUNBOOK.md](../PHASE3_RUNBOOK.md) §4.4。

---

*本文件为历史快照；日常操作与性能跟进以 PHASE3_RUNBOOK 为准。*
