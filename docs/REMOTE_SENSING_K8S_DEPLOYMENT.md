# Satellite-Cloud 遥感模块 K8s 部署手册（GitLab CI）

> 若你是从“未集成遥感应用”的历史版本迁移，请优先阅读：
> `docs/REMOTE_SENSING_BASELINE_MIGRATION_RUNBOOK.md`

本文档只描述 **satellite-cloud 项目侧** 的部署与发布配置，目标是在其他集群上可复现。

## 1. 适用范围

- 仓库：`satellite-cloud`
- 部署命名空间：`gitlab-runner`
- CI 平台：GitLab CI
- 镜像仓库：Harbor（示例：`192.168.10.238/satellite/*`）
- 遥感代码来源：内网 GitLab 私有仓库（由中转机从 GitHub 同步）

## 2. 本次关键配置（代码已落地）

### 2.1 CI 拉取遥感代码并打包到后端镜像

- 文件：`.gitlab-ci.yml`
- 变更：`build-backend` 阶段新增
  - 检查 `REMOTE_SENSING_REPO_URL`
  - 使用 `CI_JOB_TOKEN` 克隆遥感仓库到 `backend/remote-sensing-src`
  - `docker build` 时将该目录打入镜像

### 2.2 后端镜像内置遥感运行时

- 文件：`backend/Dockerfile`
- 运行时包含：
  - Go 二进制 `server` 与 `import_topology`
  - `/opt/remote-sensing`（遥感脚本）
  - `/opt/remote-sensing/.venv`（Python 虚拟环境）
  - GDAL + Matplotlib 等依赖

### 2.3 新增遥感数据 PV/PVC

- 文件：`k8s/backend/remote-sensing-pv-pvc.yaml`
- NFS：`k8s-worker22:/export/remote-sensing-data`
- PVC：`remote-sensing-data`（namespace=`gitlab-runner`）

### 2.4 后端 Deployment 挂载遥感数据与运行参数

- 文件：`k8s/backend/deployment.yaml`
- 新增环境变量：
  - `SATELLITE_REMOTE_SENSING_ROOT=/opt/remote-sensing`
  - `SATELLITE_REMOTE_SENSING_PYTHON=/opt/remote-sensing/.venv/bin/python`
- 新增 volumeMount：
  - `/opt/remote-sensing/input`（subPath=`input`）
  - `/opt/remote-sensing/output_preprocessing`（subPath=`output_preprocessing`）

## 3. 上线前准备（一次性）

### 3.1 NFS 目录

在 NFS 服务器执行：

```bash
sudo mkdir -p /export/remote-sensing-data/input
sudo mkdir -p /export/remote-sensing-data/output_preprocessing
sudo chmod -R 0777 /export/remote-sensing-data
```

### 3.2 GitLab CI/CD 变量

必须配置：

- `HARBOR_USER`
- `HARBOR_PASSWORD`
- `REMOTE_SENSING_REPO_URL`（内网 GitLab 仓库 HTTPS 地址）
  - 当前集群示例：`https://192.168.10.238:8444/root/satellite-remote-sensing.git`
- （可选）`REMOTE_SENSING_REPO_REF`（默认 `main`）

建议验证：

```bash
# 在 GitLab CI 变量里配置 REMOTE_SENSING_REPO_URL 后，构建阶段会自动执行 git ls-remote 预检查
```

## 4. 首次部署步骤（可复制）

### 4.1 先手工创建 PV/PVC（建议首轮手工）

```bash
kubectl apply -f k8s/backend/remote-sensing-pv-pvc.yaml
kubectl get pv remote-sensing-data-pv
kubectl get pvc -n gitlab-runner remote-sensing-data
```

验收：`PV/PVC` 状态均为 `Bound`。

### 4.2 触发 GitLab `main` 流水线

流水线阶段：

1. `build-backend`
2. `build-frontend`
3. `deploy`
4. `topology-sync`

## 5. 部署后验收（必须）

### 5.1 Pod 与镜像

```bash
kubectl -n gitlab-runner get deploy satellite-backend -o wide
kubectl -n gitlab-runner rollout status deploy/satellite-backend
kubectl -n gitlab-runner get pods -l app=satellite-backend
```

### 5.2 后端遥感运行时确认

```bash
kubectl -n gitlab-runner logs deploy/satellite-backend | rg "Remote sensing runtime configured"
```

验收点：日志中出现

- `root_path=/opt/remote-sensing`
- `python_bin=/opt/remote-sensing/.venv/bin/python`

### 5.3 容器内依赖确认

```bash
POD=$(kubectl -n gitlab-runner get pod -l app=satellite-backend -o jsonpath='{.items[0].metadata.name}')
kubectl -n gitlab-runner exec -it "$POD" -- /bin/sh -lc '/opt/remote-sensing/.venv/bin/python -c "from osgeo import gdal; import matplotlib; print(gdal.__version__)"'
```

### 5.4 业务联动确认

提交一条遥感任务后，检查：

1. `fusion_stack_envi` 阶段完成
2. 自动执行 `imgshow.py`
3. 产物中有 `preview`，路径类似：
   `output_preprocessing/imgshow/<prefix>-MSS1-fusion.png`

## 6. 常见问题与定位

### 问题 1：`ModuleNotFoundError: matplotlib`

原因：后端未使用 `.venv` 或镜像里未安装依赖。

定位：

```bash
kubectl -n gitlab-runner logs deploy/satellite-backend | rg "python_bin"
```

### 问题 2：`imgshow.py` 未找到

原因：CI 未成功克隆遥感仓库到 `backend/remote-sensing-src`。

定位：查看 `build-backend` job 日志里的 `git clone`。

### 问题 3：任务找不到输入/输出目录

原因：PVC 未绑定或 NFS 目录不存在。

定位：

```bash
kubectl -n gitlab-runner get pvc remote-sensing-data
kubectl -n gitlab-runner describe pod "$POD"
```

## 7. 回滚策略

### 7.1 快速回滚 Deployment

```bash
kubectl -n gitlab-runner rollout undo deploy/satellite-backend
kubectl -n gitlab-runner rollout status deploy/satellite-backend
```

### 7.2 镜像版本回滚

```bash
kubectl -n gitlab-runner set image deployment/satellite-backend satellite-backend=192.168.10.238/satellite/backend:<旧tag>
kubectl -n gitlab-runner rollout status deploy/satellite-backend
```

## 8. 文件变更索引

- `.gitlab-ci.yml`
- `backend/Dockerfile`
- `k8s/backend/deployment.yaml`
- `k8s/backend/remote-sensing-pv-pvc.yaml`
