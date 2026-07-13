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
2. Harbor 已镜像：
   - **必须**：`192.168.10.238/library/minio:RELEASE.2024-01-16T16-07-38Z`
   - **可选**：`192.168.10.238/library/mc:...`（init Job 用；拉不到见 §2.1.1）

在 **k8s-repository**（已 pull minio 时）：

```bash
bash scripts/mirror_minio_to_harbor.sh
```

#### 2.1.1 Docker Hub TLS 错误（`x509: certificate is valid for *.facebook.com`）

说明：Docker 走了错误代理/中间人，**不是 MinIO 问题**。`minio/minio` 能 pull 不代表 `mc` 也能；**可跳过 mc 镜像**。

**方案 A — 只 push minio，bucket 用手动脚本（推荐）**

```bash
docker tag minio/minio:RELEASE.2024-01-16T16-07-38Z \
  192.168.10.238/library/minio:RELEASE.2024-01-16T16-07-38Z
docker login 192.168.10.238
docker push 192.168.10.238/library/minio:RELEASE.2024-01-16T16-07-38Z
# 部署后在 k8s-master：bash scripts/minio_init_bucket.sh
```

**方案 B — 离线导入 mc 镜像**

```bash
# 在有正常网络的机器
docker pull minio/mc:RELEASE.2024-01-16T16-07-38Z
docker save minio/mc:RELEASE.2024-01-16T16-07-38Z | gzip > mc-minio.tar.gz
scp mc-minio.tar.gz pcl@k8s-repository:~/
# k8s-repository
docker load < mc-minio.tar.gz
docker tag minio/mc:RELEASE.2024-01-16T16-07-38Z 192.168.10.238/library/mc:RELEASE.2024-01-16T16-07-38Z
docker push 192.168.10.238/library/mc:RELEASE.2024-01-16T16-07-38Z
```

**方案 C — 修复 Docker 代理/CA**：检查 `HTTP_PROXY`、`/etc/docker/daemon.json`、企业根证书。

### 2.2 修改 Secret

编辑 `k8s/phase6/minio.yaml` 中 `minio-credentials` 的 `MINIO_ROOT_PASSWORD`（或使用 `kubectl create secret` 覆盖）。

### 2.3 Apply

```bash
kubectl apply -k k8s/phase6/
kubectl -n gitlab-runner rollout status deployment/minio --timeout=300s
```

**建 bucket**（二选一）：

```bash
# A) init Job（需 Harbor 已有 library/mc）
kubectl -n gitlab-runner wait --for=condition=complete job/minio-init-bucket --timeout=180s

# B) 无 mc 镜像 — k8s-master 手动（推荐）
bash scripts/minio_init_bucket.sh
```

Job 若 ImagePullBackOff：

```bash
kubectl -n gitlab-runner delete job minio-init-bucket --ignore-not-found
bash scripts/minio_init_bucket.sh
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
