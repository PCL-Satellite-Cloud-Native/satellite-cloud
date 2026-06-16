# K8s Baseline 实施手册（RS 1～9 + 目标识别第 10 阶段）

> **目标**：在现有 15 节点 K8s 集群上，把 **satellite-cloud + Satellite-Remote-Sensing + Object-Detection** 串成一条可验收的 baseline 流水线，**暂不拆微服务、不上 Redis/Argo**。  
> **前提**：集群里已跑通 RS 1～9；Object-Detection **尚未**在内网 GitLab / 镜像 / NFS 模型。  
> **关联**：[REMOTE_SENSING_K8S_DEPLOYMENT.md](./REMOTE_SENSING_K8S_DEPLOYMENT.md) §2.5、[MICROSERVICES_IMPLEMENTATION_PLAN.md](./MICROSERVICES_IMPLEMENTATION_PLAN.md) Phase 0。

---

## 0. 总览（你要做的事）

| 序号 | 事项 | 在哪里做 | 验收 |
|------|------|----------|------|
| A | 本地确认 RS+检测已在 WSL 跑通 | 开发机 | 本地任务 10 阶段全绿 |
| B | 推送 **satellite-cloud**（含检测集成代码）到内网 GitLab | 开发机 → GitLab | `main` 含 Dockerfile `detection-builder`、deployment 检测 env |
| C | 建仓并同步 **Object-Detection** 到内网 GitLab | 中转机 | GitLab 可见 `main`，含 `scripts/fetch_font.sh` |
| D | **config.env** 改为 K8s 模型路径 + CPU | Object-Detection 仓库 | `MODEL_PATH=./yolov8m-obb.onnx`，`USE_CPU=true` |
| E | NFS 上传模型 + 创建 `object_detection_output` | NFS 服务器 | `models/yolov8m-obb.onnx` 约 100MB+ |
| F | GitLab CI 变量 + Job Token 跨仓读权限 | GitLab UI | `build-backend` 能 clone 两个子仓 |
| G | 触发 pipeline，部署新 backend/frontend | GitLab CI | rollout 成功 |
| H | Pod 内验收 yolov8s / 模型 / 日志 | kubectl | 见 §6 |
| I | 提交一条含检测的 RS 任务，全链路验收 | 前端 | stage 10 成功、预览/zip/统计 |
| J | 记录 baseline 耗时（Phase 0） | 文档/表格 | 供第三方测试对照 |

---

## 1. 本地前置（开发机，约 30 分钟）

### 1.1 确认三仓代码版本一致

- **satellite-cloud**：含 `backend/internal/objectdetection/`、`detection_stage.go`、`RemoteSensing.vue` 检测 Tab、`000007` 迁移。
- **Satellite-Remote-Sensing**：与服务器 GitLab 上 RS 仓一致或更新（CI 仍从 GitLab 拉，不是 GitHub）。
- **Object-Detection**：能在 WSL 编译并 `-cpu` 跑通（见 `Object-Detection/K8S_RUNTIME_PREP.md`）。

### 1.2 本地 WSL 烟雾测试（强烈建议）

```bash
cd /mnt/d/Code/pcl_satellite_project/Object-Detection
bash scripts/fetch_font.sh
go build -o yolov8s .
export LD_LIBRARY_PATH=./third_party:$LD_LIBRARY_PATH
./yolov8s -cpu -h
```

本地 satellite-cloud：backend `.env` 配 `SATELLITE_OBJECT_DETECTION_ROOT` + `wsl-detection.cmd`，提交一条 **enable_detection=true** 的任务，确认第 10 阶段成功。

---

## 2. Object-Detection 上内网 GitLab（一次性）

### 2.1 修改 K8s 专用配置（提交前必做）

容器内模型通过 NFS **单文件挂载**到：

`/opt/object-detection/yolov8m-obb.onnx`

而仓库默认 `config.env` 指向 `./yolov8-obb-finetune-best-batch8.onnx`，**不修改会导致 stage 10 找不到模型**。

在 **Object-Detection** 仓库编辑 `config.env`：

```env
USE_CPU=true
MODEL_PATH=./yolov8m-obb.onnx
```

> 若你本地模型文件名仍是 `yolov8-obb-finetune-best-batch8.onnx`，上传到 NFS 时请 **重命名为** `yolov8m-obb.onnx`，或改 deployment 挂载名与 `MODEL_PATH` 保持一致（三处必须同名）。

确认 `*.sh` 为 **LF** 换行（仓库已有 `.gitattributes`）；Windows 编辑后可在 WSL 执行 `dos2unix scripts/*.sh` 或直接用 `bash scripts/xxx.sh`。

### 2.2 在内网 GitLab 新建私有仓库

1. 与 `satellite-cloud`、`Satellite-Remote-Sensing` 同一 Group。
2. 仓库名示例：`object-detection` 或 `Object-Detection`。
3. 默认分支：`main`，保护 `main`。

### 2.3 从中转机同步代码

详见 [OBJECT_DETECTION_REPO_MIRROR.md](./OBJECT_DETECTION_REPO_MIRROR.md)。

```bash
cd /path/to/satellite-cloud
export GITHUB_REPO_SSH='git@github.com:<org>/Object-Detection.git'
export GITLAB_REPO_HTTPS='https://192.168.10.238:8444/<group>/object-detection.git'
export GITLAB_USERNAME='root'
export GITLAB_TOKEN='<token-with-write_repository>'
bash scripts/sync_object_detection_repo.sh
```

**方式 B — 从开发机直接 push**（若 GitLab 可从办公网访问）：

```bash
cd /mnt/d/Code/pcl_satellite_project/Object-Detection
git remote add gitlab https://192.168.10.238:8444/<group>/object-detection.git
git push gitlab main
```

### 2.4 Job Token 跨仓权限

在 **Object-Detection 仓库**（被拉取方）设置：

- 允许 **satellite-cloud** 项目的 CI Job Token **read_repository**（Inbound Job Token / Allowlist，视 GitLab 版本而定）。

与 [REMOTE_SENSING_REPO_MIRROR.md](./REMOTE_SENSING_REPO_MIRROR.md) §4 对 RS 仓的配置相同。

---

## 3. satellite-cloud 推送到 GitLab

确认 `main` 包含至少：

- `backend/Dockerfile` — `detection-builder` 阶段
- `.gitlab-ci.yml` — 克隆 `OBJECT_DETECTION_REPO_URL`
- `k8s/backend/deployment.yaml` — `SATELLITE_OBJECT_DETECTION_*` 与 NFS 挂载
- `frontend` — 检测 Tab、`detection-stats`、zip 下载

```bash
cd /path/to/satellite-cloud
git status
git push origin main   # 或 push 到内网 GitLab remote
```

---

## 4. NFS 与模型（一次性）

在 **NFS 服务器**（路径与现有 RS PVC 一致，示例 `/export/remote-sensing-data`）：

```bash
sudo mkdir -p /export/remote-sensing-data/object_detection_output
sudo mkdir -p /export/remote-sensing-data/models
# 上传模型（本地文件名可不同，NFS 上必须是 yolov8m-obb.onnx）
sudo cp /path/to/yolov8m-obb.onnx /export/remote-sensing-data/models/
sudo chmod -R 0777 /export/remote-sensing-data/object_detection_output
sudo chmod 644 /export/remote-sensing-data/models/yolov8m-obb.onnx
ls -lh /export/remote-sensing-data/models/yolov8m-obb.onnx
```

`deployment.yaml` 里 **initContainer** 会在 Pod 启动时创建 `object_detection_output`、`models` 子目录（若 PVC 已 Bound，通常只需保证模型文件存在）。

**不要**把 `.onnx` 打进 Git 仓库（体积大、LFS 麻烦）；baseline 阶段 **NFS 单文件挂载**即可。

---

## 5. GitLab CI/CD 变量

在 **satellite-cloud** 项目 → Settings → CI/CD → Variables：

| 变量 | 必填 | 说明 |
|------|------|------|
| `HARBOR_USER` / `HARBOR_PASSWORD` | 是 | 已有 |
| `REMOTE_SENSING_REPO_URL` | 是 | 已有 RS 内网 HTTPS 地址 |
| `OBJECT_DETECTION_REPO_URL` | **是** | 例：`https://192.168.10.238:8444/<group>/object-detection.git` |
| `OBJECT_DETECTION_REPO_REF` | 否 | 默认 `main` |
| `REMOTE_SENSING_REPO_REF` | 否 | 默认 `main` |

> **注意**：`OBJECT_DETECTION_REPO_URL` 与 `REMOTE_SENSING_REPO_URL` 同为必填；未配置时 `build-backend` 会直接失败。

### 5.1 构建阶段网络要求

`build-backend` 的 Docker 构建会在 **detection-builder** 阶段：

1. `bash scripts/fetch_font.sh`（可能访问 GitHub raw）
2. `curl` 下载 ONNX Runtime CPU **1.24.4**（GitHub releases）

请确认 **CI Runner 或构建节点**能访问上述地址（或预置 Harbor 代理镜像/内网缓存）。若 RS 镜像已能成功 build，通常同一 Runner 可用。

---

## 6. 触发部署与 Pod 验收

### 6.1 触发 pipeline

推送 `satellite-cloud` 的 `main`，或 GitLab UI 手动 Run pipeline。

阶段：`build-backend` → `build-frontend` → `deploy` → `topology-sync`。

**build-backend 日志应出现**：

```
git clone ... backend/object-detection-src
...
detection-builder: go build -o yolov8s .
```

### 6.2 数据库迁移

后端启动时 **自动执行** embed 迁移（含 `000006`、`000007`）。无需手工跑 SQL，除非你们禁用了 migrate。

`000007` 会为已有 RS 任务补 **stage 10 `object_detection`**，并增加 `enable_detection` 等字段。

### 6.3 Pod 内硬性验收

```bash
POD=$(kubectl -n gitlab-runner get pod -l app=satellite-backend -o jsonpath='{.items[0].metadata.name}')

# 1) 检测二进制与 ORT
kubectl -n gitlab-runner exec "$POD" -- ls -l /opt/object-detection/yolov8s
kubectl -n gitlab-runner exec "$POD" -- ls /opt/object-detection/third_party/*.so

# 2) 模型（必须非 0 字节）
kubectl -n gitlab-runner exec "$POD" -- ls -lh /opt/object-detection/yolov8m-obb.onnx

# 3) config.env 指向的相对路径在容器 cwd=/opt/object-detection 下可读
kubectl -n gitlab-runner exec "$POD" -- cat /opt/object-detection/config.env | grep MODEL_PATH

# 4) 后端日志
kubectl -n gitlab-runner logs deploy/satellite-backend | grep -E "Object detection|Remote sensing runtime"
```

期望日志含：

- `Remote sensing runtime configured`（RS）
- `Object detection runtime configured`（检测根目录、runner、device=cpu）

### 6.4 可选：容器内手动跑一条检测

```bash
kubectl -n gitlab-runner exec -it "$POD" -- /bin/sh -lc '
  cd /opt/object-detection
  export LD_LIBRARY_PATH=/opt/object-detection/third_party
  ./yolov8s -cpu -h
'
```

---

## 7. 业务全链路验收（Baseline 通过标准）

### 7.1 准备输入数据

与现有 RS 流程相同：GF 等原始数据在 NFS `input/`，DEM 在 `dem/GMTED2010.jp2`（若 RS 已跑通，无需重复准备）。

### 7.2 提交任务

前端「遥感任务」创建任务，确认：

- **启用目标识别**（默认 `enable_detection=true`）
- 可选：`detection_classes`（空 = 全部 8 类）

或使用 API（示例）：

```json
{
  "name": "baseline-k8s-001",
  "input_paths": ["..."],
  "enable_detection": true,
  "detection_classes": "",
  "detection_draw_labels": false
}
```

### 7.3 阶段检查

| 阶段 | 名称 | 验收 |
|------|------|------|
| 1～9 | RS 预处理～融合预览 | 与现网一致，`fusion_stack_envi`、`imgshow` 成功 |
| **10** | `object_detection` | status=success，日志无 ONNX/模型路径错误 |

```bash
# 替换 TASK_ID
kubectl -n gitlab-runner exec "$POD" -- ls -la /opt/object-detection/output_detection/rs_task_<TASK_ID>/
```

### 7.4 前端/API 验收

1. 融合图 + **按类别 Tab** 的检测预览（每类最多 8 张预览，Tab 显示总瓦片数）。
2. **瓦片 vs 目标** 统计：`GET /api/remote-sensing/tasks/:id/detection-stats`。
3. **下载全部检测瓦片**：`GET .../detection-tiles.zip`。
4. 检测 JPG **右侧信息栏有中文**，不是 300px 白条。

### 7.5 记录 Phase 0 baseline（建议表格）

| 指标 | 记录方式 |
|------|----------|
| RS 1～9 总耗时 | 任务详情各 stage `duration_ms` 之和 |
| Stage 10 耗时 | `object_detection` 阶段 |
| 端到端 | 创建 → completed |
| 瓦片数 / 目标数 | detection-stats API |
| CPU / 内存峰值 | Grafana 或 `kubectl top pod`（可选） |

写入 [MICROSERVICES_IMPLEMENTATION_PLAN.md](./MICROSERVICES_IMPLEMENTATION_PLAN.md) Phase 0 或单独 spreadsheet，作为微服务拆分前的 **对照基线**。

---

## 8. 常见失败与处理

| 现象 | 原因 | 处理 |
|------|------|------|
| `build-backend`: `COPY object-detection-src` 失败 | 未 clone OD 仓 | 配置 `OBJECT_DETECTION_REPO_URL` + Job Token |
| `git ls-remote` 401/403 | Job Token 无跨仓读权限 | OD 仓 Allowlist satellite-cloud |
| `fetch_font.sh` / `curl ORT` 失败 | Runner 无外网 | 内网缓存 ORT tgz / 字体，或改 Dockerfile 用 Harbor 镜像 |
| 日志无 `Object detection runtime configured` | 旧镜像或未设 `SATELLITE_OBJECT_DETECTION_ROOT` | 确认 deploy 用了新镜像与 deployment.yaml |
| stage 10: 找不到模型 | `config.env` MODEL_PATH 与挂载文件名不一致 | §2.1 改 `config.env` 或改 NFS/deployment 文件名 |
| `libonnxruntime.so` 找不到 | third_party 未打进镜像 | 重建 backend 镜像，检查 detection-builder 日志 |
| 检测图右侧白条 | 字体未嵌入 | 重建镜像（须执行 `fetch_font.sh`）；容器已有 `fonts-noto-cjk` 备份 |
| stage 10 OOM / 极慢 | CPU 推理大 fusion 图 | baseline 预期；调大 `limits.memory`；后续 GPU + od-worker |
| 只有 RS 无 stage 10 | DB 未迁移或 `enable_detection=false` | 重启 backend 触发 migrate；查 task 字段 |

---

## 9. 完成 baseline 后再做什么（明确不做）

**本手册完成后你应达到**：单 Pod backend 跑通 **10 阶段**，产物在 NFS，前端可预览/下载/统计。

**此时仍不要做**（见微服务方案 Phase 1+）：

- Redis 队列、rs-worker / od-worker 拆分
- Argo Workflow DAG
- 120 节点扩缩与多星协同压测

下一步：用 Phase 0 数据评审是否进入 [MICROSERVICES_IMPLEMENTATION_PLAN.md](./MICROSERVICES_IMPLEMENTATION_PLAN.md) 的 Phase 1（API 与 Worker 分离）。

---

## 10. 快速命令清单（复制用）

```bash
# --- NFS ---
sudo mkdir -p /export/remote-sensing-data/{object_detection_output,models}
sudo cp yolov8m-obb.onnx /export/remote-sensing-data/models/
sudo chmod -R 0777 /export/remote-sensing-data/object_detection_output

# --- 部署后验收 ---
POD=$(kubectl -n gitlab-runner get pod -l app=satellite-backend -o jsonpath='{.items[0].metadata.name}')
kubectl -n gitlab-runner exec "$POD" -- ls -lh /opt/object-detection/yolov8m-obb.onnx
kubectl -n gitlab-runner logs deploy/satellite-backend | grep "Object detection"

# --- 任务产物 ---
kubectl -n gitlab-runner exec "$POD" -- ls /opt/object-detection/output_detection/rs_task_<ID>/
```

---

**文档维护**：Object-Detection 首次上 GitLab、模型路径或 CI 变量变更时，同步更新本节与 [REMOTE_SENSING_K8S_DEPLOYMENT.md](./REMOTE_SENSING_K8S_DEPLOYMENT.md) §2.5。
