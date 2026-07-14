# 归档：Phase 6 — MinIO Pilot 正式收口（P6-01～04）

> **归档日期**：2026-07-14  
> **阶段 / 主题**：MinIO 试点、存储抽象、NFS mirror、API 下载、CI 部署、Console NodePort  
> **状态**：✅ **Phase 6 Pilot 已闭合**（P6-05 未启动）  
> **SSOT**：[PHASE6_RUNBOOK.md](../PHASE6_RUNBOOK.md)  
> **分支**：已合并 `main`（PR [#93](https://github.com/PCL-Satellite-Cloud-Native/satellite-cloud/pull/93)、[#94](https://github.com/PCL-Satellite-Cloud-Native/satellite-cloud/pull/94)）  
> **前置**：[2026-07-13_phase6-minio-pilot-deploy.md](./2026-07-13_phase6-minio-pilot-deploy.md)、[2026-07-14_phase6-storage-sync-api-closure.md](./2026-07-14_phase6-storage-sync-api-closure.md)

---

## 1. 摘要

Phase 6 Pilot 在 15 节点集群完成 MinIO 对象存储试点：Worker 仍写 NFS；NFS 产物 mirror 至 MinIO；backend API 可从 MinIO 流式下载 artifact；GitLab CI `deploy-phase6-pilot` 可重复部署；Web Console 经 NodePort **30901** 与 Grafana/Prometheus 同方式访问。

---

## 2. 环境快照

| 项 | 值 |
|----|-----|
| 集群 | Pilot 15 Node |
| namespace | `gitlab-runner` |
| MinIO Pod | worker22，hostPath `/export/remote-sensing-data/minio-data` |
| MinIO 镜像 | `192.168.10.238/library/minio:RELEASE.2024-01-16T16-07-38Z-cpuv1` |
| Bucket | `satellite-artifacts` |
| main SHA | `af277eb`（含 CI PVC 检查修复） |
| rs-worker | DaemonSet 15/15；Deployment **0/0**（P5-06b） |

---

## 3. 验收结果

| # | 项 | 结果 | 证据 |
|---|-----|------|------|
| P6-01 | MinIO Deployment + PVC + init bucket | ✅ | CI `deploy-phase6-pilot` Job succeeded |
| P6-02 | `internal/storage` NFS/MinIO 抽象 | ✅ | 代码在 main |
| P6-03 | API MinIO 下载 | ✅ | task **217** / artifact **74324** → HTTP **200**，**170,267** bytes |
| P6-04 | NFS→MinIO mirror | ✅ | **298 GiB**，**19,302** objects |
| CI | `deploy-phase6-pilot` | ✅ | PVC Bound 检查（非 `get pv`）；rollout + init Job complete |
| Preflight | `phase6_preflight.sh --skip-p5` | ✅ | minio 1/1 |
| Console | NodePort **30901** | ✅ | `http://192.168.10.113:30901`（隧道 + 浏览器） |

```bash
# 2026-07-14 k8s-master 签收
bash scripts/phase6_preflight.sh --skip-p5
curl -o /tmp/test.jpg -w "HTTP %{http_code} bytes=%{size_download}\n" \
  "http://127.0.0.1:8080/api/remote-sensing/tasks/217/artifacts/74324"
# HTTP 200 bytes=170267
```

---

## 4. CI 踩坑（已修复）

| 问题 | 根因 | 处理 |
|------|------|------|
| `deploy-phase6-pilot` 报 PV 不存在 | gitlab-runner SA 无 `get pv`；Forbidden 被误判 | 改查 PVC `minio-data` Bound（PR #94） |
| kustomize apply PV Forbidden | PV 为 cluster 资源 | PV 拆出 `minio-pv.yaml`，admin 一次性 apply（PR #93） |

---

## 5. 集群态定稿

| 组件 | 存储 / 访问 |
|------|-------------|
| rs-worker DaemonSet | **NFS** 读写 |
| satellite-backend API 下载 | **MinIO**（`SATELLITE_STORAGE_BACKEND=minio`） |
| MinIO S3 API | ClusterIP `minio:9000`（集群内） |
| MinIO Console | NodePort **30901** → pod **9001** |
| 新任务产物 | 先写 NFS；需 **增量 mirror** 方可在 MinIO/API 下载 |

**Pilot 端口对照**（NodePort @ 任意节点 IP）：

| 服务 | 端口 |
|------|------|
| 前端 | 30080 |
| Grafana | 30001 |
| Prometheus | 30090 |
| MinIO Console | **30901** |

Console 登录：`minio-credentials` Secret（`MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD`）。

---

## 6. 代码 / 清单

| 路径 | 说明 |
|------|------|
| `k8s/phase6/` | minio Deployment、PVC、kustomize、console NodePort |
| `k8s/phase6/minio-pv.yaml` | PV（admin only） |
| `scripts/phase6_preflight.sh` | Phase 6 验收 |
| `scripts/sync_artifacts_nfs_to_minio.sh` | P6-04 mirror |
| `backend/internal/storage/` | NFS / MinIO backend |
| `.gitlab-ci.yml` | `deploy-phase6-pilot` |

---

## 7. 遗留与运维

| 类型 | 内容 |
|------|------|
| **运维** | 新任务后定期 `sync_artifacts_nfs_to_minio.sh` |
| **运维** | backend rollout 后确认 minio env 仍在 |
| **安全** | Console NodePort 仅 pilot 内网；生产需 ACL/VPN |
| **未做** | rs-worker 直写 MinIO（仍 NFS） |
| **未做** | `sync-artifacts-to-minio` CI 自动化（推荐 master 手工） |

---

## 8. 下一步

| 编号 | 内容 | 优先级 |
|------|------|--------|
| **路线图** | [2026-07-14_post-p6-pilot-60node-roadmap.md](./2026-07-14_post-p6-pilot-60node-roadmap.md) — 60 节点**新集群复制**、MinIO 主存储、P6-05 延后 | **SSOT** |
| 运维 | 新产物增量 mirror（Pilot 按需） | ongoing |
| P6-05 | 120 Node / pilot-map | 阶段 3（延后） |

---

*Phase 6 Pilot 收口：2026-07-14。Phase 6 总归档待路线图阶段 3。*
