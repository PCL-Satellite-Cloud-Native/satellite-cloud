# 归档：Phase 1 收口（Redis 入队 + rs-worker）

> **归档日期**：2026-06-18  
> **阶段**：Phase 1 — API 与 RS 计算分离（Pilot）  
> **状态**：**已闭合**（P1-01～P1-03 通过；P1-04/P1-05 并行压测留 Phase 1+ / Phase 2 前）  
> **活跃运维**：[PHASE1_RUNBOOK.md](../PHASE1_RUNBOOK.md)  
> **前置**：[2026-06-17_phase0-closure.md](./2026-06-17_phase0-closure.md)

---

## 1. 架构（收口后）

```text
satellite-backend (API)  ──XADD──►  Redis rs.jobs  ──XREADGROUP──►  rs-worker
       │  CreateTask / 查询                                              │ RunPipeline 1～10
       └─ 不算 RS Python                                                  └─ NFS 产物
```

- namespace：`gitlab-runner`（Pilot，与 Phase 0 相同）
- Redis：`deployment/redis`，Service `redis:6379`
- rs-worker：同 backend 镜像，入口 `./rs-worker`
- backend：`SATELLITE_USE_INPROCESS_PIPELINE=false`（已写入 `k8s/backend/deployment.yaml`）

---

## 2. 部署时间线（摘要）

| 步骤 | 动作 | 结果 |
|------|------|------|
| 0 | Redis 镜像推 Harbor；238 `:18080` systemd | ✅ |
| 1 | CI 构建含 `rs-worker` 的 backend 镜像 | ✅ |
| 2 | `deploy-phase1-pilot` / `kubectl apply -k k8s/phase1/` | ✅ redis + rs-worker Running |
| 3 | backend 切 Redis 模式（后固化进 deployment.yaml） | ✅ |
| 4 | task 140 全链路验证 | ✅ |

---

## 3. 首条 Redis 模式全链路（task 140）

**benchmark**：`artifacts/benchmarks/redis-test1/report.txt`（k8s-master）

| 项 | 值 |
|----|-----|
| task_id | 140 |
| stream_id | `1781690053637-0` |
| 端到端 | **1700.5 s (~28.3 min)** |
| RS 1～9 | ~575 s |
| stage 10 检测 | ~1126 s |
| status | completed |

**路径验证**：

| 组件 | 日志 |
|------|------|
| backend | `任务已入队 Redis` task_id=140 |
| rs-worker | `rs-worker 开始处理任务` task_id=140 |
| Redis | `last-delivered-id=1781690053637-0`，`lag=0`，`pending=0` |

---

## 4. 与 Phase 0 对比

| 指标 | Phase 0（单 Pod） | Phase 1 task 140 |
|------|-------------------|------------------|
| 端到端 median | ~45.7 min | ~28.3 min |
| RS 执行位置 | backend Pod | rs-worker Pod |
| backend NFS 写 | 高 | 近 0（仅 API） |

> task 140 更快可能含节点负载/缓存差异；并行压测（P1-05）未在本归档完成。

---

## 5. 固化项（代码仓）

| 文件 | 变更 |
|------|------|
| `k8s/backend/deployment.yaml` | Redis 队列 env 写入 manifest |
| `k8s/phase1/` | redis、rs-worker Pilot |
| `.gitlab-ci.yml` | `deploy-phase1-pilot` 手动 job |
| `backend/cmd/rs-worker`、`internal/queue` | 消费与 RunPipeline |

---

## 6. 遗留 / 下一步

| 项 | 说明 |
|----|------|
| P1-04 / P1-05 | rs-worker replicas=3 + 3 并行 GF2（可选） |
| Phase 2 | od-worker 独立 Pod + GPU 池 |
| 目标态 namespace | `satellite-control` / `satellite-compute-rs`（Pilot 仍用 gitlab-runner） |

---

## 7. 回滚快照

```bash
# deployment.yaml 中 SATELLITE_USE_INPROCESS_PIPELINE=true
# kubectl apply + scale rs-worker 0
```

详见 [PHASE1_RUNBOOK.md](../PHASE1_RUNBOOK.md) §5。

---

*本文件为历史快照；日常操作以 PHASE1_RUNBOOK 为准。*
