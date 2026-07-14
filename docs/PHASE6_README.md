# Phase 6 — 入口说明（MinIO + 120 Node 扩容）

> **状态**：✅ P6-01～04 Pilot 已签收；📋 **后续见 [路线图归档](./archives/2026-07-14_post-p6-pilot-60node-roadmap.md)**（60 节点新集群 + MinIO 主存储；P6-05 延后）  
> **Runbook**：[PHASE6_RUNBOOK.md](./PHASE6_RUNBOOK.md)  
> **SSOT 方案**：[MICROSERVICES_IMPLEMENTATION_PLAN.md](./MICROSERVICES_IMPLEMENTATION_PLAN.md) §阶段 6  
> **前置 Runbook**：[PHASE5_PLUS_RUNBOOK.md](./PHASE5_PLUS_RUNBOOK.md)（P5-05 / P5-06b 已验收）

---

## 1. 启动条件（已满足）

| # | 条件 | 状态 |
|---|------|------|
| 1 | Pilot 15 Node 稳定：`phase5_acceptance.sh --preflight-only` | ✅ |
| 2 | 并行压测 / NFS 瓶颈（按需） | 待压测 |
| 3 | 120 Node 方案 | ⏸ 规划 |
| 4 | MinIO 试点批准 | ✅ 立项 |

Phase 5+ 收尾：[archives/2026-07-09_phase5-plus-closure.md](./archives/2026-07-09_phase5-plus-closure.md)

---

## 2. 归档与路线图

| 文档 | 说明 |
|------|------|
| [2026-07-14_phase6-closure.md](./archives/2026-07-14_phase6-closure.md) | P6-01～04 Pilot 签收 |
| **[2026-07-14_post-p6-pilot-60node-roadmap.md](./archives/2026-07-14_post-p6-pilot-60node-roadmap.md)** | **后续执行计划**（60 节点新集群复制、MinIO 主存储、P6-05 延后） |

后续 Phase 6 变更在 `main` 上开 feature 分支；合并前 `phase5_acceptance.sh --preflight-only` 仍须通过。

---

## 3. Phase 6 范围

| 主题 | 方向 | 状态 |
|------|------|------|
| 存储 | MinIO 试点 + `internal/storage` + NFS mirror | ✅ P6-01～04 |
| 扩容 | 120 逻辑星 / pilot-map | ⏸ **延后**（见 [路线图](./archives/2026-07-14_post-p6-pilot-60node-roadmap.md)） |
| 60 节点 | **新集群复制**（非 15→60 原地扩） | 📋 待执行 |
| MinIO 主存储 | Worker 直写 + 生产 MinIO | 📋 阶段 2 |
| 调度 | HPA / Argo parallelism 上调 | ⏸ |
| CI | `deploy-phase6-pilot` | ✅ manual job |

---

## 4. 快速命令

```bash
# 部署 MinIO（master 或 CI manual job）
kubectl apply -k k8s/phase6/

# 验收
bash scripts/phase6_preflight.sh

# MinIO Console（NodePort，与 Grafana 30001 同类）
# http://<node-ip>:30901  → bucket satellite-artifacts

# P6-04：NFS → MinIO 产物同步（新任务后增量）
bash scripts/sync_artifacts_nfs_to_minio.sh
bash scripts/sync_artifacts_nfs_to_minio.sh --verify-only
```

---

*正式 Runbook 见 [PHASE6_RUNBOOK.md](./PHASE6_RUNBOOK.md)。*
