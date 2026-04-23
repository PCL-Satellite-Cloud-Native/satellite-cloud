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
  - Go 依赖下载使用：
    - `GOPROXY=https://goproxy.cn,direct`
    - `GOSUMDB=off`

### 2.3 新增遥感数据 PV/PVC

- 文件：`k8s/backend/remote-sensing-pv-pvc.yaml`
- NFS：`k8s-worker22:/export/remote-sensing-data`
- PVC：`remote-sensing-data`（namespace=`gitlab-runner`）

### 2.4 后端 Deployment 挂载遥感数据与运行参数

- 文件：`k8s/backend/deployment.yaml`
- 新增环境变量：
  - `SATELLITE_REMOTE_SENSING_ROOT=/opt/remote-sensing`
  - `SATELLITE_REMOTE_SENSING_PYTHON=/opt/remote-sensing/.venv/bin/python`
  - `SATELLITE_REMOTE_SENSING_DEM_FILE=/opt/remote-sensing-data/dem/GMTED2010.jp2`
  - `SATELLITE_REMOTE_SENSING_PERSIST_OUTPUT_DIR=persist_output_preprocessing`
  - `SATELLITE_REMOTE_SENSING_STAGE_TIMEOUT_SECONDS=1800`
  - `SATELLITE_REMOTE_SENSING_FUSION_STAGE_TIMEOUT_SECONDS=1500`
  - `SATELLITE_REMOTE_SENSING_STAGE_MAX_RETRIES=1`
  - `SATELLITE_REMOTE_SENSING_COMMAND_HEARTBEAT_SECONDS=60`
  - `SATELLITE_REMOTE_SENSING_PAN_RPC_PARALLELISM=2`
  - `SATELLITE_REMOTE_SENSING_PAN_RPC_CPU_THREADS=1`
  - `SATELLITE_REMOTE_SENSING_PAN_RPC_WARP_MEM_MB=1024`
  - `SATELLITE_REMOTE_SENSING_PAN_RPC_MAX_TOTAL_WARP_MEM_MB=2048`
  - `SATELLITE_REMOTE_SENSING_PAN_RPC_RESAMPLE_ALG=near`
  - `SATELLITE_REMOTE_SENSING_PANSHARPEN_PARALLELISM=3`
  - `SATELLITE_REMOTE_SENSING_PANSHARPEN_GDAL_THREADS=1`
- 说明：
  - `SATELLITE_REMOTE_SENSING_STAGE_TIMEOUT_SECONDS` 为通用阶段超时秒数
  - `SATELLITE_REMOTE_SENSING_FUSION_STAGE_TIMEOUT_SECONDS` 为融合阶段专用超时秒数
  - `SATELLITE_REMOTE_SENSING_STAGE_MAX_RETRIES` 为阶段失败后的重试次数（仅重试当前阶段）
  - `SATELLITE_REMOTE_SENSING_COMMAND_HEARTBEAT_SECONDS` 为子进程执行心跳日志间隔（秒）
  - 当前实现中 `SATELLITE_REMOTE_SENSING_PAN_RPC_PARALLELISM` 为 PAN RPC 分组并行度（每组一次脚本调用）
  - `SATELLITE_REMOTE_SENSING_PAN_RPC_CPU_THREADS` 为每个 PAN RPC 脚本进程内 GDAL 线程数
  - `SATELLITE_REMOTE_SENSING_PAN_RPC_WARP_MEM_MB` 为 PAN RPC 的 `warpMemoryLimit`（MB）
  - `SATELLITE_REMOTE_SENSING_PAN_RPC_MAX_TOTAL_WARP_MEM_MB` 为 PAN RPC 总内存预算（MB），用于自动下调分组并行度，避免 OOM 重启
  - `SATELLITE_REMOTE_SENSING_PAN_RPC_RESAMPLE_ALG` 为 PAN RPC 重采样算法（推荐默认 `near`；质量优先可切换为 `bilinear`）
  - 当前实现中 `pansharpen_fusion` 已改为单进程批量波段处理（`--band_indexes=1,2,3`），`SATELLITE_REMOTE_SENSING_PANSHARPEN_PARALLELISM` 暂保留为兼容参数；`SATELLITE_REMOTE_SENSING_PANSHARPEN_GDAL_THREADS` 仍生效
- 新增 volumeMount：
  - `/opt/remote-sensing/input`（subPath=`input`）
  - `/opt/remote-sensing/output_preprocessing`（`emptyDir` 本地 scratch，中间产物）
  - `/opt/remote-sensing/persist_output_preprocessing`（subPath=`output_preprocessing`，最终产物持久化）
  - `/opt/remote-sensing-data/dem`（subPath=`dem`）
- 资源建议：
  - `requests.memory=1Gi`
  - `limits.memory=4Gi`（避免 `PAN RPC` 阶段 OOMKilled）
  - `requests.ephemeral-storage=10Gi`
  - `limits.ephemeral-storage=48Gi`
  - `emptyDir.sizeLimit=40Gi`（避免单 Pod scratch 放大挤爆节点根盘）
- `initContainer` 建议使用内网镜像（如 `192.168.10.238/library/alpine:3.19-amd64-r1`），避免受外网拉取影响

## 3. 上线前准备（一次性）

### 3.1 NFS 目录

在 NFS 服务器执行：

```bash
sudo mkdir -p /export/remote-sensing-data/input
sudo mkdir -p /export/remote-sensing-data/output_preprocessing
sudo mkdir -p /export/remote-sensing-data/dem
sudo chmod -R 0777 /export/remote-sensing-data

#在 `/etc/exports` 中增加一行（根据你集群网段调整）：

/export/remote-sensing-data 192.168.0.0/16(rw,sync,no_subtree_check,no_root_squash)

# 使配置生效并验证：

sudo exportfs -rav
sudo exportfs -v
```

### 3.2 GitLab CI/CD 变量

必须配置：

- `HARBOR_USER`
- `HARBOR_PASSWORD`
- `REMOTE_SENSING_REPO_URL`（内网 GitLab 仓库 HTTPS 地址）
  - 当前集群示例：`https://192.168.10.238:8444/root/satellite-remote-sensing.git`
- （可选）`REMOTE_SENSING_REPO_REF`（默认 `main`）
- `CI_BUILD_IMAGE`（推荐：`192.168.10.238/library/ci-build:docker25-git-amd64-r3`）

说明：

- `CI_BUILD_IMAGE` 需要预装 `docker-cli + git`，并内置内网 CA 证书，否则 `git ls-remote` 可能报 `self-signed certificate`。

建议验证：

```bash
# 在 GitLab CI 变量里配置 REMOTE_SENSING_REPO_URL 后，构建阶段会自动执行 git ls-remote 预检查
```

### 3.3 后端运行时基础镜像（建议预构建）

现象：后端镜像构建时若执行 `apt-get update`，在受限网络下可能访问 `deb.debian.org` 失败。  
建议在可联网环境预构建并推送基础镜像，再在后端 Dockerfile 直接引用。

示例构建文件（建议放在 `backend/Dockerfile.runtime-base`）：

```dockerfile
FROM python:3.11-slim-bookworm
ENV TZ=Asia/Shanghai
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    tzdata \
    curl \
    gdal-bin \
    libgdal-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*
```

示例构建命令：

```bash
docker buildx build --platform linux/amd64 -f backend/Dockerfile.runtime-base \
  -t 192.168.10.238/library/python:3.11-slim-bookworm-gdal-amd64-r1 --push .
```

### 3.4 集群节点出网连通性（跳板机转发场景）

若通过跳板机做 NAT/iptables 转发，建议在上线前做连通性验收：

```bash
# 在 worker 节点
curl -I --max-time 10 http://deb.debian.org/debian/dists/bookworm/InRelease
curl -I --max-time 10 https://deb.debian.org/debian/dists/bookworm/InRelease
curl -I --max-time 10 https://proxy.golang.org
```

常见异常：

- `Empty reply from server`
- `unexpected eof while reading`
- `docker pull ... EOF`

这类问题通常不是应用代码故障，而是跳板机透明代理/NAT 规则导致。

## 4. 首次部署步骤（可复制）

### 4.1 先手工创建 PV/PVC（建议首轮手工）

```bash
kubectl apply -f k8s/backend/remote-sensing-pv-pvc.yaml
kubectl get pv remote-sensing-data-pv
kubectl get pvc -n gitlab-runner remote-sensing-data
```

验收：`PV/PVC` 状态均为 `Bound`。

### 4.1.1 手工准备 DEM 数据（建议首轮手工）

1. 将 `GMTED2010.jp2` 上传到 NFS：`/export/remote-sensing-data/dem/`
2. 启动后端后确认容器可见该文件：

```bash
POD=$(kubectl -n gitlab-runner get pod -l app=satellite-backend -o jsonpath='{.items[0].metadata.name}')
kubectl -n gitlab-runner exec "$POD" -- ls -l /opt/remote-sensing-data/dem
```

### 4.2 触发 GitLab `main` 流水线

流水线阶段：

1. `build-backend`
2. `build-frontend`
3. `deploy`
4. `topology-sync`

`deploy` 阶段会先执行部署前置检查脚本：

- `scripts/remote_sensing_preflight.sh`
- 硬性检查（失败则阻断部署）：
  - `PVC(remote-sensing-data)` 必须是 `Bound`
  - `satellite-backend` 必须声明 `resources.requests.ephemeral-storage`
  - Ready 节点不能出现 `DiskPressure=True`
- 告警检查（仅输出 `WARN`）：
  - namespace 内若存在 `Evicted` 的 `satellite-backend` Pod，会提示先清理节点磁盘再发起长任务

首次部署前需要先手工执行（一次）：

```bash
kubectl apply -f k8s/istio-rbac-gitlab-runner.yaml
```

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
- `dem_file=/opt/remote-sensing-data/dem/GMTED2010.jp2`
- `persist_output_dir=persist_output_preprocessing`
- `pan_rpc_parallelism=<n>`
- `pansharpen_parallelism=<n>`

### 5.3 容器内依赖确认

```bash
POD=$(kubectl -n gitlab-runner get pod -l app=satellite-backend -o jsonpath='{.items[0].metadata.name}')
kubectl -n gitlab-runner exec -it "$POD" -- /bin/sh -lc '/opt/remote-sensing/.venv/bin/python -c "from osgeo import gdal; import matplotlib; print(gdal.__version__)"'
```

### 5.3.1 Stage1 本地 scratch 挂载确认

```bash
POD=$(kubectl -n gitlab-runner get pod -l app=satellite-backend -o jsonpath='{.items[0].metadata.name}')
kubectl -n gitlab-runner exec "$POD" -- sh -lc 'mount | grep -E "/opt/remote-sensing/output_preprocessing|/opt/remote-sensing/persist_output_preprocessing"'
```

### 5.4 业务联动确认

提交一条遥感任务后，检查：

1. `fusion_stack_envi` 阶段完成
2. 自动执行 `imgshow.py`
3. 产物中有 `preview`，路径类似：
   `persist_output_preprocessing/imgshow/<prefix>-MSS1-fusion.png`

### 5.5 阶段1压测验收（推荐）

```bash
# 任务前
./scripts/remote_sensing_stage1_benchmark.sh pre --run-id stage1-run-001

# 任务后（task_id 按实际填写）
./scripts/remote_sensing_stage1_benchmark.sh post --run-id stage1-run-001 --task-id 11

# 查看报告
cat artifacts/benchmarks/stage1-run-001/report.txt
```

### 5.6 并发度 A/B 测试（阶段2）

建议测试档位：

1. `1/1`（保守）
2. `2/3`（当前默认，推荐）
3. `3/2`（反向对照）

执行方式：

```bash
kubectl -n gitlab-runner set env deploy/satellite-backend \
  SATELLITE_REMOTE_SENSING_STAGE_TIMEOUT_SECONDS=1800 \
  SATELLITE_REMOTE_SENSING_FUSION_STAGE_TIMEOUT_SECONDS=1500 \
  SATELLITE_REMOTE_SENSING_STAGE_MAX_RETRIES=1 \
  SATELLITE_REMOTE_SENSING_COMMAND_HEARTBEAT_SECONDS=60 \
  SATELLITE_REMOTE_SENSING_PAN_RPC_PARALLELISM=2 \
  SATELLITE_REMOTE_SENSING_PAN_RPC_CPU_THREADS=1 \
  SATELLITE_REMOTE_SENSING_PAN_RPC_WARP_MEM_MB=1024 \
  SATELLITE_REMOTE_SENSING_PAN_RPC_MAX_TOTAL_WARP_MEM_MB=2048 \
  SATELLITE_REMOTE_SENSING_PAN_RPC_RESAMPLE_ALG=near \
  SATELLITE_REMOTE_SENSING_PANSHARPEN_PARALLELISM=3 \
  SATELLITE_REMOTE_SENSING_PANSHARPEN_GDAL_THREADS=1
kubectl -n gitlab-runner rollout restart deploy/satellite-backend
kubectl -n gitlab-runner rollout status deploy/satellite-backend
```

阶段 2 实测结论（A/B/C 三组各两次）：

1. C 组（`warp_mem=1024`, `resample=near`）PAN RPC 耗时最低，当前作为部署默认档位
2. A 组（`warp_mem=1024`, `resample=bilinear`）次优，可作为质量优先对照档位
3. B 组（`warp_mem=1536`, `resample=bilinear`）明显变慢，不推荐作为默认

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

### 问题 2.1：`git ls-remote ... self-signed certificate`

原因：`CI_BUILD_IMAGE` 未内置内网 CA，导致容器内 `git` 不信任 GitLab 证书。  
定位命令：

```bash
docker run --rm 192.168.10.238/library/ci-build:docker25-git-amd64-r3 \
  sh -lc 'ls -l /usr/local/share/ca-certificates/harbor.crt && git ls-remote https://192.168.10.238:8444/root/satellite-remote-sensing.git'
```

### 问题 3：任务找不到输入/输出目录

原因：PVC 未绑定或 NFS 目录不存在。

定位：

```bash
kubectl -n gitlab-runner get pvc remote-sensing-data
kubectl -n gitlab-runner describe pod "$POD"
```

### 问题 4：后端构建 `apt-get update` 连接失败

现象：`Connection failed [IP ... 80]` 或 `Unable to locate package ...`。  
原因：构建容器访问外网 Debian 源失败（`ping` 可达不等于 `apt` 可达）。  
处理：采用预构建运行时镜像（如 `python:3.11-slim-bookworm-gdal-amd64-r1`），避免在 CI 构建阶段在线安装系统包。

### 问题 5：`go mod download` 长时间卡住

现象：后端构建长时间停留在 `RUN go mod download`。  
处理：在 `backend/Dockerfile` 构建阶段设置：

```dockerfile
ENV GOPROXY=https://goproxy.cn,direct \
    GOSUMDB=off
```

说明：该设置已在当前代码中落地，可作为新集群默认配置。

### 问题 6：跳板机 CLASH/iptables 导致 HTTP/HTTPS EOF

现象：worker 上 `curl http/https` 出现空回复或 TLS EOF。  
高频原因：跳板机 `nat PREROUTING` 将集群网段 TCP 重定向到本地代理端口（如 `CLASH -> REDIRECT 7892`）。

### 问题 7：`RuntimeError: 创建VRT失败` 或 `GMTED2010.jp2: No such file or directory`

原因：DEM 文件不存在或后端未挂载 `dem` 子目录。

定位：

```bash
kubectl -n gitlab-runner exec "$POD" -- ls -l /opt/remote-sensing-data/dem
kubectl -n gitlab-runner get deploy satellite-backend -o yaml | rg "SATELLITE_REMOTE_SENSING_DEM_FILE|/opt/remote-sensing-data/dem|subPath: dem"
```

### 问题 8：流程卡在 `fusion_stack_envi`，但 `fusion_envi/*.dat` 已出现

现象：

1. 阶段状态长期 `running`
2. `output_preprocessing/fusion_envi` 已有融合结果
3. `artifacts` 仍为空

处理：

1. 查看融合阶段关键日志（当前代码已增加）：

```bash
kubectl -n gitlab-runner logs deploy/satellite-backend | grep -E "fusion_stack_envi|imgshow|持久化"
```

说明：当前融合阶段已采用“后台异步持久化”，任务可先完成，随后日志会出现“后台持久化完成”。

2. 确认任务日志中是否有 `fusion_stack_envi` 和 `imgshow.py` 的执行记录：

```sql
select stage_name,level,created_at,content
from remote_sensing_task_logs
where task_id = <task_id>
order by created_at desc
limit 30;
```

3. 若长期无完成，确认后端镜像是否包含“融合超时+日志增强”版本。

临时修复示例（跳板机执行）：

```bash
sudo iptables -t nat -I CLASH 1 -s 192.168.10.0/24 -j RETURN
```

建议后续在跳板机侧做持久化配置，避免重启后规则丢失。

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
