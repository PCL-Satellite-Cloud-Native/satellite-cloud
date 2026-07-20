# 归档：P5 60 节点首通收口（cluster-120）

> **日期**：2026-07-20  
> **分支**：`cluster-120`  
> **运维节点**：sat10-m1  
> **场景**：`Scenario60_3x20`（scenario_id=3）

---

## 准出结论

**P5 三锚点 RS+OD 全链路验收通过**（API 维度：3/3 completed + 落点正确）。

| task_id | executed_sat_id | host_node_name | status |
|---------|-----------------|----------------|--------|
| 4 | sat-1-1 | sat1 | completed |
| 5 | sat-2-1 | sat21 | completed |
| 6 | sat-3-1 | sat41 | completed |

**run_id**：`p5-60-retry-20260720-0942`（task 4/5/6；前次 run task 1–3 因 Argo PAN RPC / OD 存储分裂失败）。

---

## 关键配置（60 节点 DS）

| 变量 | 值 | 说明 |
|------|-----|------|
| `SATELLITE_USE_OD_WORKER` | `false` | 阶段 10 在锚点 rs-worker 本机跑 |
| `SATELLITE_USE_ARGO_PAN_RPC` | `false` | Argo 模板绑 RWO PVC，无法在锚点 hostPath 调度 |
| `SATELLITE_RS_SATELLITE_AWARE_QUEUE` | `true` | 任务绑定 satelliteId |
| `SATELLITE_RS_TASK_PATH_ISOLATION` | `true` | 产物 `persist_output_preprocessing/tasks/{id}/` |

Manifest：`k8s/phase5/rs-worker-daemonset-60.yaml`（commit `34abee7`）。

---

## 首通踩坑与处置

### 1. Argo PAN RPC 超时（task 1–3）

- **现象**：`pan_rpc_warp_quarters` 30m timeout；Workflow 无法挂锚点 PVC。
- **处置**：`SATELLITE_USE_ARGO_PAN_RPC=false`（进程内 pan_rpc）。

### 2. od-worker 检测输入不存在（task 4–6 首次）

- **现象**：融合 `.dat` 在锚点 hostPath；od-worker 读 sat57 PVC。
- **处置**：`SATELLITE_USE_OD_WORKER=false`；DB resume 重跑阶段 10。

### 3. Redis `rs.jobs` 风暴

- **现象**：57 worker × 非本星 job ACK+re-XADD → XLEN 百万级。
- **处置**：`DEL rs.jobs` + `XGROUP CREATE`；**代码 backlog**：非本星仅 XACK。

### 4. 前端无产出预览

- **现象**：artifacts API 有记录；`GET .../artifacts/{id}` → **404**。
- **原因**：backend（sat57 PVC）≠ 产物（锚点 hostPath）。
- **验证**：rs-worker 上 `find .../rs_task_4` 有检测瓦片；curl artifact 404。
- **P5 判定**：**不阻塞**（completed + 落点为准）。

---

## 运维备忘

```bash
# API
--api-base http://192.168.12.67:30080

# Postgres primary
kubectl -n postgres get cluster postgres -o jsonpath='{.status.currentPrimary}'
# psql 须 PGPASSWORD + -h 127.0.0.1

# 正式断言（已有 completed task）
# 见 runbooks/P5-preflight-decisions.md §10.3
```

---

## 后续（非 P5 阻塞）

1. **D0** — MinIO 产物 Put + backend Open → 前端 artifact
2. **P6** — worker / queue metrics
3. **1441 动态拓扑**
4. **ReleaseRSJobForOtherConsumer** 修复；可选 `workflowtemplate-pan-rpc-60` hostPath
5. **sat57 backend** 坏镜像清理

---

## 相关文档

- [P5-preflight-decisions.md](../../../60node-platform-docs/runbooks/P5-preflight-decisions.md) §10
- [CLUSTER120_SAT10_STEPS.md](../CLUSTER120_SAT10_STEPS.md) 阶段 G
