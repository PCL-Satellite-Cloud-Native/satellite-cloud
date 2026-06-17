# 归档：Phase 0 基线收口（1～10 全链路）

> **归档日期**：2026-06-17  
> **阶段**：Phase 0 — 单 Pod baseline  
> **状态**：**已闭合**  
> **SSOT 后继**：[K8S_BASELINE_RUNBOOK.md](../K8S_BASELINE_RUNBOOK.md) §11、附录 A.4；微服务方案 Phase 0 见 [MICROSERVICES_IMPLEMENTATION_PLAN.md](../MICROSERVICES_IMPLEMENTATION_PLAN.md) §5

---

## 1. 背景

15 Node 集群上，单 Pod `satellite-backend` 跑通 RS 阶段 1～9 + CPU 目标识别阶段 10。Phase 0 要求在固定 GF2 输入下完成 **3 次** 可复现全链路，波动 ≤15%，并完成前端/API/NFS/CI 验收。

## 2. 环境快照

| 项 | 值 |
|----|-----|
| 集群 | 15 Node；namespace `gitlab-runner` |
| GitLab/Harbor/仓库机 | 192.168.10.238（`k8s-repository`） |
| NFS | 112；PVC `remote-sensing-data` |
| backend 镜像 | `192.168.10.238/satellite/backend:latest`（Pod 示例 `satellite-backend-6dbbd746cc-cnz5t`） |
| satellite-cloud SHA | `9ed17927` |
| RS / OD GitLab | `main` @ `root/satellite-remote-sensing`、`root/object-detection` |
| 检测 | `cpu`；模型 NFS `models/yolov8m-obb.onnx` |
| Pod limits | CPU `2000m` / Memory `4Gi` |

**固定任务输入**：`GF2_PMS1_E118.6_N37.4_20160826_L1A0001792619`；`enable_detection=true`；检测类别空（全类）。

## 3. 验收结果

§11 Checklist **A～G 全部通过**（2026-06-17 签字）。

| 块 | 结果 |
|----|------|
| A 基础设施 | ☑ |
| B 三次 benchmark | ☑ |
| C 前端/API | ☑ |
| D NFS 产物 | ☑ |
| E CI/仓库机 | ☑ |
| F 文档同步 | ☑ |
| G Phase 1 评审 | ☑ 通过，启动 Phase 1 |

## 4. 三次 Benchmark

| Run | task_id | 开始 | 结束 | 端到端 (min) | RS 1～9 (min) | stage10 (min) | 瓦片 | 目标 |
|-----|---------|------|------|--------------|---------------|---------------|------|------|
| #1 | 137 | 2026-06-16 18:08:13 | 2026-06-16 18:54:49 | 46.60 | 11.26 | 35.34 | 831 | 1719 |
| #2 | 138 | 2026-06-16 19:16:25 | 2026-06-16 20:01:45 | 45.34 | 10.09 | 35.25 | 905 | 1788 |
| #3 | 139 | 2026-06-17 08:59:56 | 2026-06-17 09:45:38 | 45.68 | 10.27 | 35.24 | 803 | 1695 |

**波动率**：

```text
median = 45.68 min
max − min = 46.60 − 45.34 = 1.26 min
波动率 = 1.26 / 45.68 × 100% = 2.8%  ✓ (≤ 15%)
```

## 5. Run #3 阶段耗时（report.txt）

来源：`artifacts/benchmarks/Object-Detection-test3/report.txt`（k8s-master）

| stage | name | elapsed (s) |
|-------|------|-------------|
| 1 | tiff_to_envi_mss | 9.42 |
| 2 | tiff_to_envi_pan | 18.80 |
| 3 | pan_rad_toa | 10.07 |
| 4 | pan_rpc_warp_quarters | 273.05 |
| 5 | pan_merge_warp_square | 23.00 |
| 6 | mss_rad_quac_rpc | 105.73 |
| 7 | mss_coregister_to_pan | 43.36 |
| 8 | pansharpen_fusion | 62.85 |
| 9 | fusion_stack_envi | 52.07 |
| 10 | object_detection | 2114.18 |
| — | RS 1～9 合计 | 598.34 (~10.0 min) |
| — | 端到端 | 2741.09 (~45.7 min) |

**观测**：stage 10 约占端到端 **77%**；PAN RPC（stage 4）约占 RS 段 **46%**。

## 6. 遗留项（非阻塞 Phase 1）

- 238 `:18080` 静态 HTTP 建议改 systemd 或 nginx `/static`（§5.2 方案 B）
- Run #1/#2 未跑 benchmark 脚本（已有任务级耗时与前端验收）

## 7. 下一步决议

**启动 Phase 1**：API 与 RS 计算分离（Redis + rs-worker）；检测阶段暂留单 Pod 直至 Phase 2。

---

*本文件为 2026-06-17 历史快照；活跃检查清单见 K8S_BASELINE_RUNBOOK §11。*
