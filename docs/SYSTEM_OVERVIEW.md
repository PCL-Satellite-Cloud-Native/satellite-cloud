# 系统概览（当前 Baseline · main）

> 本文说明 **项目是什么、Pilot 现网怎么跑、关键组件如何协作**。  
> 详细操作见索引：[DOCUMENTATION_INDEX.md](./DOCUMENTATION_INDEX.md)。  
> **当前准出（本分支）**：15 节点 Pilot，Phase 0～6（含 MinIO 试点）已收口。

---

## 1. 项目是做什么的

本仓库（`satellite-cloud`）是云原生 **卫星网络可视化 + 遥感/检测业务编排** 中心：

| 能力 | 说明 |
|------|------|
| 星座可视化 | Vue + Cesium：场景、卫星、拓扑（时延/路由展示） |
| 遥感流水线 | 任务阶段 **1～9**（预处理/融合等，Python/GDAL） |
| 目标识别 | 阶段 **10**（YOLOv8/ONNX） |
| 多星调度 | 任务可绑定 `satelliteId`，Worker 按节点亲和执行 |
| 产物访问 | 预览、检测统计等；Pilot 上 NFS 写 + MinIO 读试点已签收 |

算法仓（`Satellite-Remote-Sensing` / `Object-Detection`）由 CI 打进 backend 镜像；本仓负责 API、Worker、K8s 与运维文档。

---

## 2. Pilot 现网架构（main）

```text
用户 / 前端 (Vue)
    │
    ▼
satellite-backend (Go API)     namespace: gitlab-runner
    │  写 DB + XADD Redis Stream (rs.jobs)
    ▼
rs-worker（Deployment 或 DaemonSet，按阶段配置）
    │  阶段 1～9；阶段 10 可走 od-worker 或进程内（视开关）
    ▼
产物：NFS / hostPath；API 可读 MinIO（Phase 6 试点）
```

| 组件 | 角色 |
|------|------|
| `satellite-backend` | REST/SSE、入队、产物元数据 |
| Redis Stream | 任务队列 |
| `rs-worker` | 遥感阶段执行 |
| `od-worker` | 独立检测（Pilot 可启用；以现网 env 为准） |
| PostgreSQL | 场景/卫星/任务/拓扑 |
| MinIO | Phase 6 试点对象存储（Console 等见 PHASE6 文档） |
| 前端 | 遥感页、拓扑页、监控入口 |

---

## 3. 业务怎么跑通（最短路径）

1. 确认 Pilot 集群与镜像可用（见 [K8S_BASELINE_RUNBOOK.md](./K8S_BASELINE_RUNBOOK.md)、[PHASE6_RUNBOOK.md](./PHASE6_RUNBOOK.md)）  
2. 创建遥感任务（按需开启检测）  
3. 在 rs-worker / od-worker 日志中跟阶段  
4. 查看预览与检测统计  

环境变量与挂载：[REMOTE_SENSING_K8S_DEPLOYMENT.md](./REMOTE_SENSING_K8S_DEPLOYMENT.md)

---

## 4. 分支与集群对照（事实）

| 分支 / 环境 | 状态 |
|-------------|------|
| **`main`（本文）** | Pilot **15 节点**；Phase 0～6 文档与清单 |
| **`cluster-120`** | **60 星** cluster-120 现网准出与运维文档（另分支维护） |

操作前先确认你连的是哪套集群、哪条分支的清单与地址。

---

## 5. 仓库目录怎么读

| 路径 | 含义 |
|------|------|
| `backend/cmd/server` | API 入口 |
| `backend/cmd/rs-worker` | 遥感 Worker |
| `backend/cmd/od-worker` | 独立 OD Worker |
| `backend/internal/remotesensing` | 阶段流水线 |
| `backend/internal/objectdetection` | 检测调用 |
| `backend/internal/queue` | Redis 队列 |
| `backend/internal/storage` | NFS / MinIO 抽象 |
| `frontend/` | 可视化与遥感 UI |
| `k8s/` | 集群清单（phase1～6） |
| `scripts/` | 运维与验收脚本 |
| `docs/` | 说明与运维文档 |

---

## 6. 文档怎么读（推荐顺序）

1. **本文**  
2. [archives/2026-07-14_phase6-closure.md](./archives/2026-07-14_phase6-closure.md) — Pilot 最近正式收口  
3. [PHASE6_RUNBOOK.md](./PHASE6_RUNBOOK.md) + [PHASE6_README.md](./PHASE6_README.md) — MinIO / 存储  
4. [K8S_BASELINE_RUNBOOK.md](./K8S_BASELINE_RUNBOOK.md) — 1～10 全链路与 CI/NFS  
5. [REMOTE_SENSING_K8S_DEPLOYMENT.md](./REMOTE_SENSING_K8S_DEPLOYMENT.md) — env / 排障  
6. 更早阶段：[archives/ARCHIVE_INDEX.md](./archives/ARCHIVE_INDEX.md)、各 `PHASE*_RUNBOOK.md`

完整索引：[DOCUMENTATION_INDEX.md](./DOCUMENTATION_INDEX.md)
