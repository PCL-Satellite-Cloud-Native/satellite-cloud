# Argo Workflows 安装清单（Phase 3 Pilot）

> **用途**：在 **15 Node / Harbor 192.168.10.238** 环境安装 Argo Workflows Controller，供 `gitlab-runner` 内 rs-worker 提交 PAN RPC 并行 Workflow。  
> **关联**：[PHASE3_RUNBOOK.md](../../docs/PHASE3_RUNBOOK.md) §3、[MICROSERVICES_IMPLEMENTATION_PLAN.md](../../docs/MICROSERVICES_IMPLEMENTATION_PLAN.md) §4。

---

## 0. 版本与范围

> **GitLab CI 前置（集群管理员一次性）**  
> CI 使用的 `gitlab-runner` ServiceAccount **默认无权** 创建 `ServiceAccount` / `ClusterRole`。首次 Phase 3 部署前在 **k8s-master** 执行：
>
> ```bash
> cd ~/code/satellite-cloud
> git pull origin main
> bash scripts/ops/install_argo_crds.sh          # CRD 未装时
> kubectl apply -f k8s/gitlab-runner-ci-rbac-phase3.yaml
> kubectl apply -f k8s/phase1/rs-worker/serviceaccount.yaml
> kubectl apply -f k8s/phase3/argo/rbac/gitlab-runner-workflow-submitter.yaml
> kubectl apply -k k8s/phase3/argo/                # 创建 argo ns + controller（需 root）
> kubectl apply -f k8s/phase3/argo/rbac/controller-clusterrole.yaml
> kubectl apply -f k8s/phase3/argo/gitlab-runner-ci-rbac-argo-ns.yaml
> kubectl apply -k k8s/phase3/
> ```
>
> 之后 `deploy-phase2-pilot` / `deploy-phase3-pilot` 方可正常 apply。

| 项 | 选定值 |
|----|--------|
| Argo Workflows | **v3.5.12**（稳定版；可随 Harbor 镜像 tag 调整） |
| Controller namespace | **`argo`** |
| Workflow 运行 namespace | **`gitlab-runner`**（Pilot，与 rs-worker 同 PVC） |
| 安装方式 | Kustomize `k8s/phase3/argo/`（manifest 待步骤 1 PR 合入） |
| 暂不装 | Argo CD、Argo Events、UI Ingress（可选 §8） |

---

## 1. 镜像入 Harbor（238 或能 pull 外网的机器）

### 1.1 必推镜像

| 上游 | Harbor 目标（示例） |
|------|---------------------|
| `quay.io/argoproj/workflow-controller:v3.5.12` | `192.168.10.238/library/argo-workflow-controller:3.5.12-amd64-r1` |
| `quay.io/argoproj/argoexec:v3.5.12` | `192.168.10.238/library/argoexec:3.5.12-amd64-r1` |

RS step Pod 复用已有 **`satellite/backend:<SHA>`**，无需额外 Argo 业务镜像。

### 1.2 脚本

```bash
export HARBOR=192.168.10.238 HARBOR_USER=admin HARBOR_PASSWORD='***'
export ARGO_VERSION=v3.5.12
bash scripts/ops/mirror_argo_workflows_images.sh
```

### 1.3 验收

```bash
docker pull 192.168.10.238/library/argo-workflow-controller:3.5.12-amd64-r1
docker pull 192.168.10.238/library/argoexec:3.5.12-amd64-r1
```

- [ ] workflow-controller 镜像在 Harbor 可 pull  
- [ ] argoexec 镜像在 Harbor 可 pull  

---

## 2. CRD 与 Controller 安装（k8s-master）

### 2.1 安装

```bash
cd ~/code/satellite-cloud
kubectl apply -k k8s/phase3/argo/
```

等价于（manifest 未合入前可手动一次）：

```bash
# 仅首次：CRD（体积大，单独 apply）
kubectl apply -f k8s/phase3/argo/crd/

# Controller Deployment + SA + ConfigMap
kubectl apply -k k8s/phase3/argo/controller/
```

### 2.2 验收

```bash
kubectl get crd | grep argoproj.io
# 至少：workflows.argoproj.io workflowtemplates.argoproj.io workflowtaskresults.argoproj.io

kubectl -n argo get deploy,po
# workflow-controller   Running

kubectl -n argo logs deploy/workflow-controller --tail=30
# 无 CrashLoop；无 ImagePullBackOff
```

- [ ] CRD 已创建  
- [ ] `workflow-controller` Pod **Running**  
- [ ] Controller 日志无持续报错  

---

## 3. Controller 配置要点

| 配置 | 建议值 | 说明 |
|------|--------|------|
| `workflowNamespaces` | `gitlab-runner` | Pilot 仅允许在该 ns 跑 Workflow |
| `executor` 镜像 | Harbor `argoexec` | 与 mirror 脚本 tag 一致 |
| `parallelism` | `10`（可调） | 集群级最大并行 Workflow 数 |
| `resourceRateLimit` | 可选 | 防 NFS / CPU 被打满 |

ConfigMap 示例键（具体文件见 `k8s/phase3/argo/controller/configmap.yaml`）：

```yaml
containerRuntimeExecutor: emissary
artifactRepository: |
  # Phase 3 Pilot：不用 S3；step 产物走 NFS PVC 挂载，artifact 走 emptyDir
```

- [ ] executor 镜像指向 Harbor  
- [ ] `workflowNamespaces` 含 `gitlab-runner`  

---

## 4. 冒烟 Workflow（不含 RS 业务）

在 `gitlab-runner` 提交最小 Workflow，验证 RBAC + argoexec：

```bash
kubectl -n gitlab-runner apply -f k8s/phase3/argo/examples/hello-workflow.yaml
kubectl -n gitlab-runner wait --for=condition=Completed workflow/hello --timeout=120s
kubectl -n gitlab-runner get workflow hello -o yaml | grep phase
# phase: Succeeded
kubectl -n gitlab-runner delete workflow hello
```

- [ ] hello Workflow **Succeeded**  

---

## 5. RBAC — rs-worker 提交 Workflow

rs-worker 使用的 ServiceAccount（默认 `default` 或专用 SA）需权限：

| 资源 | 动词 |
|------|------|
| `workflows` | create, get, list, watch |
| `workflowtemplates` | get, list |
| `workflowtaskresults` | create, patch, get |

```bash
kubectl apply -f k8s/phase3/argo/rbac/gitlab-runner-workflow-submitter.yaml
```

验证（在 rs-worker Pod 内或临时 debug Pod）：

```bash
kubectl -n gitlab-runner auth can-i create workflows \
  --as=system:serviceaccount:gitlab-runner:default
# yes
```

- [ ] rs-worker SA 可 `create workflows`  

---

## 6. 存储 — 与 rs-worker 对齐

Workflow step Pod 跑 PAN RPC 时需与 rs-worker **相同挂载**：

| 挂载 | 用途 |
|------|------|
| PVC `remote-sensing-data` | input / persist_output / dem / 模型 |
| emptyDir 或 PVC 子路径 | `output_preprocessing` scratch |

Checklist：

- [ ] WorkflowTemplate `volumeClaimTemplates` / `volumes` 与 [rs-worker deployment](../../phase1/rs-worker/deployment.yaml) 一致  
- [ ] initContainer 或 entrypoint 对 scratch 目录 `chmod 0777`（与 Phase 1 相同）  

---

## 7. 与现有 Phase 1/2 共存

| 组件 | Phase 3 安装后 |
|------|----------------|
| Redis / rs-worker / od-worker | **继续运行**，无必须重启 |
| backend | 无变更 |
| Istio | 无必须变更；Workflow Pod 走 cluster 默认网络 |

- [ ] 安装 Argo **未** 影响 task 141 同类任务提交（安装前后各跑一次 smoke 可选）  

---

## 8. 可选 — Argo Server UI

答辩 / 调试可用，**非验收必须**：

```bash
kubectl -n argo port-forward svc/argo-server 2746:2746
# 浏览器 https://localhost:2746 （自签证书）
```

生产建议：暂不暴露；用 `kubectl get workflow` + rs-worker 日志。

- [ ] （可选）UI port-forward 可打开  

---

## 9. 故障排查

| 现象 | 检查 |
|------|------|
| ImagePullBackOff | Harbor 项目 `library`；节点 docker/containerd 登录 |
| Workflow 一直 Pending | `workflow-controller` 日志；`workflowNamespaces`；ResourceQuota |
| step OOM | PAN RPC step 请求 memory 对齐 rs-worker limit |
| CRD 已存在冲突 | 勿重复 apply 不同版本 CRD；先 `kubectl get crd workflows.argoproj.io` 看版本 |
| 无权限 create workflow | §5 RBAC |

---

## 10. 安装完成签字

| 项 | 执行人 | 日期 | 结果 |
|----|--------|------|------|
| §1 镜像 Harbor | | | ☐ |
| §2 Controller Running | | | ☐ |
| §4 hello Workflow | | | ☐ |
| §5 RBAC | | | ☐ |
| §6 存储对齐 | | | ☐ |

**下一步**：按 [PHASE3_RUNBOOK.md](../../docs/PHASE3_RUNBOOK.md) 步骤 2 合入 `WorkflowTemplate` + rs-worker 集成。

---

*清单版本：2026-06-18；随 `k8s/phase3/argo/` manifest 合入更新。*
