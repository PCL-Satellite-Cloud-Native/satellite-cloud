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
| 2026-06-17 | Phase 1 Pilot 骨架（见 `k8s/phase1/`） | Redis + rs-worker K8s 清单；Queue 配置 env 占位 | [MICROSERVICES_IMPLEMENTATION_PLAN.md](../MICROSERVICES_IMPLEMENTATION_PLAN.md) §5 阶段 1、[k8s/phase1/README.md](../../k8s/phase1/README.md) |

---

## 目录约定

```text
docs/archives/
  ARCHIVE_INDEX.md          … 本文件
  _TEMPLATE.md              … 新归档复制用
  YYYY-MM-DD_<slug>.md      … 只读快照（不再改内容，勘误用新日期新文件）
```
