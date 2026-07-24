# Post-P5 之后：60 节点下一步（cluster-120）

> **起点**：Post-P5 主线已收口 — [archives/2026-07-23_post-p5-60node-closure.md](./archives/2026-07-23_post-p5-60node-closure.md)  
> **日期**：2026-07-24

---

## 建议优先级

| 优先级 | 项 | 目标 | 验收 |
|--------|-----|------|------|
| **N0** | rs-worker 对齐 backend 新 digest | 带上 `87da08a`（in-flight 不刷屏） | ✅ 2026-07-24 sat10-m1：`rs-worker` DS rollout 57/57 |
| **N1** | P1-2 运维一页纸 | Gateway / Redis / 锚点 / 镜像规范 | ✅ `60node-platform-docs/runbooks/ops-one-pager-60node.md` |
| **N2** | P1 告警 / 巡检 | `rs.jobs` XLEN、rs-worker NotReady | ✅ `scripts/ops_patrol_60.sh`（无 Prometheus 时用手工巡检） |
| **N3** | sat57 节点修复 | backend `kubectl exec` 可用 | `ldd`/`ls` 正常（平台修盘） |
| **N4** | od-worker 策略 | 明确长期 in-process vs DS+hostPath | 决策写入 runbook |
| **N5** | P3 按需 | Argo PAN hostPath、动态拓扑、CI dual | 有业务需求再开 |

---

## N0 — 已完成（2026-07-24）

sat10-m1：`daemon set "rs-worker" successfully rolled out`（对齐 `@sha256:3f0ec26d…`）。

验收（建议再跑一次确认 imageID 单一）：

```bash
bash scripts/ops_patrol_60.sh \
  --expect-digest 3f0ec26d88b505bfdc1e22653942313fd2f98e11d1675633b541982a1b000966
```

---

## N2 — 巡检脚本（已落地）

```bash
# 日常
bash scripts/ops_patrol_60.sh

# 与 metrics 脚本互补
CLUSTER_PROFILE=60node MIN_DS_READY=50 bash scripts/phase5_verify_metrics_60.sh
```

阈值约定：`WARN_XLEN=500`、`FAIL_XLEN=10000`。有 Prometheus Operator 时可再挂 ServiceMonitor（`k8s/phase4/`）。

---

## 下一步（N3+）

| 项 | 说明 |
|----|------|
| N3 sat57 | 平台修 overlay 后验 `kubectl exec` |
| N4 od-worker | 决策：长期 in-process vs DS+hostPath |
| N5 P3 | 有业务需求再开 |

可选冒烟：UI 再跑一单 847@sat1，确认无 reclaim「忙」刷屏。

---

## 不做清单（当前）

- 不重开 Argo PAN RPC（除非 hostPath 模板就绪）  
- 不默认打开 od-worker Deployment（PVC@sat57）  
- 不扩大非锚点 GF2 输入副本（除非业务要求）
