# Phase 4 运维手册（多星协同与可观测）

> **状态（2026-06-24）**：**已收口** — 见 [archives/2026-06-24_phase4-closure.md](./archives/2026-06-24_phase4-closure.md)  
> **前置**：Phase 3 已闭合；Phase 4 定稿 benchmark **phase4-test10**（task 173–182，10/10 completed）。  
> **监控 SSOT**：`monitoring/kube-prometheus-stack` — Grafana **30001**，Prometheus **30090**（不用 istio-system:30300）。

---

## 0. 执行 vs 归档

| 阶段 | 内容 | 门禁 |
|------|------|------|
| **执行** | 部署 metrics 镜像 + phase4 manifest + 压测 | A: `satellite_queue_depth` 可查 → B: phase4-test1 通过 → C: phase4-test10 通过 |
| **归档** | `docs/archives/2026-06-24_phase4-closure.md` | ✅ 已完成 |

---

## 1. Phase 3 冒烟（task 148）

| 项 | 值 |
|----|-----|
| 总耗时 | **1498 s** |
| stage 4 | **185.6 s** |
| Argo | P3-04b，`backend:dd4bc728` |
| 瓶颈 | `object_detection` **939 s**（CPU） |

---

## 2. 实施步骤（k8s-master）

### Step 1 — 推送代码并构建镜像

GitLab Pipeline `build-backend` 完成后取 tag，例如 `192.168.10.238/satellite/backend:abc1234`。

**必须含** `backend/internal/metrics/` 埋点（commit 含 Phase 4 代码）。

### Step 2 — 一键部署

**前置（集群管理员一次性）**：若 CI 报 `Forbidden` on HPA / ServiceMonitor：

```bash
kubectl apply -f k8s/gitlab-runner-ci-rbac-phase4.yaml
```

```bash
cd ~/code/satellite-cloud   # 仓库根目录

git pull   # 拉取含 phase4 manifest + scripts 的最新代码

export BACKEND_IMAGE=192.168.10.238/satellite/backend:<tag>
bash scripts/phase4_deploy.sh
```

或 CI 手动触发 **`deploy-phase4-pilot`**（需同一 pipeline 的 `BACKEND_IMAGE`）。

脚本会：

1. `kubectl apply -k k8s/phase1/` + `phase2/` + `backend/deployment.yaml`
2. 滚动 **rs-worker / od-worker / satellite-backend** 到新镜像
3. 设置 `SATELLITE_USE_ARGO_PAN_RPC=true` + `SATELLITE_RS_WORKFLOW_IMAGE`
4. `kubectl apply -k k8s/phase4/`
5. 运行 `scripts/phase4_verify_metrics.sh`

### Step 3 — Prometheus 验收（门禁 A）

等待 **30～60s** 让 ServiceMonitor 生效，然后：

```bash
# 方式 1：NodePort
# 浏览器 http://<node-ip>:30090 → 查询 satellite_queue_depth

# 方式 2：port-forward
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
# http://127.0.0.1:9090
```

期望：`satellite_queue_depth{stream="rs.jobs"}` 等指标存在（值可为 0）。

### Step 4 — Grafana 仪表盘

1. 打开 **http://\<node-ip\>:30001**（`monitoring` namespace，非 istio 30300）
2. **Dashboards → Import** → 上传 `k8s/phase4/grafana/satellite-workers.json`
3. 选择 Prometheus datasource（kube-prometheus-stack）

### Step 5 — 3 路压测（门禁 B）

**注意**：同 `filePrefix` 时脚本默认 **`--max-in-flight 1`**（串行）。3 路 = 依次跑 3 条，测稳定性而非并发写 NFS。  
若需 3 路**同时** running，须 Phase 5+ 按 task_id 隔离目录（当前架构不支持）。

```bash
kubectl -n gitlab-runner scale deploy/rs-worker --replicas=1
kubectl -n gitlab-runner patch hpa rs-worker -p '{"spec":{"maxReplicas":1}}'

kubectl -n gitlab-runner port-forward svc/satellite-backend 8080:8080 &

bash scripts/submit_n_remote_sensing_tasks.sh \
  --run-id phase4-test1 \
  --count 3 \
  --api-base http://127.0.0.1:8080
```

### 2.1 共享 NFS 路径（同 filePrefix 冲突根因）

| 路径 | 冲突 |
|------|------|
| `persist_output_preprocessing/pan_rad_toa/` | 多 task 同前缀 |
| `persist_output_preprocessing/pan_warp_quarters/` | Argo 四块 + merge 输入 |
| `preparePanRpcPersistWorkerDirs` | 新 task 进 stage 4 会 **RemoveAll(workers/)** |

**burst / max-in-flight>1 失败后**建议清理 scratch（在 backend Pod 内）：

```bash
BE=$(kubectl -n gitlab-runner get pod -l app=satellite-backend -o jsonpath='{.items[0].metadata.name}')
kubectl -n gitlab-runner exec "$BE" -- sh -lc '
  rm -rf /opt/remote-sensing/output_preprocessing/*
  rm -rf /opt/remote-sensing/persist_output_preprocessing/pan_warp_quarters/workers
'
```

### Step 6 — 10 路压测（门禁 C → 归档）

**验收定义**：提交 10 条任务、**串行完成**（默认 in-flight=1），期间 Prometheus/Grafana 可见指标；**不是** 10 路同时写同一 GF2 前缀。

```bash
bash scripts/phase4_abort_benchmark.sh --tasks 170   # 若有卡住 task

kubectl -n gitlab-runner scale deploy/rs-worker --replicas=1
kubectl -n gitlab-runner patch hpa rs-worker -p '{"spec":{"maxReplicas":1}}'

bash scripts/submit_n_remote_sensing_tasks.sh \
  --run-id phase4-test10 \
  --count 10 \
  --max-in-flight 1 \
  --api-base http://127.0.0.1:8080 \
  --timeout 28800
```

墙钟约 **10 × 25 min ≈ 4h+**；`--timeout 28800`（8h）更稳妥。

**中止残留**：

```bash
bash scripts/phase4_abort_benchmark.sh --tasks 170
```

---

## 3. 指标说明

| 指标 | 类型 | 标签 | 说明 |
|------|------|------|------|
| `satellite_queue_depth` | Gauge | `stream` | Redis XPENDING（15s 刷新） |
| `satellite_worker_jobs_active` | Gauge | `worker` | rs-worker / od-worker |
| `satellite_task_duration_seconds` | Histogram | `worker`, `outcome` | 任务切片耗时 |
| `satellite_tasks_total` | Counter | `worker`, `outcome` | 累计计数 |

- rs-worker `outcome=od_enqueued`：RS 9 阶段完成并已投递 od.jobs  
- metrics 端口：worker **9090**；backend **8080/metrics**

---

## 4. HPA（Pilot）

| Deployment | min | max | CPU 目标 |
|------------|-----|-----|----------|
| rs-worker | 1 | 3 | 75% |
| od-worker | 1 | 2 | 70% |

```bash
kubectl -n gitlab-runner get hpa rs-worker od-worker -w
```

---

## 5. 相关路径

| 路径 | 说明 |
|------|------|
| `scripts/phase4_deploy.sh` | 一键部署 |
| `scripts/phase4_verify_metrics.sh` | 部署验收 |
| `scripts/submit_n_remote_sensing_tasks.sh` | 多 task 压测 |
| `k8s/phase4/` | ServiceMonitor、metrics Service、HPA |
| `backend/internal/metrics/` | 指标实现 |

---

## 6. 不在 Phase 4 范围

- GPU / MinIO / 120 星拓扑 / istio-monitoring 栈合并

*Phase 4 已于 2026-06-24 收口；详见 [archives/2026-06-24_phase4-closure.md](./archives/2026-06-24_phase4-closure.md)。*
