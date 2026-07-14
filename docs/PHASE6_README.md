# Phase 6 — 入口说明（MinIO + 120 Node 扩容）

> **状态**：✅ **Phase 6 Pilot 已闭合**（2026-07-14）— 已合并 `main`；P6-05 待做  
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

## 2. 收口归档

正式收口：[archives/2026-07-14_phase6-closure.md](./archives/2026-07-14_phase6-closure.md)

后续 Phase 6 变更在 `main` 上开 feature 分支；合并前 `phase5_acceptance.sh --preflight-only` 仍须通过。

---

## 3. Phase 6 范围

| 主题 | 方向 | 状态 |
|------|------|------|
| 存储 | MinIO 试点 + `internal/storage` + NFS mirror | ✅ P6-01～04 |
| 扩容 | 120 逻辑星 / pilot-map | ⏸ P6-05 |
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
