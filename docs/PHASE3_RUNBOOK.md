# Phase 3 运维手册（Argo Workflows — 阶段内并行）

> **状态（2026-06-18）**：**实施中** — 分支 `feat/phase3-argo-pan-rpc`：manifest + rs-worker 集成已合入；`USE_ARGO_PAN_RPC` 默认 **false**，验收后启用。  
> **前置**：[PHASE2_RUNBOOK.md](./PHASE2_RUNBOOK.md)（Phase 2 已闭合，task 141）。  
> **架构**：[MICROSERVICES_IMPLEMENTATION_PLAN.md](./MICROSERVICES_IMPLEMENTATION_PLAN.md) §5 阶段 3。  
> **Argo 安装**：[k8s/phase3/argo/INSTALL_CHECKLIST.md](../k8s/phase3/argo/INSTALL_CHECKLIST.md)

---

## 1. 目标架构（Phase 3）

**Phase 2 现状**：rs-worker 进程内串行跑 1～9（阶段 4 PAN RPC 已在 Go 内 goroutine 分组，但仍在单 Pod 内）。

**Phase 3 增量**：用 **Argo Workflows** 把 **可并行阶段** 拆成 DAG Step Pod（Pilot 先做 **阶段 4 PAN RPC 4 路**），其余阶段仍由 rs-worker 驱动，**不推翻** Redis + od-worker 队列。

```text
backend ──rs.jobs──► rs-worker
                         │
                         ├─ 阶段 1～3、5～9（现有 runPython，不变）
                         │
                         └─ 阶段 4 PAN RPC ──► Argo Workflow（4 并行 step Pod）
                                    │
                                    └── 完成后 rs-worker 继续 5～9
                         │
                         └── od.jobs ──► od-worker（阶段 10，Phase 2 不变）
```

| 组件 | 职责 |
|------|------|
| `argo` namespace | workflow-controller（集群级） |
| `WorkflowTemplate` | `rs-pan-rpc-parallel`（4× `pan_rpc_warp_quarters.py`） |
| `rs-worker` | 创建/等待 Workflow；更新 DB stage 4 |
| `redis` / `od-worker` | **不变** |

**Pilot namespace**：继续 `gitlab-runner`（与 Phase 1/2 一致）；Controller 建议装 `argo` 全局 namespace。

---

## 2. 分步实施计划

| 步骤 | 内容 | 产出 | 状态 |
|------|------|------|------|
| **0** | 基线 | task 141 `pan_rpc` **203.9 s**（`phase2-test1/report.txt`） | ☑ |
| **1** | Argo 安装 + RBAC | [INSTALL_CHECKLIST.md](../k8s/phase3/argo/INSTALL_CHECKLIST.md) 全部勾选 | ☑ 集群已装 |
| **2** | WorkflowTemplate | `k8s/phase3/workflows/workflowtemplate-pan-rpc.yaml` | ☑ |
| **3** | rs-worker 集成 | `SATELLITE_USE_ARGO_PAN_RPC`；`internal/argo/` | ☑ 默认 false |
| **4** | CI | `deploy-phase3-pilot` job（manual） | ☑ |
| **5** | **P3-03 验收** | 同 GF2；stage 4 墙钟 **≤152 s**（↓25%） | ☐ |
| **6** | 归档 | `archives/YYYY-MM-DD_phase3-closure.md` | ☐ |

> 步骤 2～4 未合入前，集群保持 Phase 2 行为；`USE_ARGO_PAN_RPC=false`（默认）。

---

## 3. 步骤 1 — Argo 安装（摘要）

完整清单见 **[k8s/phase3/argo/INSTALL_CHECKLIST.md](../k8s/phase3/argo/INSTALL_CHECKLIST.md)**。

**首次部署前（k8s-master，root，一次性）**：

```bash
cd ~/code/satellite-cloud && git pull origin main
bash scripts/ops/install_argo_crds.sh
kubectl apply -f k8s/gitlab-runner-ci-rbac-phase3.yaml
kubectl apply -f k8s/phase1/rs-worker/serviceaccount.yaml
kubectl apply -f k8s/phase3/argo/rbac/gitlab-runner-workflow-submitter.yaml
kubectl apply -k k8s/phase3/argo/
kubectl apply -f k8s/phase3/argo/rbac/controller-clusterrole.yaml
kubectl apply -f k8s/phase3/argo/gitlab-runner-ci-rbac-argo-ns.yaml
kubectl apply -k k8s/phase3/
```

之后 GitLab CI `deploy-phase2-pilot` / `deploy-phase3-pilot` 方可正常 apply。

```bash
# 238：镜像入 Harbor
bash scripts/ops/mirror_argo_workflows_images.sh

# CI 或手动：controller + template
kubectl apply -k k8s/phase3/argo/
kubectl apply -k k8s/phase3/

# 验收
kubectl -n argo get deploy,pod
kubectl get crd workflows.argoproj.io workflowtemplates.argoproj.io
```

---

## 4. 步骤 2～3 — Workflow 与 rs-worker（已合入）

### 4.1 路径

| 路径 | 说明 |
|------|------|
| `k8s/phase3/workflows/workflowtemplate-pan-rpc.yaml` | 4 路并行 PAN RPC |
| `backend/internal/argo/client.go` | 提交 / 等待 Workflow |
| `backend/internal/remotesensing/pan_rpc_argo.go` | 同步 pan_rad → NFS、合并产物 |

Argo step Pod 读 **NFS** 上 `persist_output_preprocessing/pan_rad_toa`（rs-worker 提交前从 scratch 同步）。

### 4.2 环境变量（rs-worker）

| 变量 | 默认 | 说明 |
|------|------|------|
| `SATELLITE_USE_ARGO_PAN_RPC` | `false` | `true` 时阶段 4 走 Argo |
| `SATELLITE_ARGO_NAMESPACE` | `gitlab-runner` | Workflow 提交 namespace |
| `SATELLITE_ARGO_PAN_RPC_TEMPLATE` | `rs-pan-rpc-parallel` | WorkflowTemplate 名 |
| `SATELLITE_RS_WORKFLOW_IMAGE` | backend 镜像 | 与 rs-worker 同 SHA |

### 4.3 启用（P3-03 前，默认 false）

```bash
kubectl -n gitlab-runner set env deployment/rs-worker \
  SATELLITE_USE_ARGO_PAN_RPC=true \
  SATELLITE_RS_WORKFLOW_IMAGE=192.168.10.238/satellite/backend:<SHA>
kubectl -n gitlab-runner rollout status deployment/rs-worker
```

### 4.4 回滚

```bash
kubectl apply -k k8s/phase1/   # rs-worker env USE_ARGO_PAN_RPC=false
# 不删除 argo namespace；仅关闭调用
```

---

## 5. 步骤 4 — CI

```text
build-backend → deploy → deploy-phase2-pilot（自动）
deploy-phase3-pilot（manual，需时点击）
```

`deploy-phase3-pilot` 建议在 `deploy-phase2-pilot` 绿了之后手动触发（Argo / WorkflowTemplate / Argo RBAC + rs-worker Phase 3 env）。

```yaml
# .gitlab-ci.yml — deploy-phase3-pilot（manual）
deploy-phase3-pilot:
  when: manual
  needs:
    - deploy-phase2-pilot
```

---

## 6. 验收（P3-03）

### 6.1 功能

提交 **1 条 GF2 + 检测**（与 Phase 2 相同输入）：

```bash
TASK_ID=<id>
kubectl -n gitlab-runner get workflow -l satellite.io/task-id=$TASK_ID
kubectl -n gitlab-runner logs deploy/rs-worker --since=2h | grep -E "$TASK_ID|Workflow|pan_rpc"
# od-worker / 10 阶段仍应 success（Phase 2 路径不变）
```

| 项 | 通过标准 |
|----|----------|
| Argo | Workflow **Succeeded**；4 个 PAN RPC step 均完成 |
| rs-worker | stage 4 由 Argo 驱动；**无** 进程内 680s 级 pan_rpc 日志块 |
| 端到端 | 10 阶段 completed；前端正常 |
| **性能** | stage 4 墙钟 **≤ 152 s**（相对 203.9 s 基线 ↓25%） |

### 6.2 Benchmark 记录

```bash
# 集群侧（与 phase2-test1 同格式）
artifacts/benchmarks/phase3-test1/report.txt
```

---

## 7. 故障排查

| 现象 | 处理 |
|------|------|
| Workflow Pending | 查 workflow-controller；节点资源；PVC mount |
| step Pod ImagePullBackOff | Harbor 补 backend / argoexec 镜像 |
| step 无 NFS 写权限 | 对齐 rs-worker volumeMount；init 目录 chmod |
| rs-worker 不提交 Workflow | `USE_ARGO_PAN_RPC`；RBAC（见安装清单 §5） |
| stage 4 变慢 | 查 4 step 是否真并行；节点 CPU 争抢；`parallelism` |

---

## 8. 相关路径

| 路径 | 说明 |
|------|------|
| [k8s/phase3/argo/INSTALL_CHECKLIST.md](../k8s/phase3/argo/INSTALL_CHECKLIST.md) | Argo 安装清单 |
| [k8s/phase3/argo/](../k8s/phase3/argo/) | Controller 清单（待增） |
| [scripts/ops/mirror_argo_workflows_images.sh](../scripts/ops/mirror_argo_workflows_images.sh) | 镜像推 Harbor |
| [MICROSERVICES_IMPLEMENTATION_PLAN.md](./MICROSERVICES_IMPLEMENTATION_PLAN.md) §5 阶段 3 | 方案 SSOT |

---

## 9. 不在 Phase 3 范围

- 全 10 阶段 Argo 化（后续扩展）
- 替换 Redis 队列
- GPU / MinIO / 120 星（Phase 2+ / 5 / 6）

*本文件随实施更新；收口后摘要进 `docs/archives/`。*
