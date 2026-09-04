# 文档索引

> 当前文档描述 **cluster-120 / 60 星 Post-P5 已准出** 的可运维状态。  
> **先读**：[SYSTEM_OVERVIEW.md](./SYSTEM_OVERVIEW.md)（项目做什么、怎么跑、关键约束）。

---

## 1. 按问题找文档

| 我想… | 打开 |
|--------|------|
| 快速理解整个系统 | [SYSTEM_OVERVIEW.md](./SYSTEM_OVERVIEW.md) |
| 看现网已验收结论 | [archives/2026-07-23_post-p5-60node-closure.md](./archives/2026-07-23_post-p5-60node-closure.md) |
| 60 星部署与操作步骤 | [CLUSTER120_DEPLOY.md](./CLUSTER120_DEPLOY.md)、[CLUSTER120_SAT10_STEPS.md](./CLUSTER120_SAT10_STEPS.md) |
| OD 为何进程内执行 | [decisions/2026-07-24_od-worker-60node.md](./decisions/2026-07-24_od-worker-60node.md) |
| MinIO 产物上传/预览 | [D0_MINIO_ARTIFACT_UPLOAD_60.md](./D0_MINIO_ARTIFACT_UPLOAD_60.md) |
| Deployment env / 挂载 / 排障 | [REMOTE_SENSING_K8S_DEPLOYMENT.md](./REMOTE_SENSING_K8S_DEPLOYMENT.md) |
| 15 节点早期全链路 baseline | [K8S_BASELINE_RUNBOOK.md](./K8S_BASELINE_RUNBOOK.md) |
| RS/OD 仓镜像同步、Runner | [REMOTE_SENSING_REPO_MIRROR.md](./REMOTE_SENSING_REPO_MIRROR.md)、[OBJECT_DETECTION_REPO_MIRROR.md](./OBJECT_DETECTION_REPO_MIRROR.md)、[GITLAB_RUNNER_IMAGE_MIRROR.md](./GITLAB_RUNNER_IMAGE_MIRROR.md) |
| 拓扑 CSV 导入 | [../CI_TOPOLOGY_NFS_SYNC.md](../CI_TOPOLOGY_NFS_SYNC.md)、[../k8s/backend/TOPOLOGY_IMPORT.md](../k8s/backend/TOPOLOGY_IMPORT.md) |
| 历史阶段收口 | [archives/ARCHIVE_INDEX.md](./archives/ARCHIVE_INDEX.md) |

日常巡检：

```bash
bash scripts/ops_patrol_60.sh --expect-digest <现网 digest>
```

---

## 2. 文档分级

| 级别 | 含义 |
|------|------|
| **L1** | 现网事实与强制约束（优先信这个） |
| **L2** | 操作手册与部署步骤 |
| **L3** | 配置、schema、模块参考 |
| **L4** | 历史收口快照（背景；配置以现网为准） |

---

## 3. 文档清单

### L1

| 文档 | 说明 |
|------|------|
| [SYSTEM_OVERVIEW.md](./SYSTEM_OVERVIEW.md) | 系统概览与阅读路径 |
| [archives/2026-07-23_post-p5-60node-closure.md](./archives/2026-07-23_post-p5-60node-closure.md) | Post-P5 准出 |
| [decisions/2026-07-24_od-worker-60node.md](./decisions/2026-07-24_od-worker-60node.md) | OD in-process 冻结 |
| [D0_MINIO_ARTIFACT_UPLOAD_60.md](./D0_MINIO_ARTIFACT_UPLOAD_60.md) | 60 星 MinIO 产物 |

### L2

| 文档 | 说明 |
|------|------|
| [CLUSTER120_DEPLOY.md](./CLUSTER120_DEPLOY.md) | cluster-120 部署与 MinIO 输入 |
| [CLUSTER120_SAT10_STEPS.md](./CLUSTER120_SAT10_STEPS.md) | sat10 操作步骤 |
| [REMOTE_SENSING_K8S_DEPLOYMENT.md](./REMOTE_SENSING_K8S_DEPLOYMENT.md) | env / 卷 / 排障 |
| [K8S_BASELINE_RUNBOOK.md](./K8S_BASELINE_RUNBOOK.md) | 早期 15 节点 1～10 全链路 |
| [PHASE1_RUNBOOK.md](./PHASE1_RUNBOOK.md)～[PHASE6_RUNBOOK.md](./PHASE6_RUNBOOK.md) | 分阶段运维（套用前核对 60 星开关） |
| [PHASE6_README.md](./PHASE6_README.md) | Phase 6（MinIO Pilot）入口 |
| Mirror / Runner 三篇 | 见上表 |

### L3

| 文档 | 说明 |
|------|------|
| [../README.md](../README.md) | 仓库简介与本地启动 |
| `backend/.env.example`、`backend/migrations/` | 本地配置与库表 |

### L4

| 文档 | 说明 |
|------|------|
| [archives/](./archives/) | 各阶段收口快照 |

---

## 4. 维护约定

| 变更类型 | 更新位置 |
|----------|----------|
| 现网行为 / 强制配置 | `SYSTEM_OVERVIEW.md`、`decisions/`、CLUSTER120 文档 |
| 部署与巡检步骤 | CLUSTER120 / Baseline / 相关 Phase runbook |
| 阶段性验收结论 | `archives/` + `ARCHIVE_INDEX.md` |
