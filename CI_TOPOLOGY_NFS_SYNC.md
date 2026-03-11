## 拓扑 CSV 自动同步到 NFS + CI 中自动导入方案（GitLab CI）

本文档设计一套**完全由 GitLab CI 驱动**的拓扑数据导入流程，目标是：

- **每次主分支流水线成功构建后**，自动把仓库里的 CSV 同步到 NFS；
- 然后由 CI 触发 K8s Job（或直接在集群内运行 `import_topology`），把 delay/T0/router 数据导入数据库。

假设前置（如果尚未完成，见下一节「零、NFS + PV/PVC 创建步骤」）：

- NFS Server：`k8s-worker22`
- NFS Export Path：`/export/topology-data`
- K8s Namespace：`gitlab-runner`
- 已在集群中创建好 `topology-data` PV/PVC，挂载到 `/export/topology-data`
- CI Runner 已能在 `deploy` 阶段调用 `kubectl`（见当前 `.gitlab-ci.yml` 的 `deploy` job）

---

## 零、NFS + PV/PVC 创建步骤（一次性操作）

> 这部分只需在首次接入拓扑导入时执行一遍，后续只要 NFS 不变、PV/PVC 不调整就无需重复。

### 0.1 在 `k8s-worker22` 上准备 NFS 导出目录

1. 创建导出目录并设置权限（示例）：

   ```bash
   sudo mkdir -p /export/topology-data
   sudo chown -R nobody:nogroup /export/topology-data || true
   sudo chmod -R 0777 /export/topology-data
   ```

2. 确认 NFS 服务已安装并启动（命令因发行版不同略有差异）：

   ```bash
   # 例如 Ubuntu/Debian：
   sudo apt-get install -y nfs-kernel-server
   sudo systemctl enable --now nfs-kernel-server
   ```

3. 在 `/etc/exports` 中增加一行（根据你集群网段调整）：

   ```bash
   /export/topology-data 192.168.0.0/16(rw,sync,no_subtree_check,no_root_squash)
   ```

4. 使配置生效并验证：

   ```bash
   sudo exportfs -rav
   sudo exportfs -v
   ```

### 0.2 在集群中创建 PV（NFS 后端）

在仓库中新增或使用以下清单（例如保存为 `k8s/backend/topology-data-pv.yaml`）：

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: topology-data-pv
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  nfs:
    server: k8s-worker22
    path: /export/topology-data
```

应用并检查：

```bash
kubectl apply -f k8s/backend/topology-data-pv.yaml
kubectl get pv topology-data-pv
```

### 0.3 在集群中创建 PVC 并绑定 PV

创建 PVC 清单 `k8s/backend/topology-data-pvc.yaml`：

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: topology-data
  namespace: gitlab-runner
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 5Gi
  volumeName: topology-data-pv
```

应用并确认 PVC 绑定成功：

```bash
kubectl apply -f k8s/backend/topology-data-pvc.yaml
kubectl get pvc -n gitlab-runner topology-data
kubectl get pv topology-data-pv
```

> 期望 PV 与 PVC 状态均为 `Bound`。

---

## 一、整体流程概览

**Pipeline 阶段：**

1. `build`：构建并推送 backend/frontend 镜像（已存在）。
2. `deploy`：更新 K8s Deployment 与 Istio（已存在）。
3. `topology-sync`（新 stage，建议追加）：  
   - Job 1：`sync-topology-csv-to-nfs` —— 使用 SSH/rsync 将 CSV 从仓库同步到 NFS `/export/topology-data`。  
   - Job 2：`import-topology` —— 使用 `kubectl` 在集群内执行导入 Job（或直接运行 `import_topology`）。

> 也可以把「导入」合并进 `deploy` job 的尾部，本方案采用**单独 job**，便于开关、重试和观察日志。

---

## 二、准备 GitLab CI 变量

在 GitLab 项目的 **Settings → CI/CD → Variables** 中新增以下变量（全部 **Masked/Protected**）：

- **NFS_SSH_USER**：有权限登录 `k8s-worker22` 的系统用户（例如 `alex` 或专用账号 `gitlab-sync`）。
- **NFS_SSH_HOST**：`k8s-worker22`
- **NFS_SSH_PORT**：`22`（如无特殊端口可省略，默认 22）
- **NFS_SSH_KEY**：上述用户的 **私钥内容**（PEM 格式），用于 `ssh`/`rsync` 登录。
- （可选）**TOPOLOGY_SCENARIO_NAME**：场景名，默认 `Scenario5_full_36x22`，可在导入 Job 中覆写。

> NFS 侧需要在 `~/.ssh/authorized_keys` 中允许此公钥登录，并限制权限（只允许写 `/export/topology-data`）。

---

## 三、通过 CI 同步 CSV 到 NFS

### 1. 新增 stage

在 `.gitlab-ci.yml` 的 `stages` 中追加一个 stage：

```yaml
stages:
  - build
  - deploy
  - topology-sync
```

### 2. 新增同步 Job：`sync-topology-csv-to-nfs`

在 `.gitlab-ci.yml` 中增加：

```yaml
sync-topology-csv-to-nfs:
  stage: topology-sync
  image: alpine:3.19
  tags:
    - k8s-cluster-runner
  needs:
    - deploy
  script:
    - apk add --no-cache openssh-client rsync
    # 准备 SSH key
    - mkdir -p ~/.ssh
    - echo "$NFS_SSH_KEY" > ~/.ssh/id_rsa
    - chmod 600 ~/.ssh/id_rsa
    - ssh-keyscan -p "${NFS_SSH_PORT:-22}" "$NFS_SSH_HOST" >> ~/.ssh/known_hosts
    # 同步 CSV 到 NFS 目录（覆盖更新）
    - |
      RSYNC_BASE="$NFS_SSH_USER@$NFS_SSH_HOST:/export/topology-data"
      echo "同步 delay_15x15.csv 到 $RSYNC_BASE"
      rsync -av --delete frontend/public/data/delay_15x15.csv "$RSYNC_BASE/"
      echo "同步 ephem_15/ 到 $RSYNC_BASE/ephem_15/"
      rsync -av --delete frontend/public/data/ephem_15/ "$RSYNC_BASE/ephem_15/"
      echo "同步 router/ 到 $RSYNC_BASE/router/"
      rsync -av --delete frontend/public/data/router/ "$RSYNC_BASE/router/"
  only:
    - main
```

说明：

- 该 job 在 `deploy` 完成后执行（`needs: deploy`），确保集群已有最新版镜像与 Deployment。
- 使用 `rsync` 的 `--delete`，保证 NFS 上的文件与仓库严格一致（可按需要去掉）。

---

## 四、在 CI 中触发 K8s 导入 Job

我们已经有 `k8s/backend/import-topology-job.yaml`，里面会挂载 PVC `topology-data`，并依次执行：

- `./import_topology -mode=delay -file /data/topology/delay_15x15.csv`
- `./import_topology -mode=t0 -dir /data/topology/ephem_15`
- `./import_topology -mode=router -dir /data/topology/router`

### 1. 新增导入 Job：`import-topology`

在 `.gitlab-ci.yml` 中追加（紧接在上一个 job 后）：

```yaml
import-topology:
  stage: topology-sync
  image: bitnami/kubectl:latest
  tags:
    - k8s-cluster-runner
  needs:
    - sync-topology-csv-to-nfs
  script:
    - echo "删除旧的导入 Job（若存在）"
    - kubectl -n gitlab-runner delete job import-topology || true
    - echo "应用新的导入 Job 清单"
    - kubectl -n gitlab-runner apply -f k8s/backend/import-topology-job.yaml
    - echo "等待导入 Job 完成..."
    - kubectl -n gitlab-runner wait --for=condition=complete --timeout=600s job/import-topology
    - echo "导入 Job 日志："
    - kubectl -n gitlab-runner logs job/import-topology --tail=100
  only:
    - main
```

说明：

- 使用与 `deploy` 相同的 `bitnami/kubectl` 镜像和 runner tag。
- 在每次导入前先 `delete job import-topology`，以保证 `apply` 后是一次新的执行。
- `wait` + `logs` 方便在 GitLab CI 的 Job 日志中直接看到导入结果。
- `import-topology-job.yaml` 中已经支持从 `SATELLITE_TOPOLOGY_SCENARIO` 读取场景名，若你在 Secret `satellite-backend-env` 中调整场景名，导入会自动跟随。

---

## 五、NFS 侧目录结构与权限约束

NFS 服务器 `k8s-worker22` 上的导出目录 `/export/topology-data` 需要满足：

```text
/export/topology-data/
  delay_15x15.csv
  ephem_15/
    Sat_6_6_ephem_ext.csv
    ...
  router/
    r001001_net_qos.csv
    ...
```

权限建议：

- 导出配置示例（`/etc/exports`）：

  ```bash
  /export/topology-data 192.168.0.0/16(rw,sync,no_subtree_check,no_root_squash)
  ```

- 为 CI 同步账号单独建一套用户/密钥，并限制其仅对该目录有读写（例如通过文件系统权限 + 不复用 root 账号）。

---

## 六、可选：增加开关变量

如果不希望每次 `main` 上的 pipeline 都执行导入，可增加一个开关变量：

1. 在 GitLab CI Variables 新增：`RUN_TOPOLOGY_IMPORT=true/false`
2. 在两个 Job 的脚本开头加一段：

```bash
if [ "${RUN_TOPOLOGY_IMPORT:-true}" != "true" ]; then
  echo "RUN_TOPOLOGY_IMPORT != true，跳过拓扑同步/导入"
  exit 0
fi
```

这样可以通过修改变量来临时关闭自动导入，而无需改 `.gitlab-ci.yml`。

---

## 七、总结

- **同步层**：`sync-topology-csv-to-nfs` 使用 SSH + rsync，保证 NFS 中的 CSV 与当前仓库一致。
- **导入层**：`import-topology` 使用现有的 `import_topology` 工具和 `import-topology-job.yaml`，在集群内执行导入逻辑。
- **集成方式**：通过新增 `topology-sync` stage 与两个 Job，将拓扑数据导入完全纳入 GitLab CI 流水线，部署后即可自动更新 DB 中的拓扑相关表。

