# Phase 1 K8s（Redis + rs-worker Pilot）

> **namespace**：`gitlab-runner`（与 backend 同 ns，共享 PVC/Secret）。  
> **backend Redis 入队**：已固化在 [`k8s/backend/deployment.yaml`](../backend/deployment.yaml)。  
> **运维 SSOT**：[docs/PHASE1_RUNBOOK.md](../../docs/PHASE1_RUNBOOK.md)

## 部署

```bash
# GitLab Pipeline 手动 job deploy-phase1-pilot，或：
kubectl apply -k k8s/phase1/
kubectl -n gitlab-runner set image deployment/rs-worker rs-worker=192.168.10.238/satellite/backend:<SHA>
```

## 验收

```bash
kubectl -n gitlab-runner get pod -l 'app in (redis,rs-worker)'
kubectl -n gitlab-runner exec deploy/redis -- redis-cli ping
kubectl -n gitlab-runner logs deploy/rs-worker --tail=15
```

## 回滚 rs-worker

```bash
kubectl -n gitlab-runner scale deployment/rs-worker --replicas=0
# backend 回滚见 PHASE1_RUNBOOK §5
```
