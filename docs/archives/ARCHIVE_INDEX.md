# 文档归档索引

> **用途**：每次 **阶段收口**、**架构大改** 或 **集群里程碑** 后，将当时状态快照写入 `docs/archives/`，避免 SSOT Runbook 无限膨胀，同时保留可审计历史。  
> **原则**：活跃文档（Runbook、微服务方案）保留摘要 + 链接；完整数据、表格、日志摘要进归档。

---

## 何时归档

| 触发 | 动作 |
|------|------|
| Phase N 验收通过 | 新建 `YYYY-MM-DD_phaseN-closure.md` |
| 集群部署方式变更（如单 Pod → rs-worker） | 新建 `YYYY-MM-DD_<主题>.md` |
| 重大 CI/NFS/仓库机变更 | 在对应 Phase 归档中增 § 或单独归档 |

**Checklist（每次大更新后）**：

1. 写归档 Markdown（模板见 [\_TEMPLATE.md](./_TEMPLATE.md)）
2. 更新本表「归档列表」
3. 在 SSOT 文档（如 `K8S_BASELINE_RUNBOOK.md`、`PHASE1_RUNBOOK.md`）顶部或附录加 **「历史详见 archives/…」**
4. 若有 benchmark 原始文件，保留在集群或仓库 `artifacts/benchmarks/phaseN-*/`（不进 Git 大文件时可只写路径）

---

## 归档列表

| 日期 | 文件 | 摘要 | 关联 SSOT |
|------|------|------|-----------|
| 2026-06-17 | [2026-06-17_phase0-closure.md](./2026-06-17_phase0-closure.md) | Phase 0 三次 GF2 benchmark 收口；波动 2.8%；task 137/138/139 | [K8S_BASELINE_RUNBOOK.md](../K8S_BASELINE_RUNBOOK.md) §11、附录 A.4 |
| 2026-06-18 | [2026-06-18_phase1-closure.md](./2026-06-18_phase1-closure.md) | Phase 1 Redis 入队 + rs-worker 收口；task 140 全链路 ~28.3 min | [PHASE1_RUNBOOK.md](../PHASE1_RUNBOOK.md)、[MICROSERVICES_IMPLEMENTATION_PLAN.md](../MICROSERVICES_IMPLEMENTATION_PLAN.md) §5 阶段 1 |
| 2026-06-18 | [2026-06-18_phase2-closure.md](./2026-06-18_phase2-closure.md) | Phase 2 od-worker 独立检测；task 141；rs→od 双队列 | [PHASE2_RUNBOOK.md](../PHASE2_RUNBOOK.md)、[MICROSERVICES_IMPLEMENTATION_PLAN.md](../MICROSERVICES_IMPLEMENTATION_PLAN.md) §5 阶段 2 |
| 2026-06-22 | [2026-06-22_phase2-production-validation.md](./2026-06-22_phase2-production-validation.md) | Phase 2 生产复验 task 143；Eviction/CI SA 教训；pan_rpc 基线 174.6 s | [PHASE2_RUNBOOK.md](../PHASE2_RUNBOOK.md) §8 |
| 2026-06-22 | [2026-06-22_phase3-closure.md](./2026-06-22_phase3-closure.md) | Phase 3 Argo PAN RPC **功能** Pilot；task 144；stage 4 212.7 s | [PHASE3_RUNBOOK.md](../PHASE3_RUNBOOK.md) |
| 2026-06-23 | [2026-06-23_phase3-performance-closure.md](./2026-06-23_phase3-performance-closure.md) | Phase 3 **正式归档**；P3-04b；生产 `dd4bc728`；task 146 **165.4 s** | [PHASE4_RUNBOOK.md](../PHASE4_RUNBOOK.md) |
| 2026-06-11 | [2026-06-11_phase5-ephem-id-bridge.md](./2026-06-11_phase5-ephem-id-bridge.md) | Phase 5 **临时**星历 ID 桥接（sat-* ↔ Sat_6_6…）；STK 更新后回滚 | [PHASE5_RUNBOOK.md](../PHASE5_RUNBOOK.md) §5 |
| 2026-06-26 | [2026-06-26_phase5-closure.md](./2026-06-26_phase5-closure.md) | Phase 5 **正式归档**；p5-multi-3sat-v4；placement 修复；P5-05 遗留 | [PHASE5_RUNBOOK.md](../PHASE5_RUNBOOK.md) |
| 2026-07-03 | [2026-07-03_phase5-05-closure.md](./2026-07-03_phase5-05-closure.md) | P5-05 NFS 路径隔离收口；p5-path-v4-0703 **3/3**；2T NFS 扩容 | [PHASE5_PLUS_RUNBOOK.md](../PHASE5_PLUS_RUNBOOK.md) §1 |
| 2026-07-08 | [2026-07-08_phase5-06b-closure.md](./2026-07-08_phase5-06b-closure.md) | P5-06b DaemonSet rs-worker + 卫星感知队列；p5-6b-v2-0707 **3/3** | [PHASE5_PLUS_RUNBOOK.md](../PHASE5_PLUS_RUNBOOK.md) §2 |
| 2026-07-09 | [2026-07-09_phase5-plus-closure.md](./2026-07-09_phase5-plus-closure.md) | Phase 5+ 收尾；closure smoke + retry；P5-08 脚本 | [PHASE5_PLUS_RUNBOOK.md](../PHASE5_PLUS_RUNBOOK.md) §2.7 |
| 2026-07-13 | [2026-07-13_phase6-minio-pilot-deploy.md](./2026-07-13_phase6-minio-pilot-deploy.md) | P6-01 MinIO Pilot；PVC/NFS/CrashLoop；hostPath@worker22 定稿 | [PHASE6_RUNBOOK.md](../PHASE6_RUNBOOK.md) §2 |
| 2026-07-14 | [2026-07-14_phase6-storage-sync-api-closure.md](./2026-07-14_phase6-storage-sync-api-closure.md) | P6-03/04 NFS mirror 298GiB + API MinIO 下载签收 | [PHASE6_RUNBOOK.md](../PHASE6_RUNBOOK.md) §3–§4 |
| 2026-07-14 | [2026-07-14_phase6-closure.md](./2026-07-14_phase6-closure.md) | **Phase 6 Pilot 正式收口**；CI deploy-phase6-pilot；Console NodePort 30901 | [PHASE6_RUNBOOK.md](../PHASE6_RUNBOOK.md) |
| 2026-07-14 | [2026-07-14_post-p6-pilot-60node-roadmap.md](./2026-07-14_post-p6-pilot-60node-roadmap.md) | **后续路线图**：60 节点新集群复制、MinIO 主存储三阶段、P6-05 延后 | [PHASE6_README.md](../PHASE6_README.md) |
| 2026-07-20 | [2026-07-20_p5-60node-closure.md](./2026-07-20_p5-60node-closure.md) | **P5 60 节点首通** cluster-120；task 4/5/6 **3/3**；OD hostPath + artifact 404 已知限制 | [CLUSTER120_SAT10_STEPS.md](../CLUSTER120_SAT10_STEPS.md) 阶段 G |

---

## 目录约定

```text
docs/archives/
  ARCHIVE_INDEX.md          … 本文件
  _TEMPLATE.md              … 新归档复制用
  YYYY-MM-DD_<slug>.md      … 只读快照（不再改内容，勘误用新日期新文件）
```
