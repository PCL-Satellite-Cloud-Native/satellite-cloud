# 归档：Phase 2 生产复验（磁盘压力修复后）

> **归档日期**：2026-06-22  
> **阶段**：Phase 2 — od-worker 独立检测（生产环境复验）  
> **状态**：**P2-03 再次通过**（task 143）；Phase 2 正式转入 Phase 3  
> **活跃运维**：[PHASE2_RUNBOOK.md](../PHASE2_RUNBOOK.md)  
> **首次收口**：[2026-06-18_phase2-closure.md](./2026-06-18_phase2-closure.md)（task 141）

---

## 1. 背景

| 事件 | 说明 |
|------|------|
| 2026-06-18 | task **141** 完成 Phase 2 首次收口（见 phase2-closure） |
| 2026-06-22 上午 | task 在 **k8s-worker22** 阶段 9 附近因 **ephemeral-storage** 被 **Evicted**；rs-worker scratch `emptyDir` 占满节点本地盘 |
| 修复 | 清理 worker22 NFS 中间产物；新 rs-worker Pod 调度至 **k8s-worker34**；`deploy-phase2-pilot` CI 因 SA RBAC 失败 → 分支 `765f679` 移除 CI 内 SA apply |
| 2026-06-22 下午 | 重新提交 GF2 全链路；task **143** 10 阶段 **completed** |

---

## 2. 验收任务（task 143）

**benchmark**（集群）：`artifacts/benchmarks/phase2-test3/report.txt`

| 项 | 值 |
|----|-----|
| task_id | **143** |
| od.jobs stream_id | `1782098863951-0` |
| 输入融合 | `GF2_PMS1_E118.6_N37.4_20160826_L1A0001792619-MSS1-fusion.dat` |
| 端到端 | **~1681.6 s (~28.0 min)** |
| stage 4 `pan_rpc_warp_quarters` | **174.6 s**（Phase 3 性能基线） |
| stage 10 检测（od-worker） | **~1070.7 s (~17.8 min)** |
| yolov8s | 1681 瓦片；289 含目标（bridge + harbor）；CPU |
| status | **completed** |

**时间线（od-worker，UTC+8 日志）**：

| 时刻 | 事件 |
|------|------|
| 11:27:43 | `od-worker 开始处理检测任务` |
| 11:28～11:44 | 心跳 `yolov8s 仍在运行`（约 17 min） |
| 11:45:34 | 目标识别完成；产物 `output_detection/rs_task_143/` |
| 11:46:12 | 任务 `status=completed` |

---

## 3. 路径验证（P2-03）

| 组件 | 结论 |
|------|------|
| rs-worker | 阶段 1～9 success；`检测任务已入队 Redis`；**无** yolov8s |
| od-worker | `开始处理检测任务`；yolov8s 完成；289 检测瓦片 + `detections.txt` 入库 |
| Redis | `od.jobs` `pending=0`，`lag=0` |
| 前端 | zip / stats 正常（与 task 141 相同验收项） |

---

## 4. 与 task 141 对比

| 指标 | task 141（2026-06-18） | task 143（2026-06-22） |
|------|------------------------|------------------------|
| 端到端 | ~1680 s | ~1682 s |
| stage 10 od-worker | ~1044 s | ~1071 s |
| stage 4 pan_rpc | ~203.9 s（test1） | **174.6 s**（test3） |
| 架构 | rs → od 双队列 | 相同 |
| 备注 | 首次收口 | 生产复验；worker 节点变更 |

> RS 1～9 墙钟受节点 IO / 磁盘压力影响；**Phase 3 PAN RPC 基线以 task 143 的 174.6 s 为准**。

---

## 5. 运维教训（写入 Runbook §8）

| 现象 | 根因 | 处理 |
|------|------|------|
| 卡在「融合堆栈 ENVI」/ Grafana disk-pressure | rs-worker **emptyDir** scratch 40Gi + 节点根盘紧张 | `kubectl describe node`；清理 NFS 中间产物；必要时 **cordon** 磁盘紧张节点 |
| Evicted Pod | `ephemeral-storage` 不足 | 删 Evicted Pod；确认新 Pod 调度到 scratch 充足节点 |
| CI `serviceaccounts "rs-worker" is forbidden` | gitlab-runner SA 无 SA 管理权 | 管理员一次性 apply SA + RBAC；CI **不** apply SA（见 PHASE2_RUNBOOK §3.3） |
| DB 旧 task 仍 running | Evicted 未写失败 | 手工 SQL 标 `failed`（非新任务硬性前提） |

---

## 6. 代码 / CI 整理（本归档同期）

| 项 | 分支 / commit | 说明 |
|----|---------------|------|
| CI SA 修复 | `feat/phase3-argo-pan-rpc` `765f679` | 从 deploy-phase1/2 移除 SA apply |
| Phase 3 manifest | 同上分支 | Argo + WorkflowTemplate + rs-worker 集成（`USE_ARGO_PAN_RPC=false`） |
| 建议 | merge → `main` | 集群 `git pull` 与 CI 一致后再 `deploy-phase3-pilot` |

---

## 7. 下一步 — Phase 3

1. 合并 `feat/phase3-argo-pan-rpc` → `main`（或集群跟踪 feature 分支）
2. k8s-master 一次性 Argo 引导（见 [PHASE3_RUNBOOK.md](../PHASE3_RUNBOOK.md) §3）
3. GitLab 手动 **deploy-phase3-pilot**
4. **P3-03**：同 GF2；stage 4 墙钟 **≤131 s**（相对 task 143 基线 174.6 s ↓25%）；通过后 `SATELLITE_USE_ARGO_PAN_RPC=true`

---

*本文件为历史快照；日常操作以 PHASE2_RUNBOOK / PHASE3_RUNBOOK 为准。*
