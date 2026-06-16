# K8s Baseline 实施手册（RS 1～9 + 目标识别第 10 阶段）

> **文档定位**：15 节点集群 **1～10 全链路 baseline** 的 **单一入口（SSOT）**——含操作步骤、CI/NFS/仓库机、故障排查，以及 **2026-06 实际部署记录**（附录 A）。  
> **文档索引**：[DOCUMENTATION_INDEX.md](./DOCUMENTATION_INDEX.md)（三仓归类与阅读路线）。  
> **目标**：单 Pod `satellite-backend` 跑通 RS + 目标识别，**暂不拆微服务、不上 Redis/Argo**。  
> **关联**：[REMOTE_SENSING_K8S_DEPLOYMENT.md](./REMOTE_SENSING_K8S_DEPLOYMENT.md)、[REMOTE_SENSING_REPO_MIRROR.md](./REMOTE_SENSING_REPO_MIRROR.md)、[OBJECT_DETECTION_REPO_MIRROR.md](./OBJECT_DETECTION_REPO_MIRROR.md)、[MICROSERVICES_IMPLEMENTATION_PLAN.md](./MICROSERVICES_IMPLEMENTATION_PLAN.md) §5 阶段 0。

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

### 2.3 代码同步：GitHub → 仓库机 → 内网 GitLab

本集群实际路径：**开发机 push GitHub** → **k8s-repository（即 192.168.10.238）bare mirror** → **内网 GitLab**。  
CI **不读 GitHub**，只读 GitLab HTTPS + Job Token。

#### 方式 A — 仓库机 bare mirror + `gitlab-internal`（本集群已验证）

仓库机目录示例：`~/Code/*.git`

| bare 仓 | GitHub remote | 推 GitLab remote |
|---------|---------------|------------------|
| `satellite-cloud.git` | `github` → `PCL-Satellite-Cloud-Native/satellite-cloud` | `satellite-cloud` → `gitlab-internal:root/satellite-cloud.git` |
| `Satellite-Remote-Sensing.git` | `origin` → `.../Satellite-Remote-Sensing` | `remote-sensing` → `gitlab-internal:root/satellite-remote-sensing.git` |
| `Object-Detection.git` | `origin` → `.../Object-Detection` | `object-detection` → `gitlab-internal:root/object-detection.git` |

```bash
# 更新 Object-Detection 示例
git -C ~/Code/Object-Detection.git fetch origin --prune
git -C ~/Code/Object-Detection.git remote add object-detection gitlab-internal:root/object-detection.git 2>/dev/null || true
git -C ~/Code/Object-Detection.git push object-detection --all --force
git -C ~/Code/Object-Detection.git push object-detection --tags --force

# satellite-cloud（含 detection-builder / download_ort.sh 的 commit 必须先上 GitHub）
git -C ~/Code/satellite-cloud.git fetch github --prune
git -C ~/Code/satellite-cloud.git push satellite-cloud --all --force
```

注意：

- 从 GitHub 拉用 **`fetch github` / `fetch origin`**，不要用会 `Permission denied` 的旧 SSH `origin`（2224 端口）。
- 推 GitLab 用 **`gitlab-internal:`**，不要用 HTTPS（自签证书会失败）。
- **先**在 GitLab 配好 CI 变量与 Job Token，**再** push `satellite-cloud` 触发 pipeline。

#### 方式 B — 脚本或 HTTPS Token

详见 [OBJECT_DETECTION_REPO_MIRROR.md](./OBJECT_DETECTION_REPO_MIRROR.md)、[REMOTE_SENSING_REPO_MIRROR.md](./REMOTE_SENSING_REPO_MIRROR.md)（`sync_*_repo.sh` + Personal Access Token）。

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

**配置位置**：内网 GitLab → 项目 **`root/satellite-cloud`** → Settings → CI/CD → Variables（不是 Object-Detection / RS 子仓）。

| 变量 | 必填 | 说明 |
|------|------|------|
| `HARBOR_USER` / `HARBOR_PASSWORD` | 是 | Harbor 推送 |
| `REMOTE_SENSING_REPO_URL` | 是 | `https://192.168.10.238:8444/root/satellite-remote-sensing.git` |
| `OBJECT_DETECTION_REPO_URL` | 是 | `https://192.168.10.238:8444/root/object-detection.git` |
| `OBJECT_DETECTION_REPO_REF` | 否 | 默认 `main` |
| `REMOTE_SENSING_REPO_REF` | 否 | 默认 `main` |
| `ORT_DOWNLOAD_URL` | **是（内网）** | 见 §5.2 |
| `FONT_DOWNLOAD_URL` | **是（内网）** | 见 §5.2 |

> `OBJECT_DETECTION_REPO_URL` 未配置时 `build-backend` 直接失败。  
> 子仓 **Job Token**：在 `object-detection`、`satellite-remote-sensing` 项目允许 **satellite-cloud** inbound `read_repository`。

### 5.1 构建阶段网络（内网无法稳定访问 GitHub 时）

`detection-builder` 默认会从 GitHub 下载 ORT 与字体；内网 CI 常出现 `curl: (18)` 或 `ORT 包过小 (785 bytes)`（实际下到 HTML 跳转页）。**必须**配置 §5.2 内网镜像 URL，并推送含 `backend/scripts/download_ort.sh` 的 `satellite-cloud` 代码。

### 5.2 构建依赖内网镜像（ORT + 字体）— 本集群方案

| 用途 | 放哪 | CI 变量 | 运行时 Pod 是否用 |
|------|------|---------|-------------------|
| ORT `.tgz`、Noto 字体 | **238 静态 HTTP** | `ORT_DOWNLOAD_URL`、`FONT_DOWNLOAD_URL` | 否（已打进镜像） |
| 检测模型 `.onnx` | **NFS** `models/yolov8m-obb.onnx` | 无 | 是（PVC 挂载） |

**本集群已验证（方案 A — 独立端口）**：

1. 文件放在 238：`/usr/share/nginx/html/static/`（ORT ~7.8MB，字体 ~16MB）
2. 因 443 被 GitLab/Harbor 占用，`https://192.168.10.238/static/...` 会返回 **785B HTML**，不可用
3. 用临时 HTTP 服务（重启 238 需重新拉起，或后续改 nginx `location /static`）：

```bash
cd /usr/share/nginx/html/static
nohup python3 -m http.server 18080 --bind 0.0.0.0 > /tmp/static-http.log 2>&1 &
```

4. CI 变量（**satellite-cloud** 项目）：

| 变量 | 值 |
|------|-----|
| `ORT_DOWNLOAD_URL` | `http://192.168.10.238:18080/onnxruntime-linux-x64-1.24.4.tgz` |
| `FONT_DOWNLOAD_URL` | `http://192.168.10.238:18080/NotoSansCJKsc-Regular.otf` |

Runner 验收：`curl -f -o /tmp/t.tgz "$ORT_DOWNLOAD_URL" && ls -lh /tmp/t.tgz` → 约 **7.8M**。

**方案 B（长期）**：在 443 的 nginx `server` 增加 `location /static/ { alias /usr/share/nginx/html/static/; }`，CI 改 `https://192.168.10.238/static/...` 并设 `CURL_INSECURE=true`。baseline 跑通后再做即可。

本地准备文件：`scripts/mirror_build_deps.sh`；WSL 已有 `Object-Detection/third_party/*.so` **不能**替代 CI 用的 `.tgz`。

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

### 7.5 记录 Phase 0 baseline

| 指标 | 记录方式 |
|------|----------|
| RS 1～9 总耗时 | 任务详情各 stage `duration_ms` 之和 |
| Stage 10 耗时 | `object_detection` 阶段 |
| 端到端 | 创建 → completed |
| 瓦片数 / 目标数 | detection-stats API |
| CPU / 内存峰值 | Grafana 或 `kubectl top pod`（可选） |

**2026-06 本集群首次全链路验收**（GF2 示例、`device=cpu`、单 Pod）：见 **附录 A**。

### 7.6 阶段 10「看起来卡住」是否正常

- 默认超时 **14400s（4h）**；CPU 全图检测 **30～90 分钟** 都可能。
- 后端约 **60s** 一条「心跳: yolov8s 仍在运行」；yolov8s 进度日志多在进程结束前才写入 DB。
- 判断是否真卡死：`ps` 有 `yolov8s`、`output_detection/rs_task_<id>/` 文件数持续增加 → **继续等**。
- 合理端到端：**40～90 分钟**（本集群 **46m36s** 属正常偏快）。

---

## 8. 常见失败与处理

| 现象 | 原因 | 处理 |
|------|------|------|
| `build-backend`: `COPY object-detection-src` 失败 | 未 clone OD 仓 | 配置 `OBJECT_DETECTION_REPO_URL` + Job Token |
| `git ls-remote` 401/403 | Job Token 无跨仓读权限 | OD/RS 仓 Allowlist satellite-cloud |
| `curl: (18)` 从 GitHub 下 ORT | Runner 外网不稳定 | §5.2 配 `ORT_DOWNLOAD_URL` |
| `ORT 包过小 (785 bytes)` | URL 下到 HTML（308/404），非 tgz | 用 `:18080` 或 nginx `/static`；`curl -f` 验收 **~7.8MB** |
| `http://192.168.10.238/static` 308 → 785B | 443 非静态站点 | 勿用该 URL；见 §5.2 |
| HTTPS push GitLab `certificate verify failed` | 自签证书 | 仓库机用 `gitlab-internal:` 推送 |
| `fetch_font.sh` 失败 | 同上 | `FONT_DOWNLOAD_URL` 指向内网 |
| 日志无 `Object detection runtime configured` | 旧镜像（Pod 运行数月） | 新 pipeline deploy 后 **rollout**；启动日志只在 Pod 创建时打一次 |
| stage 10: 找不到模型 | NFS 无 `models/yolov8m-obb.onnx` 或 `config.env` 路径不一致 | §2.1 + §4 |
| `libonnxruntime.so` 找不到 | 镜像未含 detection-builder 产物 | 重建 backend 镜像 |
| 检测图右侧白条 | 字体未嵌入 | 重建镜像 + `fetch_font.sh` / 内网字体 URL |
| 阶段 10 很久不动 | CPU 推理正常慢 | §7.6；查 `yolov8s` 进程与输出目录增长 |
| stage 10 OOM | 内存 limit 4Gi | 临时提到 8Gi；后续 od-worker |
| 只有 RS 无 stage 10 | `enable_detection=false` 或未迁移 | migrate `000007` |

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

## 附录 A：2026-06 集群实际部署记录（归档）

> 环境：15 Node K8s；namespace `gitlab-runner`；GitLab/Harbor/仓库机均为 **192.168.10.238**（`k8s-repository`）；NFS 数据在 **112**（`remote-sensing-data` PVC）；GitHub 组织 **PCL-Satellite-Cloud-Native**。

### A.1 架构与调用方式（baseline）

- **单 Pod** `satellite-backend`：Go `RemoteSensingService` 串行阶段 1～10。
- 阶段 1～9：`exec` Python（`/opt/remote-sensing/.venv/bin/python`）。
- 阶段 10：`exec` `/opt/object-detection/yolov8s -cpu`（同 Pod 子进程，**非**独立 Deployment / HTTP）。
- 镜像构建：CI clone GitLab 上 RS + OD 源码 → Dockerfile `detection-builder` 编译 `yolov8s` + ORT。
- 模型：NFS 挂载 `/opt/object-detection/yolov8m-obb.onnx`；检测输出 NFS `object_detection_output/`。

### A.2 部署时间线（摘要）

| 步骤 | 动作 | 结果 |
|------|------|------|
| 1 | 集群 RS 1～9 已运行；PVC `Bound` | 通过 |
| 2 | GitHub 三仓 push；238 上建 `Object-Detection.git` mirror | 通过 |
| 3 | `gitlab-internal` push → GitLab `root/object-detection`、`satellite-remote-sensing` | 通过 |
| 4 | GitLab Job Token + CI 变量 `REMOTE/OBJECT_DETECTION_REPO_URL` | 通过 |
| 5 | NFS 上传 `yolov8m-obb.onnx`；`object_detection_output` 目录 | 通过 |
| 6 | CI 构建 ORT 失败（GitHub `curl 18`）→ 238 `:18080` 静态 + `ORT/FONT_DOWNLOAD_URL` | 通过 |
| 7 | push `satellite-cloud`（含 `download_ort.sh`）→ pipeline deploy | 通过 |
| 8 | 前端提交 RS 任务，`enable_detection=true` | **10 阶段 success** |

### A.3 已验证 CI 变量（satellite-cloud 项目）

```
REMOTE_SENSING_REPO_URL=https://192.168.10.238:8444/root/satellite-remote-sensing.git
OBJECT_DETECTION_REPO_URL=https://192.168.10.238:8444/root/object-detection.git
ORT_DOWNLOAD_URL=http://192.168.10.238:18080/onnxruntime-linux-x64-1.24.4.tgz
FONT_DOWNLOAD_URL=http://192.168.10.238:18080/NotoSansCJKsc-Regular.otf
HARBOR_USER / HARBOR_PASSWORD=（已有）
```

### A.4 Phase 0 性能基线（首次全链路）

| 指标 | 值 | 备注 |
|------|-----|------|
| 输入 | GF2 示例（`GF2_PMS1_E118.6_N37.4_20160826_L1A0001792619`） | 与本地/WSL 同套 |
| 端到端 | **46 分 36 秒** | RS + CPU 检测 |
| 阶段 10 观感 | 约 44 分钟时 UI 仍显示 running，随后完成 | 正常，见 §7.6 |
| 环境 | `SATELLITE_OBJECT_DETECTION_DEVICE=cpu`；Pod limit **2 CPU / 4Gi** | 未上 GPU |
| 结论 | **baseline 验收通过** | 可进入微服务 Phase 1 评审 |

### A.5 运维备忘

- **238 重启后**：检查 `python3 -m http.server 18080` 是否需重新拉起（或改 nginx 方案 B）。
- **代码更新流程**：开发机 → GitHub → 238 `fetch` → `push gitlab-internal` → satellite-cloud pipeline。
- **勿混淆**：CI 构建依赖（ORT tgz）走 HTTP；推理模型走 NFS；二者路径不同。

---

**文档维护**：部署流程、CI 变量或仓库机方式变更时，优先更新本文附录 A 与 §5.2；细节同步 [REMOTE_SENSING_K8S_DEPLOYMENT.md](./REMOTE_SENSING_K8S_DEPLOYMENT.md) §2.5、§3.2。
