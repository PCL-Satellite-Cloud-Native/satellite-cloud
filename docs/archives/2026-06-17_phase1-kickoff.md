# 归档：Phase 1 启动（Redis + rs-worker 骨架）

> **归档日期**：2026-06-17  
> **阶段**：Phase 1 启动快照（**未验收**）  
> **状态**：进行中  
> **SSOT 后继**：[PHASE1_RUNBOOK.md](../PHASE1_RUNBOOK.md)

---

## 1. 背景

Phase 0 闭合后启动 Phase 1：API 与 RS 计算分离。本归档记录 **首次交付的骨架**（K8s + 代码 + 运维脚本），便于与后续「Phase 1 验收归档」区分。

## 2. 交付物

| 类别 | 路径 |
|------|------|
| K8s Pilot | `k8s/phase1/`（Redis、rs-worker、namespaces、kustomization） |
| Worker 入口 | `backend/cmd/rs-worker/main.go` |
| Redis 封装 | `backend/internal/queue/redis.go` |
| 配置 | `QueueConfig`；`SATELLITE_USE_INPROCESS_PIPELINE` 默认 `true` |
| 238 systemd | `scripts/ops/static-http-18080.service`、`install-static-http-18080.sh` |
| 归档机制 | `docs/archives/ARCHIVE_INDEX.md`、`_TEMPLATE.md`、`scripts/archive_docs_snapshot.sh` |
| Runbook | `docs/PHASE1_RUNBOOK.md` |

## 3. 刻意未做（下一阶段）

- ~~API `CreateTask` → `XADD rs.jobs`~~ → **已完成**（2026-06-17 续）
- ~~rs-worker 调用 `RunPipeline`~~ → **已完成**
- 现网 backend 设 `SATELLITE_USE_INPROCESS_PIPELINE=false`（需运维执行 switch 脚本）
- Phase 1 验收（3 星并行）

## 4. Pilot 部署命令

```bash
kubectl apply -f k8s/phase1/namespaces.yaml   # 可选
kubectl apply -k k8s/phase1/
```

## 5. 关联

- Phase 0 归档：[2026-06-17_phase0-closure.md](./2026-06-17_phase0-closure.md)

---

*验收完成后请新建 `YYYY-MM-DD_phase1-closure.md`，勿覆盖本文件。*
