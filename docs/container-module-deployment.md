# 容器模块部署流程与部署后架构

> 适用范围：satellite-cloud 仿真平台「容器」模块（任务3 容器编排算法移植效果展示）
> 关联文档：`容器编排分析与算法移植记录.md`（功能/指标/验收说明）

---

## 1. 目标

把「任务3容器编排测试代码」中的三类容器编排算法（扩缩 / 部署调度 / 迁移）接入
satellite-cloud 后端，并在仿真平台主界面「容器」模块中展示其**第四层移植验收指标**：

| 算法 | 第四层验收指标 |
|------|---------------|
| 容器自动扩缩容 (Transformer + MAPPO) | SLA 达成率、资源利用率、扩缩成本、平均奖励 |
| 服务部署调度 (Perception + Tempo + Placement) | 平均时延、平均功率 |
| 容器迁移 (Path-Slots + MAPPO + PRO) | 平均迁移时间 T_m、平均停机时间 T_d |

指标由后端调用 Python 集成脚本真实运行算法得出（`source=realtime`）；
当运行环境缺少算法包/依赖时自动回退到仿真基线（`source=baseline`），保证展示链路始终可用。

---

## 2. 部署后架构

```
┌──────────────────────────────────────────────────────────────────────┐
│  浏览器 / 用户                                                        │
│   访问仿真平台主界面 → 点击「容器」卡片 → /container                   │
└───────────────────────────┬──────────────────────────────────────────┘
                            │ HTTPS
                            ▼
┌──────────────────────────────────────────────────────────────────────┐
│  Ingress / Istio 入口  (k3s 集群)                                     │
└───────────────────────────┬──────────────────────────────────────────┘
                            │ /api  (vite 代理 / 集群内路由)
                            ▼
┌──────────────────────────────────────────────────────────────────────┐
│  frontend  (Deployment: satellite-frontend)                          │
│    src/view/Container.vue  —— ECharts 可视化三算法指标               │
│    src/api/container.js    —— fetch GET /api/container/metrics        │
└───────────────────────────┬──────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────────────┐
│  backend  (Deployment: satellite-backend, 1 副本)                    │
│    internal/api/handlers/container.go  —— ContainerHandler.Metrics    │
│      GET /api/container/metrics                                      │
│        └─ exec.Command("python3", "/app/scripts/container_metrics.py")│
└───────────────────────────┬──────────────────────────────────────────┘
                            │ 子进程
                            ▼
┌──────────────────────────────────────────────────────────────────────┐
│  同一 backend Pod 内的 Python 运行时 (python:3.11-slim, 已装 torch CPU)│
│    /app/scripts/container_metrics.py  —— 集成脚本                    │
│      ├─ /opt/container-algo/container_scaling      → inference_pipeline│
│      ├─ /opt/container-algo/Deployment_test        → main.py --e2e    │
│      └─ /opt/container-algo/Migration_test         → main.py --test    │
│      解析各算法第四层指标 → 打印统一 JSON 到 stdout                   │
└──────────────────────────────────────────────────────────────────────┘
```

**关键点**
- 「容器」模块复用既有的 frontend / backend / Ingress-Istio 链路，不引入新组件。
- 算法推理运行在 **backend Pod 内部**的 Python 运行时中，与既有的 remote-sensing /
  object-detection 的 Python 运行方式一致（镜像已基于 `python:3.11-slim`）。
- 算法源码与训练权重随**后端镜像分发**：由 CI 在构建期克隆到 `backend/container-algo-src`
  并 `COPY` 进镜像的 `/opt/container-algo`（与 `remote-sensing-src` 约定相同，不提交进仓库）。
- 后端通过 `exec` 调用脚本，超时 180s；脚本失败/缺失时后端返回基线指标，前端照常渲染。

---

## 3. 部署前准备

1. **算法源码入库**：在内网 GitLab 新建仓库（如 `root/container-algo.git`），将任务3 的三类
   算法目录原样推送为仓库根目录：
   ```
   container-algo/
   ├── container_scaling/      (含 inference_pipeline.py 与权重)
   ├── Deployment_test/        (含 main.py 与 models/ 权重、data/ 测试集)
   └── Migration_test/         (含 main.py 与 models/ 权重)
   ```
   > 权重（`.pth` / `.pt`）与测试数据（`.parquet` / `.csv`）必须一并入库，否则推理无法运行。
2. **配置 CI 变量**：在 GitLab CI/CD Variables 中设置
   `CONTAINER_ALGO_REPO_URL`（如 `https://192.168.10.238:8444/root/container-algo.git`）。
   留空则镜像仅含基线指标、构建不报错。
3. **构建网络**：构建节点需能拉取 `torch` CPU 版（默认 `--extra-index-url
   https://download.pytorch.org/whl/cpu`）与 pip 包（`numpy/pandas/pyarrow/scikit-learn/gymnasium`）。
   出网恢复或配置内网 pip 镜像后该步骤才能成功。

---

## 4. 完整部署流程

```
[1] 本地开发
    ├─ 前端：src/router/index.js 增 /container 路由
    │        src/components/HomeIndex.vue 增「容器」首页卡片
    │        src/view/Container.vue  (新) 指标可视化页面
    │        src/api/container.js     (新) 接口封装
    ├─ 后端：internal/api/handlers/container.go (新) ContainerHandler
    │        internal/api/handlers/routes.go   注册 GET /api/container/metrics
    │        backend/scripts/container_metrics.py       (新) 算法集成脚本
    └─ 部署：backend/Dockerfile  装 torch CPU + COPY 算法源码/脚本
             k8s/backend/deployment.yaml  增环境变量 + 上调内存
             .gitlab-ci.yml  增 container-algo 克隆步骤
             .gitignore  排除 backend/container-algo-src/

[2] 提交并推送到 GitHub k3s-cluster5 分支
    git add <上述文件> && git commit && git push origin k3s-cluster5

[3] 在 238 拉取 GitHub 代码并推送到内网 GitLab，触发 pipeline
    （使用仓库内 k3s改造方案/mirror-to-gitlab.ps1，或手动：
     238: git pull github k3s-cluster5 → git push gitlab k3s-cluster5）
    → pipeline 执行 build-backend：
        a. CI 克隆 container-algo 到 backend/container-algo-src
        b. docker build：基于 python:3.11-slim，pip 安装 torch(CPU)+算法依赖
           COPY container-algo-src → /opt/container-algo
           COPY scripts/container_metrics.py → /app/scripts
        c. docker push 到 Harbor（192.168.10.238/satellite/backend:latest）

[4] 部署/更新后端
    kubectl -n gitlab-runner apply -f k8s/backend/deployment.yaml
    （触发 backend Pod 滚动更新，加载含算法运行时与源码的新镜像）

[5] 验证
    - 后端：kubectl -n gitlab-runner exec deploy/satellite-backend -- \
        python3 /app/scripts/container_metrics.py   # 应输出 algorithms 数组
    - 接口：curl -s http://<backend-svc>/api/container/metrics | jq '.source'
    - 前端：访问仿真平台 /container，各算法卡片显示 realtime 指标与「实时算法」徽标
```

---

## 5. 验证与排错

| 现象 | 原因 | 处理 |
|------|------|------|
| 前端显示「仿真基线」徽标、`source=fallback` | 算法包/权重缺失或 torch 未装 | 确认 CI 已克隆 `container-algo` 且镜像含 `/opt/container-algo`；进 Pod 手动跑脚本看报错 |
| 构建阶段 `pip install torch` 失败 | 出网未恢复 / pip 源不可达 | 恢复出网或配置内网 pip 镜像；确认 `download.pytorch.org/whl/cpu` 可达 |
| Pod OOM / 重启 | torch + 权重内存占用大 | 已上调 `limits.memory=8Gi`；仍不足继续上调 |
| 首次访问 `/container` 很慢（>30s） | 每次调用都加载模型 | 属预期；如需加速可改为常驻缓存（后续优化） |
| `/api/container/metrics` 返回 500 | 脚本路径/权限问题 | 确认 `CONTAINER_METRICS_SCRIPT=/app/scripts/container_metrics.py` 且 `python3` 在 PATH |

---

## 6. 资源与性能说明

- **镜像体积**：后端镜像因含 python3.11 + torch(CPU) + 算法权重，体积较之前明显增大（预计数 GB），首次推送/拉取较慢。
- **内存**：backend Pod 内存上限已上调至 `8Gi`（请求 `2Gi`），用于 torch 推理与权重常驻。
- **调用时机**：指标为**按需计算**——仅当访问 `/container` 或调用接口时后端才 exec 脚本运行算法；单次调用受 180s 超时约束。
- **实时性**：展示的是「最近一次调用的算法实测指标」，非连续实时监控；如需持续刷新，前端「刷新数据」按钮会重新触发一次计算。
