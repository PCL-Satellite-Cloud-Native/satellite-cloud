# Post-P5 60 节点路线图（cluster-120）

> **起点**：P5 正式收口（2026-07-20，`p5-60-retry-20260720-0942`，task 4/5/6 completed）  
> **归档**：[archives/2026-07-20_p5-60node-closure.md](./archives/2026-07-20_p5-60node-closure.md)

---

## P0 — 稳态运维（优先，1～2 天）

| # | 项 | 问题 | 动作 | 验收 |
|---|-----|------|------|------|
| P0-1 | Redis 非本星 job | 57 worker ACK+re-XADD → stream 膨胀 | 非本星 **不 ACK、不 re-XADD**；留 PEL 由 XAUTOCLAIM 转交 | 提交 3 锚点任务后 `XLEN rs.jobs` 不指数增长 |
| P0-2 | sat57 backend 镜像 | `libselinux.so.1: file too short` | Job `k8s/phase5/job-purge-backend-image-sat57.yaml` + rollout | `kubectl exec` backend 可 `ls` / `ldd` |
| P0-3 | GitLab ↔ GitHub | CI 在 238，代码在 GitHub | mirror / push `cluster-120` 到 GitLab | `deploy-cluster-120` 用 `2b673f9+` |

---

## P1 — 可观测（~1 周，P0-1 后）

| # | 项 | 动作 | 验收 |
|---|-----|------|------|
| P1-1 | P6 最小监控 | DS metrics Service、Grafana 面板、rs.jobs XLEN 告警 | `phase4_verify_metrics.sh` 60node 变体通过 |
| P1-2 | 运维一页纸 | Gateway API、Postgres、Redis 清理、锚点数据 | runbook 链接可检索 |

---

## P2 — 存储 / 前端（2～4 周）

| # | 项 | 动作 | 验收 |
|---|-----|------|------|
| P2-1 | D0 MinIO Put | worker 产物 upload；backend Open from MinIO | artifact 下载 200；前端预览可见 |
| P2-2 | od-worker 策略 | D0 前维持 `USE_OD_WORKER=false` | — |

---

## P3 — 按需

- `workflowtemplate-pan-rpc-60` hostPath（重开 Argo PAN RPC 时）
- 1441 动态拓扑回放
- CI dual-cluster（Pilot + 120）
- od-worker DaemonSet + hostPath（若不走 MinIO）

---

## 实施顺序

```text
Now     P0-1 代码 → build → rollout rs-worker
        P0-2 sat57 backend（并行）
        P0-3 GitLab sync（并行）
Week 1  P1-1 P6 最小监控
Week 2+ P2-1 D0 设计与实现
```

### P0-1 状态（2026-07-20）

✅ 已验证：`SkipRSJobForOtherConsumer` 在镜像内；单任务运行期间 `XLEN rs.jobs` 稳定为 1，无指数膨胀。

### P0-2 操作（sat10-m1）

```bash
cd ~/code/satellite-cloud && git pull origin cluster-120

# 0) 确认 backend 在 sat57
kubectl -n gitlab-runner get pod -l app=satellite-backend -o wide

# 1) 缩容 / 删 Pod，释放镜像占用（API 短暂中断）
kubectl -n gitlab-runner scale deployment/satellite-backend --replicas=0
kubectl -n gitlab-runner wait --for=delete pod -l app=satellite-backend --timeout=120s || true

# 2) 清坏镜像
kubectl -n gitlab-runner delete job purge-backend-image-sat57 --ignore-not-found
kubectl apply -f k8s/phase5/job-purge-backend-image-sat57.yaml
kubectl -n gitlab-runner wait --for=condition=complete --timeout=300s job/purge-backend-image-sat57
kubectl -n gitlab-runner logs job/purge-backend-image-sat57

# 3) 重新拉镜像并启动（强制 Always）
kubectl -n gitlab-runner scale deployment/satellite-backend --replicas=1
kubectl -n gitlab-runner set image deployment/satellite-backend \
  satellite-backend=192.168.10.238/satellite/backend:cluster-120-latest
kubectl -n gitlab-runner rollout restart deployment/satellite-backend
kubectl -n gitlab-runner rollout status deployment/satellite-backend --timeout=300s

# 4) 验收：exec 不再报 libselinux
BPOD=$(kubectl -n gitlab-runner get pod -l app=satellite-backend -o jsonpath='{.items[0].metadata.name}')
kubectl -n gitlab-runner exec "$BPOD" -- ls /bin/ls
kubectl -n gitlab-runner exec "$BPOD" -- curl -fsS http://127.0.0.1:8080/health || true
curl -sI http://192.168.12.67:30080/api/remote-sensing/tasks/4 | head -5
```

当前进行：**P0-2**。
