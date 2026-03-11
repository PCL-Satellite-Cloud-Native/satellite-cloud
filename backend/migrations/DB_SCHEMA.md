# 数据库表结构说明（PostgreSQL）

本文档描述当前 Go 后端使用的数据库表结构，**以迁移脚本 `migrations/000001_init_schema.up.sql` 为准**。后续数据模型/迁移变更会在此文档持续补充与更新。

## 约定与术语

- **软删除**：表中包含 `deleted_at`（`TIMESTAMPTZ`）。当前后端 GORM 模型使用 `gorm.DeletedAt`（JSON 不输出），查询时会自动过滤软删除记录（除非显式 `Unscoped()`）。
- **时间字段**：`created_at` / `updated_at` 均为 `TIMESTAMPTZ`，默认 `NOW()`；通过触发器在 `UPDATE` 时自动刷新 `updated_at`。
- **Schema/命名空间**：表创建在 `public` schema 下（`public.scenarios`、`public.satellites`）。

## 迁移元数据表

使用 `golang-migrate` 运行迁移时，会自动维护版本表（通常为 `schema_migrations`，由 migrate 库创建/管理）。

> 该表不在本仓库迁移脚本中显式创建；由迁移工具自动创建。

## 表：`public.scenarios`

**用途**：描述一个星座仿真场景（时间范围、轨道参数、传感器配置等）。

### 字段

| 字段名 | 类型 | 约束 | 说明 |
|---|---|---|---|
| `id` | `BIGSERIAL` | `PRIMARY KEY` | 场景主键 |
| `name` | `VARCHAR(255)` | `NOT NULL` | 场景名称 |
| `epoch` | `VARCHAR(100)` | `NOT NULL` | 历元时间（字符串） |
| `start_time` | `VARCHAR(100)` | `NOT NULL` | 开始时间（字符串） |
| `end_time` | `VARCHAR(100)` | `NOT NULL` | 结束时间（字符串） |
| `alt_km` | `DOUBLE PRECISION` | `NOT NULL` | 高度（km） |
| `inc_deg` | `DOUBLE PRECISION` | `NOT NULL` | 倾角（deg） |
| `n_planes` | `INTEGER` | `NOT NULL` | 轨道面数量 |
| `n_sats_per_plane` | `INTEGER` | `NOT NULL` | 每轨道面卫星数 |
| `sensor_config` | `JSONB` |  | 传感器配置（JSON） |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT NOW()` | 创建时间 |
| `updated_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT NOW()` | 更新时间（触发器自动刷新） |
| `deleted_at` | `TIMESTAMPTZ` |  | 软删除时间 |

### 索引

| 索引名 | 列 | 说明 |
|---|---|---|
| `idx_scenarios_deleted_at` | `(deleted_at)` | 软删除过滤加速 |

### 触发器

| 触发器名 | 时机 | 作用 |
|---|---|---|
| `trg_set_updated_at_scenarios` | `BEFORE UPDATE` | 自动更新 `updated_at = NOW()` |

### 与后端模型的映射

对应 Go 模型：`backend/internal/model/scenario.go` 的 `Scenario`。

> 注：GORM 模型中的 `DeletedAt gorm.DeletedAt` 不对外输出 JSON（`json:"-"`），但数据库列为 `deleted_at TIMESTAMPTZ`。

## 表：`public.satellites`

**用途**：描述某个场景下的卫星（轨道要素、轨道面/槽位等）。

### 字段

| 字段名 | 类型 | 约束 | 说明 |
|---|---|---|---|
| `id` | `BIGSERIAL` | `PRIMARY KEY` | 卫星主键 |
| `scenario_id` | `BIGINT` | `NOT NULL` + FK | 所属场景，外键引用 `public.scenarios(id)`，`ON DELETE CASCADE` |
| `sat_id` | `VARCHAR(100)` | `NOT NULL` | 卫星 ID（业务标识） |
| `stk_name` | `VARCHAR(255)` | `NOT NULL` | STK 名称 |
| `plane_index` | `INTEGER` | `NOT NULL` | 轨道面索引 |
| `sat_index_in_plane` | `INTEGER` | `NOT NULL` | 轨道面内卫星索引 |
| `alt_km` | `DOUBLE PRECISION` | `NOT NULL` | 高度（km） |
| `sma_km` | `DOUBLE PRECISION` | `NOT NULL` | 半长轴（km） |
| `ecc` | `DOUBLE PRECISION` | `NOT NULL` | 偏心率 |
| `inc_deg` | `DOUBLE PRECISION` | `NOT NULL` | 倾角（deg） |
| `raan_deg` | `DOUBLE PRECISION` | `NOT NULL` | 升交点赤经（deg） |
| `argp_deg` | `DOUBLE PRECISION` | `NOT NULL` | 近地点幅角（deg） |
| `ta_deg` | `DOUBLE PRECISION` | `NOT NULL` | 真近点角（deg） |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT NOW()` | 创建时间 |
| `updated_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT NOW()` | 更新时间（触发器自动刷新） |
| `deleted_at` | `TIMESTAMPTZ` |  | 软删除时间 |

### 外键约束

- `satellites.scenario_id` → `scenarios.id`（`ON DELETE CASCADE`）

### 索引

| 索引名 | 列 | 说明 |
|---|---|---|
| `idx_satellites_scenario_sat_id` | `(scenario_id, sat_id)` | 按场景+卫星业务 ID 查询加速 |
| `idx_satellites_plane_sat_index` | `(plane_index, sat_index_in_plane)` | 按轨道面/槽位排序与查询加速 |
| `idx_satellites_deleted_at` | `(deleted_at)` | 软删除过滤加速 |

### 触发器

| 触发器名 | 时机 | 作用 |
|---|---|---|
| `trg_set_updated_at_satellites` | `BEFORE UPDATE` | 自动更新 `updated_at = NOW()` |

### 与后端模型的映射（含 JSON 字段名注意点）

对应 Go 模型：`backend/internal/model/satellite.go` 的 `Satellite`。

- 数据库列 `scenario_id` 在接口 JSON 中目前映射为字段 **`scenario`**（模型 tag：`json:"scenario"`）。
- 其余字段基本保持同名：`sat_id`、`stk_name`、`plane_index`、`sat_index_in_plane`、`raan_deg` 等。

## 表：`public.satellite_states`

**用途**：存储某个场景下、某颗卫星在特定时刻的空间状态与轨道要素（当前主要用于 T0，可扩展为时序状态）。  
数据来源初期为 CSV（如 `Sat_*_ephem_ext.csv`），后续可由轨道仿真/监控系统直接写入。

### 字段

| 字段名 | 类型 | 约束 | 说明 |
|---|---|---|---|
| `id` | `BIGSERIAL` | `PRIMARY KEY` | 记录主键 |
| `scenario_id` | `BIGINT` | `NOT NULL` + FK | 所属场景，外键引用 `public.scenarios(id)`，`ON DELETE CASCADE` |
| `sat_id` | `VARCHAR(100)` | `NOT NULL` | 卫星业务 ID（如 `sat-1-1`） |
| `t_utc` | `TIMESTAMPTZ` | `NOT NULL` | 状态时刻（UTC） |
| `r_x` / `r_y` / `r_z` | `DOUBLE PRECISION` | `NOT NULL` | 笛卡尔坐标分量（km） |
| `lla_lat` / `lla_lon` / `lla_alt` | `DOUBLE PRECISION` |  | 纬度 / 经度 / 高度（km） |
| `coe_sma_km` | `DOUBLE PRECISION` |  | 轨道半长轴（km） |
| `coe_ecc` | `DOUBLE PRECISION` |  | 偏心率 |
| `coe_inc_deg` | `DOUBLE PRECISION` |  | 倾角（deg） |
| `coe_raan_deg` | `DOUBLE PRECISION` |  | 升交点赤经（deg） |
| `coe_argp_deg` | `DOUBLE PRECISION` |  | 近地点幅角（deg） |
| `coe_ta_deg` | `DOUBLE PRECISION` |  | 真近点角（deg） |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT NOW()` | 创建时间 |
| `updated_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT NOW()` | 更新时间 |

### 索引

| 索引名 | 列 | 说明 |
|---|---|---|
| `idx_sat_states_scenario_sat_time` | `(scenario_id, sat_id, t_utc)` | 按场景 + 卫星 + 时间查询/排序 |


## 表：`public.satellite_delay_edges`

**用途**：存储卫星之间的延迟边（delay matrix），用于拓扑页的 delay 连线展示。  
当前数据来源为 CSV（如 `delay_15x15.csv`），后续可由监控/仿真系统生成。

### 字段

| 字段名 | 类型 | 约束 | 说明 |
|---|---|---|---|
| `id` | `BIGSERIAL` | `PRIMARY KEY` | 记录主键 |
| `scenario_id` | `BIGINT` | `NOT NULL` + FK | 所属场景 |
| `a_id` | `VARCHAR(100)` | `NOT NULL` | 起点卫星 ID |
| `b_id` | `VARCHAR(100)` | `NOT NULL` | 终点卫星 ID |
| `delay_s` | `DOUBLE PRECISION` | `NOT NULL` | 时延（秒） |
| `dist_km` | `DOUBLE PRECISION` | `NOT NULL` | 距离（km，通常为 `delay_s * c`） |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT NOW()` | 创建时间 |
| `updated_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT NOW()` | 更新时间 |

### 索引

| 索引名 | 列 | 说明 |
|---|---|---|
| `idx_delay_edges_scenario_a_b` | `(scenario_id, a_id, b_id)` | 查询某场景下特定边或按起点聚合 |


## 表：`public.router_nodes`

**用途**：将逻辑路由器 ID（如 `r001001`）映射到具体卫星及其轨道位置，用于“路由拓扑 (Router Topology)”中的节点信息。  
路由器命名约定：`rOOOSSS` ↔ 轨道面 `orbit=OOO`、槽位 `slot=SSS`，对应卫星 `sat-<orbit>-<slot>`。

### 字段

| 字段名 | 类型 | 约束 | 说明 |
|---|---|---|---|
| `id` | `BIGSERIAL` | `PRIMARY KEY` | 记录主键 |
| `scenario_id` | `BIGINT` | `NOT NULL` + FK | 所属场景 |
| `router_id` | `VARCHAR(16)` | `NOT NULL` | 路由器 ID（如 `r001001`） |
| `sat_id` | `VARCHAR(100)` | `NOT NULL` | 映射卫星 ID（如 `sat-1-1`） |
| `plane_index` | `INTEGER` | `NOT NULL` | 轨道面索引 |
| `sat_index_in_plane` | `INTEGER` | `NOT NULL` | 面内槽位索引 |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT NOW()` | 创建时间 |
| `updated_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT NOW()` | 更新时间 |

### 索引

| 索引名 | 列 | 说明 |
|---|---|---|
| `idx_router_nodes_scenario_router` | `(scenario_id, router_id)` | 按场景 + router_id 唯一查询 |


## 表：`public.router_links`

**用途**：存储路由器之间的邻接关系及 QoS 信息，用于右侧 2D 路由拓扑图。  
初期数据来源为 `/data/router/*_net_qos.csv`，字段如带宽 / 时延 / 丢包率等。

### 字段

| 字段名 | 类型 | 约束 | 说明 |
|---|---|---|---|
| `id` | `BIGSERIAL` | `PRIMARY KEY` | 记录主键 |
| `scenario_id` | `BIGINT` | `NOT NULL` + FK | 所属场景 |
| `src_router` | `VARCHAR(16)` | `NOT NULL` | 源路由 ID（如 `r001001`） |
| `dst_router` | `VARCHAR(16)` | `NOT NULL` | 目标路由 ID |
| `delay_ms` | `DOUBLE PRECISION` |  | 时延（毫秒，若 CSV 提供） |
| `loss` | `DOUBLE PRECISION` |  | 丢包率 |
| `bandwidth` | `DOUBLE PRECISION` |  | 带宽（可统一为 Mbps 或 Gbps） |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT NOW()` | 创建时间 |
| `updated_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT NOW()` | 更新时间 |

### 索引

| 索引名 | 列 | 说明 |
|---|---|---|
| `idx_router_links_scenario_src` | `(scenario_id, src_router)` | 按场景 + 源路由聚合 / BFS 起点查询 |


## 关系（ER）

**核心关系：**

- `scenarios (1) ──< (N) satellites`
  - 一个场景包含多颗卫星
  - 删除场景会级联删除卫星（硬删除层面；软删除需业务侧决定是否使用）

- `scenarios (1) ──< (N) satellite_states`
  - 一个场景可有多时刻、多颗卫星的状态记录

- `scenarios (1) ──< (N) satellite_delay_edges`
  - 每个场景维护一套独立的 delay 矩阵

- `scenarios (1) ──< (N) router_nodes`
  - 一个场景下的所有路由节点均映射到该场景的卫星集合

- `scenarios (1) ──< (N) router_links`
  - 每个场景维护一套独立的路由邻接关系

---

## 拓扑相关表的数据导入（两种使用方式）

以下表的数据可由 CSV 导入：`satellite_states`（T0 星历）、`satellite_delay_edges`（delay 矩阵）、`router_nodes` / `router_links`（路由拓扑）。导入逻辑统一在 `backend/internal/topology/importer.go`，使用方式有两种：

| 方式 | 说明 | 本地 | K8s 集群 |
|------|------|------|----------|
| **启动时自动导入** | 服务启动时若配置了相应环境变量且 `SATELLITE_TOPOLOGY_AUTO_IMPORT=true`，则自动从 CSV 导入上述表。 | 在 `backend/.env` 中配置 `SATELLITE_DELAY_CSV`、`SATELLITE_T0_CSV_DIR`、`SATELLITE_ROUTER_CSV_DIR` 等，启动 `go run ./cmd/server` 即可。 | 在 Deployment 中挂载存有 CSV 的卷，并配置同上环境变量；详见 **k8s/backend/TOPOLOGY_IMPORT.md**。 |
| **按需执行导入工具** | 不依赖服务进程，单独运行 CLI 将指定 CSV 导入 DB。 | 在 backend 目录执行：`go run ./tools/import_topology.go -mode=delay\|t0\|router -file /path/to/file.csv` 或 `-dir /path/to/dir`，数据库连接通过 `-dsn` 或 `SATELLITE_DATABASE_*` 环境变量。 | 使用同一后端镜像中的 `import_topology` 二进制，通过 Job 或临时 Pod 挂载 PVC 后执行；详见 **k8s/backend/TOPOLOGY_IMPORT.md** 与 `k8s/backend/import-topology-job.yaml`。 |

- **本地**：环境变量与 CLI 用法见 `backend/.env` 注释与 `backend/tools/import_topology.go` 文件头。
- **K8s**：两种方式的详细步骤、PVC 准备与 Job 用法见 **k8s/backend/TOPOLOGY_IMPORT.md**。


