# 归档：Phase 2 收口（od-worker 独立检测）

> **归档日期**：2026-06-18  
> **阶段**：Phase 2 — RS 与 OD 计算分离（Pilot）  
> **状态**：**已闭合**（P2-03 通过；P2-04 并行压测 / GPU 留 Phase 2+）  
> **活跃运维**：[PHASE2_RUNBOOK.md](../PHASE2_RUNBOOK.md)  
> **前置**：[2026-06-18_phase1-closure.md](./2026-06-18_phase1-closure.md)

---

## 1. 架构（收口后）

```text
backend  ──rs.jobs──►  rs-worker（1～9）──od.jobs──►  od-worker（阶段 10）
```

- `SATELLITE_USE_OD_WORKER=true`（`k8s/phase1/rs-worker/deployment.yaml`）
- od-worker：同 backend 镜像，入口 `./od-worker`
- 融合产物跨 Pod：阶段 9 后 **同步 persist** 至 NFS，od-worker 读 `persist_output_preprocessing/fusion_envi/*.dat`

---

## 2. 部署时间线（摘要）

| 步骤 | 动作 | 结果 |
|------|------|------|
| 1 | `cmd/od-worker` + `od.jobs` 队列 + 流水线切分 | ✅ 代码合入 |
| 2 | CI `deploy-phase2-pilot`（自动） | ✅ od-worker + rs-worker rollout |
| 3 | task 141 全链路验收 | ✅ |

---

## 3. 首条 OD 分离全链路（task 141）

**benchmark**：`artifacts/benchmarks/phase2-test1/report.txt`（k8s-master）

| 项 | 值 |
|----|-----|
| task_id | 141 |
| rs.jobs stream_id | `1781756045690-0` |
| od.jobs stream_id | `1781756639739-0` |
| 端到端 | **1680.4 s (~28.0 min)** |
| RS 1～9（rs-worker） | ~594 s（入队 od 前） |
| stage 10 检测（od-worker） | **1044.4 s (~17.4 min)** |
| status | completed |

**路径验证**：

| 组件 | 日志 |
|------|------|
| backend | `任务已入队 Redis` → rs.jobs |
| rs-worker | `检测任务已入队 Redis` → od.jobs；**无 yolov8s** |
| od-worker | `od-worker 开始处理检测任务`；yolov8s 心跳与产物写入 |
| Redis | rs.jobs / od.jobs 均 `lag=0`，`pending=0` |

**融合输入（od-worker）**：

```text
/opt/remote-sensing/persist_output_preprocessing/fusion_envi/GF2_PMS1_...-MSS1-fusion.dat
```

---

## 4. 与 Phase 1 对比（同输入 GF2）

| 指标 | Phase 1 task 140 | Phase 2 task 141 |
|------|------------------|------------------|
| 端到端 | ~28.3 min | ~28.0 min |
| RS 执行 Pod | rs-worker（含 stage 10） | rs-worker（仅 1～9） |
| 检测执行 Pod | rs-worker | **od-worker** |
| rs-worker 检测 CPU | 高（stage 10 占用） | 阶段 9 后释放 |

> 端到端时长接近，主要收益为 **计算隔离** 与 **独立扩缩/GPU 调度**，非单次 task 墙钟大幅缩短。

---

## 5. 固化项（代码仓）

| 文件 | 变更 |
|------|------|
| `backend/cmd/od-worker`、`internal/queue/od.go` | od.jobs 消费 |
| `backend/internal/remotesensing/od_dispatch.go` | 入队 + RunDetectionFromJob + 同步 persist |
| `k8s/phase2/` | od-worker Deployment |
| `k8s/phase1/rs-worker/deployment.yaml` | `USE_OD_WORKER=true` |
| `.gitlab-ci.yml` | `deploy-phase2-pilot`（自动 apply -k） |

---

## 6. 遗留 / 下一步

| 项 | 说明 |
|----|------|
| P2-04 | od-worker / rs-worker replicas>1 并行压测（可选） |
| GPU | od-worker `SATELLITE_OBJECT_DETECTION_DEVICE=gpu` + 节点池（Phase 2+） |
| **Phase 3** | Argo Workflows DAG — PAN RPC 阶段内并行 |

---

## 7. 回滚快照

```bash
# rs-worker deployment：SATELLITE_USE_OD_WORKER=false
kubectl apply -k k8s/phase1/
kubectl -n gitlab-runner scale deployment/od-worker --replicas=0
```

详见 [PHASE2_RUNBOOK.md](../PHASE2_RUNBOOK.md) §5。

---

*本文件为历史快照；日常操作以 PHASE2_RUNBOOK 为准。*
