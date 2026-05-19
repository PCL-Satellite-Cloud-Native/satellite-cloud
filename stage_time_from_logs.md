root@k8s-master:/home/pcl/code# cat FUSDIR-TEST-5/report.txt
cat: FUSDIR-TEST-5/report.txt: No such file or directory
root@k8s-master:/home/pcl/code# cat artifacts/benchmarks/FUSDIR-TEST-5/report.txt
run_id=FUSDIR-TEST-5
namespace=gitlab-runner
pod=satellite-backend-6967d6c7b7-zbljg
task_id=134
pre_time=2026-05-19 09:19:27 +0800
post_time=2026-05-19 09:31:38 +0800
since_seconds=762
--- runtime_config ---
SATELLITE_REMOTE_SENSING_COMMAND_HEARTBEAT_SECONDS=60
SATELLITE_REMOTE_SENSING_COREGISTER_GDAL_THREADS=2
SATELLITE_REMOTE_SENSING_COREGISTER_MODE=serial4
SATELLITE_REMOTE_SENSING_DEM_FILE=/opt/remote-sensing-data/dem/GMTED2010.jp2
SATELLITE_REMOTE_SENSING_FUSION_BLOCK_SIZE=1024
SATELLITE_REMOTE_SENSING_FUSION_DIRECT_ENABLED=true
SATELLITE_REMOTE_SENSING_FUSION_GDAL_THREADS=1
SATELLITE_REMOTE_SENSING_FUSION_STAGE_TIMEOUT_SECONDS=1500
SATELLITE_REMOTE_SENSING_PANSHARPEN_GDAL_THREADS=1
SATELLITE_REMOTE_SENSING_PANSHARPEN_MODE=parallel
SATELLITE_REMOTE_SENSING_PANSHARPEN_PARALLELISM=3
SATELLITE_REMOTE_SENSING_PAN_RPC_CPU_THREADS=1
SATELLITE_REMOTE_SENSING_PAN_RPC_MAX_TOTAL_WARP_MEM_MB=2048
SATELLITE_REMOTE_SENSING_PAN_RPC_PARALLELISM=4
SATELLITE_REMOTE_SENSING_PAN_RPC_RESAMPLE_ALG=near
SATELLITE_REMOTE_SENSING_PAN_RPC_WARP_MEM_MB=512
SATELLITE_REMOTE_SENSING_PERSIST_OUTPUT_DIR=persist_output_preprocessing
SATELLITE_REMOTE_SENSING_STAGE_MAX_RETRIES=1
SATELLITE_REMOTE_SENSING_STAGE_TIMEOUT_SECONDS=1800
--- task_summary ---
task.status=completed
task.current_stage=
task.created_at=2026-05-19T09:19:39.339807+08:00
task.started_at=2026-05-19T09:19:39.688125+08:00
task.finished_at=2026-05-19T09:28:57.576993+08:00
task.elapsed_seconds=557.889
--- cpu_delta ---
cpu.nr_throttled.delta=2651
cpu.throttled_usec.delta=556234969
cpu.usage_usec.delta=711850667
--- nfs_delta ---
nfs.output.normal_read.delta=2148934998
nfs.output.normal_write.delta=3303595051
nfs.output.direct_read.delta=0
nfs.output.direct_write.delta=0
nfs.output.server_read.delta=2024883121
nfs.output.server_write.delta=3303595051
nfs.output.read_pages.delta=494360
nfs.output.write_pages.delta=806544
nfs.input.normal_read.delta=2148934998
nfs.input.normal_write.delta=3303595051
nfs.input.direct_read.delta=0
nfs.input.direct_write.delta=0
nfs.input.server_read.delta=2024883121
nfs.input.server_write.delta=3303595051
nfs.input.read_pages.delta=494360
nfs.input.write_pages.delta=806544
--- stage_time ---
stage.fusion_stack_envi.elapsed_seconds=53.825
stage.mss_coregister_to_pan.elapsed_seconds=36.739
stage.mss_rad_quac_rpc.elapsed_seconds=54.970
stage.pan_merge_warp_square.elapsed_seconds=23.636
stage.pan_rad_toa.elapsed_seconds=27.543
stage.pan_rpc_warp_quarters.elapsed_seconds=270.651
stage.pansharpen_fusion.elapsed_seconds=72.496
stage.tiff_to_envi_mss.elapsed_seconds=2.729
stage.tiff_to_envi_pan.elapsed_seconds=14.474
--- stage_time_from_logs ---
stage.fusion_stack_envi.log_total_seconds=51.747
stage.mss_coregister_to_pan.log_total_seconds=34.878
stage.mss_rad_quac_rpc.log_total_seconds=54.391
stage.pan_merge_warp_square.log_total_seconds=22.176
stage.pan_rad_toa.log_total_seconds=26.460
stage.pan_rpc_warp_quarters.log_total_seconds=959.929
stage.tiff_to_envi.log_total_seconds=16.044

root@k8s-master:/home/pcl/code# cat artifacts/benchmarks/FUSDIR-TEST-6/report.txt
run_id=FUSDIR-TEST-6
namespace=gitlab-runner
pod=satellite-backend-6967d6c7b7-zbljg
task_id=135
pre_time=2026-05-19 10:07:15 +0800
post_time=2026-05-19 10:22:11 +0800
since_seconds=926
--- runtime_config ---
SATELLITE_REMOTE_SENSING_COMMAND_HEARTBEAT_SECONDS=60
SATELLITE_REMOTE_SENSING_COREGISTER_GDAL_THREADS=2
SATELLITE_REMOTE_SENSING_COREGISTER_MODE=serial4
SATELLITE_REMOTE_SENSING_DEM_FILE=/opt/remote-sensing-data/dem/GMTED2010.jp2
SATELLITE_REMOTE_SENSING_FUSION_BLOCK_SIZE=1024
SATELLITE_REMOTE_SENSING_FUSION_DIRECT_ENABLED=true
SATELLITE_REMOTE_SENSING_FUSION_GDAL_THREADS=1
SATELLITE_REMOTE_SENSING_FUSION_STAGE_TIMEOUT_SECONDS=1500
SATELLITE_REMOTE_SENSING_PANSHARPEN_GDAL_THREADS=1
SATELLITE_REMOTE_SENSING_PANSHARPEN_MODE=parallel
SATELLITE_REMOTE_SENSING_PANSHARPEN_PARALLELISM=3
SATELLITE_REMOTE_SENSING_PAN_RPC_CPU_THREADS=1
SATELLITE_REMOTE_SENSING_PAN_RPC_MAX_TOTAL_WARP_MEM_MB=2048
SATELLITE_REMOTE_SENSING_PAN_RPC_PARALLELISM=4
SATELLITE_REMOTE_SENSING_PAN_RPC_RESAMPLE_ALG=near
SATELLITE_REMOTE_SENSING_PAN_RPC_WARP_MEM_MB=512
SATELLITE_REMOTE_SENSING_PERSIST_OUTPUT_DIR=persist_output_preprocessing
SATELLITE_REMOTE_SENSING_STAGE_MAX_RETRIES=1
SATELLITE_REMOTE_SENSING_STAGE_TIMEOUT_SECONDS=1800
--- task_summary ---
task.status=completed
task.current_stage=
task.created_at=2026-05-19T10:07:29.530449+08:00
task.started_at=2026-05-19T10:07:29.876101+08:00
task.finished_at=2026-05-19T10:16:25.166582+08:00
task.elapsed_seconds=535.290
--- cpu_delta ---
cpu.nr_throttled.delta=2655
cpu.throttled_usec.delta=548943020
cpu.usage_usec.delta=713512668
--- nfs_delta ---
nfs.output.normal_read.delta=2148934998
nfs.output.normal_write.delta=3303557023
nfs.output.direct_read.delta=0
nfs.output.direct_write.delta=0
nfs.output.server_read.delta=2022770645
nfs.output.server_write.delta=3303557023
nfs.output.read_pages.delta=493844
nfs.output.write_pages.delta=806535
nfs.input.normal_read.delta=2148934998
nfs.input.normal_write.delta=3303557023
nfs.input.direct_read.delta=0
nfs.input.direct_write.delta=0
nfs.input.server_read.delta=2022770645
nfs.input.server_write.delta=3303557023
nfs.input.read_pages.delta=493844
nfs.input.write_pages.delta=806535
--- stage_time ---
stage.fusion_stack_envi.elapsed_seconds=49.104
stage.mss_coregister_to_pan.elapsed_seconds=40.156
stage.mss_rad_quac_rpc.elapsed_seconds=53.527
stage.pan_merge_warp_square.elapsed_seconds=27.790
stage.pan_rad_toa.elapsed_seconds=30.598
stage.pan_rpc_warp_quarters.elapsed_seconds=260.469
stage.pansharpen_fusion.elapsed_seconds=60.981
stage.tiff_to_envi_mss.elapsed_seconds=4.119
stage.tiff_to_envi_pan.elapsed_seconds=7.764
--- stage_time_from_logs ---
stage.fusion_stack_envi.log_total_seconds=48.389
stage.mss_coregister_to_pan.log_total_seconds=38.247
stage.mss_rad_quac_rpc.log_total_seconds=52.931
stage.pan_merge_warp_square.log_total_seconds=26.934
stage.pan_rad_toa.log_total_seconds=30.001
stage.pan_rpc_warp_quarters.log_total_seconds=996.118
stage.tiff_to_envi.log_total_seconds=9.255