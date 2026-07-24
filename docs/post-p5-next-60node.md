# Post-P5 之后：60 节点下一步（cluster-120）

> **起点**：Post-P5 主线已收口 — [archives/2026-07-23_post-p5-60node-closure.md](./archives/2026-07-23_post-p5-60node-closure.md)  
> **日期**：2026-07-24

---

## 建议优先级

| 优先级 | 项 | 目标 | 验收 |
|--------|-----|------|------|
| **N0** | rs-worker 对齐 backend 新 digest | 带上 `87da08a`（in-flight 不刷屏） | 跑任务时无对同一 stream 反复「忙」 |
| **N1** | P1-2 运维一页纸 | Gateway / Redis / 锚点 / 镜像规范 | ✅ `60node-platform-docs/runbooks/ops-one-pager-60node.md` |
| **N2** | P1 告警 | `rs.jobs` XLEN、rs-worker NotReady | 有 Prometheus 则接告警；否则文档化手工巡检 |
| **N3** | sat57 节点修复 | backend `kubectl exec` 可用 | `ldd`/`ls` 正常（平台修盘） |
| **N4** | od-worker 策略 | 明确长期 in-process vs DS+hostPath | 决策写入 runbook |
| **N5** | P3 按需 | Argo PAN hostPath、动态拓扑、CI dual | 有业务需求再开 |

---

## N0 — 立刻可做（5～15 分钟）

```bash
NS=gitlab-runner
# 与已验证的 backend 同 digest（含 45abc38 + 87da08a 的 build）
IMG='192.168.10.238/satellite/backend@sha256:3f0ec26d88b505bfdc1e22653942313fd2f98e11d1675633b541982a1b000966'

kubectl -n "$NS" set image ds/rs-worker rs-worker="$IMG"
kubectl -n "$NS" set env ds/rs-worker \
  SATELLITE_USE_OD_WORKER=false \
  SATELLITE_USE_ARGO_PAN_RPC=false \
  SATELLITE_RS_SATELLITE_AWARE_QUEUE=true
kubectl -n "$NS" rollout status ds/rs-worker --timeout=1200s

kubectl -n "$NS" get pod -l app=rs-worker \
  -o jsonpath='{range .items[*]}{.status.containerStatuses[0].imageID}{"\n"}{end}' | sort | uniq -c
```

---

## N1 — 运维一页纸提纲

建议新建/补强：`60node-platform-docs/runbooks/ops-one-pager-60node.md`

必含：

1. API Gateway：`http://192.168.12.67:30080`  
2. 三锚点 PK 与 hostPath 输入路径  
3. 关键 env（AWARE / MinIO / OD/Argo false）  
4. 镜像：`@sha256` 或 CI tag；禁止 digest 当 tag  
5. Redis 巡检：`XLEN rs.jobs` / `XPENDING`  
6. 常见故障：非锚点无 TIFF、ImagePullBackOff、sat57 exec  

---

## 不做清单（当前）

- 不重开 Argo PAN RPC（除非 hostPath 模板就绪）  
- 不默认打开 od-worker Deployment（PVC@sat57）  
- 不扩大非锚点 GF2 输入副本（除非业务要求）
