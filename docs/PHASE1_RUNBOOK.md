# Phase 1 实施手册（API 与 RS 计算分离）

> **文档定位**：Phase 1 **活跃 SSOT** — Redis + rs-worker Pilot 部署、验收与回滚。  
> **前置**：Phase 0 已闭合 — 历史见 [archives/2026-06-17_phase0-closure.md](./archives/2026-06-17_phase0-closure.md)。  
> **架构总览**：[MICROSERVICES_IMPLEMENTATION_PLAN.md](./MICROSERVICES_IMPLEMENTATION_PLAN.md) §5 阶段 1、§6 Redis 约定。  
> **归档规则**：Phase 1 验收通过后，执行 `bash scripts/archive_docs_snapshot.sh phase1-closure` 并更新 [ARCHIVE_INDEX.md](./archives/ARCHIVE_INDEX.md)。

---

## 0. 当前进度（2026-06-17）

| 项 | 状态 |
|----|------|
| Redis K8s 清单 | ✅ `k8s/phase1/redis/` |
| rs-worker Deployment | ✅ `k8s/phase1/rs-worker/`（含 stage 10 检测挂载） |
| `cmd/rs-worker` 消费 + RunPipeline | ✅ |
| API `CreateTask` → `XADD rs.jobs` | ✅ `SATELLITE_USE_INPROCESS_PIPELINE=false` 时生效 |
| `QueueConfig` + feature flag | ✅ 默认 `true`（现网不变） |
| Redis 镜像入 Harbor | ☐ 阶段 0 — `scripts/ops/mirror_redis_image.sh` |
| backend 切换 Redis 模式 | ☐ 阶段 3 — `switch-backend-to-redis-mode.sh` |
| Phase 1 验收（3 星并行） | ☐ 阶段 4 |

**Pilot 策略**：Redis + rs-worker 与 `satellite-backend` 同在 `gitlab-runner`，不影响现网单 Pod 流水线。

---

## A. 分阶段服务器部署（推荐顺序）

> **总原则**：分 **5 个阶段** 推进；**阶段 C 之前现网行为不变**（backend 仍 `SATELLITE_USE_INPROCESS_PIPELINE=true`）。  
> **Harbor 缺 Redis 镜像**：必须先完成 **阶段 0**，否则 Redis Pod 会 `ImagePullBackOff`。

### 阶段 0 — 前置：Redis 镜像入 Harbor ⚠️ 必做

Harbor 当前 **无** `redis` 镜像；清单引用：

```text
192.168.10.238/library/redis:7-alpine-amd64-r1
```

**在有 Docker Hub 访问的机器上**（或 238 若能拉外网）：

```bash
export HARBOR=192.168.10.238
export HARBOR_USER=admin          # 按实际
export HARBOR_PASSWORD='***'

bash scripts/ops/mirror_redis_image.sh
```

或手动：

```bash
docker pull --platform linux/amd64 redis:7-alpine
docker tag redis:7-alpine 192.168.10.238/library/redis:7-alpine-amd64-r1
docker login 192.168.10.238 -u admin -p '***'
docker push 192.168.10.238/library/redis:7-alpine-amd64-r1
```

**验收 0**

| ☐ | 检查 | 命令 | 通过标准 |
|---|------|------|----------|
| 0.1 | Harbor 可见 | UI → Projects → `library` → redis | 存在 tag `7-alpine-amd64-r1` |
| 0.2 | 节点可拉 | 在 **任意 Node** 或 Runner 宿主机 | `docker pull 192.168.10.238/library/redis:7-alpine-amd64-r1` 成功 |
| 0.3 | K8s 凭据 | `kubectl -n gitlab-runner get secret harbor-registry` | Secret 存在（与现网 backend 相同） |

> 若 tag 名不同，同步改 `k8s/phase1/redis/deployment.yaml` 第 19 行 `image:`。

**可选同期完成**（不阻塞 Phase 1，建议做）：

```bash
# 238 上 ORT/字体 HTTP 持久化
sudo bash scripts/ops/install-static-http-18080.sh
curl -f -o /tmp/t.tgz http://192.168.10.238:18080/onnxruntime-linux-x64-1.24.4.tgz && ls -lh /tmp/t.tgz
```

---

### 阶段 1 — 代码同步 + CI 构建新 backend 镜像

**现网仍跑旧逻辑**；本阶段只更新镜像，**不**切 Redis 模式。

1. 开发机 push `satellite-cloud` → GitHub  
2. 238 bare mirror → `gitlab-internal` push  
3. GitLab `satellite-cloud` pipeline：`build-backend` → `deploy`

**build-backend 日志应含**：

```text
go build ... -o bin/rs-worker ./cmd/rs-worker
```

**验收 1**

| ☐ | 检查 | 命令 | 通过标准 |
|---|------|------|----------|
| 1.1 | pipeline 绿 | GitLab UI | `build-backend`、`deploy` success |
| 1.2 | 新镜像含 rs-worker | k8s-master | 见下方命令块 |
| 1.3 | 现网仍 in-process | backend 日志 | `use_inprocess_pipeline=true` 或默认无 Redis 入队 |
| 1.4 | GF2 烟雾（可选） | 前端提交 1 任务 | 10 阶段 success（与 Phase 0 一致） |

```bash
POD=$(kubectl -n gitlab-runner get pod -l app=satellite-backend -o jsonpath='{.items[0].metadata.name}')
kubectl -n gitlab-runner exec "$POD" -- ls -l /app/rs-worker
kubectl -n gitlab-runner logs deploy/satellite-backend --tail=20 | grep -E 'in-process|Pipeline queue'
```

---

### 阶段 2 — 部署 Redis + rs-worker（Pilot，不切 backend）

**backend 仍为单 Pod 内进程流水线**；仅拉起 Redis 与 rs-worker，验证连通。

```bash
cd ~/code/satellite-cloud   # 或你 clone 的路径
kubectl apply -f k8s/phase1/namespaces.yaml    # 可选
kubectl apply -k k8s/phase1/
kubectl -n gitlab-runner rollout status deployment/redis
kubectl -n gitlab-runner rollout status deployment/rs-worker
```

**验收 2**

| ☐ | 检查 | 命令 | 通过标准 |
|---|------|------|----------|
| 2.1 | Redis Running | `kubectl -n gitlab-runner get pod -l app=redis` | `1/1 Running`，无 ImagePullBackOff |
| 2.2 | Redis PONG | 见下 | 返回 PONG |
| 2.3 | rs-worker Running | `kubectl -n gitlab-runner get pod -l app=rs-worker` | `1/1 Running` |
| 2.4 | consumer group | rs-worker 日志 | `Redis consumer group ready` |
| 2.5 | 现网不受影响 | 再跑 1 条 GF2（可选） | backend 内进程完成；rs-worker **不应**收到该 task |

```bash
# Redis
RPOD=$(kubectl -n gitlab-runner get pod -l app=redis -o jsonpath='{.items[0].metadata.name}')
kubectl -n gitlab-runner exec "$RPOD" -- redis-cli ping

# rs-worker 日志
kubectl -n gitlab-runner logs deploy/rs-worker --tail=30
```

**失败排查**

| 现象 | 处理 |
|------|------|
| Redis `ImagePullBackOff` | 回到 **阶段 0** 推 Harbor；检查 `harbor-registry` secret |
| rs-worker `CrashLoop` / 无 rs-worker 文件 | 回到 **阶段 1** 确认镜像含 `/app/rs-worker` |
| rs-worker DB 连接失败 | 检查 `satellite-db-secret` 与 backend 一致 |

---

### 阶段 3 — 切换 backend 为 Redis 入队模式

**前置**：阶段 2 全部 ☐；建议选 **无 RS 任务在跑** 的时段。

```bash
bash k8s/phase1/switch-backend-to-redis-mode.sh
```

等价于：

```bash
kubectl -n gitlab-runner set env deployment/satellite-backend \
  SATELLITE_USE_INPROCESS_PIPELINE=false \
  SATELLITE_REDIS_ADDR=redis:6379 \
  SATELLITE_REDIS_STREAM_RS=rs.jobs \
  SATELLITE_REDIS_CONSUMER_GROUP=rs-workers
kubectl -n gitlab-runner rollout status deployment/satellite-backend
```

**验收 3（单任务全链路 — Phase 1 核心）**

| ☐ | 检查 | 方法 | 通过标准 |
|---|------|------|----------|
| 3.1 | backend Redis 模式 | 日志 | `Remote sensing Redis queue mode enabled` |
| 3.2 | 入队 | 前端提交 GF2 + 检测 | backend 日志：`任务已入队 Redis` + `stream_id` |
| 3.3 | 消费 | rs-worker 日志 | `rs-worker 开始处理任务` + `task_id` |
| 3.4 | 10 阶段 | 前端 / API | 含 `object_detection` 且 success |
| 3.5 | 产物 | NFS / 前端 | 融合预览、检测 Tab、zip 可下 |
| 3.6 | API 响应 | RS 运行中 | `curl -s -o /dev/null -w '%{time_total}\n' http://<API>/health` 多次 < 0.2s |

```bash
# 提交任务后记 task_id，例如 140
kubectl -n gitlab-runner logs deploy/satellite-backend --tail=50 | grep -E '入队|Redis'
kubectl -n gitlab-runner logs deploy/rs-worker --tail=100 | grep -E '开始处理|task_id'

# Stream 中有消息被消费（可选）
kubectl -n gitlab-runner exec "$RPOD" -- redis-cli XINFO GROUPS rs.jobs
```

**回滚（阶段 3 出问题立即执行）**

```bash
kubectl -n gitlab-runner set env deployment/satellite-backend SATELLITE_USE_INPROCESS_PIPELINE=true
kubectl -n gitlab-runner rollout status deployment/satellite-backend
# rs-worker 可保留或 scale 0
kubectl -n gitlab-runner scale deployment/rs-worker --replicas=0
```

---

### 阶段 4 — Phase 1 正式验收（可选，答辩/第三方前）

| ☐ | 编号 | 项 | 通过标准 |
|---|------|-----|----------|
| ☐ | P1-04 | API 延迟 | RS 重任务运行时 `/health` 连续 20 次 P99 < 200ms |
| ☐ | P1-05 | 并行 | `rs-worker` replicas=2～3，同时 3 条 GF2 task 均 success |
| ☐ | P1-06 | 波动 | 3 次端到端与 Phase 0 比 ≤ +15%（可选） |

扩容 rs-worker（15 Node Pilot）：

```bash
kubectl -n gitlab-runner scale deployment/rs-worker --replicas=3
kubectl -n gitlab-runner set env deployment/rs-worker SATELLITE_RS_WORKER_CONCURRENCY=1
```

**阶段 4 完成后**：归档 `bash scripts/archive_docs_snapshot.sh phase1-closure`，更新 [ARCHIVE_INDEX.md](./archives/ARCHIVE_INDEX.md)。

---

### 部署阶段总览

```text
阶段 0  Redis → Harbor          ⚠️ 必做（无则 ImagePullBackOff）
阶段 1  CI 新 backend 镜像       现网不变
阶段 2  apply Redis + rs-worker  现网不变，只验连通
阶段 3  switch-backend Redis 模式  单任务全链路
阶段 4  并行 / 压测 / 归档       可选
```

---

## 1. 238 静态 HTTP 持久化（E2 补强）

在 **192.168.10.238** 上（替代 `nohup python3 -m http.server`）：

```bash
# 仓库机拉最新 satellite-cloud 后
sudo bash scripts/ops/install-static-http-18080.sh
```

验收（Runner 或 238 本机）：

```bash
curl -f -o /tmp/t.tgz "http://192.168.10.238:18080/onnxruntime-linux-x64-1.24.4.tgz"
ls -lh /tmp/t.tgz   # ~7.8M
```

长期方案 B：nginx `location /static/` — 见 [K8S_BASELINE_RUNBOOK.md](./K8S_BASELINE_RUNBOOK.md) §5.2。

---

## 2. 构建含 rs-worker 的 backend 镜像

推送含 `cmd/rs-worker` 的 `satellite-cloud` → GitLab pipeline → `build-backend`。

镜像内二进制：

- `/app/server` — API（现网）
- `/app/rs-worker` — RS Worker 入口

---

## 3. Pilot 部署 Redis + rs-worker

```bash
cd satellite-cloud/k8s/phase1

# 可选：预创建目标 namespace（不影响 Pilot）
kubectl apply -f namespaces.yaml

# Pilot（gitlab-runner）
kubectl apply -k .

kubectl -n gitlab-runner get deploy,pod | grep -E 'redis|rs-worker'
kubectl -n gitlab-runner logs deploy/rs-worker --tail=30
```

**期望日志**：

```text
rs-worker starting redis_addr=redis:6379 stream_rs=rs.jobs ...
Redis consumer group ready ...
```

Redis 冒烟：

```bash
POD=$(kubectl -n gitlab-runner get pod -l app=redis -o jsonpath='{.items[0].metadata.name}')
kubectl -n gitlab-runner exec "$POD" -- redis-cli ping
# PONG
```

---

## 4. 切换流水线（Redis 模式）

**前置**：Redis + rs-worker 已 Running；新 backend 镜像已含 `./rs-worker` 与入队逻辑。

```bash
bash k8s/phase1/switch-backend-to-redis-mode.sh
```

| 组件 | 行为 |
|------|------|
| `satellite-backend` | `CreateTask` → DB + `XADD rs.jobs`；**不**启动内进程 RS worker |
| `rs-worker` | 消费 `rs.jobs` → `RunPipeline`（含 stage 10 检测） |

提交任务后验收：

```bash
kubectl -n gitlab-runner logs deploy/rs-worker --tail=50 | grep -E '开始处理|入队'
```

**回滚**：见脚本末尾注释，或：

```bash
kubectl -n gitlab-runner set env deployment/satellite-backend SATELLITE_USE_INPROCESS_PIPELINE=true
kubectl -n gitlab-runner scale deployment/rs-worker --replicas=0
```

---

## 5. Phase 1 验收标准

| # | 项 | 方法 | 通过标准 |
|---|-----|------|----------|
| P1-01 | Redis 可用 | `redis-cli ping` | PONG |
| P1-02 | rs-worker 就绪 | logs | consumer group ready |
| P1-03 | 入队消费 | 提交 1 task | rs-worker 日志出现 task_id；DB stages 推进 |
| P1-04 | API 不被 RS 拖死 | RS 运行时 curl `/health` | P99 < 200ms（健康检查） |
| P1-05 | 3 星并行 | 3 task 不同 `satellite_id` | 全部 success |

---

## 6. 回滚

```bash
kubectl -n gitlab-runner delete deployment rs-worker redis --ignore-not-found
kubectl -n gitlab-runner delete svc redis --ignore-not-found
kubectl -n gitlab-runner set env deployment/satellite-backend SATELLITE_USE_INPROCESS_PIPELINE=true
```

---

## 7. 相关路径

| 路径 | 说明 |
|------|------|
| `k8s/phase1/` | Pilot Kustomize |
| `backend/cmd/rs-worker/` | Worker 入口 |
| `backend/internal/queue/` | Redis Stream 封装 |
| `docs/archives/` | 阶段收口归档 |

---

**文档维护**：Phase 1 验收通过后，将 §0 进度与 §5 结果写入 `docs/archives/YYYY-MM-DD_phase1-closure.md`，本手册 §0 改为「已闭合」并链接归档。
