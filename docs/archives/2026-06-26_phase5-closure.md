# 归档：Phase 5 拓扑关联收口

> **归档日期**：2026-06-26  
> **阶段**：Phase 5 — 任务 ↔ 卫星/场景绑定、拓扑高亮、Pilot 15 节点、多星压测  
> **状态**：**Phase 5 全量闭合**（P5-05 遗留为可选后续）  
> **前置**：[2026-06-24_phase4-closure.md](./2026-06-24_phase4-closure.md)  
> **运维**：[PHASE5_RUNBOOK.md](../PHASE5_RUNBOOK.md)（只读参考）  
> **分支**：`feat/phase5`（合并前 HEAD 含 `cc3f432` placement 修复）

---

## 1. 验收标准

| ID | 内容 | 结果 |
|----|------|------|
| P5-01 | `scenario_id` / `satellite_id` 入库 + API + Redis + SSE | ✅ migration `000008` |
| P5-01b | `host_node_name` / `executed_sat_id` 执行落点 | ✅ migration `000009` |
| P5-02 | 遥感选星；拓扑 running 高亮；STK 显示名 `Sat_*` | ✅ `RemoteSensing.vue` / `SatTopology.vue` |
| P5-03 | 节点标签 `satellite.io/id`；Argo **preferred** nodeAffinity；placement 记录 | ✅ `phase5_label_nodes.sh`、`worker-node-reader.yaml` |
| P5-04 | 3 task × 3 不同 `satelliteId` 压测 | ✅ **p5-multi-3sat-v4**（定稿，见 §2.4） |
| P5-05 | NFS 按 `task_id` 隔离 | ⏸ **未实施**（Phase 5+ / 可选迭代） |

**Pilot 环境**：15 K8s worker + 15 逻辑星（3 轨道面 × 5 星）；命名 SSOT `backend/internal/pilotcluster/pilot-map.json`。

---

## 2. Benchmark 汇总

### 2.1 E2E 单 task（门禁 A）

| 指标 | 值 |
|------|-----|
| 场景 | `scenario_id=2` |
| 验收 | 创建带 `satelliteId` 的任务 → `executed_sat_id` + `host_node_name` 入库 → 拓扑页绿色高亮 |
| 结果 | ✅ 通过 |

### 2.2 p5-multi-0626（早期 3 路）

| 指标 | 值 |
|------|-----|
| run_id | `p5-multi-0626` |
| task | 187–189 |
| 结果 | **3/3 completed** |
| 备注 | 仅 2 颗不同指定星（187/188 均 `satellite_id=50`）；执行落点 sat-3-3 @ worker33、sat-3-5 @ worker35 |

### 2.3 p5-multi-3sat-v3（指定 4/26/48，placement bug 未修）

| 指标 | 值 |
|------|-----|
| run_id | `p5-multi-3sat-v3` |
| 提交 | `satelliteId` **4 / 26 / 48**（sat-1-1 / sat-2-1 / sat-3-1） |
| task | 193–195 |
| 结果 | **3/3 completed** |
| `satellite_id` 入库 | ❌ 被 `recordTaskPlacement` 覆盖为 50/50/1（**已在 `cc3f432` 修复**） |
| 报告 | `artifacts/benchmarks/p5-multi-3sat-v3/`（k8s-master） |

### 2.4 定稿 — p5-multi-3sat-v4（placement 修复后）

| 指标 | 值 |
|------|-----|
| run_id | `p5-multi-3sat-v4` |
| 提交 | `--satellite-ids 4,26,48` |
| task | **196–198** |
| 结果 | **3/3 completed** |
| 报告 | `artifacts/benchmarks/p5-multi-3sat-v4/summary.csv` |

| task_id | satellite_id（指定） | executed_sat_id | host_node_name | status |
|---------|---------------------|-----------------|----------------|--------|
| 196 | 4 (sat-1-1) | sat-3-4 | k8s-worker34 | completed |
| 197 | 26 (sat-2-1) | sat-3-4 | k8s-worker34 | completed |
| 198 | 48 (sat-3-1) | sat-1-1 | k8s-worker11 | completed |

**解读**：

- **`satellite_id` 指定绑定**：✅ 196/197/198 全程保持 4/26/48（修复生效）
- **3 颗不同星提交 + 3 路并行完成**：✅ P5-04 签收
- **`executed_sat_id` ≠ 指定星**：⚠️ 预期内——当前 **rs-worker 单副本**，落点反映 **Pod 所在节点** 的 `satellite.io/id`，非 Argo 软亲和目标；196/197 同落 worker34

同 `filePrefix` 3 路并行本次未 NFS 冲突；**不能**视为 P5-05 已完成（见 §5）。

---

## 3. 生产签收（2026-06-26）

| 项 | 值 |
|----|-----|
| 分支 | `feat/phase5` → 待 merge `main` |
| 命名 | 页面 `Sat_{p}_{s}`；业务 ID `sat-{p}-{s}`；部署节点单独展示 |
| Pilot 映射 | `pilot-map.json`（15 node ↔ 15 sat） |
| 星历桥接 | 临时 +5 偏移，见 [2026-06-11_phase5-ephem-id-bridge.md](./2026-06-11_phase5-ephem-id-bridge.md) |
| 一次性集群 | `scripts/phase5_label_nodes.sh --apply`；`k8s/phase5/worker-node-reader.yaml` |

### 3.1 关键修复（归档记录）

| 问题 | 修复 |
|------|------|
| 15 星叠在原点 | `ephem.go` + `topology.go` 桥接 legacy 星历 |
| K8s 主机名当卫星名 | 前端 `displaySatName`；`host_node` 单独字段 |
| `satellite_id` 被 `executed_sat_id` 覆盖 | `placement.go` 仅写 `executed_sat_id` / `host_node_name`（`cc3f432`） |
| 压测脚本选星重复 | `submit_multi_satellite_tasks.sh` pilot-map 解析 + dedupe |
| Pilot 列表 legacy 名不匹配 | `pilot_filter.go` 含 `Sat_6_6…` 匹配 |

---

## 4. 固化产物

| 路径 | 说明 |
|------|------|
| `backend/migrations/000008_*` | scenario_id / satellite_id |
| `backend/migrations/000009_*` | host_node_name / executed_sat_id |
| `backend/internal/pilotcluster/` | Pilot 映射、命名、星历桥接 |
| `backend/internal/k8snode/placement.go` | 读节点 `satellite.io/id` |
| `backend/internal/remotesensing/placement.go` | 任务执行落点入库 |
| `backend/internal/argo/client.go` | PAN RPC preferred nodeAffinity |
| `frontend/src/view/SatTopology.vue` | 3D 拓扑 + running 高亮 + 路由图 |
| `frontend/src/view/RemoteSensing.vue` | 选星 + 执行信息展示 |
| `frontend/src/utils/satNaming.js` | STK 显示名 |
| `scripts/submit_multi_satellite_tasks.sh` | P5-04 多星压测 |
| `scripts/phase5_label_nodes.sh` | 节点打标签 |
| `k8s/phase5/worker-node-reader.yaml` | rs-worker 读 Node RBAC |

---

## 5. Phase 5+ 遗留（非 Phase 5 阻塞）

| 项 | 说明 | 建议阶段 |
|----|------|----------|
| **P5-05** | NFS 按 `task_id` 隔离 persist/scratch | Phase 5+ 迭代或 Phase 6 前 |
| **多节点执行** | rs-worker 多副本 + **required** nodeAffinity；指定星 = 在该星节点跑 | Phase 5+ |
| **STK 对齐** | 新 export → 删除 `ephem.go` +5 桥接 | 仿真数据就绪时 |
| **MinIO / 120 星** | 对象存储 + 扩容 | Phase 6 |
| 拓扑 footprint polygon | 遥感条带 overlay | v2 |

---

## 6. 下一步决议

1. **Merge** `feat/phase5` → `main`，CI `deploy` + `deploy-phase2-pilot` 生产签收  
2. **P5-05** 与 **多节点 rs-worker** 按业务优先级排入下一迭代  
3. **STK 更新** 后按 [2026-06-11_phase5-ephem-id-bridge.md](./2026-06-11_phase5-ephem-id-bridge.md) §6 回滚桥接  
4. **Phase 6** MinIO 在第三方压测 / 120 Node 扩容前启动

---

## 7. 外部产物路径

| 路径 | 说明 |
|------|------|
| `~/code/scripts/ops/artifacts/benchmarks/p5-multi-0626/` | 早期 3 路 |
| `~/code/scripts/ops/artifacts/benchmarks/p5-multi-3sat-v3/` | placement bug 时代 |
| `~/code/scripts/ops/artifacts/benchmarks/p5-multi-3sat-v4/` | **定稿** summary.csv |

---

*Phase 5 正式闭合；日常运维见 PHASE5_RUNBOOK（只读）。*
