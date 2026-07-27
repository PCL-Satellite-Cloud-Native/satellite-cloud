# 云原生卫星网络可视化系统

基于 Go + Kubernetes 的卫星可视化与遥感/检测编排系统。

**当前分支（`main`）**：Pilot **15 节点**，Phase 0～6（含 MinIO 试点）已准出可运维。

## 先读文档

1. **[docs/SYSTEM_OVERVIEW.md](docs/SYSTEM_OVERVIEW.md)** — 项目做什么、架构、怎么跑  
2. **[docs/DOCUMENTATION_INDEX.md](docs/DOCUMENTATION_INDEX.md)** — 按问题查文档  
3. [docs/archives/2026-07-14_phase6-closure.md](docs/archives/2026-07-14_phase6-closure.md) — Phase 6 Pilot 收口  
4. [docs/PHASE6_RUNBOOK.md](docs/PHASE6_RUNBOOK.md) — MinIO / 存储操作  

> 60 星 cluster-120 现网文档在分支 **`cluster-120`** 维护。

## 技术栈

- **后端**：Go、Gin、GORM、PostgreSQL、Redis  
- **前端**：Vue.js 3、Vite、Cesium  
- **基础设施**：Kubernetes、Docker、GitLab CI/CD、MinIO  

## 仓库结构

```text
satellite-cloud/
├── backend/      # API、rs-worker、od-worker
├── frontend/     # 可视化与遥感 UI
├── k8s/          # 集群清单
├── scripts/      # 运维与验收脚本
└── docs/         # 系统说明与运维文档
```

## 本地开发

```bash
# 后端
cd backend && go mod download && go run cmd/server/main.go

# 前端
cd frontend && npm install && npm run dev
```

配置见 `backend/.env.example`。集群操作以 `docs/SYSTEM_OVERVIEW.md` 与 Phase / Baseline runbook 为准。

## 提交规范

Conventional Commits：`feat` / `fix` / `docs` / `refactor` / `test` / `chore` 等。
