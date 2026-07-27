# Phase 5 运维手册（拓扑关联）

> **状态（2026-06-26）**：**Phase 5 已闭合** — 详见 [archives/2026-06-26_phase5-closure.md](./archives/2026-06-26_phase5-closure.md)  
> **前置**：[Phase 4 归档](./archives/2026-06-24_phase4-closure.md)  

---

## 0. Phase 5 目标（已达成）

| 维度 | Phase 4（已闭合） | Phase 5（本阶段） |
|------|-------------------|-------------------|
| 可观测 | Prometheus / Grafana / HPA | 任务 ↔ 卫星 / 场景绑定 ✅ |
| 多 task | 同 prefix 串行 10 路 | 不同 `satellite_id` 多 task 并行试点 ✅ |
| 前端 | 遥感任务页 | 拓扑页卫星高亮 + STK 命名 ✅ |
| 存储 | NFS | 仍 NFS；task 级路径隔离 **未做**（P5-05 遗留） |

---

## 1. 实施路线图（归档快照）

| ID | 内容 | 状态 | 产出 |
|----|------|------|------|
| **P5-01** | `scenario_id` / `satellite_id` 入库 + API + Redis + SSE | ✅ | migration `000008` |
| **P5-01b** | `host_node_name` / `executed_sat_id` | ✅ | migration `000009` |
| **P5-02** | 遥感选星；拓扑 running 高亮；`Sat_*` 显示名 | ✅ | `RemoteSensing.vue` / `SatTopology.vue` |
| **P5-03** | 节点标签 + Argo preferred affinity + placement | ✅ | `phase5_label_nodes.sh`、`worker-node-reader.yaml` |
| **P5-04** | 3 task × 3 不同 satellite 压测 | ✅ | `submit_multi_satellite_tasks.sh`；定稿 **p5-multi-3sat-v4** |
| **P5-05** | NFS 按 `task_id` 隔离 | ⏸ 遗留 | 见 §6 |

---

## 2. API 速查（仍有效）

### 2.1 创建任务

```http
POST /api/remote-sensing/tasks
Content-Type: application/json

{
  "filePrefix": "GF2_PMS1_E118.6_N37.4_20160826_L1A0001792619",
  "inputDirectory": "input",
  "scenarioId": 2,
  "satelliteId": 4,
  "enableDetection": true
}
```

- `satelliteId` = `satellites.id`（DB 主键），非 `sat-1-1` 字符串
- **`satellite_id`**：用户指定绑定；**`executed_sat_id`**：rs-worker 实际所在节点（二者可不同）

### 2.2 拓扑 API

```bash
curl -s http://<backend>/api/topology/t0 | jq 'length'          # Pilot 下期望 15
curl -s http://<backend>/api/topology/pilot-map | jq '.nodes | length'
curl -s http://<backend>/api/topology/delay
curl -s 'http://<backend>/api/topology/router?center=sat-1-1'
```

### 2.3 集群一次性配置

```bash
bash scripts/phase5_label_nodes.sh --apply
kubectl apply -f k8s/phase5/worker-node-reader.yaml
kubectl get nodes -L satellite.io/id
```

---

## 3. 压测脚本（P5-04）

```bash
# 自动从 pilot-map 选 N 颗不同星
bash scripts/submit_multi_satellite_tasks.sh \
  --run-id p5-multi-$(date +%m%d) \
  --api-base http://127.0.0.1:8080 \
  --scenario-id 2 \
  --count 3

# 手动指定 DB 主键（推荐验收）
bash scripts/submit_multi_satellite_tasks.sh \
  --run-id p5-multi-3sat \
  --api-base http://127.0.0.1:8080 \
  --scenario-id 2 \
  --satellite-ids 4,26,48
```

**警告**：同 `filePrefix` 并行仍可能 NFS 冲突（P5-05 未完成前谨慎解读）。

---

## 4. 命名约定

| 层级 | 格式 | 示例 |
|------|------|------|
| 页面显示 | `Sat_{p}_{s}`（STK） | `Sat_1_1` |
| 业务 ID | `sat-{p}-{s}` | `sat-1-1` |
| K8s 标签 | `satellite.io/id` | `sat-1-1` |
| 部署节点 | K8s 主机名 | `k8s-worker11` |

SSOT：`backend/internal/pilotcluster/pilot-map.json`

---

## 5. 临时：星历 ID 桥接

Pilot `sat-1-1` 与 DB/CSV 星历 `Sat_6_6…Sat_8_10` 不一致时，API 用 **+5/+5** 偏移取坐标。

| 项 | 说明 |
|----|------|
| 代码 | `backend/internal/pilotcluster/ephem.go` |
| 归档 | [archives/2026-06-11_phase5-ephem-id-bridge.md](./archives/2026-06-11_phase5-ephem-id-bridge.md) |
| 退役 | STK 重新 import 后按归档 §6 删除桥接 |

---

## 6. P5-05 遗留（task 路径隔离）

Phase 4 结论：同 `filePrefix` 并行写 NFS 可能冲突。隔离方案：

```
persist_output_preprocessing/tasks/{task_id}/pan_warp_quarters/...
output_preprocessing/tasks/{task_id}/...
```

完成后可重测同 prefix 多路并行。详见 closure 归档 §5。

---

## 7. 相关路径

| 路径 | 说明 |
|------|------|
| [archives/2026-06-26_phase5-closure.md](./archives/2026-06-26_phase5-closure.md) | **Phase 5 收口归档** |
| `backend/internal/pilotcluster/` | Pilot 映射 |
| `frontend/src/view/SatTopology.vue` | 拓扑主视图 |
| [PHASE4_RUNBOOK.md](./PHASE4_RUNBOOK.md) | Phase 4（只读） |

---

*Phase 5 已闭合；后续变更请更新 closure 归档或新建 Phase 5+ 文档，勿无限扩写本文。*
