# 归档：Phase 4 可观测与多 task 队列收口

> **归档日期**：2026-06-24  
> **阶段**：Phase 4 — Prometheus 指标 + Grafana + HPA + 多 task 压测  
> **状态**：**Phase 4 全量闭合**  
> **前置**：[2026-06-23_phase3-performance-closure.md](./2026-06-23_phase3-performance-closure.md)  
> **运维**：[PHASE4_RUNBOOK.md](../PHASE4_RUNBOOK.md)（只读参考）

---

## 1. 验收标准

| ID | 内容 | 结果 |
|----|------|------|
| P4-01 | Prometheus 指标（queue_depth / worker_active / task_duration） | ✅ 镜像 `e33e2ed7` |
| P4-02 | Grafana 仪表盘 + ServiceMonitor | ✅ `k8s/phase4/grafana/satellite-workers.json` |
| P4-03 | HPA（rs-worker 1→3 CPU 75%；od-worker 1→2 CPU 70%） | ✅ manifest 已部署 |
| P4-04 | 多 task 脚本 | ✅ `scripts/submit_n_remote_sensing_tasks.sh` |
| P4-05 | 压测 + 归档 | ✅ 见 §2 |

**环境约束**：无 GPU；od-worker 保持 CPU。

---

## 2. Benchmark 汇总

### 2.1 门禁 B — phase4-test1（3 路，早期 max-in-flight 默认）

| 指标 | 值 |
|------|-----|
| run_id | `phase4-test1` |
| task | 149–151 |
| 结果 | **3/3 completed** |
| 窗口 | ~49 min（有 in-flight 重叠） |

### 2.2 门禁 C — phase4-test10（10 路串行，定稿）

| 指标 | 值 |
|------|-----|
| run_id | `phase4-test10` |
| task | **173–182** |
| max_in_flight | **1**（同 filePrefix 串行） |
| 结果 | **10/10 completed** |
| 窗口 | 15:56 → 20:24（**~4h 28min**） |
| 报告 | `artifacts/benchmarks/phase4-test10/`（k8s-master） |

| task_id | elapsed (s) | pan_rpc (s) | detection (s) |
|---------|-------------|-------------|---------------|
| 173 | 1622 | 191 | 1047 |
| 174 | 1618 | 216 | 1056 |
| 175 | 1580 | 206 | 1043 |
| 176 | 1595 | 216 | 1051 |
| 177 | 1609 | 211 | 1052 |
| 178 | 1587 | 216 | 1058 |
| 179 | 1565 | 211 | 1028 |
| 180 | 1570 | 206 | 1050 |
| 181 | 1593 | 206 | 1061 |
| 182 | 1577 | 206 | 1057 |
| **均值** | **~1592** | **~208** | **~1050** |

相对 Phase 3 单路（task 148：总 ~1498 s，stage 4 ~186 s，检测 ~939 s）：串行 10 路性能稳定，stage 4 / 检测时长与单路同量级。

### 2.3 失败试验（归档记录，非定稿）

| run | 配置 | 结果 | 根因 |
|-----|------|------|------|
| phase4-test10 burst（task 152–171） | 10 路一次提交 / in-flight>1 | 多数 failed | 同 filePrefix 共享 NFS + `RemoveAll(workers/)` |
| phase4-test10 retry（task 162–171） | max-in-flight=3 | 2/10 completed | 同上，3 路仍并发写 persist |

**结论**：Phase 4 **不引入** task 级 NFS 隔离；同 prefix **必须 max-in-flight=1**。真正多路并发写同一景数据 → **Phase 5+**。

---

## 3. 生产签收（2026-06-24）

| 项 | 值 |
|----|-----|
| 镜像 | `192.168.10.238/satellite/backend:e33e2ed7` |
| Argo | P3-04b 不变（`USE_ARGO_PAN_RPC=true`） |
| 监控 SSOT | `monitoring` Grafana **30001** / Prometheus **30090** |
| RBAC 一次性 | `k8s/gitlab-runner-ci-rbac-phase4.yaml` |
| 指标 | `satellite_queue_depth`, `satellite_worker_jobs_active`, `satellite_task_duration_seconds`, `satellite_tasks_total` |

---

## 4. 固化产物

| 路径 | 说明 |
|------|------|
| `backend/internal/metrics/` | 指标实现 |
| `k8s/phase4/` | metrics Service、ServiceMonitor、HPA |
| `scripts/phase4_deploy.sh` | 一键部署 |
| `scripts/phase4_verify_metrics.sh` | 部署验收 |
| `scripts/submit_n_remote_sensing_tasks.sh` | 压测（默认 in-flight=1） |
| `scripts/phase4_abort_benchmark.sh` | 中止残留 task |

CI：手动 job `deploy-phase4-pilot`。

---

## 5. Phase 5+ 遗留（非 Phase 4 阻塞）

| 项 | 说明 |
|----|------|
| 同 prefix 多 task **并行** RS | 按 `task_id` 隔离 persist/scratch 路径 |
| 队列深度 HPA | 需 Prometheus Adapter + 自定义指标 |
| GPU od-worker | 集群暂无 GPU 节点 |
| MinIO / 扩容相关 | 见 Phase 6 文档 |

---

*Phase 4 正式闭合；日常运维见 PHASE4_RUNBOOK。*
