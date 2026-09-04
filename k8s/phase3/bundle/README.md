# Phase 3 手动安装包（k8s-master 无 git 仓库）

> 适用：`/home/pcl/code` 不是完整 `satellite-cloud` 仓库，只能 scp 文件到 master 执行。

## 文件

| 文件 | 用途 |
|------|------|
| `phase3-manual-install.yaml` | argo ns + controller + RBAC（不含 WorkflowTemplate） |
| `../workflows/workflowtemplate-pan-rpc.yaml` | PAN RPC 模板（**唯一 SSOT**，与 CI `kubectl apply -k k8s/phase3/` 相同） |
| `gitlab-runner-workflow-executor.yaml` | Workflow step Pod SA + pod patch RBAC |
| `hello-workflow.yaml` | 冒烟 Workflow |

## 用法（k8s-master）

```bash
# 1) scp bundle 下 yaml + workflows/workflowtemplate-pan-rpc.yaml 到 master

# 2) 前置：CRD 已装；rs-worker SA 已存在

# 3) 安装（若 controller 已 apply 成功可跳过第一步）
kubectl apply -f phase3-manual-install.yaml
kubectl apply -f gitlab-runner-workflow-executor.yaml
kubectl apply -f workflowtemplate-pan-rpc.yaml   # 即仓库 k8s/phase3/workflows/ 下同名文件
kubectl -n argo rollout status deployment/workflow-controller --timeout=180s

# 4) 验收
kubectl -n argo get deploy,pod
kubectl -n gitlab-runner get workflowtemplate rs-pan-rpc-parallel

# 5) 冒烟
kubectl -n gitlab-runner create -f hello-workflow.yaml
kubectl -n gitlab-runner get workflow -w
```

## 长期建议

在 k8s-master clone 内网 GitLab 仓库，与 CI manifest 保持一致：

```bash
git clone <内网 GitLab satellite-cloud URL> /home/pcl/code/satellite-cloud
cd /home/pcl/code/satellite-cloud && git pull origin main
kubectl apply -k k8s/phase3/argo/
kubectl apply -k k8s/phase3/
```
