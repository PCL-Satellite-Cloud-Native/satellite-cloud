# 归档：P5-05 NFS 按 task_id 路径隔离收口

> **归档日期**：2026-07-03  
> **阶段 / 主题**：Phase 5+ / P5-05 — NFS 中间产物按 `task_id` 隔离  
> **状态**：**已闭合**  
> **SSOT 后继文档**：[PHASE5_PLUS_RUNBOOK.md](../PHASE5_PLUS_RUNBOOK.md) §1  
> **前置**：[2026-06-26_phase5-closure.md](./2026-06-26_phase5-closure.md)

---

## 1. 背景

同 `filePrefix` 多 task 并行时，legacy 全局目录（如 `pan_warp_quarters/workers/`）会互相 `RemoveAll`，导致 NFS 冲突。P5-05 在 scratch 与 persist 根下插入 `tasks/{task_id}/` 段；并在 rs-worker 重启 / NFS 满盘等场景下补齐 recovery 与 resume 校验。

---

## 2. 环境快照

| 项 | 值 |
|----|-----|
| 集群 | Pilot 15 Node |
| namespace | `gitlab-runner` |
| NFS 服务器 | **192.168.10.112**（k8s-worker22） |
| NFS export | `/export/remote-sensing-data`（**2T vdb**，自 ~98G 迁移） |
| K8s PV/PVC | `remote-sensing-data` 元数据 500Gi |
| 关键 env | `SATELLITE_RS_TASK_PATH_ISOLATION=true` |
| 代码 SSOT | `backend/internal/remotesensing/taskpaths.go` |

---

## 3. 验收结果

| run_id | 结果 | 备注 |
|--------|------|------|
| p5-path-v2-0702 | 2/3 | task 219 NFS 100% 满盘 I/O error |
| p5-path-v3-0702 | 2/3 | 同上 |
| **p5-path-v4-0703** | **3/3 completed** | **定稿 sign-off** |

### 定稿 — p5-path-v4-0703

| task_id | satellite_id | executed_sat_id | host_node_name | status |
|---------|--------------|-----------------|----------------|--------|
| 220 | 4 | sat-1-1 | k8s-worker11 | completed |
| 221 | 26 | sat-1-1 | k8s-worker11 | completed |
| 222 | 48 | sat-1-2 | k8s-worker12 | completed |

**通过项**：

- 3/3 `completed`
- 多星绑定 4 / 26 / 48
- NFS 2T 扩容后无满盘 I/O 失败
- 路径隔离 + resume / recovery 在生产压测中稳定

**非阻塞观察**（P5-06b 范围）：

- `executed_sat_id` 与 `satellite_id` 指定星不完全对齐（单 rs-worker + preferred affinity）

---

## 4. 关键修复（迭代摘要）

| 问题 | 根因 | 修复 |
|------|------|------|
| task 204 orphan | rs-worker Pod 重启，`WaitWorkflowCompleted` 中断 | recovery / XAUTOCLAIM / Argo idempotency |
| task 215 failed | resume 跳过阶段但 merge 产物在旧 Pod emptyDir | `scratchDir()` 写 NFS persist + `stageOutputStillValid` |
| task 219 failed | NFS **100%** | 方案 C：vdb 2T + ops 脚本 |

---

## 5. 遗留项与非阻塞建议

| 项 | 说明 |
|----|------|
| legacy 全局目录清理 | `scripts/ops/cleanup_remote_sensing_nfs_legacy.sh`（无 running task 时） |
| vda 备份 | worker22 `/export/remote-sensing-data.vda-bak` 验证稳定后可删 |
| Grafana dashboard | Pod 重启后需 re-import `k8s/phase4/grafana/satellite-workers.json` |
| **P5-06b** | 按节点 rs-worker + required affinity（下一步） |

---

## 6. 下一步决议

1. **P5-05 正式闭合** — 本文归档  
2. **P5-06b** — per-node rs-worker、卫星感知 Redis 消费、Argo required nodeAffinity  
3. 可选：P5-07 STK 对齐、P5-08 回归脚本

---

## 7. 外部产物路径

| 路径 | 说明 |
|------|------|
| `artifacts/benchmarks/p5-path-v4-0703/summary.csv` | 定稿 summary（k8s-master） |
| `persist_output_preprocessing/tasks/{220,221,222}/` | NFS 隔离目录 |
| `scripts/ops/expand_remote_sensing_nfs.sh` | NFS 扩容运维 |
| `scripts/ops/cleanup_remote_sensing_nfs_legacy.sh` | legacy 清理 |

---

*本文件为历史快照，后续变更请更新 SSOT Runbook，勿直接改本文。*
