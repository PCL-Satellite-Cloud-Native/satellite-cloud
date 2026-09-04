# 云原生卫星网络可视化系统

基于 Go + Kubernetes 的卫星可视化与遥感/检测编排系统。

**当前现网**：cluster-120，**60 星 Post-P5 已准出**（任务选星、本星执行、MinIO 预览/检测统计）。

## 先读文档

1. **[docs/SYSTEM_OVERVIEW.md](docs/SYSTEM_OVERVIEW.md)** — 项目做什么、架构、约束、怎么跑  
2. **[docs/DOCUMENTATION_INDEX.md](docs/DOCUMENTATION_INDEX.md)** — 按问题查文档  
3. [docs/archives/2026-07-23_post-p5-60node-closure.md](docs/archives/2026-07-23_post-p5-60node-closure.md) — 准出记录  
4. [docs/decisions/2026-07-24_od-worker-60node.md](docs/decisions/2026-07-24_od-worker-60node.md) — OD 现网策略  

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
├── scripts/      # 巡检与运维脚本
└── docs/         # 系统说明与运维文档
```

## 本地开发

```bash
# 后端
cd backend && go mod download && go run cmd/server/main.go

# 前端
cd frontend && npm install && npm run dev
```

配置见 `backend/.env.example`。集群操作以 `docs/CLUSTER120_*.md` 与 `docs/SYSTEM_OVERVIEW.md` 为准。

## 现网巡检（摘要）

```bash
bash scripts/ops_patrol_60.sh --expect-digest <现网 digest>
```

## 提交规范

Conventional Commits：`feat` / `fix` / `docs` / `refactor` / `test` / `chore` 等。
