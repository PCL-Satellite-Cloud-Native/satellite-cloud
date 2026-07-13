# Phase 6 — 入口说明（MinIO + 120 Node 扩容）

> **状态**：🚧 **进行中** — 分支 `feat/phase6-minio`；P6-01 MinIO + 存储抽象  
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

## 2. 分支策略（必须）

**所有 Phase 6 代码、manifest、CI job 在 `feat/phase6-minio` 开发，合并前 review。**

```bash
git checkout main && git pull
git checkout -b feat/phase6-minio   # 已创建
```

合并 `main` 前：

- `phase5_acceptance.sh --preflight-only` 通过
- [PHASE6_RUNBOOK.md](./PHASE6_RUNBOOK.md) 与实测一致
- Phase 5+ DaemonSet rs-worker 不受影响（storage 默认 nfs）

---

## 3. Phase 6 范围

| 主题 | 方向 | 状态 |
|------|------|------|
| 存储 | MinIO 试点 + `internal/storage` | ✅ P6-01～03；P6-04 同步脚本 |
| 扩容 | 120 逻辑星 / pilot-map | ⏸ |
| 调度 | HPA / Argo parallelism 上调 | ⏸ |
| CI | `deploy-phase6-pilot` | 🚧 |

---

## 4. 快速命令

```bash
# 部署 MinIO（master 或 CI manual job）
kubectl apply -k k8s/phase6/

# 验收
bash scripts/phase6_preflight.sh

# P6-04：NFS → MinIO 产物同步（API minio 模式前）
bash scripts/sync_artifacts_nfs_to_minio.sh
bash scripts/sync_artifacts_nfs_to_minio.sh --verify-only
```

---

*正式 Runbook 见 [PHASE6_RUNBOOK.md](./PHASE6_RUNBOOK.md)。*
