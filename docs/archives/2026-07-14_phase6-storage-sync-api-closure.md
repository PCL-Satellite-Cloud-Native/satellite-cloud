# 归档：Phase 6 — NFS 同步 + MinIO API 下载（P6-04 / P6-03）

> **归档日期**：2026-07-14  
> **阶段 / 主题**：NFS→MinIO mirror、backend MinIO 下载试点、对象键修复  
> **状态**：✅ **P6-03 / P6-04 已签收**  
> **SSOT**：[PHASE6_RUNBOOK.md](../PHASE6_RUNBOOK.md)  
> **分支**：`feat/phase6-minio`  
> **前置**：[2026-07-13_phase6-minio-pilot-deploy.md](./2026-07-13_phase6-minio-pilot-deploy.md)（P6-01）

---

## 1. 摘要

P6-01 MinIO 就绪后，完成 NFS 产物 **298 GiB / 19,302 objects** mirror 至 `satellite-artifacts`；`satellite-backend` 启用 `SATELLITE_STORAGE_BACKEND=minio`，API 从 MinIO 流式下载检测瓦片验证通过。rs-worker **仍写 NFS**。

---

## 2. P6-04 同步签收

| 指标 | 值 |
|------|-----|
| Bucket | `satellite-artifacts` |
| 总量 | **298 GiB**，**19,302** objects |
| RS `tasks/` | **288 GiB**，734 objects |
| 脚本 | `scripts/sync_artifacts_nfs_to_minio.sh`（`--verify-only` / `--no-wait`） |

对象键映射：

| NFS subPath | MinIO 前缀 |
|-------------|------------|
| `output_preprocessing/` | `remote_sensing/persist_output_preprocessing/` |
| `object_detection_output/` | `object_detection/output_detection/` |

---

## 3. P6-03 API 下载签收

| 项 | 值 |
|----|-----|
| Backend 镜像 | `192.168.10.238/satellite/backend:87940254`（含 `122dcd8` 对象键修复） |
| Storage | `SATELLITE_STORAGE_BACKEND=minio` |
| 用例 | task **217**，artifact **74324** |
| 结果 | **HTTP 200**，**170,267 bytes**，JPEG 940×640 |

```bash
curl -o /tmp/test.jpg -w "HTTP %{http_code} bytes=%{size_download}\n" \
  "http://127.0.0.1:18080/api/remote-sensing/tasks/217/artifacts/74324"
# HTTP 200 bytes=170267
# JPEG image data, 940x640
```

---

## 4. 踩坑

| 问题 | 根因 | 处理 |
|------|------|------|
| sync Job `wait` 超时 | 大数据 mirror >1h；Job TTL 600s 后消失 | `--no-wait` + `logs -f`；TTL 改为 24h |
| HTTP 500 `NoSuchKey` | 检测产物 path 以 `output_detection/` 开头，误拼 `remote_sensing/` 前缀 | `rootKeyForObject()`（`122dcd8`） |
| backend rollout 失败 | 镜像路径 `library/satellite-backend` 不存在 | 正确路径 **`satellite/backend:$CI_COMMIT_SHORT_SHA`** |
| port-forward 断连 | rollout 后 sandbox 销毁 | `pkill` 旧 forward，换 **18080** 重建 |

---

## 5. 集群态（Pilot 定稿 2026-07-14）

| 组件 | 存储行为 |
|------|----------|
| rs-worker DaemonSet | **NFS**（不变） |
| satellite-backend API 下载 | **MinIO**（试点） |
| 新任务产物 | 先写 NFS；需 **增量 mirror** 方可在 MinIO 下载 |

Backend env（节选）：`SATELLITE_MINIO_ENDPOINT=minio:9000`，凭证来自 `minio-credentials` Secret（**不进 Git**）。

---

## 6. 代码 / 脚本

| 路径 | 说明 |
|------|------|
| `backend/internal/storage/minio.go` | MinIO Open + `rootKeyForObject` |
| `scripts/sync_artifacts_nfs_to_minio.sh` | P6-04 mirror / verify |
| `docs/PHASE6_RUNBOOK.md` §3–§4 | 启用 minio 下载 + 同步 |

---

## 7. 下一步

| 编号 | 内容 |
|------|------|
| 合并 | `feat/phase6-minio` → `main`；PR + `phase6_preflight.sh` |
| 运维 | 新任务后定期 `sync_artifacts_nfs_to_minio.sh` |
| P6-05 | 120 Node / pilot-map 扩展 |

---

*P6-03 / P6-04 签收：2026-07-14。*
