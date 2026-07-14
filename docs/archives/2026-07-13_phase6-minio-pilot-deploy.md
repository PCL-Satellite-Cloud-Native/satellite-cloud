# 归档：Phase 6 — MinIO Pilot 首次部署（P6-01）

> **归档日期**：2026-07-13  
> **阶段 / 主题**：MinIO 试点部署、Harbor 镜像、存储/调度/CPU 踩坑  
> **状态**：✅ **P6-01 已签收**（MinIO Running + bucket init）  
> **SSOT**：[PHASE6_RUNBOOK.md](../PHASE6_RUNBOOK.md)  
> **分支**：`feat/phase6-minio`  
> **前置**：[2026-07-09_phase5-plus-closure.md](./2026-07-09_phase5-plus-closure.md)

---

## 1. 摘要

Phase 6 立项后在 pilot 15 节点集群完成 MinIO 试点部署。经历 PVC `local-storage`、NFS 跨节点 CrashLoop、vda disk-pressure Eviction、**x86-64-v2** 镜像不兼容等排查后定稿：**worker22 + vdb hostPath + `-cpuv1` 镜像**。`minio-init-bucket` 创建 `satellite-artifacts` 成功。

---

## 2. 镜像（Harbor / Quay）

| 组件 | Harbor tag | 备注 |
|------|------------|------|
| minio server | `library/minio:RELEASE.2024-01-16T16-07-38Z-cpuv1` | **必须 cpuv1**（Pilot CPU 无 x86-64-v2） |
| mc | `library/mc:RELEASE.2024-01-16T16-06-34Z-cpuv1` | Quay 拉取（Docker Hub TLS 失败） |

---

## 3. 集群凭证

| 项 | 值 |
|----|-----|
| Secret | `gitlab-runner/minio-credentials` |
| `MINIO_ROOT_USER` | `satellite-minio` |
| `MINIO_ROOT_PASSWORD` | 集群 Secret（**不进 Git**） |

---

## 4. 踩坑时间线

| 问题 | 根因 | 定稿 |
|------|------|------|
| PVC Pending | 默认 `local-storage` | 静态 PV |
| FailedMount | NFS export 未建 | worker22 `/export/minio-data` |
| NFS CrashLoop | MinIO 不接受 NFS 客户端 FS | **hostPath 本地盘** |
| Evicted 循环 | vda 85%；数据在系统盘 | **vdb** `/export/remote-sensing-data/minio-data` |
| Pending + Evicted | disk-pressure taint | tolerations + 删 `.vda-bak` 腾 vda |
| CrashLoop `x86-64-v2` | 标准 MinIO 镜像 CPU 要求 | **`-cpuv1`** 镜像 |

---

## 5. 定稿拓扑（2026-07-13 签收）

| 项 | 值 |
|----|-----|
| Pod | `minio-546b66c464-tqdpf` **1/1 Running** @ **k8s-worker22** |
| PV hostPath | `/export/remote-sensing-data/minio-data`（**vdb1 2T**） |
| Service | `minio:9000` / `:9001` |
| Bucket | **`satellite-artifacts`**（init Job ✅） |
| backend 存储 | 默认 **`nfs`**（Phase 5+ 不变） |

---

## 6. 签收命令输出摘要

```text
minio 1/1 Running @ k8s-worker22
Version: RELEASE.2024-01-16T16-07-38Z (go1.21.6 linux/amd64)
job/minio-init-bucket: bucket satellite-artifacts ready
```

---

## 7. 后续归档

P6-03 / P6-04 签收见 [2026-07-14_phase6-storage-sync-api-closure.md](./2026-07-14_phase6-storage-sync-api-closure.md)。

| 编号 | 内容 |
|------|------|
| P6-05 | 120 Node / pilot-map |
| 合并 | `feat/phase6-minio` → `main` |

---

## 8. 代码 / manifest

| 路径 | 说明 |
|------|------|
| `k8s/phase6/minio-pv.yaml` | hostPath@vdb PV（admin 一次性） |
| `k8s/phase6/minio-pvc.yaml` | PVC（CI/kustomize） |
| `k8s/phase6/minio.yaml` | Deployment + Service + init Job（cpuv1） |
| `backend/internal/storage/` | nfs / minio 抽象 |
| `scripts/sync_artifacts_nfs_to_minio.sh` | P6-04 NFS→MinIO mirror |
| `k8s/phase6/minio-artifact-sync-job.yaml` | 同步 Job 模板（参考） |

---

*P6-01 签收：2026-07-13。Phase 5+ rs-worker / NFS 流水线未切换 MinIO。*
