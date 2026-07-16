# cluster-120 部署与 MinIO 数据上传

> **分支策略**：`main` = Pilot 15 节点 baseline（不变）；`cluster-120` = 60→120 节点生产目标。  
> **CI**：build 走 `k8s-cluster-runner`（Harbor）；deploy 走 `k8s-120-runner`（120 集群）。

---

## 1. MinIO Console 地址（重要）

| 集群 | Console URL | 说明 |
|------|-------------|------|
| **Pilot 15 节点** | `http://192.168.10.113:30901/` | 你当前隧道能打开的 **是这一台** |
| **120 集群（60 节点）** | `http://192.168.12.67:30901/`（sat57，或 sat58–60 同端口） | **P5 数据必须传到这里** |

上传到 Pilot MinIO（113）**不会**被 120 集群应用读到。请把隧道延伸到 **192.168.12.x 管理网**（例如经 sat10-m1 `192.168.12.20` 转发 30901）。

登录账号：与集群 Secret `minio-credentials` 一致（`MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD`）。

---

## 2. Bucket 与目录结构

在 Console 中创建 bucket（若不存在）：**`satellite-inputs`**

| 对象前缀 | 内容 | 来源 |
|----------|------|------|
| `topology/ephem_60/` | 60× `Sat_*_ephem_ext.csv` | **CI** `sync-inputs-to-minio`（已在 git）或手工 |
| `topology/delay_60x60.csv` | T0 时延矩阵 | 同上 |
| `dem/GMTED2010.jp2` | DEM | 从 Pilot NFS/112 拷贝或本机上传 |
| `models/yolov8m-obb.onnx` | 检测模型 | Object-Detection 仓 / Pilot |
| `input/GF2_PMS1_E118.6_N37.4_20160826_L1A0001792619/` | GF2 单景输入 | **本机浏览器上传**（见下） |

拓扑也可由 CI 自动同步：`cluster-120` Pipeline → 手动 **sync-inputs-to-minio**。

---

## 3. GF2 浏览器上传（本机 `D:\Code\remote-sensing`）

在 **`satellite-inputs`** bucket 下新建「文件夹」路径：

```text
input/GF2_PMS1_E118.6_N37.4_20160826_L1A0001792619/
```

**必须上传**（预处理 pipeline 最小集，约 2.1 GiB）：

| 文件 | 大小约 |
|------|--------|
| `GF2_PMS1_E118.6_N37.4_20160826_L1A0001792619-MSS1.tiff` | 385 MB |
| `GF2_PMS1_E118.6_N37.4_20160826_L1A0001792619-MSS1.xml` | 3 KB |
| `GF2_PMS1_E118.6_N37.4_20160826_L1A0001792619-MSS1.rpb` | 3 KB |
| `GF2_PMS1_E118.6_N37.4_20160826_L1A0001792619-PAN1.tiff` | 1.5 GB |
| `GF2_PMS1_E118.6_N37.4_20160826_L1A0001792619-PAN1.xml` | 3 KB |
| `GF2_PMS1_E118.6_N37.4_20160826_L1A0001792619-PAN1.rpb` | 3 KB |

**可选**（不影响 baseline 验收）：`.jpg`、`.tiff.enp`、`*_thumb.jpg`

Console 支持多文件/拖拽；大文件上传较慢，可改用 `mc cp`（sat10-m1 上）。

---

## 4. P5 执行顺序（cluster-120）

1. push **`cluster-120`** → build-backend / build-frontend  
2. sat10-m1 一次性：`bash scripts/p5_60node_bootstrap.sh`  
3. Pipeline 手动：**sync-inputs-to-minio**（拓扑）  
4. MinIO Console 上传：DEM、model、GF2（或 sat10-m1 `mc mirror`）  
5. sat57：`mc mirror` MinIO → hostPath（RS 首通仍读 PVC）  
6. Pipeline 手动：**import-topology-60** → **deploy-cluster-120**  
7. `CLUSTER_PROFILE=60node bash scripts/phase5_acceptance.sh`

---

## 5. sat57 hostPath 从 MinIO 拉取（首通 RS）

```bash
# sat10-m1 或 sat57
mc alias set c120 http://minio.gitlab-runner.svc:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"
# 外网/跳板用 NodePort：http://127.0.0.1:30901 经隧道

mc mirror c120/satellite-inputs/topology/ephem_60/ /export/topology-import/ephem_60/
mc cp c120/satellite-inputs/topology/delay_60x60.csv /export/topology-import/
mc mirror c120/satellite-inputs/input/GF2_PMS1_E118.6_N37.4_20160826_L1A0001792619/ \
  /export/remote-sensing-data/input/GF2_PMS1_E118.6_N37.4_20160826_L1A0001792619/
mc cp c120/satellite-inputs/dem/GMTED2010.jp2 /export/remote-sensing-data/dem/
mc cp c120/satellite-inputs/models/yolov8m-obb.onnx /export/remote-sensing-data/models/
```

锚点节点 sat1/sat21/sat41 验收前需同样 mirror 到各自 `/export/remote-sensing-data/`（或后续 D0 全 MinIO）。
