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

# 4) 新提交 1 个锚点任务，完成后用 GET（勿用 curl -sI / HEAD）：
curl -s -o /dev/null -w "%{http_code}\n" \
  "http://192.168.12.67:30080/api/remote-sensing/tasks/<id>/artifacts/<preview_id>"
# 期望：200
```

## 验收记录（2026-07-21～22）

- task **70** `completed` @ sat1；backend MinIO Open OK。
- 首次未自动上传：集群 DS 曾丢失 `SATELLITE_MINIO_ACCESS_KEY/SECRET`（已 apply DS 补回）。
- 存量补传：sat1 rs-worker 内 Python SigV4 PUT（节点拉不了外网 `minio/mc`）。
- 实测：preview `1165` → 200；tile `1996` → 200。
- task **74**：检测图可见但 UI「0 目标」→ `GetDetectionStats` 改为 MinIO Open 后修复。
- task **78**：preview/summary **200**；**tiles=824，dets=1705**（自动上传，无需手工 backfill）。
- 队列：`6067490` 非阻塞 sem；双任务 79/80 @ sat1 均 completed；镜像 digest `9d93de0b…`。

## 存量 task 4/5/6

自动上传仅对新产生的 artifact 生效。存量可用锚点补传（上记 Python/mc）或重跑验收任务。

## 回滚

```bash
kubectl -n gitlab-runner set env deployment/satellite-backend SATELLITE_STORAGE_BACKEND=nfs
kubectl -n gitlab-runner set env ds/rs-worker SATELLITE_ARTIFACT_UPLOAD_MINIO=false
```
