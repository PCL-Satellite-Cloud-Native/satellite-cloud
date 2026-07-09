# Phase 6 — 入口说明（MinIO + 120 Node 扩容）

> **状态**：⏸ **未启动** — Phase 5+ 已闭合（2026-07-09）；待立项门禁评审  
> **SSOT 方案**：[MICROSERVICES_IMPLEMENTATION_PLAN.md](./MICROSERVICES_IMPLEMENTATION_PLAN.md) §阶段 6  
> **前置 Runbook**：[PHASE5_PLUS_RUNBOOK.md](./PHASE5_PLUS_RUNBOOK.md)（P5-05 / P5-06b 已验收）

---

## 1. 何时启动 Phase 6

满足 **多数** 下列条件时再立项（团队评审）：

| # | 条件 |
|---|------|
| 1 | Pilot 15 Node 稳定：`scripts/phase5_acceptance.sh --preflight-only` 通过 |
| 2 | 并行 task **≥5** 或第三方压测排期，且 **NFS 成为瓶颈** |
| 3 | **120 Node** 硬件 / 网络 / pilot-map 扩展方案明确 |
| 4 | 产物存储策略：MinIO（S3 API）试点或主存储已批准 |

Phase 5+ 收尾归档：[archives/2026-07-09_phase5-plus-closure.md](./archives/2026-07-09_phase5-plus-closure.md)

---

## 2. 分支策略（必须）

**所有 Phase 6 代码、manifest、CI job 在独立 feature 分支开发，不直接在 `main` 上改。**

```bash
git checkout main
git pull origin main
git checkout -b feat/phase6-minio    # 或 feat/phase6-scale-120
```

合并 `main` 前：

- `phase5_acceptance.sh` 在 pilot 集群通过
- Phase 6 自有 Runbook 章节或 `PHASE6_RUNBOOK.md` 草稿
- 不影响现有 DaemonSet rs-worker pilot（feature flag / 可选组件）

---

## 3. Phase 6 范围预览（未实施）

| 主题 | 方向 |
|------|------|
| 存储 | NFS 产物逐步迁 **MinIO**；`ArtifactAbsolutePath` 抽象 backend |
| 扩容 | 40 主机 / **120** 逻辑星；`pilot-map.json` 扩展 |
| 调度 | HPA / Argo parallelism 上调；Worker 无状态扩缩 |
| CI | 新 job 如 `deploy-phase6-pilot`（manual） |

---

## 4. 当前建议（2026-07-09）

1. 保持 **main** = Phase 5+ 稳定 pilot  
2. 运维偶发问题走 **PHASE5_PLUS_RUNBOOK.md §2.6**  
3. 定期：`bash scripts/phase5_acceptance.sh --preflight-only`  
4. STK 就绪 → 分支 `feat/phase5-07-stk` 做 P5-07（可与 Phase 6 并行规划，但建议独立分支）  
5. Phase 6 门禁会议通过 → **`git checkout -b feat/phase6-...`** 再开工

---

*本文档随 Phase 6 立项更新为正式 Runbook。*
