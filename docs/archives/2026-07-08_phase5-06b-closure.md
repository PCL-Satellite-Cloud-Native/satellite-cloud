# 归档：P5-06b 按节点 rs-worker + 卫星感知消费收口

> **归档日期**：2026-07-08  
> **阶段 / 主题**：Phase 5+ / P5-06b — DaemonSet rs-worker、卫星感知 Redis、Argo required affinity  
> **状态**：**已闭合**  
> **SSOT 后继文档**：[PHASE5_PLUS_RUNBOOK.md](../PHASE5_PLUS_RUNBOOK.md) §2  
> **前置**：[2026-07-03_phase5-05-closure.md](./2026-07-03_phase5-05-closure.md)

---

## 1. 背景

P5-05 完成 NFS 按 `task_id` 隔离后，P5-06b 将 rs-worker 从单 Deployment 改为 **每节点 DaemonSet**，并实现：

- Redis `rs.jobs` **卫星感知消费**（非本星 ACK + 重新入队）
- Argo PAN RPC **required** nodeAffinity（`SATELLITE_ARGO_REQUIRED_NODE_AFFINITY=true`）
- od-worker **不覆盖** rs-worker 已写入的 `executed_sat_id` / `host_node_name`

---

## 2. 环境快照

| 项 | 值 |
|----|-----|
| 集群 | Pilot 15 Node（14/15 rs-worker Running；worker22 NFS Evicted 可接受） |
| namespace | `gitlab-runner` |
| rs-worker | **DaemonSet**（Deployment scaled **0/0**；**hpa/rs-worker 已删除**） |
| 定稿镜像 | `192.168.10.238/satellite/backend:a21d6643` |
| 关键 env | `SATELLITE_RS_SATELLITE_AWARE_QUEUE=true`、`SATELLITE_ARGO_REQUIRED_NODE_AFFINITY=true` |
| Pilot 映射 SSOT | `backend/internal/pilotcluster/pilot-map.json` |

---

## 3. 验收结果

| run_id | 结果 | 备注 |
|--------|------|------|
| p5-6b-0707 | 机制 2/3 | Redis LOADING、Deployment 双消费、od 覆盖落点 |
| **p5-6b-v2-0707** | **3/3 completed** | **定稿 sign-off** |

### 定稿 — p5-6b-v2-0707

| task_id | satellite_id | executed_sat_id | host_node_name | status |
|---------|--------------|-----------------|----------------|--------|
| 232 | 4 | sat-1-1 | k8s-worker11 | completed |
| 233 | 26 | sat-2-1 | k8s-worker21 | completed |
| 234 | 48 | sat-3-1 | k8s-worker31 | completed |

**通过项**：

- 3/3 任务级 `completed`
- `executed_sat_id` 与指定星 **sat-1-1 / sat-2-1 / sat-3-1** 一致
- `host_node_name` 为 **worker11 / worker21 / worker31**
- od-worker 日志：`保留 rs-worker 执行落点，od-worker 不覆盖`

**非阻塞观察**：

- 232/234 的 `object_detection` 阶段曾因 **重复 od.jobs** 显示 `running` + message「目标识别完成」（任务级已 completed）；代码已加 `shouldSkipODJob` 防护（待下一镜像部署）
- Redis `od.jobs` 积压 ~251 条（rs-worker resume 重复入队 + 消费者组丢失期间）

---

## 4. 关键修复与运维教训（迭代摘要）

| 问题 | 根因 | 修复 |
|------|------|------|
| Deployment rs-worker 1/1 双消费 | `hpa/rs-worker` minReplicas=1 拉回副本 | **删除 HPA**（Resource 指标无法 min=0）；Deployment scale 0 |
| DaemonSet 镜像未更新 | CI job 未跑完 / rollout 600s 超时 | 手工 `set image` + delete 旧 Pod |
| od.jobs 阶段 10 永久等待 | Redis 重启后 Stream 在、**消费者组 `od-workers` 丢失** | `XGROUP CREATE od.jobs od-workers 0`；代码：od-worker NOGROUP 时自动重建 |
| DB 落点被 od 覆盖 | `recordTaskPlacement` 无 guard | od-worker 跳过已设 `executed_sat_id` |
| 阶段 10 UI running + 消息完成 | 已完成 task 的重复 OD job 把 stage 改回 running | `shouldSkipODJob` + rs-worker 跳过重复 OD 入队 |

### Redis od.jobs 消费者组恢复（master）

```bash
REDIS=$(kubectl -n gitlab-runner get pod -l app=redis --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')
kubectl -n gitlab-runner exec "$REDIS" -c redis -- redis-cli XGROUP CREATE od.jobs od-workers 0
# 已存在则 BUSYGROUP，跳过
kubectl -n gitlab-runner exec "$REDIS" -c redis -- redis-cli XINFO GROUPS od.jobs
```

### P5-06b 部署检查清单

1. Redis `PONG`
2. `kubectl get deploy rs-worker` → **0/0**；**无 hpa/rs-worker**
3. DaemonSet rs-worker 镜像 = 当前 `BACKEND_IMAGE`；锚点 11/21/31 为新 tag
4. `od.jobs` 存在且 `XINFO GROUPS` 含 `od-workers`

---

## 5. 代码变更摘要（定稿后待 push / 部署）

| 路径 | 说明 |
|------|------|
| `k8s/phase5/rs-worker-daemonset.yaml` | DaemonSet |
| `k8s/phase5/rs-worker-deployment-scale.yaml` | Deployment replicas=0 |
| `.gitlab-ci.yml` → `deploy-phase5-plus-pilot` | 删 HPA、apply phase5 |
| `backend/internal/remotesensing/placement.go` | od 不覆盖 RS 落点 |
| `backend/internal/remotesensing/od_dispatch.go` | OD 重试 + `shouldSkipODJob` |
| `backend/cmd/od-worker/main.go` | NOGROUP 自动重建 consumer group |

---

## 6. 遗留项与非阻塞建议

| 项 | 说明 |
|----|------|
| od.jobs 积压清理 | lag 高时可 `scale od-worker 0` 后评估 `XTRIM` / 新组 `$`（无 running OD 任务时） |
| worker22 rs-worker Evicted | NFS 节点磁盘压力；pilot 可接受 14/15 |
| 阶段 10 DB 展示修复 | 对已 completed 任务执行 stage success SQL（见 Runbook §2.6） |
| **P5-07** | STK 对齐、移除 +5 星历桥接 |
| **P5-08** | `phase5_acceptance.sh` 回归脚本 |

---

## 7. 下一步决议

1. **P5-06b 正式闭合** — 本文归档  
2. **Phase 5+ 收尾** — [2026-07-09_phase5-plus-closure.md](./2026-07-09_phase5-plus-closure.md)  
3. Phase 6 → [PHASE6_README.md](../PHASE6_README.md)（**新分支** `feat/phase6-*`）  
4. 可选：P5-07 STK；`scripts/phase5_acceptance.sh` 定期回归

---

## 8. 外部产物路径

| 路径 | 说明 |
|------|------|
| `artifacts/benchmarks/p5-6b-v2-0707/summary.csv` | 定稿 summary（k8s-master） |
| `persist_output_preprocessing/tasks/{232,233,234}/` | NFS 隔离目录 |
| `backend/internal/pilotcluster/pilot-map.json` | 15 节点 ↔ sat_id 映射 |

---

*本文件为历史快照，后续变更请更新 SSOT Runbook，勿直接改本文。*
