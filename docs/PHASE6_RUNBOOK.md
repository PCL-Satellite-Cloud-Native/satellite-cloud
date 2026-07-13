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

### 2.2 修改 Secret

编辑 `k8s/phase6/minio.yaml` 中 `minio-credentials` 的 `MINIO_ROOT_PASSWORD`（或使用 `kubectl create secret` 覆盖）。

**NFS 目录（Pilot 必做，worker22 / 192.168.10.112）**：

```bash
# 在 NFS 主机 worker22 上（ssh，非 kubectl）
sudo mkdir -p /export/minio-data
sudo chmod 0777 /export/minio-data
```

Pilot 使用静态 PV `minio-data-pv` → `/export/minio-data`（见 `k8s/phase6/minio-pv-pvc.yaml`）。若无 StorageClass，**不要**仅用默认 PVC，否则 Pod 永久 Pending。

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
| PVC `Pending` | 先 apply `minio-pv-pvc.yaml`；NFS 上建 `/export/minio-data` |
| `ImagePullBackOff` | Harbor 确认 `library/minio` / `library/mc` 已 push |
| init Job 失败 | minio Ready 后 `kubectl delete job minio-init-bucket && kubectl apply -k k8s/phase6/` |

**修复 Pending PVC 后重装**

```bash
kubectl -n gitlab-runner delete deployment minio --ignore-not-found
kubectl -n gitlab-runner delete pvc minio-data --ignore-not-found
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

---

*随 P6-04（NFS→MinIO 同步）与 120 Node 扩容持续更新。*
