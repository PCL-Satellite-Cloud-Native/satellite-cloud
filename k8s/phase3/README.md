# Phase 3 K8s（Argo Workflows Pilot）

> **SSOT**：[docs/PHASE3_RUNBOOK.md](../../docs/PHASE3_RUNBOOK.md)  
> **Argo 安装**：[argo/INSTALL_CHECKLIST.md](./argo/INSTALL_CHECKLIST.md)

## 目录

```text
k8s/phase3/
  kustomization.yaml              … WorkflowTemplate
  workflows/workflowtemplate-pan-rpc.yaml
  argo/
    kustomization.yaml            … namespace + controller + RBAC
    namespace.yaml
    controller/                   … Harbor 镜像 controller
    rbac/
    examples/hello-workflow.yaml
```

## 部署（分支 feat/phase3-argo-pan-rpc）

```bash
# CRD 若未装（一次性）
bash scripts/ops/install_argo_crds.sh

# Controller + RBAC + Template
kubectl apply -k k8s/phase3/argo/
kubectl apply -k k8s/phase3/
kubectl apply -f k8s/phase3/argo/rbac/gitlab-runner-workflow-submitter.yaml
kubectl apply -k k8s/phase1/

# 冒烟
kubectl -n gitlab-runner create -f k8s/phase3/argo/examples/hello-workflow.yaml
kubectl -n gitlab-runner wait --for=condition=Completed workflow -l workflows.argoproj.io/workflow --timeout=120s

# 启用 Argo PAN RPC（验收 P3-03 前）
kubectl -n gitlab-runner set env deployment/rs-worker SATELLITE_USE_ARGO_PAN_RPC=true
kubectl -n gitlab-runner set env deployment/rs-worker SATELLITE_RS_WORKFLOW_IMAGE=192.168.10.238/satellite/backend:<SHA>
```

GitLab：Pipeline 手动 **`deploy-phase3-pilot`**
