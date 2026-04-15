# 遥感分钟级处理路线图（低资源/多星协同场景）

适用背景：

- 硬件资源受限，后续可能进一步降配（仿真在轨场景）
- 目标是把单任务处理时延压到分钟级，并支持多任务协同

核心原则：

1. 先降 I/O 放大，再谈微服务拆分
2. 每次只做一个小改动，并可回滚
3. 每步都要有量化验收

---

## 阶段 0：统一基线（先做）

目标：

- 固化同一输入、同一参数、同一版本，形成可重复压测基线

操作：

1. 固定输入：`GF2_PMS1_E118.6_N37.4_20160826_L1A0001792619`
2. 固定处理参数（含 DEM 路径）
3. 同时记录：
   - 任务总时长
   - 三个重阶段耗时：`pan_rpc_warp_quarters`、`pansharpen_fusion`、`fusion_stack_envi`
   - Pod 资源状态（throttle/restart）
   - NFS bytes 前后快照

验收：

- 连续跑 3 次，结果波动不超过 15%

---

## 阶段 1：本地 scratch（最高优先级）

目标：

- 将中间产物从 NFS 挪到本地临时盘，降低网络存储读写放大

操作（最小改动）：

1. 在后端 `Deployment` 增加 `emptyDir`，挂载为 `/opt/remote-sensing/output_preprocessing`
2. 让遥感流程中间目录写入该本地 scratch 目录
3. 仅最终产物（融合 dat + 预览图）拷回 NFS

当前仓库已落地的等价实现：

1. 中间产物路径：`/opt/remote-sensing/output_preprocessing`（`emptyDir`）
2. 持久化路径：`/opt/remote-sensing/persist_output_preprocessing`（PVC/NFS）
3. 配置项：`SATELLITE_REMOTE_SENSING_PERSIST_OUTPUT_DIR=persist_output_preprocessing`

验收：

- 与基线相比，总时长下降 30% 以上
- 结果一致（文件存在 + 基本统计一致）

回滚：

- 恢复 `output_preprocessing` 直接写 NFS 的旧挂载配置

---

## 阶段 2：重阶段并行度重排（次优先）

目标：

- 在不提高硬件规格前提下，压缩 `PAN RPC` 和 `Pan-sharpen` 阶段时间

操作（最小改动）：

1. `PAN RPC 分块` 改为“最多 2 并发”执行四块（避免 4 并发内存抖动）
2. `Pan-sharpen` 保持波段串行，但减少重复打开/关闭文件次数
3. 固定线程参数：
   - `GDAL_NUM_THREADS=2`
   - `warp_mem_mb=1024`

验收：

- `PAN RPC` 阶段耗时下降到 4 分钟以内
- 无 OOM、无失败重试

当前仓库已落地的阶段2-A实现：

1. 后端 `executePanRpc` 使用并发度 `2` 执行 4 个 `areaidx`
2. 每个分块使用独立临时目录 `output_preprocessing/pan_warp_quarters/workers/area{n}`，避免共享 `vrt` 文件冲突
3. 每块完成后再复制 `wrap-part{n}.tif` 到主目录供后续拼接阶段使用

当前仓库已落地的阶段2-B实现：

1. `pansharpen_fusion` 从串行改为并发度 `2`
2. 每个波段使用独立临时目录 `output_preprocessing/pansharpen/workers/band{n}`
3. 每个波段完成后复制 `*_fused_band{n}.dat/.hdr` 到主输出目录，兼容后续 `fusion_stack_envi`

回滚：

- 将分块执行恢复为当前串行逻辑

---

## 阶段 3：任务队列化（为多星协同做准备）

目标：

- 提升多任务协同能力，避免前端/API 与重计算互相抢资源

操作（最小改动）：

1. 把“创建任务即后台 goroutine 执行”改为“入队”
2. 新增独立 worker 进程/Deployment 消费队列
3. 设定 worker 并发度（初始建议 `1`，再按压测升到 `2`）

验收：

- 多任务并发下，单任务时延稳定（P95 抖动下降）
- API 不再因重任务卡顿

回滚：

- 切回“本进程执行”模式（保留 feature flag）

---

## 阶段 4：微服务化（最后做）

目标：

- 在阶段 1~3 完成后，按职责拆分，支撑长期演进

拆分建议：

1. API 编排服务
2. 遥感 worker 服务
3. 产物服务（下载、预览、元数据）

说明：

- 微服务化主要解决扩展与隔离，不是第一提速手段
- 若阶段 1~3 已满足指标，可暂缓大规模拆分

---

## 推荐指标（建议写入项目 KPI）

在“低资源档”下（需你定义具体 CPU/内存）：

1. 总时长：P50 < 10 分钟，P95 < 12 分钟
2. `PAN RPC`：< 4 分钟
3. `Pansharpen`：< 3 分钟
4. `Fusion stack`：< 1 分钟

---

## 每阶段统一检查命令

```bash
# 1) 任务阶段耗时
kubectl -n gitlab-runner logs deploy/satellite-backend | rg "总时间|pan_rpc_warp_quarters|pansharpen_fusion|fusion_stack_envi"

# 2) Pod 重启/OOM
POD=$(kubectl -n gitlab-runner get pod -l app=satellite-backend -o jsonpath='{.items[0].metadata.name}')
kubectl -n gitlab-runner get pod "$POD" -o jsonpath='{.status.containerStatuses[?(@.name=="satellite-backend")].restartCount}{"\n"}'
kubectl -n gitlab-runner describe pod "$POD" | sed -n '/Last State/,+20p'

# 3) NFS bytes（任务前后各采一次）
kubectl -n gitlab-runner exec "$POD" -- sh -lc '
grep -A120 -E "device 192.168.10.112:/export/remote-sensing-data/(input|output_preprocessing)" /proc/self/mountstats \
| grep -E "device .*remote-sensing-data/(input|output_preprocessing)|[[:space:]]bytes:"
'
```

### 阶段1推荐：一键采集脚本（可重复）

脚本路径：

- `scripts/remote_sensing_stage1_benchmark.sh`

执行示例：

```bash
# 1) 任务开始前
./scripts/remote_sensing_stage1_benchmark.sh pre --run-id stage1-run-001

# 2) 在页面触发任务，记下 task_id（例如 11）

# 3) 任务结束后
./scripts/remote_sensing_stage1_benchmark.sh post --run-id stage1-run-001 --task-id 11

# 查看报告
cat artifacts/benchmarks/stage1-run-001/report.txt
```

报告包含：

1. CPU throttle 增量
2. NFS bytes 增量（input/output_preprocessing）
3. 指定 task 的各阶段耗时（通过 `/api/remote-sensing/tasks/<id>/stages` 计算）

---

## 执行策略（避免一次改太多）

1. 只改一项
2. 跑 3 次基线任务
3. 记录结果到同一份实验记录
4. 满足阈值再进入下一阶段
