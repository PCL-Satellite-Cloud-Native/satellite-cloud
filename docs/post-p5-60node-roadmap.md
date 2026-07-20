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

### P0-2 状态（2026-07-20）

| 结论 | 说明 |
|------|------|
| 根因 | 同 digest `sha256:5f84530c…` 在 sat1 正常、sat57 `lib*.so file too short` → **sat57 节点 overlay/磁盘损坏** |
| 清镜像 | Job `purge-backend-image-sat57` 已成功删除本地 backend 层；重拉后仍损坏 |
| 迁节点 | 失败：PVC `remote-sensing-data` 为 **RWO hostPath@sat57**，affinity 到 sat5 → Pending |
| 决议 | **方案 A**：backend 留 sat57；API/入队正常；`kubectl exec` 不可用；artifact 仍靠 D0 |
| 后续 | 平台修 sat57 盘/containerd；或方案 B 把 PV nodeAffinity 改到健康节点 |

### P0-2 操作（历史，sat10-m1）

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
```

### P0-3 操作（GitLab ↔ GitHub）

目标：GitLab `192.168.10.238:8444` 上 `cluster-120` 至少包含 `cd7658f`（含 P0-1/P0-2 文档与 Job）。

**在能推 GitLab 的机器上**（仓库机 238 或已配 PAT/SSH 的 sat10）：

```bash
# 若用 GitHub → GitLab mirror（仓库机常见）
# git -C ~/Code/satellite-cloud.git fetch github cluster-120
# git -C ~/Code/satellite-cloud.git push gitlab-internal cluster-120

# 或 sat10 已能 SSH GitHub 时，另加 GitLab remote 后：
cd ~/code/satellite-cloud
git fetch origin cluster-120
git log -1 --oneline origin/cluster-120   # 期望 ≥ cd7658f

# 推送到 GitLab（按实际 remote 名/URL 改）
git remote add gitlab https://192.168.10.238:8444/root/satellite-cloud.git 2>/dev/null || true
GIT_SSL_NO_VERIFY=true git -c http.sslVerify=false push gitlab cluster-120
```

验收：GitLab Web → Branches → `cluster-120` 最新 commit 与 GitHub 一致；可选触发 `deploy-cluster-120` 确认不回退旧镜像。

当前进行：**P0-3**。
