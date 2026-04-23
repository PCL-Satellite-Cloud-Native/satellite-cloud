root@k8s-master:/home/pcl/code# cat artifacts/benchmarks/stageA-evict-fix1/report.txt
run_id=stageA-evict-fix1
namespace=gitlab-runner
pod=satellite-backend-6d94f99bc-69xtf
task_id=52
pre_time=2026-04-23 10:03:41 +0800
post_time=2026-04-23 10:21:25 +0800
since_seconds=1094
--- runtime_config ---
SATELLITE_REMOTE_SENSING_DEM_FILE=/opt/remote-sensing-data/dem/GMTED2010.jp2
SATELLITE_REMOTE_SENSING_PANSHARPEN_GDAL_THREADS=1
SATELLITE_REMOTE_SENSING_PANSHARPEN_PARALLELISM=3
SATELLITE_REMOTE_SENSING_PAN_RPC_CPU_THREADS=1
SATELLITE_REMOTE_SENSING_PAN_RPC_MAX_TOTAL_WARP_MEM_MB=2048
SATELLITE_REMOTE_SENSING_PAN_RPC_PARALLELISM=2
SATELLITE_REMOTE_SENSING_PAN_RPC_RESAMPLE_ALG=near
SATELLITE_REMOTE_SENSING_PAN_RPC_WARP_MEM_MB=1024
SATELLITE_REMOTE_SENSING_PERSIST_OUTPUT_DIR=persist_output_preprocessing
--- task_summary ---
task.status=completed
task.current_stage=
task.created_at=2026-04-23T10:03:54.73578+08:00
task.started_at=2026-04-23T10:03:55.29723+08:00
task.finished_at=2026-04-23T10:20:10.940802+08:00
task.elapsed_seconds=975.644
--- cpu_delta ---
cpu.nr_throttled.delta=2799
cpu.throttled_usec.delta=662239106
cpu.usage_usec.delta=1130183372
--- nfs_delta ---
nfs.output.normal_read.delta=2116136697
nfs.output.normal_write.delta=3279510586
nfs.output.direct_read.delta=0
nfs.output.direct_write.delta=0
nfs.output.server_read.delta=2024761362
nfs.output.server_write.delta=3279510586
nfs.output.read_pages.delta=494331
nfs.output.write_pages.delta=800664
nfs.input.normal_read.delta=2116136697
nfs.input.normal_write.delta=3279510586
nfs.input.direct_read.delta=0
nfs.input.direct_write.delta=0
nfs.input.server_read.delta=2024761362
nfs.input.server_write.delta=3279510586
nfs.input.read_pages.delta=494331
nfs.input.write_pages.delta=800664
--- stage_time ---
stage.fusion_stack_envi.elapsed_seconds=132.474
stage.mss_coregister_to_pan.elapsed_seconds=125.624
stage.mss_rad_quac_rpc.elapsed_seconds=61.376
stage.pan_merge_warp_square.elapsed_seconds=31.714
stage.pan_rad_toa.elapsed_seconds=27.102
stage.pan_rpc_warp_quarters.elapsed_seconds=354.372
stage.pansharpen_fusion.elapsed_seconds=228.679
stage.tiff_to_envi_mss.elapsed_seconds=5.677
stage.tiff_to_envi_pan.elapsed_seconds=7.369
--- stage_time_from_logs ---
stage.fusion_stack_envi.log_total_seconds=127.288
stage.mss_coregister_to_pan.log_total_seconds=124.672
stage.mss_rad_quac_rpc.log_total_seconds=60.628
stage.pan_merge_warp_square.log_total_seconds=31.177
stage.pan_rad_toa.log_total_seconds=26.245
stage.pan_rpc_warp_quarters.log_total_seconds=667.147
stage.pansharpen_fusion.log_total_seconds=595.018
stage.tiff_to_envi.log_total_seconds=7.894

root@k8s-master:/home/pcl/code# cat artifacts/benchmarks/stageA-evict-fix2/report.txt
run_id=stageA-evict-fix2
namespace=gitlab-runner
pod=satellite-backend-578bdc489f-5qsl9
task_id=53
pre_time=2026-04-23 11:51:18 +0800
post_time=2026-04-23 14:21:45 +0800
since_seconds=9058
--- runtime_config ---
SATELLITE_REMOTE_SENSING_DEM_FILE=/opt/remote-sensing-data/dem/GMTED2010.jp2
SATELLITE_REMOTE_SENSING_PANSHARPEN_GDAL_THREADS=1
SATELLITE_REMOTE_SENSING_PANSHARPEN_PARALLELISM=3
SATELLITE_REMOTE_SENSING_PAN_RPC_CPU_THREADS=1
SATELLITE_REMOTE_SENSING_PAN_RPC_MAX_TOTAL_WARP_MEM_MB=2048
SATELLITE_REMOTE_SENSING_PAN_RPC_PARALLELISM=2
SATELLITE_REMOTE_SENSING_PAN_RPC_RESAMPLE_ALG=near
SATELLITE_REMOTE_SENSING_PAN_RPC_WARP_MEM_MB=1024
SATELLITE_REMOTE_SENSING_PERSIST_OUTPUT_DIR=persist_output_preprocessing
--- task_summary ---
task.status=completed
task.current_stage=
task.created_at=2026-04-23T11:51:27.518656+08:00
task.started_at=2026-04-23T11:51:27.868665+08:00
task.finished_at=2026-04-23T12:08:20.420294+08:00
task.elapsed_seconds=1012.552
--- cpu_delta ---
cpu.nr_throttled.delta=2174
cpu.throttled_usec.delta=607959400
cpu.usage_usec.delta=1069113106
--- nfs_delta ---
nfs.output.normal_read.delta=2116136697
nfs.output.normal_write.delta=3279510586
nfs.output.direct_read.delta=0
nfs.output.direct_write.delta=0
nfs.output.server_read.delta=2025499702
nfs.output.server_write.delta=3279510586
nfs.output.read_pages.delta=494511
nfs.output.write_pages.delta=800664
nfs.input.normal_read.delta=2116136697
nfs.input.normal_write.delta=3279510586
nfs.input.direct_read.delta=0
nfs.input.direct_write.delta=0
nfs.input.server_read.delta=2025499702
nfs.input.server_write.delta=3279510586
nfs.input.read_pages.delta=494511
nfs.input.write_pages.delta=800664
--- stage_time ---
stage.fusion_stack_envi.elapsed_seconds=139.214
stage.mss_coregister_to_pan.elapsed_seconds=125.712
stage.mss_rad_quac_rpc.elapsed_seconds=60.815
stage.pan_merge_warp_square.elapsed_seconds=28.358
stage.pan_rad_toa.elapsed_seconds=30.548
stage.pan_rpc_warp_quarters.elapsed_seconds=352.142
stage.pansharpen_fusion.elapsed_seconds=245.097
stage.tiff_to_envi_mss.elapsed_seconds=6.068
stage.tiff_to_envi_pan.elapsed_seconds=23.777
--- stage_time_from_logs ---
stage.fusion_stack_envi.log_total_seconds=134.659
stage.mss_coregister_to_pan.log_total_seconds=124.818
stage.mss_rad_quac_rpc.log_total_seconds=60.110
stage.pan_merge_warp_square.log_total_seconds=27.985
stage.pan_rad_toa.log_total_seconds=29.979
stage.pan_rpc_warp_quarters.log_total_seconds=664.916
stage.pansharpen_fusion.log_total_seconds=243.676
stage.tiff_to_envi.log_total_seconds=28.675

root@k8s-master:/home/pcl/code# cat artifacts/benchmarks/stageA-evict-fix3/report.txt
run_id=stageA-evict-fix3
namespace=gitlab-runner
pod=satellite-backend-578bdc489f-5qsl9
task_id=54
pre_time=2026-04-23 14:22:49 +0800
post_time=2026-04-23 16:31:06 +0800
since_seconds=7727
--- runtime_config ---
SATELLITE_REMOTE_SENSING_DEM_FILE=/opt/remote-sensing-data/dem/GMTED2010.jp2
SATELLITE_REMOTE_SENSING_PANSHARPEN_GDAL_THREADS=1
SATELLITE_REMOTE_SENSING_PANSHARPEN_PARALLELISM=3
SATELLITE_REMOTE_SENSING_PAN_RPC_CPU_THREADS=1
SATELLITE_REMOTE_SENSING_PAN_RPC_MAX_TOTAL_WARP_MEM_MB=2048
SATELLITE_REMOTE_SENSING_PAN_RPC_PARALLELISM=2
SATELLITE_REMOTE_SENSING_PAN_RPC_RESAMPLE_ALG=near
SATELLITE_REMOTE_SENSING_PAN_RPC_WARP_MEM_MB=1024
SATELLITE_REMOTE_SENSING_PERSIST_OUTPUT_DIR=persist_output_preprocessing
--- task_summary ---
task.status=completed
task.current_stage=
task.created_at=2026-04-23T14:22:43.432073+08:00
task.started_at=2026-04-23T14:22:43.779909+08:00
task.finished_at=2026-04-23T14:39:29.424197+08:00
task.elapsed_seconds=1005.644
--- cpu_delta ---
cpu.nr_throttled.delta=1185
cpu.throttled_usec.delta=14532861
cpu.usage_usec.delta=858824933
--- nfs_delta ---
nfs.output.normal_read.delta=1664426836
nfs.output.normal_write.delta=3279510586
nfs.output.direct_read.delta=0
nfs.output.direct_write.delta=0
nfs.output.server_read.delta=1575403163
nfs.output.server_write.delta=3279510586
nfs.output.read_pages.delta=384558
nfs.output.write_pages.delta=800664
nfs.input.normal_read.delta=1664426836
nfs.input.normal_write.delta=3279510586
nfs.input.direct_read.delta=0
nfs.input.direct_write.delta=0
nfs.input.server_read.delta=1575403163
nfs.input.server_write.delta=3279510586
nfs.input.read_pages.delta=384558
nfs.input.write_pages.delta=800664
--- stage_time ---
stage.fusion_stack_envi.elapsed_seconds=157.714
stage.mss_coregister_to_pan.elapsed_seconds=0.808
stage.mss_rad_quac_rpc.elapsed_seconds=66.243
stage.pan_merge_warp_square.elapsed_seconds=28.293
stage.pan_rad_toa.elapsed_seconds=36.629
stage.pan_rpc_warp_quarters.elapsed_seconds=364.228
stage.pansharpen_fusion.elapsed_seconds=326.743
stage.tiff_to_envi_mss.elapsed_seconds=4.651
stage.tiff_to_envi_pan.elapsed_seconds=19.519
--- stage_time_from_logs ---
stage.fusion_stack_envi.log_total_seconds=154.733
stage.mss_coregister_to_pan.log_total_seconds=0.089
stage.mss_rad_quac_rpc.log_total_seconds=65.643
stage.pan_merge_warp_square.log_total_seconds=27.951
stage.pan_rad_toa.log_total_seconds=36.018
stage.pan_rpc_warp_quarters.log_total_seconds=676.498
stage.pansharpen_fusion.log_total_seconds=326.263
stage.tiff_to_envi.log_total_seconds=22.985