# 拓扑数据导入使用说明

拓扑数据（delay 矩阵、T0 星历、路由 CSV）进入数据库的方式有两种，**本地与 K8s 集群均适用**：

| 方式 | 说明 | 适用场景 |
|------|------|----------|
| **方式一：启动时自动导入** | Backend 启动时若 `SATELLITE_TOPOLOGY_AUTO_IMPORT=true` 且配置了 CSV 路径，则自动执行导入。 | 数据路径固定、希望每次启动都同步一次。 |
| **方式二：按需执行导入工具** | 单独运行 `import_topology`（本地 `go run ./tools/import_topology.go`，K8s 用 Job/临时 Pod），不依赖 Backend 进程。 | 按需执行、或数据在临时卷/仅一次性导入。 |

下文先写**本地环境**的两种用法，再写 **K8s 集群**的两种用法。表结构说明见 `backend/migrations/DB_SCHEMA.md`。

---

## 本地环境

- **方式一**：在 `backend/.env` 中设置 `SATELLITE_TOPOLOGY_AUTO_IMPORT=true`，以及 `SATELLITE_TOPOLOGY_SCENARIO`、`SATELLITE_DELAY_CSV`、`SATELLITE_T0_CSV_DIR`、`SATELLITE_ROUTER_CSV_DIR`（按需），然后 `go run ./cmd/server`，启动时会自动导入。
- **方式二**：`go run ./tools/import_topology.go -mode=delay -file <path>` 或 `-mode=t0 -dir <dir>` / `-mode=router -dir <dir>`，数据库连接用 `-dsn` 或 `SATELLITE_DATABASE_*` 环境变量。详见 `backend/tools/import_topology.go` 文件头注释。

---

## K8s 集群

### 方式一：Backend 启动时自动导入（推荐用于已有数据卷）

若 CSV 文件能在 Pod 内通过**挂载卷**访问，则只需配置环境变量，Backend 启动时会自动导入。

### 1. 准备数据卷

任选一种方式让 Backend 能读到 CSV：

- **PVC**：创建 PersistentVolumeClaim，把 `delay_15x15.csv`、`ephem_15/`、`router/` 等放入该卷（例如用 Job 从对象存储同步，或 init 容器从 Git 拉取）。
- **ConfigMap**：仅适合小文件（如单个 delay 矩阵）。T0 / router 的 CSV 较多，建议用 PVC。

### 2. 在 Deployment 中挂载并配置环境变量

在 `deployment.yaml` 的 `containers[0]` 中增加卷挂载与拓扑相关 env：

```yaml
env:
  # ... 现有 DB、SATELLITE_TOPOLOGY_AUTO_IMPORT、SATELLITE_TOPOLOGY_SCENARIO、SATELLITE_DELAY_CSV ...
  - name: SATELLITE_T0_CSV_DIR
    value: "/data/topology/ephem_15"
  - name: SATELLITE_ROUTER_CSV_DIR
    value: "/data/topology/router"
# 若 SATELLITE_DELAY_CSV 指向卷内路径，例如：
# - name: SATELLITE_DELAY_CSV
#   value: "/data/topology/delay_15x15.csv"
volumeMounts:
  - name: topology-data
    mountPath: /data/topology
    readOnly: true
# 在 spec.template.spec 下增加：
volumes:
  - name: topology-data
    persistentVolumeClaim:
      claimName: topology-data
```

并确保 Secret `satellite-backend-env` 中存在：

- `SATELLITE_TOPOLOGY_AUTO_IMPORT=true`
- `SATELLITE_TOPOLOGY_SCENARIO`（如 `Scenario5_full_36x22`）
- `SATELLITE_DELAY_CSV`（如 `/data/topology/delay_15x15.csv`）

这样每次 Backend Pod 启动都会按上述路径执行导入。

---

### 方式二：单独运行导入 Job（按需执行）

当数据在**临时卷**或希望**按需执行**导入、而不在每次 Backend 启动时导入时，使用导入 Job。

### 1. 准备 PVC 与目录结构

创建 PVC（若尚未有），并把 CSV 放入卷，挂载到 Job 的 `/data/topology` 后目录结构示例：

```
/data/topology/
  delay_15x15.csv
  ephem_15/
    Sat_6_6_ephem_ext.csv
    Sat_6_7_ephem_ext.csv
    ...
  router/
    r001001_net_qos.csv
    ...
```

可通过一次性 Pod 从本机或对象存储拷贝到该 PVC，或由 CI 构建镜像时包含数据并挂载到同一路径。

### 2. 执行 Job

```bash
# 确保 topology-data PVC 已存在且数据已就绪
kubectl apply -f k8s/backend/import-topology-job.yaml

# 查看日志
kubectl logs -f job/import-topology -n gitlab-runner
```

Job 会依次执行 delay、T0、router 三种导入；使用的 DB 连接与 Backend 相同（Secret `satellite-db-secret`），场景名来自 `SATELLITE_TOPOLOGY_SCENARIO`（或默认 `Scenario5_full_36x22`）。

### 3. 只导入某一类数据

可编辑 `import-topology-job.yaml`，将 `command` 改为只运行一个 mode，例如仅 delay：

```yaml
command:
  - ./import_topology
  - -mode=delay
  - -file
  - /data/topology/delay_15x15.csv
```

或使用临时 Pod（替换镜像 tag、namespace 等）：

```bash
kubectl run import-topology --rm -it --restart=Never \
  --image=192.168.10.238/satellite/backend:latest \
  -n gitlab-runner \
  --env="SATELLITE_DATABASE_HOST=..." \
  --env="SATELLITE_DATABASE_USER=..." \
  --env="SATELLITE_DATABASE_PASSWORD=..." \
  --env="SATELLITE_DATABASE_DBNAME=..." \
  --overrides='{"spec":{"containers":[{"name":"import","image":"192.168.10.238/satellite/backend:latest","command":["./import_topology","-mode=delay","-file","/data/topology/delay_15x15.csv"],"volumeMounts":[{"name":"data","mountPath":"/data/topology"}]}],"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"topology-data"}}]}}' \
  --
```

---

## 小结

| 方式           | 适用场景                     | 本地                         | K8s                            |
|----------------|------------------------------|------------------------------|---------------------------------|
| 启动自动导入   | 数据固定、每次启动都要导入   | `.env` + 启动 server         | 卷挂载到 Backend Pod + 同上 env |
| 按需执行导入   | 按需执行、或数据在临时卷     | `go run ./tools/import_topology.go` | Job/临时 Pod 运行 `import_topology`，卷挂载到 Pod（PVC） |

K8s 镜像内已包含 `import_topology` 二进制，与 Backend 使用相同镜像即可。表结构见 `backend/migrations/DB_SCHEMA.md`。
