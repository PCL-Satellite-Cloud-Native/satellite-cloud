# Phase 2 K8s（od-worker Pilot）

> **前置**：Phase 1 Redis + rs-worker 已部署。  
> **CI**：push `main` 后 `deploy-phase2-pilot` **自动**执行（与 Phase 1 rs-worker 同模式）。  
> **运维 SSOT**：[docs/PHASE2_RUNBOOK.md](../../docs/PHASE2_RUNBOOK.md)

## 部署

```bash
# GitLab Pipeline 自动 deploy-phase2-pilot，或：
kubectl apply -k k8s/phase2/
kubectl apply -k k8s/phase1/
kubectl -n gitlab-runner set image deployment/od-worker od-worker=192.168.10.238/satellite/backend:<SHA>
kubectl -n gitlab-runner set image deployment/rs-worker rs-worker=192.168.10.238/satellite/backend:<SHA>
```

## 回滚

```bash
# rs-worker：apply -k phase1 且 manifest 中 SATELLITE_USE_OD_WORKER=false
kubectl apply -k k8s/phase1/
kubectl -n gitlab-runner scale deployment/od-worker --replicas=0
```
