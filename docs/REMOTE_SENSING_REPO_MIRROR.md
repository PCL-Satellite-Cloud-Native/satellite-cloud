# 遥感仓库镜像与 CI 拉取配置（内网 GitLab）

本文档解决以下场景：

- GitHub 仓库为私有且 Deploy Key 被组织策略禁用
- K8s 在内网，CI 不能直接稳定访问外网 GitHub
- 需要由中转机先同步代码到内网 GitLab，再由 `satellite-cloud` CI 拉取

## 1. 一次性准备：在内网 GitLab 新建仓库

在内网 GitLab 创建私有仓库（示例名）：`Satellite-Remote-Sensing`

建议：

1. 与 `satellite-cloud` 放在同一个 Group/命名空间
2. 默认分支保持 `main`
3. 开启保护分支（至少保护 `main`）

## 2. 中转机同步 GitHub -> 内网 GitLab

仓库已提供脚本：

- `scripts/sync_remote_sensing_repo.sh`

在中转机执行示例：

```bash
cd /path/to/satellite-cloud
export GITHUB_REPO_SSH='git@github.com:PCL-Satellite-Cloud-Native/Satellite-Remote-Sensing.git'
export GITLAB_REPO_HTTPS='https://<gitlab-host>/<group>/Satellite-Remote-Sensing.git'
export GITLAB_USERNAME='<gitlab-username>'
export GITLAB_TOKEN='<gitlab-token>'
./scripts/sync_remote_sensing_repo.sh
```

验收：

1. 内网 GitLab 仓库可看到分支与标签
2. `main` 分支包含最新 `imgshow.py` 与 `requirements.txt`

## 3. 给 satellite-cloud CI 配置拉取地址

在 `satellite-cloud` 项目 CI 变量中新增：

- `REMOTE_SENSING_REPO_URL`
  - 当前集群示例：`https://192.168.10.238:8444/root/satellite-remote-sensing.git`
- 可选：`REMOTE_SENSING_REPO_REF`
  - 默认 `main`

说明：

- `.gitlab-ci.yml` 已改为使用 `CI_JOB_TOKEN` + `REMOTE_SENSING_REPO_URL` 拉取遥感仓库
- 不再依赖 `GITHUB_DEPLOY_KEY`

## 4. Job Token 权限（关键）

若出现 401/403，通常是 Job Token 没有跨仓库读取权限。

请在 **遥感仓库（被拉取方）** 中配置：

1. 允许来自 `satellite-cloud` 的 Job Token 访问（Allowlist/Inbound Job Token）
2. 至少开放 `read_repository`

> 不同 GitLab 版本界面名称略有差异，核心是：
> 让 `satellite-cloud` 项目的 CI_JOB_TOKEN 可以读取 `Satellite-Remote-Sensing` 仓库。

## 5. 流水线验收

触发 `satellite-cloud` 的 `main` pipeline 后，检查 `build-backend`：

```bash
# 关键日志应包含：
# 1) git ls-remote 成功
# 2) git clone --branch <ref> ... backend/remote-sensing-src 成功
```

## 6. 常见失败与处理

### 6.1 `REMOTE_SENSING_REPO_URL 未配置`

处理：在 `satellite-cloud` CI/CD Variables 添加该变量。

### 6.2 `HTTP Basic: Access denied` / `401`

处理：检查被拉取仓库是否允许来自 `satellite-cloud` 的 CI_JOB_TOKEN 读仓库。

### 6.3 `not found` / `repository does not exist`

处理：检查 URL 是否完整且仓库名大小写一致。

当前已验证的地址格式示例：

`https://192.168.10.238:8444/root/satellite-remote-sensing.git`

### 6.4 同步后分支不对

处理：设置 `REMOTE_SENSING_REPO_REF=main`（或你的目标分支/tag）。

## 7. 安全建议

1. 中转机同步使用最小权限 token
2. CI 变量设为 `Masked` + `Protected`
3. 不在日志中打印 token/url 明文
