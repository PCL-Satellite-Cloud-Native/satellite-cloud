# Object-Detection 仓库镜像与 CI 拉取配置（内网 GitLab）

与 [REMOTE_SENSING_REPO_MIRROR.md](./REMOTE_SENSING_REPO_MIRROR.md) 相同模式：中转机同步 GitHub → 内网 GitLab，`satellite-cloud` CI 用 Job Token 拉取并打入 backend 镜像。

## 1. 一次性准备：在内网 GitLab 新建仓库

在内网 GitLab 创建私有仓库（示例名）：`object-detection` 或 `Object-Detection`

建议：

1. 与 `satellite-cloud`、`Satellite-Remote-Sensing` 放在同一 Group
2. 默认分支 `main`，保护 `main`
3. 推送前确认 `config.env` 含：
   - `MODEL_PATH=./yolov8m-obb.onnx`
   - `USE_CPU=true`（K8s baseline；backend 仍会传 `-cpu`）

## 2. 中转机同步 GitHub → 内网 GitLab

### 2.1 本集群方式：k8s-repository bare mirror（推荐）

仓库机 **即 192.168.10.238**（`k8s-repository`），使用 **bare 仓 + `gitlab-internal:`** 推送，无需 HTTPS Token。

```bash
# Object-Detection 示例
git clone --mirror git@github.com:PCL-Satellite-Cloud-Native/Object-Detection.git
git -C Object-Detection.git remote add object-detection gitlab-internal:root/object-detection.git
git -C Object-Detection.git fetch origin --prune
git -C Object-Detection.git push object-detection --all --force
```

完整三仓流程与 CI 变量见 [K8S_BASELINE_RUNBOOK.md](./K8S_BASELINE_RUNBOOK.md) §2.3、附录 A。

### 2.2 脚本方式（HTTPS + Token）

脚本：`scripts/sync_object_detection_repo.sh`

```bash
cd /path/to/satellite-cloud
export GITHUB_REPO_SSH='git@github.com:PCL-Satellite-Cloud-Native/Object-Detection.git'
export GITLAB_REPO_HTTPS='https://192.168.10.238:8444/root/object-detection.git'
export GITLAB_USERNAME='root'
export GITLAB_TOKEN='<gitlab-token>'
bash scripts/sync_object_detection_repo.sh
```

验收：

1. 内网 GitLab 可见 `main` 分支
2. `config.env`、`scripts/fetch_font.sh`、Go 源码齐全
3. **不要**把 `.onnx` 模型提交进 Git（走 NFS 挂载）

## 3. satellite-cloud CI 变量

| 变量 | 说明 |
|------|------|
| `OBJECT_DETECTION_REPO_URL` | 内网 HTTPS，例：`https://192.168.10.238:8444/root/object-detection.git` |
| `OBJECT_DETECTION_REPO_REF` | 可选，默认 `main` |

自 baseline 起，`OBJECT_DETECTION_REPO_URL` **未配置将导致 build-backend 失败**（与 `REMOTE_SENSING_REPO_URL` 同等必填）。

## 4. Job Token 权限

在 **Object-Detection 仓库（被拉取方）** 配置：

1. 允许 `satellite-cloud` 项目的 CI Job Token 访问（Inbound Job Token / Allowlist）
2. 至少 `read_repository`

## 5. 流水线验收

`build-backend` 日志应包含：

```
git clone ... backend/object-detection-src
detection-builder: bash scripts/fetch_font.sh
detection-builder: go build -o yolov8s .
```

部署后 Pod 内：

```bash
POD=$(kubectl -n gitlab-runner get pod -l app=satellite-backend -o jsonpath='{.items[0].metadata.name}')
kubectl -n gitlab-runner exec "$POD" -- cat /opt/object-detection/config.env | grep MODEL_PATH
kubectl -n gitlab-runner exec "$POD" -- ls -lh /opt/object-detection/yolov8m-obb.onnx
```

## 6. 常见失败

| 现象 | 处理 |
|------|------|
| `OBJECT_DETECTION_REPO_URL 未配置` | 在 CI/CD Variables 添加 |
| 401/403 on clone | Object-Detection 仓开放 Job Token |
| stage 10 找不到模型 | NFS 上传 `models/yolov8m-obb.onnx`；与 `config.env` 一致 |
| 镜像无 `config.env` | 使用含 `COPY config.env` 的最新 backend Dockerfile |

完整 baseline 步骤见 [K8S_BASELINE_RUNBOOK.md](./K8S_BASELINE_RUNBOOK.md)。
