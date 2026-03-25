# 数据库迁移说明

本目录下的迁移脚本用于创建 `scenarios` / `satellites` 表结构并可选导入示例数据。**后端启动时会自动执行未应用的迁移**，无需在 K8s 或本地单独跑 SQL，保证环境一致。

## 文件说明

- **`000001_init_schema.up.sql`**
  - 创建 `scenarios` 和 `satellites` 两张表（含软删除字段 `deleted_at`）
  - 包含：`sensor_config` JSONB、`created_at`/`updated_at`、`deleted_at`、索引、`updated_at` 触发器

- **`000002_seed_data.up.sql`**
  - 插入一条场景（Scenario5）及 plane 1 前三颗卫星，用于前后端联调
- **`000005_remote_sensing_tasks.up.sql`**
  - 创建遥感任务、阶段、产物与日志表，支撑远程感知流水线 API

- **`embed.go`**
  - 将 `*.up.sql` 打进二进制，供启动时通过 golang-migrate 执行

## 部署时自动迁移

后端在连接数据库后、对外提供服务前会执行：

1. 使用 [golang-migrate](https://github.com/golang-migrate/migrate) 读取内嵌的 `*.up.sql`
2. 按版本号顺序执行尚未应用的迁移（依赖表 `schema_migrations`）
3. 若已是最新则跳过；若失败则进程退出，不启动 HTTP 服务

因此：

- **K8s / 生产**：无需在 CI 或 Job 里跑迁移，新 Pod 启动即自动追上最新 schema
- **本地**：`go run ./cmd/server` 或运行二进制时同样自动迁移，与服务器一致

## 新增迁移的约定

1. 在 `migrations/` 下新增 `000003_描述.up.sql`（编号递增、含 `.up.sql` 后缀）
2. 重新构建并部署后端，下次启动时会自动执行

可选：如需可回滚，可增加同名 `000003_描述.down.sql`（golang-migrate 支持 `m.Steps(-1)` 等，当前未在启动逻辑中使用）。

## 手动执行（可选）

仅在需要不启动后端、仅对某库执行迁移时使用：

```bash
cd backend
migrate -path migrations -database "postgres://user:pass@host:5432/dbname?sslmode=disable" up
```

或使用 [migrate CLI](https://github.com/golang-migrate/migrate/tree/master/cmd/migrate) 指定 `-path` 为包含 `*.up.sql` 的目录。

## 与后端的联动

后端通过环境变量连接数据库（如 K8s 中通过 Secret 注入）：

- `SATELLITE_DATABASE_HOST`、`SATELLITE_DATABASE_PORT`、`SATELLITE_DATABASE_USER`、`SATELLITE_DATABASE_PASSWORD`、`SATELLITE_DATABASE_DBNAME`、`SATELLITE_DATABASE_SSLMODE`

迁移完成后，API 即可使用：

- `GET /api/scenarios`
- `GET /api/scenarios/:id`
- `GET /api/scenarios/:id/satellites`
- `GET /api/satellites`（支持 `?scenario_id=`）
