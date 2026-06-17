# Phase 1 K8s 清单（Redis + rs-worker）

> **模式**：默认 **Pilot** — 与现有 `satellite-backend` 同 namespace `gitlab-runner`，共享 PVC/Secret，降低迁移风险。  
> **目标态**：namespace 拆分见 `namespaces.yaml` + [MICROSERVICES_IMPLEMENTATION_PLAN.md](../../docs/MICROSERVICES_IMPLEMENTATION_PLAN.md) §5 阶段 1。

## 目录

| 路径 | 说明 |
|------|------|
| `namespaces.yaml` | 目标态：`satellite-control`、`satellite-compute-rs`、`satellite-compute-od` |
| `redis/` | Redis 7（Stream 队列） |
| `rs-worker/` | RS Worker Deployment（消费 `rs.jobs`） |
| `kustomization.yaml` | Pilot：namespace=`gitlab-runner` |

## Pilot 部署（推荐第一步）

**前置**：Phase 0 已闭合；`satellite-backend` 仍 `SATELLITE_USE_INPROCESS_PIPELINE=true`（默认），rs-worker 仅验证 Redis 连通与镜像内二进制。

```bash
# 在 k8s-master 或 CI Runner 节点
cd satellite-cloud/k8s/phase1

# 1) 可选：预创建目标 namespace（不影响 Pilot）
kubectl apply -f namespaces.yaml

# 2) Pilot — Redis + rs-worker（gitlab-runner）
kubectl apply -k .

# 3) 验证
kubectl -n gitlab-runner get deploy,pod | grep -E 'redis|rs-worker'
kubectl -n gitlab-runner logs deploy/rs-worker --tail=50

# 4) Redis 冒烟
POD=$(kubectl -n gitlab-runner get pod -l app=redis -o jsonpath='{.items[0].metadata.name}')
kubectl -n gitlab-runner exec "$POD" -- redis-cli ping
```

## 回滚

```bash
kubectl -n gitlab-runner delete deployment rs-worker redis --ignore-not-found
kubectl -n gitlab-runner delete svc redis --ignore-not-found
```

不影响现有 `satellite-backend`（单 Pod 流水线仍可用）。

## 镜像

rs-worker 与 backend **同一镜像** `192.168.10.238/satellite/backend:latest`，入口 `./rs-worker`（Phase 1 代码合并后 CI 自动打入）。

## 目标态迁移（后续）

1. 将 `satellite-api`（现 backend HTTP 部分）迁至 `satellite-control`
2. Redis 已在 `satellite-control` 时，rs-worker 改 `SATELLITE_REDIS_ADDR=redis.satellite-control.svc.cluster.local:6379`
3. NFS：为 `satellite-compute-rs` 新建 RWX PVC 指向同一 export，或暂保留 Pilot 至 Phase 2
