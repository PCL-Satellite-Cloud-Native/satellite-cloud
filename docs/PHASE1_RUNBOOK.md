# Phase 1 运维手册（Redis + rs-worker）

> **状态（2026-06-18）**：**Phase 1 已闭合** — 历史见 [archives/2026-06-18_phase1-closure.md](./archives/2026-06-18_phase1-closure.md)。  
> **前置**：Phase 0 — [archives/2026-06-17_phase0-closure.md](./archives/2026-06-17_phase0-closure.md)。  
> **架构**：[MICROSERVICES_IMPLEMENTATION_PLAN.md](./MICROSERVICES_IMPLEMENTATION_PLAN.md) §5 阶段 1。

---

## 1. 当前架构

```text
satellite-backend   →  CreateTask + XADD rs.jobs  （不算 RS）
Redis (rs.jobs)     →  Stream 队列
rs-worker           →  RunPipeline 阶段 1～10（含检测）
```

| 组件 | namespace | 说明 |
|------|-----------|------|
| `satellite-backend` | `gitlab-runner` | env 见 `k8s/backend/deployment.yaml`（`USE_INPROCESS_PIPELINE=false`） |
| `redis` | `gitlab-runner` | `k8s/phase1/redis/` |
| `rs-worker` | `gitlab-runner` | `k8s/phase1/rs-worker/`，镜像同 backend |

---

## 2. 一次性前置（新集群 / 重建）

### 2.1 Redis 镜像入 Harbor

```bash
export HARBOR=192.168.10.238 HARBOR_USER=admin HARBOR_PASSWORD='***'
bash scripts/ops/mirror_redis_image.sh
# 目标：192.168.10.238/library/redis:7-alpine-amd64-r1
```

### 2.2 238 构建依赖 HTTP（ORT/字体）

```bash
# 在 238，脚本与 static-http-18080.service 同目录
sudo bash install-static-http-18080.sh
curl -sf -o /tmp/t.tgz http://127.0.0.1:18080/onnxruntime-linux-x64-1.24.4.tgz && ls -lh /tmp/t.tgz
```

---

## 3. 日常发布（一步到位）

### 3.1 开发机 → GitHub → 238 mirror → GitLab

```bash
# 238
git -C ~/Code/satellite-cloud.git fetch github --prune
git -C ~/Code/satellite-cloud.git push satellite-cloud --all --force
```

### 3.2 GitLab pipeline

自动执行：`build-backend` → `build-frontend` → **`deploy`**

`deploy` 会 `apply k8s/backend/deployment.yaml`（**已含 Redis 入队 env**）并更新镜像。

### 3.3 部署 / 更新 Redis + rs-worker

**手动** 在 GitLab Pipeline 点击 **`deploy-phase1-pilot`**，或 k8s-master：

```bash
cd ~/code/satellite-cloud
kubectl apply -k k8s/phase1/
kubectl -n gitlab-runner set image deployment/rs-worker rs-worker=192.168.10.238/satellite/backend:<SHA>
kubectl -n gitlab-runner rollout status deployment/redis
kubectl -n gitlab-runner rollout status deployment/rs-worker
```

> `deploy` **不会**自动 apply phase1；Redis/rs-worker 用上面 job 或 kubectl。

---

## 4. 验收（每次发版或故障恢复后）

```bash
# Pod 健康
kubectl -n gitlab-runner get pod -l 'app in (satellite-backend,redis,rs-worker)'

# backend Redis 模式
POD=$(kubectl -n gitlab-runner get pod -l app=satellite-backend -o jsonpath='{.items[0].metadata.name}')
kubectl -n gitlab-runner exec "$POD" -- sh -c 'echo INPROCESS=$SATELLITE_USE_INPROCESS_PIPELINE REDIS=$SATELLITE_REDIS_ADDR'
kubectl -n gitlab-runner logs "$POD" | grep 'Redis queue mode'

# Redis + rs-worker
RPOD=$(kubectl -n gitlab-runner get pod -l app=redis -o jsonpath='{.items[0].metadata.name}')
kubectl -n gitlab-runner exec "$RPOD" -- redis-cli ping
kubectl -n gitlab-runner logs deploy/rs-worker --tail=10
```

提交 **1 条 GF2+检测** 后：

```bash
TASK_ID=<id>
kubectl -n gitlab-runner logs deploy/satellite-backend --since=1h | grep -E "入队 Redis|$TASK_ID"
kubectl -n gitlab-runner logs deploy/rs-worker --since=1h | grep -E "开始处理|$TASK_ID"
```

| 项 | 通过标准 |
|----|----------|
| backend | `任务已入队 Redis`；**无** `worker 开始处理` |
| rs-worker | `rs-worker 开始处理任务` |
| 任务 | 10 阶段 success |

---

## 5. 回滚单 Pod 模式

编辑 `k8s/backend/deployment.yaml`：

```yaml
- name: SATELLITE_USE_INPROCESS_PIPELINE
  value: "true"
```

删除或注释 Redis 相关 env 四行，然后：

```bash
kubectl -n gitlab-runner apply -f k8s/backend/deployment.yaml
kubectl -n gitlab-runner scale deployment/rs-worker --replicas=0
kubectl -n gitlab-runner rollout status deployment/satellite-backend
```

---

## 6. 可选：并行压测（Phase 1+）

```bash
kubectl -n gitlab-runner scale deployment/rs-worker --replicas=3
# 同时提交 3 条 GF2；验收 3 个 task 均 completed
```

---

## 7. 相关路径

| 路径 | 说明 |
|------|------|
| `k8s/backend/deployment.yaml` | backend env（含 Redis 入队） |
| `k8s/phase1/` | redis、rs-worker |
| `.gitlab-ci.yml` | `deploy-phase1-pilot`（manual） |
| `scripts/ops/mirror_redis_image.sh` | Redis 推 Harbor |
| `docs/archives/2026-06-18_phase1-closure.md` | 收口归档 |

---

## 8. 故障排查

| 现象 | 处理 |
|------|------|
| 任务一直 pending | 查 rs-worker Running；`redis-cli ping`；backend 是否 `INPROCESS=false` |
| deploy 后又不入队 | 确认 `deployment.yaml` 含 Redis env 且 `apply` 成功 |
| Redis ImagePullBackOff | Harbor 补 redis 镜像 |
| rs-worker CrashLoop | 日志；DB secret；镜像是否含 `/app/rs-worker` |
