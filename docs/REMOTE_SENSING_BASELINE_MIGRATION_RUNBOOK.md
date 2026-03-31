# Satellite-Cloud 集成遥感应用实施手册（从“无遥感基线”迁移）

本文档用于在其他集群复现本次改造，起点是：**系统原本不包含遥感应用能力**。

适用对象：

- `satellite-cloud`（主业务仓库）
- `Satellite-Remote-Sensing`（遥感处理仓库）
- 内网 GitLab + Harbor + Kubernetes 集群

---

## 1. 目标与边界

本次改造目标：

1. `satellite-cloud` 后端可调用 `Satellite-Remote-Sensing` 脚本完成遥感处理
2. 前端可展示任务流程、阶段日志与产物预览图（含 `imgshow.py` 自动联动）
3. 整体可在内网 K8s 集群通过 GitLab CI 持续部署

非目标：

- 不在本文展开算法本身细节
- 不在本文展开业务页面交互细节（仅覆盖部署与运行链路）

---

## 2. 迁移总览（从基线到目标）

从“无遥感版本”迁移到“含遥感版本”，需要同时完成 5 条链路：

1. 代码链路：`Satellite-Remote-Sensing` 进入内网 GitLab，并允许 `satellite-cloud` CI 拉取
2. 存储链路：新增遥感输入/输出的 NFS + PV/PVC
3. 镜像链路：所有 CI/Runner/基础镜像完成 Harbor 内网化（且统一 amd64）
4. 运行链路：后端镜像内置 Python 虚拟环境与遥感脚本，任务阶段完成后自动触发 `imgshow.py`
5. 部署链路：GitLab Runner 与 `satellite-cloud` CI 配置调整，避免外网依赖与架构错配

---

## 3. 先决条件（新集群上线前）

必须满足：

1. K8s 节点架构统一为 `amd64`（至少 Runner 与 CI 构建节点需 amd64）
2. Harbor 可用，且 Runner/CI 所在命名空间有拉取凭据（`imagePullSecret`）
3. 内网 GitLab 可访问，已创建两个仓库：
   - `satellite-cloud`
   - `satellite-remote-sensing`
4. NFS 可用并可被集群节点挂载

建议先检查：

```bash
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{" => "}{.status.nodeInfo.architecture}{"\n"}{end}'
```

---

## 4. 代码与仓库链路

### 4.1 远程遥感仓库同步到内网 GitLab

参考文档：

- `docs/REMOTE_SENSING_REPO_MIRROR.md`

关键点：

1. 不依赖 GitHub Deploy Key（受组织策略时可用中转机镜像同步）
2. `satellite-cloud` CI 通过 `CI_JOB_TOKEN` 读取内网 `satellite-remote-sensing`
3. 被拉取方仓库必须配置 Job Token Allowlist（允许 `satellite-cloud` 读仓库）

### 4.2 `satellite-cloud` CI 变量

至少配置：

- `HARBOR_USER`
- `HARBOR_PASSWORD`
- `REMOTE_SENSING_REPO_URL`（内网 GitLab 遥感仓库 HTTPS 地址）
- 可选：`REMOTE_SENSING_REPO_REF`（默认 `main`）

---

## 5. 存储与 K8s 资源链路

### 5.1 NFS 目录（示例）

```bash
sudo mkdir -p /export/remote-sensing-data/input
sudo mkdir -p /export/remote-sensing-data/output_preprocessing
sudo chmod -R 0777 /export/remote-sensing-data

#在 `/etc/exports` 中增加一行（根据你集群网段调整）：

/export/remote-sensing-data 192.168.0.0/16(rw,sync,no_subtree_check,no_root_squash)

# 使配置生效并验证：

sudo exportfs -rav
sudo exportfs -v
```

### 5.2 PV/PVC

应用：

```bash
kubectl apply -f k8s/backend/remote-sensing-pv-pvc.yaml
kubectl -n gitlab-runner get pvc remote-sensing-data
```

验收：`PVC=Bound`。

---

## 6. 镜像链路（最容易踩坑）

## 6.1 必须内网化的镜像类别

1. Runner 镜像：`gitlab-runner`
2. Runner helper 镜像：`gitlab-runner-helper`
3. CI 基础镜像：`alpine`、`docker`、`bitnami-kubectl`
4. 构建阶段自定义镜像：`ci-build`（内置 docker-cli + git）
5. 业务构建依赖镜像：`node`、`nginx`、`golang`、`python` 等

参考文档：

- `docs/GITLAB_RUNNER_IMAGE_MIRROR.md`

## 6.2 强约束：统一 amd64 + 不复用模糊 tag

强烈建议使用带后缀 tag，例如：

- `alpine:3.19-amd64-r1`
- `docker:25.0-amd64-r1`
- `gitlab-runner:alpine-v17.10.1-amd64`
- `ci-build:docker25-git-amd64-r1`

禁止继续覆盖单一通用 tag（如 `:latest` 或 `:3.19`）用于跨架构复用。

---

## 7. GitLab Runner 改造（关键）

建议版本：`17.10.1`（Runner 与 helper 版本严格一致）。

核心配置原则：

1. `FF_USE_LEGACY_KUBERNETES_EXECUTION_STRATEGY=false`
2. `helper_image` 指向 Harbor 内网地址
3. Runner Deployment 镜像与 helper 镜像都使用 amd64 标签

典型验收：

```bash
kubectl -n gitlab-runner logs deploy/gitlab-runner --tail=120
```

应看到：

- `Running with gitlab-runner 17.10.1`
- 不再出现 `container not found ("build")`

---

## 8. satellite-cloud CI 改造（本次最终形态）

关键点：

1. `build-backend`/`build-frontend` 使用内网 `CI_BUILD_IMAGE`
2. 构建阶段不再 `apk add` 外网安装依赖
3. 通过 `DOCKER_HOST=unix:///var/run/docker.sock` 使用宿主机 Docker
4. `build-backend` 通过 `CI_JOB_TOKEN` 克隆遥感仓库到 `backend/remote-sensing-src`

当前关键变量建议：

- `CI_BUILD_IMAGE=192.168.10.238/library/ci-build:docker25-git-amd64-r3`
- `CI_KUBECTL_IMAGE=192.168.10.238/library/bitnami-kubectl:latest-amd64-r1`
- `CI_ALPINE_IMAGE=192.168.10.238/library/alpine:3.19-amd64-r1`

后端运行时建议使用预构建基础镜像（避免 CI 内执行 `apt-get`）：

- `python:3.11-slim-bookworm-gdal-amd64-r1`

后端构建阶段建议固定：

- `GOPROXY=https://goproxy.cn,direct`
- `GOSUMDB=off`

---

## 9. 后端运行链路改造（遥感联动）

已完成的关键行为：

1. 后端在遥感流程 `fusion_stack_envi` 成功后自动触发 `imgshow.py`
2. `imgshow.py` 输入来自融合输出目录，自动生成预览图
3. 阶段日志写入任务日志表，前端可按流程显示阶段状态

部署后最小验收：

1. 提交一条遥感任务
2. 阶段显示按顺序推进至融合完成
3. 自动出现 `imgshow.py` 执行日志
4. 产物目录出现预览图（如 `*-fusion.png`）

---

## 10. 新集群复现的推荐执行顺序

1. 创建内网 GitLab 仓库并完成遥感仓库同步
2. 准备 Harbor 仓库与 imagePullSecret
3. 一次性导入 amd64 镜像（Runner/helper/CI/业务基镜像）
4. 安装或升级 Runner 到 17.10.1，并绑定 Harbor 镜像
5. 创建 NFS 目录与 PV/PVC
6. 配置 `satellite-cloud` CI 变量
7. 推送 `main` 并触发 pipeline
8. 按“构建成功 -> 部署成功 -> 遥感任务端到端成功”三层验收

---

## 10.1 网络前置验收（跳板机转发场景）

在任一 worker 节点执行：

```bash
curl -I --max-time 10 http://deb.debian.org/debian/dists/bookworm/InRelease
curl -I --max-time 10 https://deb.debian.org/debian/dists/bookworm/InRelease
curl -I --max-time 10 https://proxy.golang.org
```

若出现 `Empty reply` / `TLS EOF`，优先排查跳板机 iptables/CLASH 透明代理规则。

---

## 11. 常见故障速查（本次实战结论）

1. `container not found ("build")`：
   - 优先检查 Runner 版本与执行策略，升级 Runner 并关闭 legacy
2. `exec format error`：
   - 100% 优先排查镜像架构错配（arm/amd）
3. `apk add` 失败（EOF/Permission denied）：
   - 说明仍依赖外网源，改为内网预装工具镜像
4. Runner rollout 卡在 `2 out of 3`：
   - 检查新 Pod 是否 CrashLoop / 镜像拉取失败 / 旧 RS 未切完
5. `x509: certificate signed by unknown authority`：
   - 先区分是 Docker daemon 拉 Harbor 失败，还是 CI 容器内 git 访问 GitLab 失败
   - 若是后者，需在 `CI_BUILD_IMAGE` 中内置 CA 证书
6. 后端构建 `apt-get update` 失败：
   - `ping` 可达不代表 `apt` 可达（协议/端口/出口策略不同）
   - 推荐改为预构建 `python+gdal` 运行时镜像
7. 后端构建 `go mod download` 卡住：
   - 配置 `GOPROXY=https://goproxy.cn,direct` 与 `GOSUMDB=off`
8. `curl/docker pull` 出现 EOF 但跳板机本机可用：
   - 排查跳板机 `nat PREROUTING` 是否把集群网段重定向到 CLASH 端口
   - 可临时加白名单：`iptables -t nat -I CLASH 1 -s <集群网段> -j RETURN`

---

## 12. 变更文件索引（相对无遥感基线）

`satellite-cloud` 侧核心文件：

- `.gitlab-ci.yml`
- `backend/Dockerfile`
- `backend/internal/remotesensing/*`
- `k8s/backend/deployment.yaml`
- `k8s/backend/remote-sensing-pv-pvc.yaml`
- `docs/REMOTE_SENSING_K8S_DEPLOYMENT.md`
- `docs/REMOTE_SENSING_REPO_MIRROR.md`
- `docs/GITLAB_RUNNER_IMAGE_MIRROR.md`

> 建议：在新集群落地时，始终通过分支发布并保留“镜像 tag + 配置版本 + 验收记录”三元组，便于快速回滚与追溯。
