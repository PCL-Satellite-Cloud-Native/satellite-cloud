# 归档：Phase 6 — MinIO Pilot 首次部署（P6-01）

> **归档日期**：2026-07-13  
> **阶段 / 主题**：MinIO 试点部署、Harbor 镜像、PVC/NFS/hostPath 踩坑  
> **状态**：🚧 **进行中** — hostPath@worker22 修复待复验  
> **SSOT**：[PHASE6_RUNBOOK.md](../PHASE6_RUNBOOK.md)  
> **分支**：`feat/phase6-minio`  
> **前置**：[2026-07-09_phase5-plus-closure.md](./2026-07-09_phase5-plus-closure.md)

---

## 1. 摘要

Phase 6 立项后在 pilot 15 节点集群首次部署 MinIO。完成 Harbor 镜像推送（minio server + mc@Quay）、Secret 配置、静态 PV 绑定；排查 PVC `local-storage` Pending、NFS `FailedMount`、远程 NFS 挂载 **CrashLoopBackOff** 三类问题。**定稿**：MinIO 仅调度 **k8s-worker22**，数据卷为 **hostPath `/export/minio-data`**（本地盘，非跨节点 NFS 客户端挂载）。

---

## 2. 镜像（k8s-repository）

| 镜像 | 来源 | Harbor |
|------|------|--------|
| minio server | `minio/minio:RELEASE.2024-01-16T16-07-38Z` | `192.168.10.238/library/minio:...` |
| mc client | `quay.io/minio/mc:RELEASE.2024-01-16T16-06-34Z`（Docker Hub TLS 失败） | `192.168.10.238/library/mc:RELEASE.2024-01-16T16-06-34Z` |

---

## 3. 集群凭证

| 项 | 值 |
|----|-----|
| Secret | `gitlab-runner/minio-credentials` |
| `MINIO_ROOT_USER` | `satellite-minio` |
| `MINIO_ROOT_PASSWORD` | 已写入集群 Secret（**不进 Git**） |

---

## 4. 部署时间线

| 步骤 | 结果 |
|------|------|
| `kubectl apply -k phase6/`（初版 PVC 无 PV） | PVC 绑定 `local-storage`，Pod **Pending** |
| `minio-pv-pvc.yaml`（NFS PV） | PVC **Bound**；Pod 调度 **worker11** |
| worker22 未建 `/export/minio-data` | **FailedMount** `No such file or directory` |
| worker22 建目录 + `/etc/exports` | NFS mount 成功 |
| Pod 启动 | **CrashLoopBackOff**（MinIO 不接受 NFS 客户端文件系统） |
| **定稿修复** | hostPath PV + `nodeSelector: k8s-worker22` |

---

## 5. worker22 NFS export（可选，非 MinIO 进程挂载）

```text
/export/minio-data 192.168.0.0/16(rw,sync,no_subtree_check,no_root_squash)
```

目录：`/export/minio-data`，`chmod 0777`。

---

## 6. 定稿拓扑

| 项 | 值 |
|----|-----|
| Namespace | `gitlab-runner` |
| Deployment | `minio` replicas=1 |
| **nodeSelector** | `kubernetes.io/hostname: k8s-worker22` |
| PV | `minio-data-pv` — hostPath `/export/minio-data` |
| Service | `minio:9000` / `:9001` |
| Bucket | `satellite-artifacts`（init Job 或 Console） |

---

## 7. 待复验（hostPath 修复 apply 后）

```bash
kubectl -n gitlab-runner get pods -l app=minio -o wide   # 期望 worker22, 1/1 Ready
bash scripts/phase6_preflight.sh --skip-p5
kubectl -n gitlab-runner logs job/minio-init-bucket
```

---

## 8. 与 Phase 5+ 关系

- `SATELLITE_STORAGE_BACKEND` 默认 **nfs** — rs-worker DaemonSet / NFS 产物路径 **不变**。
- MinIO 为并行可选组件，P6-04 再做 NFS→MinIO 同步。

---

## 9. 代码 / manifest

| 路径 | 说明 |
|------|------|
| `k8s/phase6/minio-pv-pvc.yaml` | hostPath@worker22 |
| `k8s/phase6/minio.yaml` | Deployment + Service + init Job |
| `backend/internal/storage/` | nfs / minio 抽象 |
| `docs/PHASE6_RUNBOOK.md` | 运维 SSOT |

---

*hostPath 修复 commit 见 `feat/phase6-minio`；复验通过后更新 §7 为 ✅。*
