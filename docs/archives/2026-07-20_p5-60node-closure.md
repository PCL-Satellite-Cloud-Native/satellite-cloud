# 归档：P5 60 节点首通收口（cluster-120）

> **状态**：**已正式收口** — `phase5_acceptance.sh` →「Phase 5+ 回归验收通过」  
> **日期**：2026-07-20  
> **分支**：`cluster-120` @ **`2b673f9`**  
> **运维节点**：sat10-m1  
> **场景**：`Scenario60_3x20`（scenario_id=3）  
> **会话全量归档**：外部运维笔记 `60node-platform-docs/runbooks/P5-60node-session-archive-20260720.md`（不在本仓库；本仓以本文与 Post-P5 收口为准）

---

## 准出结论

**P5 三锚点 RS+OD 全链路验收通过**（3/3 completed + 落点正确）。

| task_id | satellite_id | executed_sat_id | host_node_name | status |
|---------|--------------|-----------------|----------------|--------|
| 4 | 847 | sat-1-1 | sat1 | completed |
| 5 | 822 | sat-2-1 | sat21 | completed |
| 6 | 826 | sat-3-1 | sat41 | completed |

| run_id | 说明 |
|--------|------|
| `p5-60-20260717-1801` | task 1–3 失败（Argo PAN RPC） |
| **`p5-60-retry-20260720-0942`** | **正式准出** task 4–6 |

---

## 正式断言（2026-07-20 sat10-m1）

```bash
CLUSTER_PROFILE=60node MIN_DS_READY=50 \
  bash scripts/phase5_acceptance.sh \
  --run-id p5-60-retry-20260720-0942 \
  --api-base http://192.168.12.67:30080 \
  --no-submit --skip-preflight
```

```text
  OK   task 4 executed_sat_id=sat-1-1
  OK   task 4 host_node_name=sat1
  OK   task 5 executed_sat_id=sat-2-1
  OK   task 5 host_node_name=sat21
  OK   task 6 executed_sat_id=sat-3-1
  OK   task 6 host_node_name=sat41

Phase 5+ 回归验收通过
```

summary.csv 路径：`artifacts/benchmarks/p5-60-retry-20260720-0942/summary.csv`

---

## 关键配置（60 节点 DS）

| 变量 | 值 | 说明 |
|------|-----|------|
| `SATELLITE_USE_OD_WORKER` | `false` | 阶段 10 在锚点 rs-worker 本机跑 |
| `SATELLITE_USE_ARGO_PAN_RPC` | `false` | Argo 模板绑 RWO PVC，无法在锚点 hostPath 调度 |
| `SATELLITE_RS_SATELLITE_AWARE_QUEUE` | `true` | 任务绑定 satelliteId |
| `SATELLITE_RS_TASK_PATH_ISOLATION` | `true` | 产物 `persist_output_preprocessing/tasks/{id}/` |

Manifest：`k8s/phase5/rs-worker-daemonset-60.yaml`

| commit | 说明 |
|--------|------|
| `34abee7` | OD in-process + securityContext |
| `2b673f9` | 本归档 + CLUSTER120 阶段 G |

---

## 首通踩坑与处置

### 1. Argo PAN RPC 超时（task 1–3）

- **现象**：`pan_rpc_warp_quarters` 30m timeout；Workflow 无法挂锚点 PVC。
- **处置**：`SATELLITE_USE_ARGO_PAN_RPC=false`（进程内 pan_rpc）。

### 2. Redis `rs.jobs` 风暴

- **现象**：57 worker × 非本星 job ACK+re-XADD → XLEN 百万级。
- **处置**：`DEL rs.jobs` + `XGROUP CREATE`；**→ P0：非本星仅 XACK**。

### 3. od-worker 检测输入不存在（task 4–6 首次）

- **现象**：融合 `.dat` 在锚点 hostPath；od-worker 读 sat57 PVC。
- **处置**：`SATELLITE_USE_OD_WORKER=false` + DB resume 阶段 10。

### 4. 前端无产出预览（不阻塞 P5）

- **现象**：DB 有 artifacts；`GET .../artifacts/{id}` → **404**。
- **验证**：rs-worker 上检测瓦片存在；backend sat57 PVC 无文件。
- **→ P2：D0 MinIO 产物**。

### 5. 其他运维

- sat49/sat60：`securityContext` runAsUser 1000；坏镜像 crictl purge。
- Postgres：primary `postgres-2`；`psql` 需 `PGPASSWORD` + `-h 127.0.0.1`。
- API：Istio Gateway `:30080`；勿 port-forward。

---

## Post-P5 路线图

后续运维见 Post-P5 收口与 CLUSTER120 文档。

---

## 相关文档

- 外部运维笔记（若不在本机）：`60node-platform-docs/runbooks/P5-preflight-decisions.md`、`P5-60node-session-archive-20260720.md`
- [CLUSTER120_SAT10_STEPS.md](../CLUSTER120_SAT10_STEPS.md) 阶段 G
- [2026-07-23_post-p5-60node-closure.md](./2026-07-23_post-p5-60node-closure.md)
