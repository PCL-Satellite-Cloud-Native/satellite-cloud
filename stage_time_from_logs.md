root@k8s-master:/home/pcl/code# cat artifacts/benchmarks/coregC0-1/report.txt
run_id=coregC0-1
namespace=gitlab-runner
pod=satellite-backend-cfcb64ddd-mm6fr
task_id=83
pre_time=2026-04-30 09:53:52 +0800
post_time=2026-04-30 10:14:08 +0800
since_seconds=1247
--- runtime_config ---
SATELLITE_REMOTE_SENSING_COMMAND_HEARTBEAT_SECONDS=60
SATELLITE_REMOTE_SENSING_DEM_FILE=/opt/remote-sensing-data/dem/GMTED2010.jp2
SATELLITE_REMOTE_SENSING_FUSION_BLOCK_SIZE=1024
SATELLITE_REMOTE_SENSING_FUSION_GDAL_THREADS=1
SATELLITE_REMOTE_SENSING_FUSION_STAGE_TIMEOUT_SECONDS=1500
SATELLITE_REMOTE_SENSING_PANSHARPEN_GDAL_THREADS=1
SATELLITE_REMOTE_SENSING_PANSHARPEN_MODE=parallel
SATELLITE_REMOTE_SENSING_PANSHARPEN_PARALLELISM=3
SATELLITE_REMOTE_SENSING_PAN_RPC_CPU_THREADS=1
SATELLITE_REMOTE_SENSING_PAN_RPC_MAX_TOTAL_WARP_MEM_MB=2048
SATELLITE_REMOTE_SENSING_PAN_RPC_PARALLELISM=2
SATELLITE_REMOTE_SENSING_PAN_RPC_RESAMPLE_ALG=near
SATELLITE_REMOTE_SENSING_PAN_RPC_WARP_MEM_MB=1024
SATELLITE_REMOTE_SENSING_PERSIST_OUTPUT_DIR=persist_output_preprocessing
SATELLITE_REMOTE_SENSING_STAGE_MAX_RETRIES=1
SATELLITE_REMOTE_SENSING_STAGE_TIMEOUT_SECONDS=1800
--- task_summary ---
task.status=completed
task.current_stage=
task.created_at=2026-04-30T09:54:02.546934+08:00
task.started_at=2026-04-30T09:54:02.705226+08:00
task.finished_at=2026-04-30T10:10:58.958908+08:00
task.elapsed_seconds=1016.254
--- cpu_delta ---
cpu.nr_throttled.delta=1585
cpu.throttled_usec.delta=69292894
cpu.usage_usec.delta=1146531906
--- nfs_delta ---
nfs.output.normal_read.delta=2120107097
nfs.output.normal_write.delta=3279510586
nfs.output.direct_read.delta=0
nfs.output.direct_write.delta=0
nfs.output.server_read.delta=2024504374
nfs.output.server_write.delta=3279510586
nfs.output.read_pages.delta=494268
nfs.output.write_pages.delta=800664
nfs.input.normal_read.delta=2120107097
nfs.input.normal_write.delta=3279510586
nfs.input.direct_read.delta=0
nfs.input.direct_write.delta=0
nfs.input.server_read.delta=2024504374
nfs.input.server_write.delta=3279510586
nfs.input.read_pages.delta=494268
nfs.input.write_pages.delta=800664
--- stage_time ---
stage.fusion_stack_envi.elapsed_seconds=124.610
stage.mss_coregister_to_pan.elapsed_seconds=211.081
stage.mss_rad_quac_rpc.elapsed_seconds=62.673
stage.pan_merge_warp_square.elapsed_seconds=27.411
stage.pan_rad_toa.elapsed_seconds=24.289
stage.pan_rpc_warp_quarters.elapsed_seconds=351.843
stage.pansharpen_fusion.elapsed_seconds=198.515
stage.tiff_to_envi_mss.elapsed_seconds=4.987
stage.tiff_to_envi_pan.elapsed_seconds=10.434
--- stage_time_from_logs ---
stage.fusion_stack_envi.log_total_seconds=121.762
stage.mss_coregister_to_pan.log_total_seconds=210.344
stage.mss_rad_quac_rpc.log_total_seconds=62.211
stage.pan_merge_warp_square.log_total_seconds=27.093
stage.pan_rad_toa.log_total_seconds=23.757
stage.pan_rpc_warp_quarters.log_total_seconds=676.017
stage.pansharpen_fusion.log_total_seconds=528.473
stage.tiff_to_envi.log_total_seconds=12.231

root@k8s-master:/home/pcl/code# cat artifacts/benchmarks/coregC0-2/report.txt
run_id=coregC0-2
namespace=gitlab-runner
pod=satellite-backend-cfcb64ddd-mm6fr
task_id=84
pre_time=2026-04-30 10:14:35 +0800
post_time=2026-04-30 10:33:18 +0800
since_seconds=1154
--- runtime_config ---
SATELLITE_REMOTE_SENSING_COMMAND_HEARTBEAT_SECONDS=60
SATELLITE_REMOTE_SENSING_DEM_FILE=/opt/remote-sensing-data/dem/GMTED2010.jp2
SATELLITE_REMOTE_SENSING_FUSION_BLOCK_SIZE=1024
SATELLITE_REMOTE_SENSING_FUSION_GDAL_THREADS=1
SATELLITE_REMOTE_SENSING_FUSION_STAGE_TIMEOUT_SECONDS=1500
SATELLITE_REMOTE_SENSING_PANSHARPEN_GDAL_THREADS=1
SATELLITE_REMOTE_SENSING_PANSHARPEN_MODE=parallel
SATELLITE_REMOTE_SENSING_PANSHARPEN_PARALLELISM=3
SATELLITE_REMOTE_SENSING_PAN_RPC_CPU_THREADS=1
SATELLITE_REMOTE_SENSING_PAN_RPC_MAX_TOTAL_WARP_MEM_MB=2048
SATELLITE_REMOTE_SENSING_PAN_RPC_PARALLELISM=2
SATELLITE_REMOTE_SENSING_PAN_RPC_RESAMPLE_ALG=near
SATELLITE_REMOTE_SENSING_PAN_RPC_WARP_MEM_MB=1024
SATELLITE_REMOTE_SENSING_PERSIST_OUTPUT_DIR=persist_output_preprocessing
SATELLITE_REMOTE_SENSING_STAGE_MAX_RETRIES=1
SATELLITE_REMOTE_SENSING_STAGE_TIMEOUT_SECONDS=1800
--- task_summary ---
task.status=completed
task.current_stage=
task.created_at=2026-04-30T10:15:11.136476+08:00
task.started_at=2026-04-30T10:15:11.27917+08:00
task.finished_at=2026-04-30T10:32:30.567611+08:00
task.elapsed_seconds=1039.288
--- cpu_delta ---
cpu.nr_throttled.delta=1428
cpu.throttled_usec.delta=73123659
cpu.usage_usec.delta=1156283774
--- nfs_delta ---
nfs.output.normal_read.delta=2116136697
nfs.output.normal_write.delta=3275539350
nfs.output.direct_read.delta=0
nfs.output.direct_write.delta=0
nfs.output.server_read.delta=2024609749
nfs.output.server_write.delta=2930769920
nfs.output.read_pages.delta=494293
nfs.output.write_pages.delta=799693
nfs.input.normal_read.delta=2116136697
nfs.input.normal_write.delta=3275539350
nfs.input.direct_read.delta=0
nfs.input.direct_write.delta=0
nfs.input.server_read.delta=2024609749
nfs.input.server_write.delta=2930769920
nfs.input.read_pages.delta=494293
nfs.input.write_pages.delta=799693
--- stage_time ---
stage.fusion_stack_envi.elapsed_seconds=112.408
stage.mss_coregister_to_pan.elapsed_seconds=216.258
stage.mss_rad_quac_rpc.elapsed_seconds=62.158
stage.pan_merge_warp_square.elapsed_seconds=28.837
stage.pan_rad_toa.elapsed_seconds=20.118
stage.pan_rpc_warp_quarters.elapsed_seconds=360.943
stage.pansharpen_fusion.elapsed_seconds=226.600
stage.tiff_to_envi_mss.elapsed_seconds=2.646
stage.tiff_to_envi_pan.elapsed_seconds=8.975
--- stage_time_from_logs ---
stage.fusion_stack_envi.log_total_seconds=108.835
stage.mss_coregister_to_pan.log_total_seconds=215.504
stage.mss_rad_quac_rpc.log_total_seconds=61.662
stage.pan_merge_warp_square.log_total_seconds=28.498
stage.pan_rad_toa.log_total_seconds=19.621
stage.pan_rpc_warp_quarters.log_total_seconds=687.141
stage.pansharpen_fusion.log_total_seconds=584.789
stage.tiff_to_envi.log_total_seconds=10.565

root@k8s-master:/home/pcl/code# cat artifacts/benchmarks/coregC1-1/report.txt
run_id=coregC1-1
namespace=gitlab-runner
pod=satellite-backend-64999d455d-9v2m5
task_id=85
pre_time=2026-04-30 10:34:13 +0800
post_time=2026-04-30 11:02:19 +0800
since_seconds=1717
--- runtime_config ---
SATELLITE_REMOTE_SENSING_COMMAND_HEARTBEAT_SECONDS=60
SATELLITE_REMOTE_SENSING_DEM_FILE=/opt/remote-sensing-data/dem/GMTED2010.jp2
SATELLITE_REMOTE_SENSING_FUSION_BLOCK_SIZE=1024
SATELLITE_REMOTE_SENSING_FUSION_GDAL_THREADS=1
SATELLITE_REMOTE_SENSING_FUSION_STAGE_TIMEOUT_SECONDS=1500
SATELLITE_REMOTE_SENSING_PANSHARPEN_GDAL_THREADS=1
SATELLITE_REMOTE_SENSING_PANSHARPEN_MODE=parallel
SATELLITE_REMOTE_SENSING_PANSHARPEN_PARALLELISM=3
SATELLITE_REMOTE_SENSING_PAN_RPC_CPU_THREADS=1
SATELLITE_REMOTE_SENSING_PAN_RPC_MAX_TOTAL_WARP_MEM_MB=2048
SATELLITE_REMOTE_SENSING_PAN_RPC_PARALLELISM=2
SATELLITE_REMOTE_SENSING_PAN_RPC_RESAMPLE_ALG=near
SATELLITE_REMOTE_SENSING_PAN_RPC_WARP_MEM_MB=1024
SATELLITE_REMOTE_SENSING_PERSIST_OUTPUT_DIR=persist_output_preprocessing
SATELLITE_REMOTE_SENSING_STAGE_MAX_RETRIES=1
SATELLITE_REMOTE_SENSING_STAGE_TIMEOUT_SECONDS=1800
--- task_summary ---
task.status=completed
task.current_stage=
task.created_at=2026-04-30T10:34:26.394067+08:00
task.started_at=2026-04-30T10:34:26.730586+08:00
task.finished_at=2026-04-30T10:52:35.86345+08:00
task.elapsed_seconds=1089.133
--- cpu_delta ---
cpu.nr_throttled.delta=1542
cpu.throttled_usec.delta=70345984
cpu.usage_usec.delta=1115148744
--- nfs_delta ---
nfs.output.normal_read.delta=2120107097
nfs.output.normal_write.delta=3279510586
nfs.output.direct_read.delta=0
nfs.output.direct_write.delta=0
nfs.output.server_read.delta=2028646806
nfs.output.server_write.delta=3279510586
nfs.output.read_pages.delta=495280
nfs.output.write_pages.delta=800664
nfs.input.normal_read.delta=2120107097
nfs.input.normal_write.delta=3279510586
nfs.input.direct_read.delta=0
nfs.input.direct_write.delta=0
nfs.input.server_read.delta=2028646806
nfs.input.server_write.delta=3279510586
nfs.input.read_pages.delta=495280
nfs.input.write_pages.delta=800664
--- stage_time ---
stage.fusion_stack_envi.elapsed_seconds=128.944
stage.mss_coregister_to_pan.elapsed_seconds=208.077
stage.mss_rad_quac_rpc.elapsed_seconds=64.149
stage.pan_merge_warp_square.elapsed_seconds=30.430
stage.pan_rad_toa.elapsed_seconds=34.627
stage.pan_rpc_warp_quarters.elapsed_seconds=362.705
stage.pansharpen_fusion.elapsed_seconds=238.068
stage.tiff_to_envi_mss.elapsed_seconds=7.327
stage.tiff_to_envi_pan.elapsed_seconds=14.017
--- stage_time_from_logs ---
stage.fusion_stack_envi.log_total_seconds=122.412
stage.mss_coregister_to_pan.log_total_seconds=207.812
stage.mss_rad_quac_rpc.log_total_seconds=63.438
stage.pan_merge_warp_square.log_total_seconds=29.976
stage.pan_rad_toa.log_total_seconds=33.242
stage.pan_rpc_warp_quarters.log_total_seconds=674.393
stage.pansharpen_fusion.log_total_seconds=591.739
stage.tiff_to_envi.log_total_seconds=14.813

root@k8s-master:/home/pcl/code# cat artifacts/benchmarks/coregC1-2/report.txt
run_id=coregC1-2
namespace=gitlab-runner
pod=satellite-backend-64999d455d-9v2m5
task_id=86
pre_time=2026-04-30 11:02:28 +0800
post_time=2026-04-30 14:43:36 +0800
since_seconds=13298
--- runtime_config ---
SATELLITE_REMOTE_SENSING_COMMAND_HEARTBEAT_SECONDS=60
SATELLITE_REMOTE_SENSING_DEM_FILE=/opt/remote-sensing-data/dem/GMTED2010.jp2
SATELLITE_REMOTE_SENSING_FUSION_BLOCK_SIZE=1024
SATELLITE_REMOTE_SENSING_FUSION_GDAL_THREADS=1
SATELLITE_REMOTE_SENSING_FUSION_STAGE_TIMEOUT_SECONDS=1500
SATELLITE_REMOTE_SENSING_PANSHARPEN_GDAL_THREADS=1
SATELLITE_REMOTE_SENSING_PANSHARPEN_MODE=parallel
SATELLITE_REMOTE_SENSING_PANSHARPEN_PARALLELISM=3
SATELLITE_REMOTE_SENSING_PAN_RPC_CPU_THREADS=1
SATELLITE_REMOTE_SENSING_PAN_RPC_MAX_TOTAL_WARP_MEM_MB=2048
SATELLITE_REMOTE_SENSING_PAN_RPC_PARALLELISM=2
SATELLITE_REMOTE_SENSING_PAN_RPC_RESAMPLE_ALG=near
SATELLITE_REMOTE_SENSING_PAN_RPC_WARP_MEM_MB=1024
SATELLITE_REMOTE_SENSING_PERSIST_OUTPUT_DIR=persist_output_preprocessing
SATELLITE_REMOTE_SENSING_STAGE_MAX_RETRIES=1
SATELLITE_REMOTE_SENSING_STAGE_TIMEOUT_SECONDS=1800
--- task_summary ---
task.status=completed
task.current_stage=
task.created_at=2026-04-30T11:03:06.900601+08:00
task.started_at=2026-04-30T11:03:07.230776+08:00
task.finished_at=2026-04-30T11:21:19.425547+08:00
task.elapsed_seconds=1092.195
--- cpu_delta ---
cpu.nr_throttled.delta=1575
cpu.throttled_usec.delta=70844195
cpu.usage_usec.delta=1138518120
--- nfs_delta ---
nfs.output.normal_read.delta=2120107097
nfs.output.normal_write.delta=3279510586
nfs.output.direct_read.delta=0
nfs.output.direct_write.delta=0
nfs.output.server_read.delta=2025392085
nfs.output.server_write.delta=3279510586
nfs.output.read_pages.delta=494484
nfs.output.write_pages.delta=800664
nfs.input.normal_read.delta=2120107097
nfs.input.normal_write.delta=3279510586
nfs.input.direct_read.delta=0
nfs.input.direct_write.delta=0
nfs.input.server_read.delta=2025392085
nfs.input.server_write.delta=3279510586
nfs.input.read_pages.delta=494484
nfs.input.write_pages.delta=800664
--- stage_time ---
stage.fusion_stack_envi.elapsed_seconds=128.315
stage.mss_coregister_to_pan.elapsed_seconds=226.636
stage.mss_rad_quac_rpc.elapsed_seconds=58.880
stage.pan_merge_warp_square.elapsed_seconds=30.184
stage.pan_rad_toa.elapsed_seconds=23.682
stage.pan_rpc_warp_quarters.elapsed_seconds=362.952
stage.pansharpen_fusion.elapsed_seconds=229.097
stage.tiff_to_envi_mss.elapsed_seconds=6.214
stage.tiff_to_envi_pan.elapsed_seconds=25.515
--- stage_time_from_logs ---
stage.fusion_stack_envi.log_total_seconds=124.050
stage.mss_coregister_to_pan.log_total_seconds=226.387
stage.mss_rad_quac_rpc.log_total_seconds=58.290
stage.pan_merge_warp_square.log_total_seconds=29.801
stage.pan_rad_toa.log_total_seconds=23.014
stage.pan_rpc_warp_quarters.log_total_seconds=682.737
stage.pansharpen_fusion.log_total_seconds=594.429
stage.tiff_to_envi.log_total_seconds=30.349