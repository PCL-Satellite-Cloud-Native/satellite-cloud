# 归档：Post-P5 60 节点主线收口（cluster-120）

> **状态**：**已正式收口**（2026-07-23～24）  
> **运维节点**：sat10-m1  
> **API**：`http://192.168.12.67:30080`  
> **场景**：`Scenario60_3x20`（scenario_id=3）  
> **前置**：P5 准出 [2026-07-20_p5-60node-closure.md](./2026-07-20_p5-60node-closure.md)

---

## 准出结论

Post-P5 主线（D0 MinIO + 本星队列 + 强制选卫星）在 60 节点验收通过，前端可预览融合/检测结果。

| 能力 | 验收要点 | 结果 |
|------|----------|------|
| D0 MinIO | GET preview/summary 200；detection-stats dets>0 | ✅ task 78/83 |
| 本星 XCLAIM | `satelliteId=847` → host=sat1，非 sat36 | ✅ |
| 非阻塞 sem | 双任务排队；「忙，留 PEL」后第二单继续 | ✅ task 79/80 |
| 三锚点 | 847/822/826 → sat1/sat21/sat41 | ✅ 78/81/82 |
| API 强制卫星 | 无 satelliteId → 拒绝；**HTTP 400** | ✅ backend `@sha256:3f0ec26d…` |
| UI 强制卫星 | 执行卫星必选 | ✅ frontend `@sha256:1cb1ee94…` |

---

## 关键任务样本

| task | satellite_id | host / executed | 说明 |
|------|--------------|-----------------|------|
| 78 | 847 | sat1 / sat-1-1 | D0：tiles=824，dets=1705 |
| 81 | 822 | sat21 / sat-2-1 | 无检测冒烟 |
| 82 | 826 | sat41 / sat-3-1 | 无检测冒烟 |
| 83 | 847 | sat1 / sat-1-1 | 页面端到端（含检测） |
| 79/80 | 847 | sat1 | 双任务排队 |

---

## 关键镜像 / 配置（验收时）

| 组件 | 镜像 / 配置 |
|------|-------------|
| backend | `192.168.10.238/satellite/backend@sha256:3f0ec26d88b505bfdc1e22653942313fd2f98e11d1675633b541982a1b000966` |
| frontend | `192.168.10.238/satellite/frontend@sha256:1cb1ee9456c50cabd34cfad9d49ea76b2779a2e106a3f7f0f6165f6c435f240b` |
| rs-worker（队列验收） | 曾用 `@sha256:9d93de0b…`；建议对齐含 `87da08a` 的新 digest |
| `SATELLITE_RS_SATELLITE_AWARE_QUEUE` | `true`（backend + rs-worker） |
| `SATELLITE_STORAGE_BACKEND` | backend=`minio`；worker 写盘 + `ARTIFACT_UPLOAD_MINIO=true` |
| `USE_OD_WORKER` / `USE_ARGO_PAN_RPC` | `false` / `false` |

**镜像运维：** 使用 CI 的 `cluster-120-latest` 或 `@sha256:`；**禁止**把 digest 字符串当作 tag（曾导致 ImagePullBackOff）。

---

## 关键代码提交（cluster-120）

| commit | 说明 |
|--------|------|
| `48725d6` | 本星 XCLAIM + fail-closed + MinIO detection-stats |
| `c2928d0` | API/UI 强制 satelliteId |
| `6067490` | 非阻塞 sem |
| `45abc38` | 无卫星创建 HTTP 400 |
| `87da08a` | reclaim 跳过 in-flight；收口文档 |

详情见 [post-p5-60node-roadmap.md](../post-p5-60node-roadmap.md)、[D0_MINIO_ARTIFACT_UPLOAD_60.md](../D0_MINIO_ARTIFACT_UPLOAD_60.md)。

---

## 踩坑摘要

| 问题 | 根因 | 处置 |
|------|------|------|
| 绑 847 仍在 sat36 跑 | 旧镜像全员 XAUTOCLAIM + fail-open | 本星 XCLAIM + fail-closed |
| 第二单一直 pending | reclaim 阻塞在 sem | 非阻塞 sem（`6067490`） |
| UI「0 目标」 | backend 本地读不到 detections.txt | MinIO Open |
| frontend/rs-worker PullBackOff | digest 误作 tag | `@sha256:` / 真实 tag |
| sat33 拉镜像失败 | containerd 坏 blob | sat1 export → sat33 import |
| set image latest 不滚动 | tag 未变、Pod AGE 仍几十小时 | 显式 `@sha256:` 强制更新 |

---

## 挂起项（不阻塞 Post-P5）

- sat57 backend `kubectl exec`（节点 overlay；方案 A）
- od-worker 仍 scale 0（OD 在 rs-worker）
- P3：Argo hostPath、动态拓扑、CI dual-cluster

---

## 日常用法

1. 创建任务必须选场景 + **锚点卫星**（847/822/826 ↔ sat1/sat21/sat41）。  
2. 产物验收用 **GET**，勿用 `curl -sI`（HEAD 未注册）。  
3. GF2 输入仅在三锚点 hostPath：`/export/remote-sensing-data/input/...`。
