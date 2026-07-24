# Post-P5 之后：60 节点下一步（cluster-120）

> **起点**：Post-P5 主线已收口 — [archives/2026-07-23_post-p5-60node-closure.md](./archives/2026-07-23_post-p5-60node-closure.md)  
> **日期**：2026-07-24

---

## 建议优先级

| 优先级 | 项 | 目标 | 验收 |
|--------|-----|------|------|
| **N0** | rs-worker 对齐 backend 新 digest | 带上 `87da08a`（in-flight 不刷屏） | ✅ 2026-07-24 rollout + `ops_patrol_60` 通过（57/57，digest 一致，XLEN=20） |
| **N1** | P1-2 运维一页纸 | Gateway / Redis / 锚点 / 镜像规范 | ✅ `60node-platform-docs/runbooks/ops-one-pager-60node.md` |
| **N2** | P1 告警 / 巡检 | `rs.jobs` XLEN、rs-worker NotReady | ✅ `scripts/ops_patrol_60.sh`（无 Prometheus Operator） |
| **N3** | sat57 节点修复 | backend `kubectl exec` 可用 | 挂起（平台修盘） |
| **N4** | od-worker 策略 | 明确长期 in-process vs DS+hostPath | ✅ [decisions/2026-07-24_od-worker-60node.md](./decisions/2026-07-24_od-worker-60node.md) |
| **N5** | P3 按需 | Argo PAN hostPath、动态拓扑、CI dual | 有业务需求再开 |

---

## N0 / N2 — 已验收（2026-07-24 sat10-m1）

```text
desired=57 ready=57
57 × backend@sha256:3f0ec26d…
XLEN(rs.jobs)=20  XPENDING=0
无 Prometheus Operator CRD
ops_patrol_60 通过
```

日常：

```bash
bash scripts/ops_patrol_60.sh \
  --expect-digest 3f0ec26d88b505bfdc1e22653942313fd2f98e11d1675633b541982a1b000966
```

---

## N4 — od-worker 策略（已冻结）

见 [decisions/2026-07-24_od-worker-60node.md](./decisions/2026-07-24_od-worker-60node.md)：

- **默认**：`USE_OD_WORKER=false`，OD 在锚点 rs-worker 内跑  
- **`od-worker` replicas=0**（勿套 Pilot Phase2）

---

## 剩余（N3 / N5）

| 项 | 说明 |
|----|------|
| N3 sat57 | 平台修 overlay 后验 `kubectl exec` |
| N5 P3 | 有业务需求再开（Argo hostPath / 拓扑 / CI dual） |

---

## 不做清单（当前）

- 不重开 Argo PAN RPC（除非 hostPath 模板就绪）  
- 不默认打开 od-worker Deployment（PVC@sat57）  
- 不扩大非锚点 GF2 输入副本（除非业务要求）
