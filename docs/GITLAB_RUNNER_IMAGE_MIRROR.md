# GitLab Runner 镜像源内网化配置（解决 helper 拉取失败）

适用症状：

- `pulling image registry.gitlab.com/gitlab-org/gitlab-runner/gitlab-runner-helper ... EOF`
- CI Pod 在 `prepare environment` 阶段失败

## 1. 必须先镜像到 Harbor 的镜像

至少包含（建议全部使用 `-amd64-r1` 这类不可变标签）：

- `gitlab-runner:alpine-v17.10.1-amd64-r1`
- `gitlab-runner-helper:x86_64-v17.10.1-amd64-r1`
- `docker:25.0-amd64-r1`
- `bitnami-kubectl:latest-amd64-r1`
- `alpine:3.19-amd64-r1`
- `node:22-alpine-amd64-r1`
- `nginx:alpine-amd64-r1`
- `golang:1.25.7-bookworm-amd64-r1`
- `python:3.11-slim-bookworm-amd64-r1`
- `ci-build:docker25-git-amd64-r3`

建议统一放在：`192.168.10.238/library/*`

### 1.1 在外网机器按 amd64 拉取并推送 Harbor（示例）

```bash
docker pull --platform linux/amd64 gitlab/gitlab-runner:alpine-v17.10.1
docker pull --platform linux/amd64 registry.gitlab.com/gitlab-org/gitlab-runner/gitlab-runner-helper:x86_64-v17.10.1
docker pull --platform linux/amd64 node:22-alpine
docker pull --platform linux/amd64 nginx:alpine
docker pull --platform linux/amd64 golang:1.25.7-bookworm
docker pull --platform linux/amd64 python:3.11-slim-bookworm

docker tag gitlab/gitlab-runner:alpine-v17.10.1 192.168.10.238/library/gitlab-runner:alpine-v17.10.1-amd64-r1
docker tag registry.gitlab.com/gitlab-org/gitlab-runner/gitlab-runner-helper:x86_64-v17.10.1 192.168.10.238/library/gitlab-runner-helper:x86_64-v17.10.1-amd64-r1
docker tag node:22-alpine 192.168.10.238/library/node:22-alpine-amd64-r1
docker tag nginx:alpine 192.168.10.238/library/nginx:alpine-amd64-r1
docker tag golang:1.25.7-bookworm 192.168.10.238/library/golang:1.25.7-bookworm-amd64-r1
docker tag python:3.11-slim-bookworm 192.168.10.238/library/python:3.11-slim-bookworm-amd64-r1

docker push 192.168.10.238/library/gitlab-runner:alpine-v17.10.1-amd64-r1
docker push 192.168.10.238/library/gitlab-runner-helper:x86_64-v17.10.1-amd64-r1
docker push 192.168.10.238/library/node:22-alpine-amd64-r1
docker push 192.168.10.238/library/nginx:alpine-amd64-r1
docker push 192.168.10.238/library/golang:1.25.7-bookworm-amd64-r1
docker push 192.168.10.238/library/python:3.11-slim-bookworm-amd64-r1
```

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
    image = "192.168.10.238/library/alpine:3.19-amd64-r1"
    helper_image = "192.168.10.238/library/gitlab-runner-helper:x86_64-v17.10.1-amd64-r1"
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
        image = "192.168.10.238/library/alpine:3.19-amd64-r1"
        helper_image = "192.168.10.238/library/gitlab-runner-helper:x86_64-v17.10.1-amd64-r1"
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
- `CI_BUILD_IMAGE`
- `CI_KUBECTL_IMAGE`
- `CI_ALPINE_IMAGE`
- `BASE_IMAGE_REGISTRY`

Dockerfile 也已支持 `BASE_IMAGE_REGISTRY` 参数，避免构建时访问外网镜像源。

补充：

- `CI_BUILD_IMAGE` 推荐：`192.168.10.238/library/ci-build:docker25-git-amd64-r3`
- 该镜像需包含 `docker-cli + git + ca-certificates`，并内置内网 CA 证书
- 否则 `git ls-remote https://<gitlab>/...` 可能报 `self-signed certificate`
- `gitlab-runner` Deployment 本体镜像建议也固定到 Harbor：
  - `192.168.10.238/library/gitlab-runner:alpine-v17.10.1-amd64-r1`

后端若在构建阶段执行 `apt-get update` 访问 Debian 外网源，也可能失败。  
建议将 `python + gdal` 运行时依赖预构建为内网镜像（如 `python:3.11-slim-bookworm-gdal-amd64-r1`）。

后端构建若卡在 `go mod download`，建议在 `backend/Dockerfile` builder 阶段设置：

```dockerfile
ENV GOPROXY=https://goproxy.cn,direct \
    GOSUMDB=off
```

若节点通过跳板机做透明代理转发，且出现 `curl/docker EOF`，需检查跳板机 `nat PREROUTING` 是否将集群网段流量重定向到代理端口（如 CLASH 7892）。

## 6. 验收命令

```bash
# Runner pod 正常
kubectl -n gitlab-runner get pods -l app=gitlab-runner

# 版本确认
kubectl -n gitlab-runner logs deploy/gitlab-runner --tail=60 | rg "Running with gitlab-runner"

# 新跑一条 pipeline，确认不再卡在 prepare environment
# 并在 build-backend/build-frontend 里不再出现外网镜像拉取 EOF
```
