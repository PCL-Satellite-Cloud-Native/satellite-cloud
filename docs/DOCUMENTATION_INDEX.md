# 文档索引

> 当前文档描述 **`main` / Pilot 15 节点** 已准出可运维状态（Phase 0～6）。  
> **先读**：[SYSTEM_OVERVIEW.md](./SYSTEM_OVERVIEW.md)。

---

## 1. 按问题找文档

| 我想… | 打开 |
|--------|------|
| 快速理解整个系统 | [SYSTEM_OVERVIEW.md](./SYSTEM_OVERVIEW.md) |
| Pilot Phase 6（MinIO）收口 | [archives/2026-07-14_phase6-closure.md](./archives/2026-07-14_phase6-closure.md) |
| MinIO / 存储操作 | [PHASE6_README.md](./PHASE6_README.md)、[PHASE6_RUNBOOK.md](./PHASE6_RUNBOOK.md) |
| 1～10 全链路 baseline | [K8S_BASELINE_RUNBOOK.md](./K8S_BASELINE_RUNBOOK.md) |
| Deployment env / 挂载 / 排障 | [REMOTE_SENSING_K8S_DEPLOYMENT.md](./REMOTE_SENSING_K8S_DEPLOYMENT.md) |
| RS/OD 仓镜像同步、Runner | [REMOTE_SENSING_REPO_MIRROR.md](./REMOTE_SENSING_REPO_MIRROR.md)、[OBJECT_DETECTION_REPO_MIRROR.md](./OBJECT_DETECTION_REPO_MIRROR.md)、[GITLAB_RUNNER_IMAGE_MIRROR.md](./GITLAB_RUNNER_IMAGE_MIRROR.md) |
| 拓扑 CSV 导入 | [../CI_TOPOLOGY_NFS_SYNC.md](../CI_TOPOLOGY_NFS_SYNC.md)、[../k8s/backend/TOPOLOGY_IMPORT.md](../k8s/backend/TOPOLOGY_IMPORT.md) |
| 历史阶段收口 | [archives/ARCHIVE_INDEX.md](./archives/ARCHIVE_INDEX.md) |

---

## 2. 文档分级

| 级别 | 含义 |
|------|------|
| **L1** | 现网事实与系统说明（优先） |
| **L2** | 操作手册与部署步骤 |
| **L3** | 配置、schema、模块参考 |
| **L4** | 历史收口快照 |

---

## 3. 文档清单

### L1

| 文档 | 说明 |
|------|------|
| [SYSTEM_OVERVIEW.md](./SYSTEM_OVERVIEW.md) | 系统概览与阅读路径 |
| [archives/2026-07-14_phase6-closure.md](./archives/2026-07-14_phase6-closure.md) | Phase 6 Pilot 正式收口 |

### L2

| 文档 | 说明 |
|------|------|
| [K8S_BASELINE_RUNBOOK.md](./K8S_BASELINE_RUNBOOK.md) | 1～10 全链路与 CI/NFS |
| [REMOTE_SENSING_K8S_DEPLOYMENT.md](./REMOTE_SENSING_K8S_DEPLOYMENT.md) | env / 卷 / 排障 |
| [PHASE1_RUNBOOK.md](./PHASE1_RUNBOOK.md)～[PHASE6_RUNBOOK.md](./PHASE6_RUNBOOK.md) | 分阶段运维 |
| [PHASE6_README.md](./PHASE6_README.md) | Phase 6 入口 |
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
| 系统说明 / 现网行为 | `SYSTEM_OVERVIEW.md` |
| 部署与巡检 | Baseline / Phase runbook |
| 阶段性验收结论 | `archives/` + `ARCHIVE_INDEX.md` |
