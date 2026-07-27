# Phase 6 — 入口说明（MinIO Pilot）

> **状态**：✅ P6-01～04 Pilot 已签收（2026-07-14）  
> **Runbook**：[PHASE6_RUNBOOK.md](./PHASE6_RUNBOOK.md)  
> **前置**：[PHASE5_PLUS_RUNBOOK.md](./PHASE5_PLUS_RUNBOOK.md)  
> **环境**：Pilot 15 节点（`main`）

---

## 1. Pilot 条件

| # | 条件 | 状态 |
|---|------|------|
| 1 | Pilot 15 Node 稳定 | ✅ |
| 2 | MinIO 试点 | ✅ P6-01～04 |

收尾：[archives/2026-07-09_phase5-plus-closure.md](./archives/2026-07-09_phase5-plus-closure.md)  
签收：[archives/2026-07-14_phase6-closure.md](./archives/2026-07-14_phase6-closure.md)

---

## 2. Phase 6 已完成范围（Pilot）

| 主题 | 状态 |
|------|------|
| MinIO 试点 + `internal/storage` + NFS mirror | ✅ |
| CI `deploy-phase6-pilot` | ✅ |

---

## 3. 快速命令

```bash
# 部署 MinIO（master 或 CI manual job）
kubectl apply -f k8s/phase6/
```

细节以 [PHASE6_RUNBOOK.md](./PHASE6_RUNBOOK.md) 为准。
