# Post-P5 60 节点路线图（cluster-120）

> **起点**：P5 正式收口（2026-07-20，`p5-60-retry-20260720-0942`，task 4/5/6 completed）  
> **归档**：[archives/2026-07-20_p5-60node-closure.md](./archives/2026-07-20_p5-60node-closure.md)

---

## P0 — 稳态运维（优先，1～2 天）

| # | 项 | 问题 | 动作 | 验收 |
|---|-----|------|------|------|
| P0-1 | Redis 非本星 job | 57 worker ACK+re-XADD → stream 膨胀 | 非本星 **不 ACK、不 re-XADD**；留 PEL 由 XAUTOCLAIM 转交 | 提交 3 锚点任务后 `XLEN rs.jobs` 不指数增长 |
| P0-2 | sat57 backend 镜像 | `libselinux.so.1: file too short` | privileged Job `crictl rmi` + rollout | `kubectl exec` backend 可 `ls` |
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

当前进行：**P0-1**（见 `backend/internal/queue/redis.go`、`cmd/rs-worker/main.go`）。
