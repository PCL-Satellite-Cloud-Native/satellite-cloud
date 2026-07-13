# Phase 6 Runbook — MinIO 试点 + 存储抽象

> **分支**：`feat/phase6-minio`（不在 `main` 直接开发）  
> **状态**：🚧 **进行中** — P6-01 MinIO 部署 + 存储 backend 抽象  
> **SSOT 方案**：[MICROSERVICES_IMPLEMENTATION_PLAN.md](./MICROSERVICES_IMPLEMENTATION_PLAN.md) §阶段 6  
> **前置**：[PHASE5_PLUS_RUNBOOK.md](./PHASE5_PLUS_RUNBOOK.md)（Phase 5+ 已闭合）

---

## 1. 目标与范围

| 编号 | 内容 | 状态 |
|------|------|------|
| P6-01 | MinIO 试点部署（`k8s/phase6/`） | 🚧 |
| P6-02 | `internal/storage` 抽象（nfs 默认 / minio 可选） | 🚧 |
| P6-03 | 产物 API 流式下载（MinIO 模式） | 🚧 |
| P6-04 | Worker 仍写 NFS；MinIO 同步/upload（后续） | ⏸ |
| P6-05 | 120 Node / pilot-map 扩展 | ⏸ |

**Pilot 原则**：默认 **`SATELLITE_STORAGE_BACKEND=nfs`**，Phase 5+ DaemonSet rs-worker **不受影响**。

---

## 2. 部署 MinIO（k8s-master）

### 2.1 前置

1. Phase 5+ preflight 通过：`bash scripts/phase5_acceptance.sh --preflight-only`
2. Harbor 已镜像（在 **k8s-repository** 或能访问外网的机器执行）：
   - `minio/minio:RELEASE.2024-01-16T16-07-38Z` → `192.168.10.238/library/minio:...`
   - `minio/mc` **若 Docker Hub TLS 失败**，改用 Quay（见 §2.1.1）

#### 2.1.1 Docker Hub 拉 mc 失败（x509 / facebook.com 证书）

现象：`docker pull minio/mc:...` 报 `certificate is valid for *.facebook.com ... not registry-1.docker.io` — 内网代理劫持 Docker Hub。

**方案 A — Quay（推荐，Pilot 实测 tag）**

```bash
# k8s-repository
docker pull quay.io/minio/mc:RELEASE.2024-01-16T16-06-34Z

docker tag quay.io/minio/mc:RELEASE.2024-01-16T16-06-34Z \
  192.168.10.238/library/mc:RELEASE.2024-01-16T16-06-34Z
docker login 192.168.10.238
docker push 192.168.10.238/library/mc:RELEASE.2024-01-16T16-06-34Z
```

**方案 B — 仅 push 已拉到的 minio，bucket 手工创建（可跳过 mc Job）**

```bash
# minio 已成功 pull 时先 push server 镜像
docker tag minio/minio:RELEASE.2024-01-16T16-07-38Z \
  192.168.10.238/library/minio:RELEASE.2024-01-16T16-07-38Z
docker push 192.168.10.238/library/minio:RELEASE.2024-01-16T16-07-38Z

# 部署时跳过 init Job（见 §2.3），Console 手工建 bucket satellite-artifacts
```

**方案 C — 从已有机器 docker save/load**

在能 pull `minio/mc` 的机器上 `docker save`，scp 到 k8s-repository 后 `docker load`，再 tag/push Harbor。

### 2.2 Secret 与 worker22 数据目录

**Secret（不进 Git）**：在 master 写入 `minio-credentials`：

```bash
kubectl -n gitlab-runner create secret generic minio-credentials \
  --from-literal=MINIO_ROOT_USER=satellite-minio \
  --from-literal=MINIO_ROOT_PASSWORD='***' \
  --dry-run=client -o yaml | kubectl apply -f -
```

**worker22 本地目录（必做，须在 vdb 2T 盘内）**：

```bash
# ssh k8s-worker22
# 勿用 /export/minio-data（落在 vda 系统盘 ~85%%，会 Evicted）
sudo mkdir -p /export/remote-sensing-data/minio-data
sudo chmod 0777 /export/remote-sensing-data/minio-data
df -h /export/remote-sensing-data/minio-data   # 应显示 vdb1 ~2T
```

**存储模型（Pilot 定稿）**：MinIO Pod **必须调度在 k8s-worker22**，使用 **hostPath** `/export/minio-data`（`minio-pv-pvc.yaml`）。  
**不要用 NFS PV 挂载到 worker11 等远程节点** — MinIO 会 **CrashLoopBackOff**（要求本地文件系统）。

可选：若需从其它节点备份访问，可保留 `/etc/exports` 中 `/export/minio-data` export；MinIO 进程仍只跑 worker22。

确认 worker22 可调度：

```bash
kubectl get node k8s-worker22
kubectl describe node k8s-worker22 | grep -E "Taints|Unschedulable|Conditions" -A3
```

| 状态 | 处理 |
|------|------|
| `SchedulingDisabled` | `kubectl uncordon k8s-worker22` |
| `disk-pressure` taint | manifest 已含 tolerations；`kubectl apply -f minio.yaml` 重建 Pod |
| 仍 Pending | `kubectl describe pod -l app=minio` 看 Events |

### 2.3 Apply

**完整部署（Harbor 已有 minio + mc）**

```bash
kubectl apply -k k8s/phase6/
kubectl -n gitlab-runner rollout status deployment/minio --timeout=300s
kubectl -n gitlab-runner wait --for=condition=complete job/minio-init-bucket --timeout=180s
```

**rollout 超时排查**

```bash
kubectl -n gitlab-runner get pods -l app=minio -o wide
kubectl -n gitlab-runner describe pod -l app=minio
kubectl -n gitlab-runner describe pvc minio-data
kubectl -n gitlab-runner get events --sort-by='.lastTimestamp' | tail -20
```

| 现象 | 处理 |
|------|------|
| PVC `Pending` + `local-storage` | 删 PVC，apply `minio-pv-pvc.yaml`（hostPath + worker22） |
| `FailedMount` No such file | worker22 建 `/export/minio-data` |
| **CrashLoopBackOff**（NFS 挂载成功） | 改 **hostPath + nodeSelector worker22**（§2.2） |
| **Evicted**（disk-pressure） | MinIO 数据必须在 **vdb**：`/export/remote-sensing-data/minio-data` |
| `ImagePullBackOff` | Harbor 确认 `library/minio` / `library/mc` 已 push |
| Pod **Evicted** on worker22 | 数据目录若在 vda 系统盘 → 改 **vdb** 路径 `/export/remote-sensing-data/minio-data` |
| init Job 失败 | minio Ready 后 `kubectl delete job minio-init-bucket && kubectl apply -k k8s/phase6/` |

**修复 Pending PVC 后重装（含 NFS→hostPath 迁移）**

```bash
kubectl -n gitlab-runner delete deployment minio --ignore-not-found
kubectl -n gitlab-runner delete job minio-init-bucket --ignore-not-found
kubectl -n gitlab-runner delete pvc minio-data --ignore-not-found
kubectl delete pv minio-data-pv --ignore-not-found
kubectl apply -k k8s/phase6/
kubectl -n gitlab-runner rollout status deployment/minio --timeout=300s
```

**仅 minio、无 mc 镜像时（方案 B）**

```bash
# 只 apply Secret/PVC/Deployment/Service，不跑 init Job
kubectl apply -f k8s/phase6/minio.yaml
kubectl -n gitlab-runner delete job minio-init-bucket --ignore-not-found
kubectl -n gitlab-runner rollout status deployment/minio --timeout=300s

# Console 建 bucket（§2.4）
kubectl -n gitlab-runner port-forward svc/minio 9001:9001 &
# 浏览器 http://127.0.0.1:9001 → Buckets → Create → satellite-artifacts
```

### 2.4 验证

```bash
bash scripts/phase6_preflight.sh
# 或跳过 P5：bash scripts/phase6_preflight.sh --skip-p5
```

Console（可选 port-forward）：

```bash
kubectl -n gitlab-runner port-forward svc/minio 9001:9001
# 浏览器 http://127.0.0.1:9001
```

---

## 3. 启用 MinIO 产物下载（API 试点）

> Worker / GDAL 仍读写 NFS；仅 **API 下载** 可走 MinIO（对象已同步时）。

在 `satellite-backend` Deployment 增加 env（**试点时手动 patch，默认不启用**）：

```yaml
- name: SATELLITE_STORAGE_BACKEND
  value: "minio"
- name: SATELLITE_MINIO_ENDPOINT
  value: "minio:9000"
- name: SATELLITE_MINIO_BUCKET
  value: "satellite-artifacts"
- name: SATELLITE_MINIO_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: minio-credentials
      key: MINIO_ROOT_USER
- name: SATELLITE_MINIO_SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: minio-credentials
      key: MINIO_ROOT_PASSWORD
```

对象键约定：`{prefix/}{remote_sensing|object_detection}/{artifact.Path}`（见 `internal/storage/minio.go`）。

---

## 4. CI

| Job | 说明 |
|-----|------|
| `build-backend` | 含 `minio-go` 依赖 |
| `deploy-phase6-pilot` | manual；apply `k8s/phase6/` + preflight 提示 |

合并 `main` 前：`phase5_acceptance.sh --preflight-only` 仍必须通过（MinIO 为可选组件）。

---

## 5. 回滚

```bash
kubectl -n gitlab-runner delete -k k8s/phase6/ --ignore-not-found
# backend 移除 SATELLITE_STORAGE_BACKEND=minio 或设为 nfs
```

---

## 6. 相关文档

| 文档 | 说明 |
|------|------|
| [PHASE6_README.md](./PHASE6_README.md) | 立项与分支策略 |
| [archives/2026-07-09_phase5-plus-closure.md](./archives/2026-07-09_phase5-plus-closure.md) | Phase 5+ 收尾 |
| [archives/2026-07-13_phase6-minio-pilot-deploy.md](./archives/2026-07-13_phase6-minio-pilot-deploy.md) | P6-01 MinIO Pilot 部署踩坑与 hostPath 定稿 |

---

*随 P6-04（NFS→MinIO 同步）与 120 Node 扩容持续更新。*
