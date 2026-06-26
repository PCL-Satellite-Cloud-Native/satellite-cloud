# 归档：Phase 5 Pilot 星历 ID 桥接（临时）

> **归档日期**：2026-06-11  
> **主题**：Pilot 15 星 `sat-{p}-{s}` 与 legacy STK 星历 `Sat_6_6…Sat_8_10` 的偏移映射  
> **状态**：**临时桥接，待 STK 更新后回滚**  
> **SSOT 后继**：[PHASE5_RUNBOOK.md](../PHASE5_RUNBOOK.md)、[MICROSERVICES_IMPLEMENTATION_PLAN.md](../MICROSERVICES_IMPLEMENTATION_PLAN.md) §5

---

## 1. 背景

Phase 5 Pilot 集群采用 **业务 ID** `sat-1-1 … sat-3-5`（K8s 标签 `satellite.io/id`、API、页面 STK 显示名 `Sat_1_1`）。

当前入库 / 静态 CSV 星历仍来自 **Scenario5 子集**，文件名为 **`Sat_6_6 … Sat_8_10`**（3 轨道面 × 5 星，对应 orbit 6–8、slot 6–10）。

在 ID 未对齐前，`/api/topology/t0` 按 `sat-1-1` 过滤后 **无有效 `r_x/r_y/r_z`**，前端 15 颗星全部落在 `(0,0,0)`。

**2026-06-11 修复**：引入 **+5/+5 偏移桥接**，用 legacy 星历坐标渲染 Pilot 拓扑，待 STK 重新导出并导入后 **删除桥接、恢复 ID 一一对应**。

---

## 2. 映射表（Pilot ↔ Legacy 星历）

| Pilot sat_id | 显示名 | Legacy STK / CSV | 轨道面 | 槽位 |
|--------------|--------|------------------|--------|------|
| sat-1-1 | Sat_1_1 | Sat_6_6 | 1→6 | 1→6 |
| sat-1-2 | Sat_1_2 | Sat_6_7 | 1→6 | 2→7 |
| … | … | … | … | … |
| sat-3-5 | Sat_3_5 | Sat_8_10 | 3→8 | 5→10 |

**公式**（代码 SSOT：`backend/internal/pilotcluster/ephem.go`）：

```text
legacy_orbit  = pilot_orbit  + 5
legacy_slot   = pilot_slot   + 5
legacy_stk    = Sat_{legacy_orbit}_{legacy_slot}
```

示例：`sat-2-3` → `Sat_7_8`。

---

## 3. 代码触点

| 路径 | 作用 |
|------|------|
| `backend/internal/pilotcluster/ephem.go` | 偏移常量与 `EphemSTKName` |
| `backend/internal/api/handlers/topology.go` | `applyPilotClusterT0` / `applyPilotClusterDelay` 桥接 |
| `frontend/src/view/SatTopology.vue` | 同轨 **闭合环网**（与 ID 无关，可保留） |
| `frontend/public/data/ephem_15/Sat_6_* … Sat_8_*` | Legacy CSV（容器内 fallback） |
| `frontend/public/data/delay_15x15.csv` | Legacy 时延矩阵（列名为 Sat_6_6…） |

**DB**：`satellite_states` / `satellite_delay_edges` 中 `sat_id` / `a_id` / `b_id` 仍为 **Legacy STK 名** 时，桥接在 API 层重映射为 `sat-*`。

---

## 4. 验收（桥接生效）

```bash
curl -s http://<backend>/api/topology/t0 | jq '[.[] | select(.r[0]!=0 or .r[1]!=0 or .r[2]!=0)] | length'
# 期望 15

curl -s http://<backend>/api/topology/t0 | jq '.[0] | {id, display_name, r}'
# id 为 sat-1-1，r 数量级 ~±6000 km
```

前端：3D 拓扑 15 星分散，3 条同轨闭合环；时延模式有跨星连线。

---

## 5. 回滚条件

当 **STK 重新导出** 且满足以下全部条件时，可移除桥接：

1. 星历 / DB 中 `sat_id` 与 Pilot 一致：`sat-1-1` 或 `Sat_1_1`（与 `pilot-map.json` 一一对应，**无 +5 偏移**）
2. `satellite_states`、`satellite_delay_edges` 已按新场景 **重新 import**
3. 静态 CSV（若仍使用 fallback）已替换为 `Sat_1_1_ephem_ext.csv` … `Sat_3_5_ephem_ext.csv`（或等价命名）

---

## 6. 回滚步骤（ID 一一对应）

### 6.1 数据

```bash
# 示例：导入新 T0 星历与时延（场景名按实际 STK 场景）
# 见 backend/internal/topology/importer.go、import_topology 工具
go run ./tools/import_topology --scenario <新场景名> ...
```

确认 DB：

```sql
SELECT sat_id, r_x, r_y, r_z FROM satellite_states WHERE scenario_id = ? LIMIT 5;
-- sat_id 应为 sat-1-1 或 Sat_1_1，且 r 非零
```

### 6.2 代码

1. **删除或归零偏移**（推荐删除桥接，直接 ID 匹配）：
   - 删除 `backend/internal/pilotcluster/ephem.go`（及 `ephem_test.go`）
   - 简化 `topology.go` 中 `applyPilotClusterT0`：仅 `ContainsSatID` + 填充 `display_name` / `host_node`，**不再** `lookupPilotEphem`
   - 简化 `applyPilotClusterDelay`：仅按 `sat-*` 过滤，**不再** `ephemToPilot` 重映射

2. 更新 `topoCSVFiles`（若仍用 CSV fallback）为 `Sat_1_1` … `Sat_3_5` 文件名。

3. 替换 `frontend/public/data/ephem_15/` 与 `delay_15x15.csv`（列名改为 `sat-1-1` 或 `Sat_1_1`）。

4. 跑测试并部署：

```bash
cd backend && go test ./... && go build ./...
cd frontend && npm run build
```

### 6.3 验收（回滚后）

```bash
curl -s http://<backend>/api/topology/t0 | jq '.[] | select(.id=="sat-1-1") | .r'
# 非零；且代码库中已无 EphemOrbitSlot(+5) 调用
```

---

## 7. 遗留项

| 项 | 说明 |
|----|------|
| STK 场景与 Pilot 15 星正式对齐 | 待业主提供/确认新导出 |
| `topoScenarioName()` 默认 `Scenario5_full_36x22` | 新 STK 场景名需同步 env `SATELLITE_TOPOLOGY_SCENARIO` |
| 120 星扩展 | 桥接仅适用于当前 15 星 Pilot；扩展时应用新 STK 直接 ID 对应 |

---

## 8. 相关 commit / 分支

- 分支：`feat/phase5`
- 功能：`pilotcluster/ephem.go`、`topology.go` 桥接、前端同轨闭合环

---

*本文件为历史快照与回滚手册；STK 更新并完成回滚后，在 [ARCHIVE_INDEX.md](./ARCHIVE_INDEX.md) 标记本桥接已退役，勿再改本文。*
