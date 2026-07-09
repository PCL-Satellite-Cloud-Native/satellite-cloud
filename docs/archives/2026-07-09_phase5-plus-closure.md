# 归档：Phase 5+ 收尾闭合（部署 + 冒烟 + 回归）

> **归档日期**：2026-07-09  
> **阶段 / 主题**：P5-05 / P5-06b 签收后的 pilot 稳态与 closure smoke  
> **状态**：**已闭合**  
> **SSOT**：[PHASE5_PLUS_RUNBOOK.md](../PHASE5_PLUS_RUNBOOK.md)  
> **前置**：[2026-07-08_phase5-06b-closure.md](./2026-07-08_phase5-06b-closure.md)

---

## 1. 摘要

Phase 5+ 功能签收（P5-05 路径隔离、P5-06b DaemonSet rs-worker）完成后，经 **CI/手工部署对齐**、**集群稳态检查**、**closure smoke** 与 **单星 retry**，pilot 15 节点基线可用于演示与后续 Phase 6 立项评审。

---

## 2. 部署与稳态（2026-07-08）

| 项 | 定稿状态 |
|----|----------|
| rs-worker | **DaemonSet**；Deployment **0/0**；**无 hpa/rs-worker** |
| 镜像 | `192.168.10.238/satellite/backend:latest`（Harbor 与 CI SHA 同步） |
| DaemonSet | ready **14/15**（worker22 Evicted 可接受） |
| Redis | PONG；`od.jobs` 消费者组 **od-workers**；lag=0 |
| od-worker | replicas=1；与 backend 同系列镜像 |
| CI | `deploy-phase5-plus-pilot`：phase5 仅 DaemonSet；`phase5_wait_ds_rollout.sh` 放宽 pilot 等待 |

---

## 3. Closure 验收

### p5-closure-smoke-0708

| task_id | satellite_id | executed_sat_id | host_node_name | status |
|---------|--------------|-----------------|----------------|--------|
| 235 | 4 | sat-1-1 | k8s-worker11 | completed |
| 236 | 26 | sat-2-1 | k8s-worker21 | completed |
| 237 | 48 | sat-3-1 | k8s-worker31 | **failed** |

**237 失败**：RS 阶段 5 `pan_merge_warp_square` — `中心点无法找到有效内接正方形`。  
四象限 `pan_warp_quarters` 四个 part 均 ~537M 存在 → **非 NFS 缺文件、非 P5-06b 调度**。

### p5-closure-retry-0709

| task_id | satellite_id | executed_sat_id | host_node_name | status |
|---------|--------------|-----------------|----------------|--------|
| 238 | 48 | sat-3-1 | k8s-worker31 | completed |

**三锚点结论**：235 / 236 / **238** → sat-1-1 @ worker11、sat-2-1 @ worker21、sat-3-1 @ worker31，**全链路 completed**。

---

## 4. 回归脚本

`scripts/phase5_acceptance.sh` — preflight + `submit_multi_satellite_tasks.sh` + 落点断言（P5-08）。

---

## 5. Phase 6 入口约定

**不在 `main` 上直接做 Phase 6 开发。** 立项后从 `main` 创建专用分支，例如：

```bash
git checkout main && git pull
git checkout -b feat/phase6-minio
```

详见 [PHASE6_README.md](../PHASE6_README.md)。

---

## 6. 外部产物

| 路径 | 说明 |
|------|------|
| `artifacts/benchmarks/p5-closure-smoke-0708/` | smoke summary |
| `artifacts/benchmarks/p5-closure-retry-0709/` | sat-3-1 retry |

---

*Phase 5+ 正式闭合；Phase 6 待门禁评审后在新分支启动。*
