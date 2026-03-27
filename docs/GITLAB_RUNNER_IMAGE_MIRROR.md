# GitLab Runner 镜像源内网化配置（解决 helper 拉取失败）

适用症状：

- `pulling image registry.gitlab.com/gitlab-org/gitlab-runner/gitlab-runner-helper ... EOF`
- CI Pod 在 `prepare environment` 阶段失败

## 1. 必须先镜像到 Harbor 的镜像

至少包含：

- `gitlab-runner-helper:x86_64-v16.8.0`
- `docker:25.0`
- `docker:25.0-dind`
- `bitnami-kubectl:latest`
- `alpine:3.19`
- `node:22-alpine`
- `nginx:alpine`
- `golang:1.25.7-bookworm`
- `python:3.11-slim-bookworm`

建议统一放在：`192.168.10.238/library/*`

## 2. Kubernetes Executor（config.toml）示例

若你的 Runner 使用原生 `config.toml`，关键是设置 `helper_image`：

```toml
[[runners]]
  name = "k8s-cluster-runner"
  url = "https://192.168.10.238:8444"
  token = "<runner-token>"
  executor = "kubernetes"

  [runners.kubernetes]
    namespace = "gitlab-runner"
    image = "192.168.10.238/library/alpine:3.19"
    helper_image = "192.168.10.238/library/gitlab-runner-helper:x86_64-v16.8.0"
    pull_policy = "if-not-present"
    privileged = true

  [runners.cache]
    Type = ""
```

修改后重启 runner：

```bash
kubectl -n gitlab-runner rollout restart deploy/gitlab-runner
kubectl -n gitlab-runner rollout status deploy/gitlab-runner
```

## 3. Helm 安装 Runner（values.yaml）示例

如果是 Helm 部署 GitLab Runner：

```yaml
gitlabUrl: https://192.168.10.238:8444
runnerToken: <runner-token>

runners:
  config: |
    [[runners]]
      [runners.kubernetes]
        namespace = "gitlab-runner"
        image = "192.168.10.238/library/alpine:3.19"
        helper_image = "192.168.10.238/library/gitlab-runner-helper:x86_64-v16.8.0"
        pull_policy = "if-not-present"
        privileged = true
```

应用：

```bash
helm upgrade --install gitlab-runner gitlab/gitlab-runner -n gitlab-runner -f values.yaml
```

## 4. imagePullSecret（私有 Harbor 必配）

```bash
kubectl -n gitlab-runner create secret docker-registry harbor-registry \
  --docker-server=192.168.10.238 \
  --docker-username=<harbor-user> \
  --docker-password=<harbor-password>
```

并确保 Runner ServiceAccount 使用该 secret。

## 5. 与本仓库 CI 的对应关系

本仓库 `.gitlab-ci.yml` 已改为使用 Harbor 镜像：

- `CI_DOCKER_IMAGE`
- `CI_DIND_IMAGE`
- `CI_KUBECTL_IMAGE`
- `CI_ALPINE_IMAGE`
- `BASE_IMAGE_REGISTRY`

Dockerfile 也已支持 `BASE_IMAGE_REGISTRY` 参数，避免构建时访问外网镜像源。

## 6. 验收命令

```bash
# Runner pod 正常
kubectl -n gitlab-runner get pods -l app=gitlab-runner

# 新跑一条 pipeline，确认不再卡在 prepare environment
# 并在 build-backend/build-frontend 里不再出现外网镜像拉取 EOF
```

