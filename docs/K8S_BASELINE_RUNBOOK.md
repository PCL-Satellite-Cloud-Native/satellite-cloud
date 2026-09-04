# K8s Baseline 实施手册（RS 1～9 + 目标识别第 10 阶段）

> **文档定位**：15 节点集群 **1～10 全链路 baseline** 的 **单一入口（SSOT）**——含操作步骤、CI/NFS/仓库机、故障排查，以及 **2026-06 实际部署记录**（附录 A）。  
> **Phase 0 历史快照**（只读）：[archives/2026-06-17_phase0-closure.md](./archives/2026-06-17_phase0-closure.md) — 三次 benchmark 完整表。  
> **Phase 1 历史快照**（只读）：[archives/2026-06-18_phase1-closure.md](./archives/2026-06-18_phase1-closure.md) — Redis + rs-worker 收口。  
> **Phase 2 历史快照**（只读）：[archives/2026-06-18_phase2-closure.md](./archives/2026-06-18_phase2-closure.md) — od-worker 收口。  
> **活跃运维**：[PHASE2_RUNBOOK.md](./PHASE2_RUNBOOK.md)（Phase 2）、[PHASE1_RUNBOOK.md](./PHASE1_RUNBOOK.md)（Phase 1）  
> **文档索引**：[DOCUMENTATION_INDEX.md](./DOCUMENTATION_INDEX.md)（三仓归类与阅读路线）。  
> **目标**：单 Pod `satellite-backend` 跑通 RS + 目标识别，**暂不拆微服务、不上 Redis/Argo**。  
> **关联**：[REMOTE_SENSING_K8S_DEPLOYMENT.md](./REMOTE_SENSING_K8S_DEPLOYMENT.md)、[REMOTE_SENSING_REPO_MIRROR.md](./REMOTE_SENSING_REPO_MIRROR.md)、[OBJECT_DETECTION_REPO_MIRROR.md](./OBJECT_DETECTION_REPO_MIRROR.md)；**Phase 0 收口**见 **§11**。

---

## 0. 总览（你要做的事）


| 序号  | 事项                                        | 在哪里做                | 验收                                                        |
| --- | ----------------------------------------- | ------------------- | --------------------------------------------------------- |
| A   | 本地确认 RS+检测已在 WSL 跑通                       | 开发机                 | 本地任务 10 阶段全绿                                              |
| B   | 推送 **satellite-cloud**（含检测集成代码）到内网 GitLab | 开发机 → GitLab        | `main` 含 Dockerfile `detection-builder`、deployment 检测 env |
| C   | 建仓并同步 **Object-Detection** 到内网 GitLab     | 中转机                 | GitLab 可见 `main`，含 `scripts/fetch_font.sh`                |
| D   | **config.env** 改为 K8s 模型路径 + CPU          | Object-Detection 仓库 | `MODEL_PATH=./yolov8m-obb.onnx`，`USE_CPU=true`            |
| E   | NFS 上传模型 + 创建 `object_detection_output`   | NFS 服务器             | `models/yolov8m-obb.onnx` 约 100MB+                        |
| F   | GitLab CI 变量 + Job Token 跨仓读权限            | GitLab UI           | `build-backend` 能 clone 两个子仓                              |
| G   | 触发 pipeline，部署新 backend/frontend          | GitLab CI           | rollout 成功                                                |
| H   | Pod 内验收 yolov8s / 模型 / 日志                 | kubectl             | 见 §6                                                      |
| I   | 提交一条含检测的 RS 任务，全链路验收                      | 前端                  | stage 10 成功、预览/zip/统计                                     |
| J   | 记录 baseline 耗时（Phase 0）                   | 文档/表格               | 见 **§11 Phase 0 收口 Checklist**                            |


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


| bare 仓                         | GitHub remote                                           | 推 GitLab remote                                                        |
| ------------------------------ | ------------------------------------------------------- | ---------------------------------------------------------------------- |
| `satellite-cloud.git`          | `github` → `PCL-Satellite-Cloud-Native/satellite-cloud` | `satellite-cloud` → `gitlab-internal:root/satellite-cloud.git`         |
| `Satellite-Remote-Sensing.git` | `origin` → `.../Satellite-Remote-Sensing`               | `remote-sensing` → `gitlab-internal:root/satellite-remote-sensing.git` |
| `Object-Detection.git`         | `origin` → `.../Object-Detection`                       | `object-detection` → `gitlab-internal:root/object-detection.git`       |


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

- 从 GitHub 拉用 `**fetch github` / `fetch origin**`，不要用会 `Permission denied` 的旧 SSH `origin`（2224 端口）。
- 推 GitLab 用 `**gitlab-internal:**`，不要用 HTTPS（自签证书会失败）。
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
- `k8s/backend/deployment.yaml` — `SATELLITE_OBJECT_DETECTION_`* 与 NFS 挂载
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

**配置位置**：内网 GitLab → 项目 `**root/satellite-cloud`** → Settings → CI/CD → Variables（不是 Object-Detection / RS 子仓）。


| 变量                                | 必填        | 说明                                                              |
| --------------------------------- | --------- | --------------------------------------------------------------- |
| `HARBOR_USER` / `HARBOR_PASSWORD` | 是         | Harbor 推送                                                       |
| `REMOTE_SENSING_REPO_URL`         | 是         | `https://192.168.10.238:8444/root/satellite-remote-sensing.git` |
| `OBJECT_DETECTION_REPO_URL`       | 是         | `https://192.168.10.238:8444/root/object-detection.git`         |
| `OBJECT_DETECTION_REPO_REF`       | 否         | 默认 `main`                                                       |
| `REMOTE_SENSING_REPO_REF`         | 否         | 默认 `main`                                                       |
| `ORT_DOWNLOAD_URL`                | **是（内网）** | 见 §5.2                                                          |
| `FONT_DOWNLOAD_URL`               | **是（内网）** | 见 §5.2                                                          |


> `OBJECT_DETECTION_REPO_URL` 未配置时 `build-backend` 直接失败。  
> 子仓 **Job Token**：在 `object-detection`、`satellite-remote-sensing` 项目允许 **satellite-cloud** inbound `read_repository`。

### 5.1 构建阶段网络（内网无法稳定访问 GitHub 时）

`detection-builder` 默认会从 GitHub 下载 ORT 与字体；内网 CI 常出现 `curl: (18)` 或 `ORT 包过小 (785 bytes)`（实际下到 HTML 跳转页）。**必须**配置 §5.2 内网镜像 URL，并推送含 `backend/scripts/download_ort.sh` 的 `satellite-cloud` 代码。

### 5.2 构建依赖内网镜像（ORT + 字体）— 本集群方案


| 用途                 | 放哪                                | CI 变量                                  | 运行时 Pod 是否用 |
| ------------------ | --------------------------------- | -------------------------------------- | ----------- |
| ORT `.tgz`、Noto 字体 | **238 静态 HTTP**                   | `ORT_DOWNLOAD_URL`、`FONT_DOWNLOAD_URL` | 否（已打进镜像）    |
| 检测模型 `.onnx`       | **NFS** `models/yolov8m-obb.onnx` | 无                                      | 是（PVC 挂载）   |


**本集群已验证（方案 A — 独立端口）**：

1. 文件放在 238：`/usr/share/nginx/html/static/`（ORT ~7.8MB，字体 ~16MB）
2. 因 443 被 GitLab/Harbor 占用，`https://192.168.10.238/static/...` 会返回 **785B HTML**，不可用
3. 用临时 HTTP 服务（重启 238 需重新拉起，或后续改 nginx `location /static`）：

```bash
cd /usr/share/nginx/html/static
nohup python3 -m http.server 18080 --bind 0.0.0.0 > /tmp/static-http.log 2>&1 &
```

1. CI 变量（**satellite-cloud** 项目）：


| 变量                  | 值                                                              |
| ------------------- | -------------------------------------------------------------- |
| `ORT_DOWNLOAD_URL`  | `http://192.168.10.238:18080/onnxruntime-linux-x64-1.24.4.tgz` |
| `FONT_DOWNLOAD_URL` | `http://192.168.10.238:18080/NotoSansCJKsc-Regular.otf`        |


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


| 阶段     | 名称                 | 验收                                     |
| ------ | ------------------ | -------------------------------------- |
| 1～9    | RS 预处理～融合预览        | 与现网一致，`fusion_stack_envi`、`imgshow` 成功 |
| **10** | `object_detection` | status=success，日志无 ONNX/模型路径错误         |


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


| 指标          | 记录方式                            |
| ----------- | ------------------------------- |
| RS 1～9 总耗时  | 任务详情各 stage `duration_ms` 之和    |
| Stage 10 耗时 | `object_detection` 阶段           |
| 端到端         | 创建 → completed                  |
| 瓦片数 / 目标数   | detection-stats API             |
| CPU / 内存峰值  | Grafana 或 `kubectl top pod`（可选） |


**2026-06 本集群首次全链路验收**（GF2 示例、`device=cpu`、单 Pod）：见 **附录 A**。

### 7.6 阶段 10「看起来卡住」是否正常

- 默认超时 **14400s（4h）**；CPU 全图检测 **30～90 分钟** 都可能。
- 后端约 **60s** 一条「心跳: yolov8s 仍在运行」；yolov8s 进度日志多在进程结束前才写入 DB。
- 判断是否真卡死：`ps` 有 `yolov8s`、`output_detection/rs_task_<id>/` 文件数持续增加 → **继续等**。
- 合理端到端：**40～90 分钟**（本集群 **46m36s** 属正常偏快）。

---

## 8. 常见失败与处理


| 现象                                              | 原因                                                   | 处理                                                   |
| ----------------------------------------------- | ---------------------------------------------------- | ---------------------------------------------------- |
| `build-backend`: `COPY object-detection-src` 失败 | 未 clone OD 仓                                         | 配置 `OBJECT_DETECTION_REPO_URL` + Job Token           |
| `git ls-remote` 401/403                         | Job Token 无跨仓读权限                                     | OD/RS 仓 Allowlist satellite-cloud                    |
| `curl: (18)` 从 GitHub 下 ORT                     | Runner 外网不稳定                                         | §5.2 配 `ORT_DOWNLOAD_URL`                            |
| `ORT 包过小 (785 bytes)`                           | URL 下到 HTML（308/404），非 tgz                           | 用 `:18080` 或 nginx `/static`；`curl -f` 验收 **~7.8MB** |
| `http://192.168.10.238/static` 308 → 785B       | 443 非静态站点                                            | 勿用该 URL；见 §5.2                                       |
| HTTPS push GitLab `certificate verify failed`   | 自签证书                                                 | 仓库机用 `gitlab-internal:` 推送                           |
| `fetch_font.sh` 失败                              | 同上                                                   | `FONT_DOWNLOAD_URL` 指向内网                             |
| 日志无 `Object detection runtime configured`       | 旧镜像（Pod 运行数月）                                        | 新 pipeline deploy 后 **rollout**；启动日志只在 Pod 创建时打一次    |
| stage 10: 找不到模型                                 | NFS 无 `models/yolov8m-obb.onnx` 或 `config.env` 路径不一致 | §2.1 + §4                                            |
| `libonnxruntime.so` 找不到                         | 镜像未含 detection-builder 产物                            | 重建 backend 镜像                                        |
| 检测图右侧白条                                         | 字体未嵌入                                                | 重建镜像 + `fetch_font.sh` / 内网字体 URL                    |
| 阶段 10 很久不动                                      | CPU 推理正常慢                                            | §7.6；查 `yolov8s` 进程与输出目录增长                           |
| stage 10 OOM                                    | 内存 limit 4Gi                                         | 临时提到 8Gi；后续 od-worker                                |
| 只有 RS 无 stage 10                                | `enable_detection=false` 或未迁移                        | migrate `000007`                                     |


---

## 9. 完成 baseline 后再做什么（明确不做）

**本手册完成后你应达到**：单 Pod backend 跑通 **10 阶段**，产物在 NFS，前端可预览/下载/统计。

**Phase 0 正式闭合**（3 次可复现、报告归档、运维可持续）：按 **§11 Checklist** 逐项勾选。

**Phase 2 已闭合**（2026-06-18）：od-worker 独立检测；运维 [PHASE2_RUNBOOK.md](./PHASE2_RUNBOOK.md)，历史 [archives/2026-06-18_phase2-closure.md](./archives/2026-06-18_phase2-closure.md)。

**本手册仍适用**：Phase 0 单 Pod 部署、CI/NFS/238 前置、故障排查。当前生产路径：**backend → rs.jobs → rs-worker（1～9）→ od.jobs → od-worker（10）**。

**尚未做**（见 [PHASE3_RUNBOOK.md](./PHASE3_RUNBOOK.md)）：

- Argo Workflow DAG（阶段 4 PAN RPC 并行 Pilot）
- GPU 池 / 120 节点扩缩
- MinIO、多星协同压测

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

## 11. Phase 0 收口 Checklist

> **用途**：首次全链路跑通（附录 A）之后，用本清单把 baseline **可复现、可对照** 地「封口」。  
> **状态（2026-06-17）**：**已闭合** — 完整数据见 [archives/2026-06-17_phase0-closure.md](./archives/2026-06-17_phase0-closure.md)。  
> **后继**：Phase 1 已闭合 — 运维 [PHASE1_RUNBOOK.md](./PHASE1_RUNBOOK.md)；归档 [archives/2026-06-18_phase1-closure.md](./archives/2026-06-18_phase1-closure.md)。

### 11.1 总览进度


| 块   | 主题              | 项数  | 全部完成 |
| --- | --------------- | --- | ---- |
| A   | 部署与基础设施（一次性复核）  | 8   | ☑    |
| B   | 三次全链路 benchmark | 6   | ☑    |
| C   | 前端与 API 验收      | 6   | ☑    |
| D   | 产物与 NFS         | 5   | ☑    |
| E   | CI / 仓库机可持续     | 5   | ☑    |
| F   | 文档与代码同步         | 4   | ☑    |
| G   | 签字与 Phase 1 评审  | 3   | ☑    |


**Phase 0 闭合条件**：A～F **全部勾选**；G 完成评审记录；B.5 三次端到端波动 **≤15%** — **已满足（2.8%）**，见 §11.9。

---

### 11.2 A — 部署与基础设施（一次性复核）

> 首次部署已在附录 A 完成；此处确认 **当前生产状态** 仍满足，避免「能跑一次、不能复现」。


| ☑   | 检查项            | 命令 / 位置                                                              | 通过标准                                                     |
| --- | -------------- | -------------------------------------------------------------------- | -------------------------------------------------------- |
| A1  | backend Pod 健康 | `kubectl -n gitlab-runner get deploy satellite-backend`              | `READY 1/1`                                              |
| A2  | PVC 绑定         | `kubectl -n gitlab-runner get pvc remote-sensing-data`               | `Bound`                                                  |
| A3  | 检测二进制在镜像内      | `kubectl -n $NS exec "$POD" -- ls -l /opt/object-detection/yolov8s` | 可执行文件存在                                                  |
| A4  | NFS 模型         | `kubectl -n $NS exec "$POD" -- ls -lh /opt/object-detection/yolov8m-obb.onnx` | **约 40～50MB**，非 0                                        |
| A5  | `config.env`   | `kubectl -n $NS exec "$POD" -- grep MODEL_PATH /opt/object-detection/config.env` | `yolov8m-obb.onnx`                                       |
| A6  | DEM            | `kubectl -n $NS exec "$POD" -- ls /opt/remote-sensing-data/dem/GMTED2010.jp2`    | 存在                                                       |
| A7  | GitLab CI 子仓变量 | satellite-cloud → CI/CD → Variables                                  | `REMOTE_SENSING_REPO_URL`、`OBJECT_DETECTION_REPO_URL` 已配 |
| A8  | Job Token      | RS、OD 两仓 inbound 允许 satellite-cloud                                  | CI `build-backend` 能 clone 两子仓                           |


---

### 11.3 B — 三次全链路 benchmark

> 记录表见 **§11.9**。每次任务前确认无其他 RS 任务在跑（`worker_concurrency=1`）。


| ☑   | 步骤              | 说明                                                                                                        |
| --- | --------------- | --------------------------------------------------------------------------------------------------------- |
| B1  | **Run #1** 提交任务 | task_id=137；2026-06-16 18:08 起；附录 A 首次                                                                 |
| B2  | **Run #2** 提交任务 | task_id=138；2026-06-16 19:16 起                                                                             |
| B3  | **Run #3** 提交任务 | task_id=139；2026-06-17 08:59 起；报告 `artifacts/benchmarks/Object-Detection-test3/report.txt`              |
| B4  | 各 stage 耗时      | Run #3 见 §11.9 阶段明细表                                                                                      |
| B5  | 端到端波动           | **2.8%**（median 45.68 min；max−min=1.26 min）≤ 15% ✓                                                      |
| B6  | 归档报告            | Run #3 已归档；建议将三次 report 汇总至 `artifacts/benchmarks/phase0-20260617/`                                      |


**可选（阶段 1 专项）**：某次 Run 前后执行：

```bash
./scripts/remote_sensing_stage1_benchmark.sh pre  --run-id phase0-run-002 --clean-scratch
# …提交任务，完成后…
./scripts/remote_sensing_stage1_benchmark.sh post --run-id phase0-run-002 --task-id <TASK_ID>
```

---

### 11.4 C — 前端与 API 验收

> 至少对 **Run #3**（或任意一次成功任务）完整勾选。


| ☑   | 检查项      | 验证方式                                                | 通过标准                                |
| --- | -------- | --------------------------------------------------- | ----------------------------------- |
| C1  | 10 阶段全绿  | 任务详情 stages                                         | 含 `object_detection` 且 success      |
| C2  | 融合预览     | 前端融合 Tab                                            | PNG 正常                              |
| C3  | 检测 Tab   | 按类别切换                                               | 每类有预览；Tab 显示瓦片总数                    |
| C4  | 瓦片 vs 目标 | `GET /api/remote-sensing/tasks/:id/detection-stats` | 数字与目录大致一致                           |
| C5  | 批量下载     | 「下载全部检测瓦片」                                          | zip 可下、可解压、含 JPG + `detections.txt` |
| C6  | 检测图质量    | 随机打开 2～3 张 JPG                                      | 右侧信息栏 **有中文**，非空白条                  |


---

### 11.5 D — 产物与 NFS


| ☑   | 检查项                          | 命令                                                 | 通过标准                        |
| --- | ---------------------------- | -------------------------------------------------- | --------------------------- |
| D1  | 检测输出目录                       | `ls …/output_detection/rs_task_<TASK_ID>/`         | 含按类子目录、`detections.txt`     |
| D2  | RS 持久化融合                     | NFS `output_preprocessing/fusion_envi/`、`imgshow/` | 有对应 `-MSS1-fusion.dat/.png` |
| D3  | 产物可跨 Pod 读                   | 重启 backend 后历史任务仍可预览                               | 依赖 NFS，非 emptyDir           |
| D4  | NFS 模型未误删                    | NFS 112 `models/yolov8m-obb.onnx`                  | 大小正常                        |
| D5  | `object_detection_output` 权限 | 新任务能写入                                             | 无 Permission denied         |


---

### 11.6 E — CI / 仓库机可持续


| ☑   | 检查项          | 说明                                                                            | 通过标准                                                       |
| --- | ------------ | ----------------------------------------------------------------------------- | ---------------------------------------------------------- |
| E1  | ORT/字体 HTTP  | `curl -f -o /tmp/t.tgz "$ORT_DOWNLOAD_URL" && ls -lh /tmp/t.tgz`（在 Runner 节点） | **~7.8MB**                                                 |
| E2  | `:18080` 持久化 | 238 重启后仍可用                                                                    | systemd 自启 **或** nginx `/static`（§5.2 方案 B）                |
| E3  | 故意触发 rebuild | push 小改动 → pipeline `build-backend` 绿                                         | detection-builder 从内网 URL 下载成功                             |
| E4  | 三仓 mirror 流程 | 238 `fetch github` → `push gitlab-internal`                                   | 同事可按 [DOCUMENTATION_INDEX.md](./DOCUMENTATION_INDEX.md) 复现 |
| E5  | Harbor 镜像    | `satellite/backend:latest` 与 pipeline SHA 一致                                  | deploy 后 Pod 镜像 ID 更新                                      |


---

### 11.7 F — 文档与代码同步


| ☑   | 检查项                       | 说明                                                                     |
| --- | ------------------------- | ---------------------------------------------------------------------- |
| F1  | `satellite-cloud` `main`  | 含 `K8S_BASELINE_RUNBOOK`、`DOCUMENTATION_INDEX`、`download_ort.sh`       |
| F2  | `Object-Detection` `main` | 含 `config.env`（`yolov8m-obb.onnx`）、`fetch_font.sh` 内网 URL 支持           |
| F3  | GitLab 与 GitHub 一致        | 238 mirror 已 push；CI 构建与本地 commit 对齐                                   |
| F4  | 附录 A / §11.9 已填           | 三次 benchmark 数据写入 runbook 或 `artifacts/benchmarks/phase0-*/summary.md` |


---

### 11.8 G — 签字与 Phase 1 评审


| ☑   | 项          | 记录                                                      |
| --- | ---------- | ------------------------------------------------------- |
| G1  | Phase 0 结论 | ☑ **通过**，可进入 Phase 1 评审 ☐ 有条件通过 ☐ 不通过 |
| G2  | 遗留项        | **非阻塞**：238 `:18080` 建议改 systemd/nginx 方案 B（§5.2）；Run #1/#2 未跑 benchmark 脚本（有任务级耗时即可） |
| G3  | 下一步决议      | ☑ **Phase 1（rs-worker）** — 见 §11.12 评审结论 ☐ 保持单 Pod ☐ 分钟级优化优先 |


**评审参与建议**：负责人 + 运维 + 1 名算法/载荷同事。  
**收口日期**：2026-06-17。

---

### 11.9 三次 Benchmark 记录表（复制填写）

**环境快照**（填一次即可）：


| 项                          | 值                                                                                                                              |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| 集群                         | 15 Node；namespace `gitlab-runner`                                                                                              |
| backend 镜像                 | `192.168.10.238/satellite/backend:latest`（Pod `satellite-backend-6dbbd746cc-cnz5t`）                                           |
| RS GitLab ref              | `main` @ [satellite-remote-sensing](https://192.168.10.238:8444/root/satellite-remote-sensing.git) |
| OD GitLab ref              | `main` @ [object-detection](https://192.168.10.238:8444/root/object-detection.git)                 |
| satellite-cloud GitLab SHA | `9ed17927`                                                                                                                       |
| 检测 device                  | `cpu`                                                                                                                          |
| Pod limits                 | CPU `2000m` / Memory `4Gi`                                                                                                     |


**三次运行**（固定 GF2 输入 `GF2_PMS1_E118.6_N37.4_20160826_L1A0001792619`；`enable_detection=true`；全类）：


| Run | task_id | 开始时间                | 结束时间                | 端到端 (min) | RS 1～9 (min) | stage10 (min) | 瓦片数 | 目标数  | 备注      |
| --- | ------- | ------------------- | ------------------- | --------- | ------------ | ------------- | --- | ---- | ------- |
| #1  | 137     | 2026-06-16 18:08:13 | 2026-06-16 18:54:49 | 46.60     | 11.26        | 35.34         | 831 | 1719 | 附录 A 首次 |
| #2  | 138     | 2026-06-16 19:16:25 | 2026-06-16 20:01:45 | 45.34     | 10.09        | 35.25         | 905 | 1788 |         |
| #3  | 139     | 2026-06-17 08:59:56 | 2026-06-17 09:45:38 | 45.68     | 10.27        | 35.24         | 803 | 1695 | benchmark 脚本归档 |


**波动计算**：

```text
三次端到端 (min)：46.60, 45.34, 45.68（Run #3 以 task.elapsed_seconds=2741.09 为准）
median = 45.68 min
max − min = 46.60 − 45.34 = 1.26 min
波动率 = 1.26 / 45.68 × 100% = 2.8%   → 目标 ≤ 15%  ✓
```

> 若以 Run #2 的 45.34 为 median：波动率 = 1.26 / 45.34 × 100% = **2.8%**，同样通过。

**各阶段耗时（Run #3 明细，来源 `Object-Detection-test3/report.txt`）**：


| stage | name                      | duration_ms | elapsed (s) |
| ----- | ------------------------- | ----------- | ----------- |
| 1     | tiff_to_envi_mss          | 9416        | 9.42        |
| 2     | tiff_to_envi_pan          | 18799       | 18.80       |
| 3     | pan_rad_toa               | 10073       | 10.07       |
| 4     | pan_rpc_warp_quarters     | 273047      | 273.05      |
| 5     | pan_merge_warp_square     | 23004       | 23.00       |
| 6     | mss_rad_quac_rpc          | 105732      | 105.73      |
| 7     | mss_coregister_to_pan     | 43357       | 43.36       |
| 8     | pansharpen_fusion         | 62845       | 62.85       |
| 9     | fusion_stack_envi         | 52068       | 52.07       |
| 10    | object_detection          | 2114180     | 2114.18     |
| —     | **RS 1～9 合计**             | 598341      | 598.34 (~10.0 min) |
| —     | **端到端**                   | 2741090     | 2741.09 (~45.7 min) |

**Run #3 观测摘要**：stage 10 占端到端 **~77%**；PAN RPC（stage 4）占 RS 段 **~46%**；NFS 读写各约 **3.2GB / 3.4GB**（见 report `nfs_delta`）。


---

### 11.10 快速导出任务数据（API 示例）

将 `<TASK_ID>`、`<API_HOST>` 换成实际值（需已登录或带 token）：

```bash
# 阶段列表与耗时
curl -s "<API_HOST>/api/remote-sensing/tasks/<TASK_ID>/stages" | jq '.[] | {name, status, duration_ms}'

# 检测统计
curl -s "<API_HOST>/api/remote-sensing/tasks/<TASK_ID>/detection-stats"
```

---

### 11.11 常见收口遗漏


| 遗漏                       | 后果            | 对应项   |
| ------------------------ | ------------- | ----- |
| 只做 1 次全链路                | 无法证明稳定        | B1～B6 |
| 238 重启后 CI 挂             | 下次发版失败        | E2    |
| 文档只在本地                   | 同事无法复现        | F1～F3 |
| 未验 zip / detection-stats | 前端回归未发现       | C4～C5 |
| 跳过 NFS 模型复核              | stage 10 偶发失败 | A4、D4 |


---

### 11.12 Phase 1 准入评审（2026-06-17）

| 维度 | 结论 | 说明 |
|------|------|------|
| **功能** | ✅ 通过 | 三次 GF2 全链路 10 阶段 success；前端融合/检测/zip/stats 验收通过 |
| **稳定性** | ✅ 通过 | 端到端波动 **2.8%**（远低于 15% 门槛） |
| **可复现** | ✅ 通过 | CI 变量、NFS 模型、三仓 mirror、Job Token 已固化于本文 |
| **运维可持续** | ⚠️ 建议补强 | `:18080` 持久化（E2）建议在 Phase 1 并行完成，避免 238 重启阻断发版 |
| **性能** | 📊 基线已建立 | 端到端 **~46 min**；stage 10 **~35 min（77%）**；RS **~10 min** |

**是否进入 Phase 1（rs-worker）**：**是，建议启动。**

理由：

1. Phase 0 验收项（3× benchmark、波动率、产物、前端）均已满足。
2. 当前瓶颈在 **单 Pod 串行 + CPU 检测**；Phase 1 解决 **API 与 RS 计算分离、多 task 并行**，不依赖 GPU。
3. 检测耗时优化留 **Phase 2（od-worker + GPU）**，不必阻塞 Phase 1。

**Phase 1 启动前建议（1～2 天，可与开发并行）** — **均已完成（2026-06-18）**：

- [x] 238 上 `:18080` 改 systemd（`scripts/ops/install-static-http-18080.sh`）
- [x] 部署 Redis + rs-worker Pilot（[PHASE1_RUNBOOK.md](./PHASE1_RUNBOOK.md) §3）
- [x] 实现 API 入队 + rs-worker RunPipeline；env 固化于 `k8s/backend/deployment.yaml`
- [x] P1-03 全链路验收（task 140）；P1-04/P1-05 并行压测留 Phase 1+

**Phase 1 收口**：见 [archives/2026-06-18_phase1-closure.md](./archives/2026-06-18_phase1-closure.md)。

**不建议现在做**：Argo DAG（Phase 3）、120 节点扩缩、MinIO 替换 NFS（除非 NFS 已成为明确瓶颈）。

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


| 步骤  | 动作                                                                                 | 结果                |
| --- | ---------------------------------------------------------------------------------- | ----------------- |
| 1   | 集群 RS 1～9 已运行；PVC `Bound`                                                          | 通过                |
| 2   | GitHub 三仓 push；238 上建 `Object-Detection.git` mirror                                | 通过                |
| 3   | `gitlab-internal` push → GitLab `root/object-detection`、`satellite-remote-sensing` | 通过                |
| 4   | GitLab Job Token + CI 变量 `REMOTE/OBJECT_DETECTION_REPO_URL`                        | 通过                |
| 5   | NFS 上传 `yolov8m-obb.onnx`；`object_detection_output` 目录                             | 通过                |
| 6   | CI 构建 ORT 失败（GitHub `curl 18`）→ 238 `:18080` 静态 + `ORT/FONT_DOWNLOAD_URL`          | 通过                |
| 7   | push `satellite-cloud`（含 `download_ort.sh`）→ pipeline deploy                       | 通过                |
| 8   | 前端提交 RS 任务，`enable_detection=true`                                                 | **10 阶段 success** |


### A.3 已验证 CI 变量（satellite-cloud 项目）

```
REMOTE_SENSING_REPO_URL=https://192.168.10.238:8444/root/satellite-remote-sensing.git
OBJECT_DETECTION_REPO_URL=https://192.168.10.238:8444/root/object-detection.git
ORT_DOWNLOAD_URL=http://192.168.10.238:18080/onnxruntime-linux-x64-1.24.4.tgz
FONT_DOWNLOAD_URL=http://192.168.10.238:18080/NotoSansCJKsc-Regular.otf
HARBOR_USER / HARBOR_PASSWORD=（已有）
```

### A.4 Phase 0 性能基线（首次全链路 + 三次收口）

**首次（Run #1，附录 A 归档）**

| 指标       | 值                                                                 | 备注                |
| -------- | ----------------------------------------------------------------- | ----------------- |
| 输入       | GF2 示例（`GF2_PMS1_E118.6_N37.4_20160826_L1A0001792619`）            | 与本地/WSL 同套        |
| task_id  | 137                                                               |                   |
| 端到端      | **46 分 36 秒**                                                     | RS + CPU 检测       |
| 阶段 10 观感 | 约 44 分钟时 UI 仍显示 running，随后完成                                      | 正常，见 §7.6         |
| 环境       | `SATELLITE_OBJECT_DETECTION_DEVICE=cpu`；Pod limit **2 CPU / 4Gi** | 未上 GPU            |

**三次收口（2026-06-16～17，详见 §11.9）**

| 指标 | 值 |
|------|-----|
| task_id | 137 / 138 / 139 |
| 端到端 | 46.60 / 45.34 / 45.68 min |
| 波动率 | **2.8%** ≤ 15% ✓ |
| stage 10 占比 | ~77%（Run #3：35.2 min / 45.7 min） |
| 结论 | **Phase 0 正式闭合**；可进入 Phase 1 评审（§11.12） |


### A.5 运维备忘

- **238 重启后**：检查 `python3 -m http.server 18080` 是否需重新拉起（或改 nginx 方案 B）。
- **代码更新流程**：开发机 → GitHub → 238 `fetch` → `push gitlab-internal` → satellite-cloud pipeline。
- **勿混淆**：CI 构建依赖（ORT tgz）走 HTTP；推理模型走 NFS；二者路径不同。

---

**文档维护**：部署流程、CI 变量或仓库机方式变更时，优先更新本文附录 A 与 §5.2；细节同步 [REMOTE_SENSING_K8S_DEPLOYMENT.md](./REMOTE_SENSING_K8S_DEPLOYMENT.md) §2.5、§3.2。