# 归档：Phase 3 性能收口（P3-04b 定稿）

> **归档日期**：2026-06-23  
> **阶段**：Phase 3 — Argo Workflows 阶段 4 PAN RPC  
> **状态**：**Phase 3 全量闭合**（功能 P3-03 + 性能相对 Phase 2 不劣）  
> **功能 Pilot**：[2026-06-22_phase3-closure.md](./2026-06-22_phase3-closure.md)（task 144）  
> **活跃运维**：[PHASE3_RUNBOOK.md](../PHASE3_RUNBOOK.md)

---

## 1. 性能验收标准（定稿）

| 标准 | 说明 | 结果 |
|------|------|------|
| **功能** | Argo Workflow Succeeded；10 阶段 completed | ✅ task 144/146/147 |
| **相对 Phase 2 不劣** | stage 4 ≤ task 143 基线 **174.6 s** | ✅ task **146** **165.4 s** |
| **Stretch（原 P3-04）** | stage 4 ≤ **131 s**（↓25%） | ❌ 未达；留 Phase 4+ |

**生产配置**：**P3-04b**（4×1 + 直写 persist + 无 init-dirs + persist merge）。

---

## 2. Benchmark 汇总（同输入 GF2）

| task | run_id | 配置 | stage 4 | 判定 |
|------|--------|------|---------|------|
| 143 | phase2-test3 | Phase 2 进程内 | **174.6 s** | 基线 |
| 144 | phase3-test1 | Argo 4×1 + init-dirs + NFS sync | 212.7 s | 功能 ✅ |
| 145 | — | Argo 2×2（P3-04） | 285.5 s | ❌ 回退 |
| **146** | **phase3-test3** | **P3-04b** | **165.4 s** | **✅ 定稿** |
| 147 | phase3-test4 | P3-04c（直写 + 亲和 + 高算力） | 202.5 s | ❌ 回退 |

报告路径（k8s-master）：`artifacts/benchmarks/phase3-test3/report.txt`

---

## 3. P3-04b 固化项

| 优化 | 相对 task 144 |
|------|----------------|
| 阶段 3 `pan_rad_toa` 直写 persist | 省 NFS scratch→persist 同步 |
| 去掉 Workflow `init-dirs` | rs-worker 预建 `workers/group{1..4}` |
| persist 上 merge | `rename` 替代 scratch 回拷 |
| 4×1 并行 step | 4 CPU limit；无 Pod 亲和 |

**未采用（task 147 验证失败）**：

- step 直写 `pan_warp_quarters/`（同目录 NFS 争用）
- Pod 亲和共置 4 step
- 强制 cpu_threads≥2、warp_mem_mb≥1024

---

## 4. 集群定稿操作

```bash
# 推送含 P3-04b 回退的 main 后
kubectl apply -k k8s/phase3/
kubectl -n gitlab-runner set env deployment/rs-worker SATELLITE_USE_ARGO_PAN_RPC=true
# CI deploy-phase2-pilot 会更新 rs-worker 镜像；或手动 set image
kubectl -n gitlab-runner rollout status deployment/rs-worker
```

回滚 Phase 2 进程内：`SATELLITE_USE_ARGO_PAN_RPC=false`。

---

## 5. 生产签收（2026-06-23）

| 项 | 值 |
|----|-----|
| 配置 | **P3-04b**；`USE_ARGO_PAN_RPC=true`（`k8s/phase1/rs-worker` manifest 默认定稿） |
| 镜像 | `192.168.10.238/satellite/backend:dd4bc728` |
| WorkflowTemplate | `workers/group{N}`；4×1 area step |
| 定稿 benchmark | task **146** / `phase3-test3` / stage 4 **165.4 s** |
| 冒烟 | `phase3-smoke`（部署后回归，进行中） |

Phase 3 **正式归档**；后续工作见 [PHASE4_RUNBOOK.md](../PHASE4_RUNBOOK.md)（**无 GPU** 约束）。

---

## 6. 历史：stretch 与 Phase 4+

- 原 stretch ≤131 s 未达；更多阶段 Argo 化 / NFS 拓扑优化 **非 Phase 4 阻塞项**
- GPU od-worker：**延后**（集群暂无 GPU）

---

*Phase 3 正式闭合；日常运维见 PHASE3_RUNBOOK。*
