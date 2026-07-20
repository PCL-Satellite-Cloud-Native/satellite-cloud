# D0 — 60 节点产物上传 MinIO（前端 artifact 可读）

> 依赖：P5 收口；MinIO `satellite-artifacts` bucket；`minio-credentials` Secret。  
> 代码：`storage.Backend.Put` + `SATELLITE_ARTIFACT_UPLOAD_MINIO`（rs-worker）+ backend `SATELLITE_STORAGE_BACKEND=minio`。

## 行为

| 组件 | 写盘 | 读产物 |
|------|------|--------|
| rs-worker | hostPath（流水线不变） | — |
| rs-worker | Put 预览/检测图 → MinIO | — |
| backend | — | Open from MinIO |

上传类型：`preview` / `detection_preview` / `detection_tile` / `detection_summary`（跳过 fusion `.dat`）。

对象键：与 Phase 6 一致 — `remote_sensing/{artifact.Path}` 或 `object_detection/{artifact.Path}`。

## 部署（sat10-m1）

```bash
cd ~/code/satellite-cloud
git pull origin cluster-120

# 1) 确保 bucket
kubectl -n gitlab-runner get secret minio-credentials
# Console 30901 或 mc：mb local/satellite-artifacts

# 2) backend 读 MinIO
kubectl -n gitlab-runner patch deployment satellite-backend --type strategic \
  --patch-file k8s/phase5/backend-minio-artifact-patch.yaml
kubectl -n gitlab-runner rollout status deployment/satellite-backend --timeout=300s

# 3) rs-worker 上传（apply DS 或 set env）
kubectl apply -f k8s/phase5/rs-worker-daemonset-60.yaml
# 保留已有 USE_OD_WORKER=false / USE_ARGO_PAN_RPC=false
kubectl -n gitlab-runner set env ds/rs-worker \
  SATELLITE_USE_OD_WORKER=false \
  SATELLITE_USE_ARGO_PAN_RPC=false
kubectl -n gitlab-runner rollout status ds/rs-worker --timeout=600s

# 4) 新提交 1 个锚点任务，完成后：
curl -sI "http://192.168.12.67:30080/api/remote-sensing/tasks/<id>/artifacts/<preview_id>"
# 期望：HTTP 200（非 404）
```

## 存量 task 4/5/6

自动上传仅对新产生的 artifact 生效。存量可用锚点 `mc cp` 按 Phase 6 键约定上传，或重跑验收任务。

## 回滚

```bash
kubectl -n gitlab-runner set env deployment/satellite-backend SATELLITE_STORAGE_BACKEND=nfs
kubectl -n gitlab-runner set env ds/rs-worker SATELLITE_ARTIFACT_UPLOAD_MINIO=false
```
