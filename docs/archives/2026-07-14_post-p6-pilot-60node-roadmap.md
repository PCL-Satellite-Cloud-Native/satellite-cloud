# 归档：Phase 6 后续路线图 — 60 节点新集群 + MinIO 主存储

> **归档日期**：2026-07-14  
> **阶段 / 主题**：P6 Pilot 之后执行计划；60 节点**新集群复制**（非原地扩容）；MinIO 主存储路线  
> **状态**：📋 **已决议，待执行**（新对话 / 新集群开工）  
> **SSOT 方案**：[MICROSERVICES_IMPLEMENTATION_PLAN.md](../MICROSERVICES_IMPLEMENTATION_PLAN.md) §2.2、§阶段 6  
> **Pilot 收口**：[2026-07-14_phase6-closure.md](./2026-07-14_phase6-closure.md)（P6-01～04）  
> **Runbook**：[PHASE6_RUNBOOK.md](../PHASE6_RUNBOOK.md)

---

## 1. 背景与决议摘要

P6-01～04 在 **15 节点 Pilot 集群**已签收：MinIO 部署、存储抽象、NFS mirror、API/Console 读 MinIO 验证通过。**默认写存储仍为 NFS**；MinIO 为试点读路径 + mirror，**不必在 Pilot 上继续专项测试**。

近期目标：**新建 60 节点 K8s 集群**（**复制现有 Pilot 配置**，**非**将 15 节点原地扩至 60）。战略上 **产物主存储迁移至 MinIO** 与 SSOT 一致，但 **不在 Pilot 上「只改 env 一刀切」**——须 **MinIO 生产化 + Worker 直写** 同步完成。

**P6-05（120 逻辑星 / pilot-map）延后**，待 60 节点 + MinIO 主存储稳态后再做。Phase 6 **总归档**在 P6-05 与压测完成后进行。

---

## 2. 当前 Pilot（15 Node）定稿态 — 复制源

| 项 | 值 |
|----|-----|
| 集群 | Pilot **15 Node**（**保留**，作参考 / 对照） |
| 写存储 | **NFS**（rs-worker / od-worker / Argo） |
| 读存储（API） | Pilot 上 **手工 patch** `SATELLITE_STORAGE_BACKEND=minio` |
| MinIO | 单 Pod @ worker22；Console **NodePort 30901**；bucket `satellite-artifacts` |
| mirror | `scripts/sync_artifacts_nfs_to_minio.sh`（298 GiB 已签收） |
| 代码默认 | `SATELLITE_STORAGE_BACKEND` 未设 → **nfs**（`config.go`） |
| Git manifest | `k8s/backend/deployment.yaml` **无** minio env |
| rs-worker | DaemonSet 15/15；Deployment 0/0（P5-06b） |

**复制到新集群时携带**：manifest、脚本、Harbor 镜像策略、Phase 1～6 Runbook 流程；**MinIO pilot 单点 hostPath 方案仅作参考，60 节点须重新设计**。

---

## 3. 关键架构决策（2026-07-14）

| # | 决策 | 说明 |
|---|------|------|
| D1 | **新集群 60 节点**，非原地扩容 | 从 Pilot **复制**部署与配置到新环境；Pilot 可继续运行或只读参考 |
| D2 | **战略上 MinIO 为主存储** | 符合 SSOT「并行压测 / 第三方测试前引入 MinIO」 |
| D3 | **不在 Pilot 上立即切换主存储** | `storage` 抽象仅 **API 下载**；Worker **仍写 NFS 路径** |
| D4 | **禁止仅改 backend env** | 不解决 60 节点 NFS 写瓶颈；须 Worker **scratch → upload MinIO** |
| D5 | **P6-05 延后** | 120 逻辑星 / 前端高亮 → 60 节点 + MinIO 主存储稳定后 |
| D6 | **Pilot MinIO 测试可停止** | Console 下载成功即足够；默认 nfs 下无需重复 API 测试 |

---

## 4. 三阶段执行计划

### 阶段 1 — 60 节点新集群基础设施（优先）

**目标**：新集群就绪，算力与存储底座可承载生产负载。

| 任务 | 内容 |
|------|------|
| 1.1 | **新建 60 节点 K8s**；自 Pilot **复制** namespace、Deployment、DaemonSet、CI、Harbor、NFS/MinIO 策略 |
| 1.2 | **MinIO 生产化**（与 Pilot 单点分离）：多副本/分布式或专用节点 + 独立盘；容量规划（≥ 现有 298GiB + 增长） |
| 1.3 | **NFS 短期保留**：输入影像、DEM、模型等读多写少数据 |
| 1.4 | 节点标签 `satellite.io/id`、rs-worker DaemonSet、Redis、Argo、监控（30001/30090） |
| 1.5 | MinIO Console NodePort（如 **30901**）与内网隧道访问 |
| 1.6 | 验收：`phase5_acceptance.sh --preflight-only`、`phase6_preflight.sh` |

**本阶段不做**：Worker 改 MinIO 写路径；P6-05 120 逻辑星。

**参考文档**：[K8S_BASELINE_RUNBOOK.md](../K8S_BASELINE_RUNBOOK.md)、[REMOTE_SENSING_BASELINE_MIGRATION_RUNBOOK.md](../REMOTE_SENSING_BASELINE_MIGRATION_RUNBOOK.md)、[PHASE6_RUNBOOK.md](../PHASE6_RUNBOOK.md)

---

### 阶段 2 — MinIO 成为产物主存储（核心）

**目标**：新 task 产物 **直写 MinIO**；消除 mirror 延迟与 NFS 写瓶颈。

| 任务 | 内容 |
|------|------|
| 2.1 | 扩展 `internal/storage`：`Put` / 任务级 bulk upload |
| 2.2 | rs-worker / od-worker / Argo：**本地 scratch（emptyDir）跑 GDAL → 完成后 upload MinIO** |
| 2.3 | `k8s/backend/deployment.yaml` 固化 `SATELLITE_STORAGE_BACKEND=minio` 及 MinIO 凭证 |
| 2.4 | 历史数据：Pilot 已 mirror 部分可 **一次性导入新 MinIO**；新任务 **不依赖** `sync_artifacts_nfs_to_minio.sh` |
| 2.5 | 过渡期（可选）：MinIO 优先读、NFS 回退；mirror 脚本改为 **对账 / 补历史** |
| 2.6 | 分支建议：`feat/minio-primary-write` |

**验收**：新提交 task → **不跑 mirror** → API + Console **直接**可下载产物。

**对象键约定**（不变）：见 `internal/storage/minio.go`、`rootKeyForObject`（`122dcd8`）。

---

### 阶段 3 — 60 节点稳态后（延后）

| 任务 | 内容 |
|------|------|
| 3.1 | **P6-05**：120 逻辑星 / `pilot-map` / 前端高亮（60 物理机承载 120 逻辑星） |
| 3.2 | 并行压测 / 第三方测试（P50/P95） |
| 3.3 | HPA / Argo parallelism 按 60 节点上调 |
| 3.4 | **Phase 6 总归档**（含 P6-05） |
| 3.5 | 可选：NFS 仅留输入卷；长期 Ceph 评估（SSOT §2.2） |

---

## 5. 不建议的路径

| 做法 | 原因 |
|------|------|
| Pilot 15→60 **原地扩容** | 已决议改为 **新集群复制** |
| 仅 patch backend `minio` | Worker 仍写 NFS，60 节点瓶颈未解 |
| 停 NFS、全靠 mirror | 双份存储、延迟、运维负担 |
| 继续 Pilot 上 MinIO 专项测试 | P6-01～04 已签收；Console 下载成功即可 |
| 阶段 1 未完成即做 P6-05 | 依赖 60 节点与存储底座 |

---

## 6. 新集群复制检查清单（开工用）

```text
[ ] 60 节点 K8s 安装与网络（与 Pilot 机房/交换机规划对齐）
[ ] Harbor / 镜像（含 minio -cpuv1、backend、rs-worker）
[ ] gitlab-runner + CI RBAC（phase3～6）
[ ] NFS：remote-sensing-data PVC + 输入/DEM/模型数据迁移或挂载
[ ] MinIO：生产 manifest（非 worker22 单点 hostPath 照搬）
[ ] PV minio-data：admin 一次性 apply + PVC Bound
[ ] Phase 1～5+ 组件：Redis、rs-worker DS、od-worker、Argo
[ ] backend、frontend（30080）、Grafana（30001）、Prometheus（30090）
[ ] phase5_acceptance + phase6_preflight 通过
[ ] 决定是否从 Pilot **导入** MinIO 对象 / NFS 产物子集
```

---

## 7. Pilot 集群后续（可选）

| 选项 | 说明 |
|------|------|
| 保持运行 | 开发/对照环境；默认 nfs + 按需 mirror |
| 只读参考 | 新集群稳定后减少任务提交 |
| 数据 | 历史 task/产物可择要迁移至新 MinIO |

---

## 8. 相关代码与文档

| 路径 | 用途 |
|------|------|
| `backend/internal/storage/` | NFS/MinIO 抽象（待扩展 Write） |
| `scripts/sync_artifacts_nfs_to_minio.sh` | 阶段 2 前 bridge；之后对账 |
| `k8s/phase6/` | MinIO + console NodePort |
| `backend/internal/pilotcluster/pilot-map.json` | P6-05 扩展（延后） |
| [PHASE6_README.md](../PHASE6_README.md) | Phase 6 入口（见 §后续路线图） |

---

## 9. 版本记录

| 日期 | 说明 |
|------|------|
| 2026-07-14 | 决议归档：60 节点**新集群复制**、MinIO 主存储三阶段、P6-05 延后 |

---

*本文件为路线图快照；执行进度在新对话 / 新归档中更新。Phase 6 总归档待阶段 3 完成。*
