# Phase 6 Runbook — MinIO 试点 + 存储抽象

> **分支**：`feat/phase6-minio`（不在 `main` 直接开发）  
> **状态**：✅ **Pilot 签收** — P6-01～04 ✅（2026-07-14）；P6-05 待做  
> **前置**：[PHASE5_PLUS_RUNBOOK.md](./PHASE5_PLUS_RUNBOOK.md)（Phase 5+ 已闭合）

---

## 1. 目标与范围

| 编号 | 内容 | 状态 |
|------|------|------|
| P6-01 | MinIO 试点部署（`k8s/phase6/`） | ✅ **已签收** 2026-07-13 |
| P6-02 | `internal/storage` 抽象（nfs 默认 / minio 可选） | ✅ |
| P6-03 | 产物 API 流式下载（MinIO 模式） | ✅ **已签收** 2026-07-14 |
| P6-04 | Worker 仍写 NFS；NFS→MinIO mirror | ✅ **已签收** 2026-07-14 |
| P6-05 | 120 Node / pilot-map 扩展 | ⏸ |

**Pilot 原则**：rs-worker **仍写 NFS**；`satellite-backend` **API 下载** 已试点 MinIO（集群态 2026-07-14）。合并 `main` 前 backend 默认仍可保持 `nfs`，按环境 patch。

---

## 2. 部署 MinIO（k8s-master）

### 2.1 前置

1. Phase 5+ preflight 通过：`bash scripts/phase5_acceptance.sh --preflight-only`
2. Harbor 已镜像（在 **k8s-repository** 或能访问外网的机器执行）：
   - `minio/minio:RELEASE.2024-01-16T16-07-38Z` → Harbor（**Pilot CPU 旧：须 `-cpuv1`**）
   - `minio/mc` **若 Docker Hub TLS 失败**，改用 Quay（见 §2.1.1）

#### 2.1.0 Pilot CPU 较旧（x86-64-v1）

容器日志 `Fatal glibc error: CPU does not support x86-64-v2` → 标准 MinIO 镜像需 **x86-64-v2**，与 `amd64` 标签无关。

**须用 `-cpuv1` 变体**（Quay）：

```bash
docker pull quay.io/minio/minio:RELEASE.2024-01-16T16-07-38Z-cpuv1
docker pull quay.io/minio/mc:RELEASE.2024-01-16T16-06-34Z-cpuv1
# push Harbor tag 见 §2.1.1
```

#### 2.1.1 Docker Hub 拉 mc 失败（x509 / facebook.com 证书）

现象：`docker pull minio/mc:...` 报 `certificate is valid for *.facebook.com ... not registry-1.docker.io` — 内网代理劫持 Docker Hub。

**方案 A — Quay（推荐，Pilot 实测 tag）**

```bash
# k8s-repository
docker pull quay.io/minio/mc:RELEASE.2024-01-16T16-06-34Z

docker tag quay.io/minio/mc:RELEASE.2024-01-16T16-06-34Z \
  192.168.10.238/library/mc:RELEASE.2024-01-16T16-06-34Z-cpuv1
docker login 192.168.10.238
docker push 192.168.10.238/library/mc:RELEASE.2024-01-16T16-06-34Z-cpuv1

# minio server（cpuv1，Pilot 必须）
docker pull quay.io/minio/minio:RELEASE.2024-01-16T16-07-38Z-cpuv1
docker tag quay.io/minio/minio:RELEASE.2024-01-16T16-07-38Z-cpuv1 \
  192.168.10.238/library/minio:RELEASE.2024-01-16T16-07-38Z-cpuv1
docker push 192.168.10.238/library/minio:RELEASE.2024-01-16T16-07-38Z-cpuv1
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
# 勿用 /export/minio-data（落在 vda 系统盘 ~85%，会 Evicted）
sudo mkdir -p /export/remote-sensing-data/minio-data
sudo chmod 0777 /export/remote-sensing-data/minio-data
df -h /export/remote-sensing-data/minio-data   # 应显示 vdb1 ~2T
```

**存储模型（Pilot 定稿）**：MinIO Pod **必须调度在 k8s-worker22**，hostPath 见 `minio-pv.yaml`（**cluster-admin 一次性 apply**，不进 CI）。  
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
# cluster-admin 一次性（CI/gitlab-runner SA 无 PV 权限）
kubectl apply -f k8s/phase6/minio-pv.yaml

# 命名空间资源（CI deploy-phase6-pilot 或 master）
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
| PVC `Pending` + `local-storage` | 确认 PV 已 apply：`kubectl apply -f k8s/phase6/minio-pv.yaml`（admin）；再 apply kustomize |
| `FailedMount` No such file | worker22 建 `/export/minio-data` |
| **CrashLoopBackOff**（NFS 挂载成功） | 改 **hostPath + nodeSelector worker22**（§2.2） |
| **CrashLoop** `x86-64-v2` | 换 **`-cpuv1`** 镜像（§2.1.0） |
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

**preflight 常见 FAIL**

| 现象 | 处理 |
|------|------|
| `Deployment/rs-worker replicas=1（期望 0）` | P5-06b 须保留 Deployment **0/0** + DaemonSet；见下方一键修复 |
| `minio-init-bucket Job 不存在` | Job TTL 清理后正常；bucket 已在 P6-01 创建则 **OK**（新脚本不再 WARN） |

P5-06b 稳态修复（k8s-master）：

```bash
kubectl -n gitlab-runner delete hpa rs-worker --ignore-not-found
kubectl -n gitlab-runner scale deployment/rs-worker --replicas=0
kubectl -n gitlab-runner patch deployment/rs-worker --type=merge -p '{"spec":{"replicas":0}}'
kubectl -n gitlab-runner get deploy rs-worker -o wide
kubectl -n gitlab-runner get ds rs-worker
```

**Console（Web 浏览 bucket）**

与 Grafana `30001`、Prometheus `30090` 相同，经 **NodePort** 访问（manifest：`minio-console-nodeport.yaml`）：

```bash
kubectl apply -f k8s/phase6/minio-console-nodeport.yaml
# 或 kubectl apply -k k8s/phase6/（已含 console Service）
kubectl -n gitlab-runner get svc minio-console
```

浏览器：**http://\<node-ip\>:30901**（例：隧道后 `http://192.168.10.113:30901`）。  
登录：`minio-credentials` Secret 的 `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD`。  
进入 bucket **`satellite-artifacts`** → Object Browser。

备选 port-forward（无 NodePort 时）：

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
**检测产物**：`path` 以 `output_detection/` 开头时须用 `object_detection` 前缀（`rootKeyForObject`，commit `122dcd8`）。

**Backend 镜像路径（Harbor）**：`192.168.10.238/satellite/backend:$CI_COMMIT_SHORT_SHA`（**不是** `library/satellite-backend`）。

### 3.1 签收示例（2026-07-14）

task 217 / artifact 74324：HTTP 200，JPEG 940×640，170,267 bytes。详见 [archives/2026-07-14_phase6-storage-sync-api-closure.md](./archives/2026-07-14_phase6-storage-sync-api-closure.md)。

---

## 4. P6-04 — NFS 产物同步到 MinIO

> Worker / rs-worker **仍写 NFS**；本步骤仅把已有产物 **mirror** 到 MinIO，供 API 试点下载。  
> **勿**在同步完成前把 backend 设为 `SATELLITE_STORAGE_BACKEND=minio`。

### 4.1 对象键映射（与 `internal/storage/minio.go` 一致）

| NFS（PVC `remote-sensing-data` subPath） | MinIO 对象前缀 |
|------------------------------------------|----------------|
| `output_preprocessing/` | `remote_sensing/persist_output_preprocessing/` |
| `object_detection_output/` | `object_detection/output_detection/` |

DB 中 `artifact.Path` 形如 `persist_output_preprocessing/tasks/{id}/...` 或 `output_detection/tasks/{id}/...`，backend 在 minio 模式下会拼成上表右侧键。

### 4.2 执行同步（k8s-master）

```bash
cd ~/code/satellite-cloud   # 或 clone 的仓库路径
bash scripts/sync_artifacts_nfs_to_minio.sh
# 仅 RS 或 OD：--rs-only / --od-only
# 增量重跑：再次执行同名 Job（脚本会先 delete 旧 Job）
```

依赖：MinIO Deployment Ready；PVC `remote-sensing-data` 已 Bound。

### 4.3 验证

```bash
bash scripts/sync_artifacts_nfs_to_minio.sh --verify-only
```

可选：对已知 task 的 artifact 路径做 `mc stat local/satellite-artifacts/remote_sensing/{artifact.Path}`。

### 4.4 启用 API MinIO 下载（同步完成后）

见 §3 patch `satellite-backend` env；curl 下载 artifact 验证 HTTP 200。

### 4.5 签收（2026-07-14）

| 指标 | 值 |
|------|-----|
| `--verify-only` | 298 GiB，19,302 objects |
| RS `tasks/` | 288 GiB，734 objects |

---

## 5. CI

| Job | 说明 |
|-----|------|
| `build-backend` | 含 `minio-go` 依赖 |
| `deploy-phase6-pilot` | manual；apply `k8s/phase6/` + preflight 提示 |
| `sync-artifacts-to-minio` | manual；P6-04 mirror Job |

合并 `main` 前：`phase5_acceptance.sh --preflight-only` 仍必须通过（MinIO 为可选组件）。

---

## 6. 回滚

```bash
kubectl -n gitlab-runner delete -k k8s/phase6/ --ignore-not-found
# backend 移除 SATELLITE_STORAGE_BACKEND=minio 或设为 nfs
```

---

## 7. 相关文档

| 文档 | 说明 |
|------|------|
| [PHASE6_README.md](./PHASE6_README.md) | Phase 6 入口 |
| [archives/2026-07-09_phase5-plus-closure.md](./archives/2026-07-09_phase5-plus-closure.md) | Phase 5+ 收尾 |
| [archives/2026-07-13_phase6-minio-pilot-deploy.md](./archives/2026-07-13_phase6-minio-pilot-deploy.md) | P6-01 MinIO Pilot 部署踩坑与 hostPath 定稿 |
| [archives/2026-07-14_phase6-storage-sync-api-closure.md](./archives/2026-07-14_phase6-storage-sync-api-closure.md) | P6-03/04 同步 + API 下载签收 |
| [archives/2026-07-14_phase6-closure.md](./archives/2026-07-14_phase6-closure.md) | **Phase 6 Pilot 正式收口**（CI、preflight、Console 30901） |

---

*P6-01～04 已闭合（2026-07-14）。60 星现网见 Post-P5 收口与 CLUSTER120 文档。*
