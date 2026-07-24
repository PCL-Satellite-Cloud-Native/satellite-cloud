# Post-P5 60 节点路线图（cluster-120）

> **起点**：P5 正式收口（2026-07-20，`p5-60-retry-20260720-0942`）  
> **Post-P5 主线收口**：2026-07-23～24 — [archives/2026-07-23_post-p5-60node-closure.md](./archives/2026-07-23_post-p5-60node-closure.md)  
> **下一步**：[post-p5-next-60node.md](./post-p5-next-60node.md)

---

## 状态总览（2026-07-24）

| 阶段 | 项 | 状态 |
|------|-----|------|
| P0-1 | 本星队列（XCLAIM / fail-closed / 非阻塞 sem） | ✅ |
| P0-2 | sat57 backend exec | 挂起（方案 A） |
| P0-3 | GitLab ↔ GitHub | ✅ 可同步发版 |
| P1-1 | 60 节点 metrics | ✅ 脚本通过 |
| P1-2 | 运维一页纸 | ✅ ops-one-pager-60node.md |
| P2-1 | D0 MinIO | ✅ |
| P2-2 | od-worker | 维持 scale 0 |
| P3 | Argo / 拓扑 / CI dual | 按需 |

---

## P0 — 稳态运维

| # | 项 | 状态 | 说明 |
|---|-----|------|------|
| P0-1 | Redis 非本星 job | ✅ | 本星 XPENDING+XCLAIM；`6067490` 非阻塞 sem；`87da08a` 跳过 in-flight |
| P0-2 | sat57 backend 镜像 | 挂起 | 节点 overlay；API 可用；exec 不可用 |
| P0-3 | GitLab ↔ GitHub | ✅ | `cluster-120` 发版路径可用 |

---

## P1 — 可观测

| # | 项 | 状态 |
|---|-----|------|
| P1-1 | P6 最小监控 | ✅ `phase5_verify_metrics_60.sh` |
| P1-2 | 运维一页纸 | ✅ [ops-one-pager-60node.md](../../60node-platform-docs/runbooks/ops-one-pager-60node.md) |

---

## P2 — 存储 / 前端

| # | 项 | 状态 |
|---|-----|------|
| P2-1 | D0 MinIO | ✅ task78/83；GET 200；stats OK |
| P2-2 | od-worker | ✅ 冻结 in-process；见 [decisions/2026-07-24_od-worker-60node.md](./decisions/2026-07-24_od-worker-60node.md) |

---

## P3 — 按需

见 [post-p5-next-60node.md](./post-p5-next-60node.md) N5。

---

## 验收摘要

| 能力 | 结果 |
|------|------|
| D0 | preview/summary 200；dets>0 |
| 三锚点 | 847→sat1，822→sat21，826→sat41 |
| 强制卫星 | UI 必选；API **HTTP 400**（backend `3f0ec26d`） |
| frontend | `@sha256:1cb1ee94…` |

关键 commit：`48725d6`、`c2928d0`、`6067490`、`45abc38`、`87da08a`。
