# Phase 2 运维手册（od-worker 独立检测）

> **状态（2026-06-22）**：**Phase 2 已闭合** — 首次收口 [2026-06-18_phase2-closure.md](./archives/2026-06-18_phase2-closure.md)（task 141）；生产复验 [2026-06-22_phase2-production-validation.md](./archives/2026-06-22_phase2-production-validation.md)（task **143**）。  
> **下一阶段**：[PHASE4_RUNBOOK.md](./PHASE4_RUNBOOK.md)（规划；集群**暂无 GPU**）。
> **前置**：[PHASE1_RUNBOOK.md](./PHASE1_RUNBOOK.md)（Phase 1 已闭合）。  

---

## 1. 当前架构（Phase 2 目标）

```text
backend        →  XADD rs.jobs
rs-worker      →  阶段 1～9  →  XADD od.jobs（enable_detection 时）
od-worker      →  阶段 10（yolov8s）
```

| 组件 | 队列 | 职责 |
|------|------|------|
| `satellite-backend` | 入队 `rs.jobs` | API |
| `rs-worker` | 消费 `rs.jobs` | RS 1～9；`USE_OD_WORKER=true` 时不跑检测 |
| `od-worker` | 消费 `od.jobs` | 阶段 10 目标识别 |
| `redis` | Stream | `rs.jobs` + `od.jobs` |

---

## 2. 关键环境变量

| 变量 | rs-worker | od-worker | 说明 |
|------|-----------|-----------|------|
| `SATELLITE_USE_OD_WORKER` | `true` | — | `false` 回滚：检测回到 rs-worker |
| `SATELLITE_REDIS_STREAM_OD` | — | `od.jobs` | OD 队列名 |
| `SATELLITE_REDIS_OD_CONSUMER_GROUP` | — | `od-workers` | OD 消费组 |

backend / rs-worker 默认 **不** 改；Phase 2 开关仅在 rs-worker Deployment。

---

## 3. 部署（一步到位）

### 3.1 发版镜像（含 `./od-worker`）

GitLab Pipeline（push `main` 后 **自动**）：

```text
build-backend → deploy → deploy-phase2-pilot（自动）
```

`deploy-phase2-pilot` 与 Phase 1 的 `deploy-phase1-pilot` 同模式：

- `kubectl apply -k k8s/phase2/` + 更新 od-worker 镜像
- `kubectl apply -k k8s/phase1/` 更新 rs-worker（含 `SATELLITE_USE_OD_WORKER=true`）+ 更新镜像

> **勿** `kubectl apply -f k8s/phase1/rs-worker/deployment.yaml`：rs-worker 由 kustomize 创建，selector 含 `satellite.io/phase` 标签，裸 apply 会触发 selector 不可变错误。

> 后续若需改为手动触发，在 `.gitlab-ci.yml` 的 `deploy-phase2-pilot` 增加 `when: manual`（与当前 `deploy-phase1-pilot` 一致）。

手动兜底（k8s-master）：

```bash
cd ~/code/satellite-cloud
kubectl apply -k k8s/phase2/
kubectl apply -k k8s/phase1/
kubectl -n gitlab-runner set image deployment/od-worker od-worker=192.168.10.238/satellite/backend:<SHA>
kubectl -n gitlab-runner set image deployment/rs-worker rs-worker=192.168.10.238/satellite/backend:<SHA>
kubectl -n gitlab-runner rollout status deployment/od-worker
kubectl -n gitlab-runner rollout status deployment/rs-worker
```

> **前置**：Phase 1 的 redis + rs-worker 必须已 Running。

### 3.3 CI 报错 `serviceaccounts "rs-worker" is forbidden`

**原因**：GitLab CI 使用 `gitlab-runner` ServiceAccount，默认**无权** get/create `ServiceAccount`。Phase 2 job **不应** apply SA（rs-worker SA 在 Phase 1 首次部署前由管理员创建一次即可）。

**在 k8s-master 执行（一次性）**：

```bash
cd ~/code/satellite-cloud && git pull
kubectl apply -f k8s/gitlab-runner-ci-rbac-phase3.yaml   # 可选：供 Phase 3 CI apply Argo RBAC
kubectl apply -f k8s/phase1/rs-worker/serviceaccount.yaml
kubectl get sa rs-worker -n gitlab-runner
```

确认 SA 存在后，重新跑 Pipeline 的 `deploy-phase2-pilot`（无需 CI 再 apply SA）。

### 3.2 验证二进制

```bash
POD=$(kubectl -n gitlab-runner get pod -l app=od-worker -o jsonpath='{.items[0].metadata.name}')
kubectl -n gitlab-runner exec "$POD" -- ls -lh /app/od-worker
```

---

## 4. 验收（P2-03）

提交 **1 条 GF2 + enable_detection** 后：

```bash
TASK_ID=<id>
kubectl -n gitlab-runner logs deploy/rs-worker --since=2h | grep -E "$TASK_ID|检测任务已入队"
kubectl -n gitlab-runner logs deploy/od-worker --since=2h | grep -E "$TASK_ID|开始目标识别|yolov8s"
kubectl -n gitlab-runner exec deploy/redis -- redis-cli XINFO GROUPS od.jobs
```

| 项 | 通过标准 |
|----|----------|
| rs-worker | 阶段 1～9 日志；**有** `检测任务已入队 Redis`；**无** yolov8s |
| od-worker | `od-worker 开始处理检测任务`；yolov8s 输出 |
| 任务 | 10 阶段 success；前端 zip/stats 正常 |

---

## 5. 回滚

编辑 `k8s/phase1/rs-worker/deployment.yaml`：`SATELLITE_USE_OD_WORKER=false`，然后：

```bash
kubectl apply -k k8s/phase1/
kubectl -n gitlab-runner scale deployment/od-worker --replicas=0
kubectl -n gitlab-runner rollout status deployment/rs-worker
```

回滚后检测重新在 rs-worker 内联执行（Phase 1 行为）。

---

## 6. GPU（Phase 2+，可选）

集群有 GPU 节点后，仅改 od-worker：

```yaml
SATELLITE_OBJECT_DETECTION_DEVICE: "gpu"
resources.limits.nvidia.com/gpu: "1"
nodeSelector: { ... }
```

无需改业务代码。

---

## 7. 相关路径

| 路径 | 说明 |
|------|------|
| `backend/cmd/od-worker/` | OD 消费者入口 |
| `backend/internal/queue/od.go` | `od.jobs` 消息 |
| `backend/internal/remotesensing/od_dispatch.go` | 入队 + RunDetectionFromJob |
| `k8s/phase2/` | od-worker Deployment |
| `.gitlab-ci.yml` | `deploy-phase2-pilot`（push main 自动；可改 manual） |

---

## 8. 故障排查

| 现象 | 处理 |
|------|------|
| 任务卡在 stage 9 后不动 | 查 `USE_OD_WORKER=true`；od-worker Running；`XINFO GROUPS od.jobs` |
| od-worker 报融合文件不存在 | rs-worker 同步持久化失败；查 NFS `output_preprocessing/fusion_envi/` |
| 检测仍在 rs-worker | `USE_OD_WORKER=false` 或未 rollout rs-worker |
| rs-worker **Evicted** / DiskPressure | 节点 **ephemeral-storage** 不足（scratch emptyDir 40Gi）；清理 NFS 中间产物；cordon 紧张节点；见 [2026-06-22_phase2-production-validation.md](./archives/2026-06-22_phase2-production-validation.md) §5 |
| Evicted 后 DB task 仍 running | 手工将旧 task 标 `failed`；重新提交 GF2 |

---

## 9. 验收记录（归档索引）

| 日期 | task | benchmark | 归档 |
|------|------|-----------|------|
| 2026-06-18 | 141 | `artifacts/benchmarks/phase2-test1/report.txt` | [phase2-closure](./archives/2026-06-18_phase2-closure.md) |
| 2026-06-22 | **143** | `artifacts/benchmarks/phase2-test3/report.txt` | [production-validation](./archives/2026-06-22_phase2-production-validation.md) |
