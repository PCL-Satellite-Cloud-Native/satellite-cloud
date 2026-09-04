# 决策：60 节点 OD 执行路径（N4 / Post-P5）

> **状态**：**已冻结**（2026-07-24）  
> **集群**：120 节点 / `Scenario60_3x20` / namespace `gitlab-runner`  
> **相关**：P5 准出、D0 MinIO、本星队列

---

## 决策（一句话）

**60 节点长期默认：OD 在锚点 `rs-worker` 进程内执行**（`SATELLITE_USE_OD_WORKER=false`），**`od-worker` Deployment 保持 `replicas=0`**。  
不采用「中心 PVC + 独立 od-worker」作为 60 节点主路径。

---

## 为什么

| 事实 | 含义 |
|------|------|
| 融合产物在锚点 **hostPath**（sat1/sat21/sat41） | sat57 上 PVC 的 od-worker **读不到** `.dat` |
| P5 / Post-P5 已用 in-process OD 验收通过 | 再拆 od-worker 无新能力，只增加调度与存储复杂度 |
| D0 已把预览/检测统计走 MinIO | 读侧不依赖 od-worker 落点；写侧仍在本星 rs-worker |

历史失败模式（勿回退）：

1. `USE_OD_WORKER=true` + od-worker@sat57 → 阶段 10「输入不存在」  
2. 扩大 od-worker 副本但不解决 hostPath → 同样失败  

---

## 现网强制配置

```bash
# rs-worker DS（及任何会跑阶段 10 的进程）
SATELLITE_USE_OD_WORKER=false
SATELLITE_USE_ARGO_PAN_RPC=false

# od-worker 必须为 0
kubectl -n gitlab-runner scale deployment/od-worker --replicas=0
```

Manifest 参考：`k8s/phase5/rs-worker-daemonset-60.yaml`（已注释说明原因）。

巡检：`scripts/ops_patrol_60.sh` / `phase5_verify_metrics_60.sh` 会提示 od-worker≠0。

---

## 何时可以重新评估（退出条件）

仅当**同时**满足时，才开「独立 od-worker」专项：

1. **数据面**：锚点融合产物对 od-worker 可读（例如每锚点 hostPath DS、或统一对象存储输入且路径约定清晰）  
2. **调度**：本星感知队列同样约束 OD job（避免跨星抢任务）  
3. **业务驱动**：需要独立扩缩 OD、与 RS 解耦资源（CPU/GPU）  

在此之前：**不**把 Pilot 的 `deploy-phase2` / od-worker 自动扩副本套到 60 节点。

可选远期形态（未实施）：

| 方案 | 说明 | 风险 |
|------|------|------|
| A. 维持 in-process（**当前**） | 简单、与 hostPath 一致 | RS/OD 争用同一 Pod 资源 |
| B. od-worker DaemonSet + hostPath | 每节点独立 OD 容器 | 运维面翻倍；须本星队列 |
| C. OD 只读 MinIO 融合对象 | 与 D0 对齐 | 需改流水线上传融合大文件 + 延迟 |

---

## Pilot vs 60 节点

| | Pilot | 60 节点 |
|--|-------|---------|
| 融合存储 | 常为共享 PVC/NFS | 锚点 hostPath |
| `USE_OD_WORKER` | 可为 true（Phase 2） | **必须 false** |
| `od-worker` replicas | 可 >0 | **必须 0** |

CI / 文档提到 `deploy-phase2` 时，**不得**无条件应用到 cluster-120 60 节点配置。

---

## 验收（决策落地）

- [x] 本文件入库并挂到 Post-P5 next / 运维一页纸  
- [x] 现网 `USE_OD_WORKER=false`、od-worker=0（P5/Post-P5 已验证）  
- [ ] （可选）UI 冒烟一单 847：OD 仍在 sat1 rs-worker 完成
