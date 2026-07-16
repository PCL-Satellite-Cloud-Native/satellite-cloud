# cluster-120 @ sat10-m1 逐步实施

> 前置：MinIO `satellite-inputs` 已含 topology / dem / models / GF2 input。  
> Pilot **`main`** 不动；120 集群只用 **`cluster-120`** 分支。

---

## 阶段 A — 把 cluster-120 推上 GitLab（238）

`cluster-120` 已在 GitHub；GitLab 需单独 push 或镜像。

### A1. sat10-m1 上（推荐）

```bash
cd ~/code/satellite-cloud

# 若仅有 GitLab origin
git remote -v

# 添加 GitHub 为 upstream（一次性）
git remote add github git@github.com:PCL-Satellite-Cloud-Native/satellite-cloud.git 2>/dev/null || true
git fetch github cluster-120
git checkout -B cluster-120 github/cluster-120

# 推送到 GitLab（按你们实际 URL 改）
git push -u origin cluster-120
# 或：git push -u gitlab cluster-120
```

GitLab 地址示例：`https://192.168.10.238:8444/root/satellite-cloud.git`

### A2. 或 GitLab Web

**Repository → Settings → Repository → Mirroring**，从 GitHub 拉 `cluster-120`（若已配置镜像则 **Update mirror**）。

### A3. 确认

GitLab → **Repository → Branches** 能看到 **`cluster-120`**，且含：

- `frontend/public/data/ephem_60/`
- `scripts/p5_60node_bootstrap.sh`
- `.gitlab-ci.yml` 内 `deploy-cluster-120`

---

## 阶段 B — GitLab CI 变量（一次性）

**Settings → CI/CD → Variables** 添加（与 `minio-credentials` 一致）：

| 变量 | Masked |
|------|--------|
| `MINIO_ROOT_USER` | 可选 |
| `MINIO_ROOT_PASSWORD` | **是** |

已有 `HARBOR_USER` / `HARBOR_PASSWORD` / `REMOTE_SENSING_REPO_URL` 等则不用改。

---

## 阶段 C — Pipeline build

1. GitLab → **cluster-120** → **Run pipeline**（或 push 触发）
2. 等待 **build-backend**、**build-frontend** 成功  
3. Harbor 应有：`satellite/backend:cluster-120-latest`

**不要**点任何 `k8s-cluster-runner` 的 Pilot deploy job。

---

## 阶段 D — hostPath 准备 + MinIO 镜像（sat10-m1）

```bash
cd ~/code/satellite-cloud
git checkout cluster-120 && git pull

# D1. PV/PVC + Secret + pilot-map + 打标（import 可先跳过，见 D2）
bash scripts/p5_60node_bootstrap.sh --skip-import

# D2. MinIO → sat57 hostPath（拓扑 + RS 输入）
bash scripts/p5_60node_mirror_minio_to_hostpath.sh

# D3. 拓扑导入 DB
kubectl -n gitlab-runner delete job import-topology-60 --ignore-not-found
kubectl apply -f k8s/backend/import-topology-job-60.yaml
kubectl -n gitlab-runner wait --for=condition=complete --timeout=600s job/import-topology-60
kubectl -n gitlab-runner logs job/import-topology-60 --tail=20
```

验证 DB（可选）：

```bash
kubectl -n gitlab-runner exec -it satellite-postgres-1 -- psql -U postgres -d satellite -c \
  "SELECT count(*) FROM satellite_delay_edges e JOIN scenarios s ON s.id=e.scenario_id WHERE s.name='Scenario60_3x20';"
```

---

## 阶段 E — GitLab 部署 120 集群

Pipeline **cluster-120** 上手动（顺序）：

1. **sync-inputs-to-minio** — 与 Console 数据对齐（可重复跑，overwrite）
2. **deploy-cluster-120** — backend / frontend / od-worker / rs-worker DS

或 sat10-m1 只看 rollout：

```bash
kubectl -n gitlab-runner rollout status deployment/satellite-backend --timeout=300s
kubectl -n gitlab-runner get ds rs-worker
kubectl -n gitlab-runner get pods -l app=rs-worker --field-selector=status.phase=Running | wc -l
```

backend 首次启动会自动跑 migration **000010**（Scenario60_3x20）。

---

## 阶段 F — 锚点节点 RS 数据（验收前）

P5 锚点 **sat1 / sat21 / sat41** 也需本地 RS 数据（或仅测 preflight 可先跳过 GF2）：

```bash
for host in 192.168.12.11 192.168.12.31 192.168.12.51; do
  ssh root@${host} 'mkdir -p /export/remote-sensing-data/{input,dem,models}'
  # 从 sat57 拉取（示例）
  ssh root@192.168.12.67 "tar -C /export/remote-sensing-data -cf - input dem models" | \
    ssh root@${host} 'tar -C /export/remote-sensing-data -xf -'
done
```

---

## 阶段 G — 验收

```bash
cd ~/code/satellite-cloud
kubectl -n gitlab-runner port-forward svc/satellite-backend 8080:8080 &

CLUSTER_PROFILE=60node MIN_DS_READY=50 \
  bash scripts/phase5_acceptance.sh --preflight-only

CLUSTER_PROFILE=60node MIN_DS_READY=50 \
  bash scripts/phase5_acceptance.sh --run-id p5-60-$(date +%m%d)
```

---

## 故障速查

| 现象 | 处理 |
|------|------|
| Job Pending @ sat10-m1 | CP 污点；Job 应用 **sat57** |
| `minio:9000 connection refused` | `kubectl get pods -l app=minio` 先修 MinIO |
| docker mc `/bin/sh` 错误 | `--entrypoint /bin/sh` |
| import Job 失败 | `ls /export/topology-import/ephem_60 \| wc -l` 应为 60 |
