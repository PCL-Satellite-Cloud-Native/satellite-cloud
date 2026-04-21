root@k8s-master:/home/pcl/code# cat artifacts/benchmarks/step2_2_4/report.txt
run_id=step2_2_4
namespace=gitlab-runner
pod=satellite-backend-8dfcbddc5-42tdb
task_id=35
pre_time=2026-04-21 09:45:18 +0800
post_time=2026-04-21 10:26:41 +0800
since_seconds=2514
--- cpu_delta ---
cpu.nr_throttled.delta=3408
cpu.throttled_usec.delta=687133787
cpu.usage_usec.delta=1325249359
--- nfs_delta ---
nfs.output.normal_read.delta=2116136697
nfs.output.normal_write.delta=3279509578
nfs.output.direct_read.delta=0
nfs.output.direct_write.delta=0
nfs.output.server_read.delta=2024687634
nfs.output.server_write.delta=3279509578
nfs.output.read_pages.delta=494313
nfs.output.write_pages.delta=800664
nfs.input.normal_read.delta=2116136697
nfs.input.normal_write.delta=3279509578
nfs.input.direct_read.delta=0
nfs.input.direct_write.delta=0
nfs.input.server_read.delta=2024687634
nfs.input.server_write.delta=3279509578
nfs.input.read_pages.delta=494313
nfs.input.write_pages.delta=800664
--- stage_time ---
stage.fusion_stack_envi.elapsed_seconds=129.688
stage.mss_coregister_to_pan.elapsed_seconds=130.057
stage.mss_rad_quac_rpc.elapsed_seconds=69.932
stage.pan_merge_warp_square.elapsed_seconds=31.241
stage.pan_rad_toa.elapsed_seconds=34.799
stage.pan_rpc_warp_quarters.elapsed_seconds=463.181
stage.pansharpen_fusion.elapsed_seconds=208.487
stage.tiff_to_envi_mss.elapsed_seconds=15.002
stage.tiff_to_envi_pan.elapsed_seconds=22.309
--- stage_time_from_logs ---
stage.fusion_stack_envi.log_total_seconds=123.950
stage.mss_coregister_to_pan.log_total_seconds=129.335
stage.mss_rad_quac_rpc.log_total_seconds=69.443
stage.pan_merge_warp_square.log_total_seconds=30.861
stage.pan_rad_toa.log_total_seconds=34.044
stage.pan_rpc_warp_quarters.log_total_seconds=850.493
stage.pansharpen_fusion.log_total_seconds=555.426
stage.tiff_to_envi.log_total_seconds=29.926

root@k8s-master:/home/pcl/code# cat artifacts/benchmarks/step2_2_5/report.txt
run_id=step2_2_5
namespace=gitlab-runner
pod=satellite-backend-8dfcbddc5-42tdb
task_id=36
pre_time=2026-04-21 10:27:01 +0800
post_time=2026-04-21 10:44:23 +0800
since_seconds=1072
--- cpu_delta ---
cpu.nr_throttled.delta=2377
cpu.throttled_usec.delta=72156603
cpu.usage_usec.delta=1108033522
--- nfs_delta ---
nfs.output.normal_read.delta=2127555866
nfs.output.normal_write.delta=2950955008
nfs.output.direct_read.delta=0
nfs.output.direct_write.delta=0
nfs.output.server_read.delta=2026417288
nfs.output.server_write.delta=2424307712
nfs.output.read_pages.delta=494736
nfs.output.write_pages.delta=591872
nfs.input.normal_read.delta=2127555866
nfs.input.normal_write.delta=2950955008
nfs.input.direct_read.delta=0
nfs.input.direct_write.delta=0
nfs.input.server_read.delta=2026417288
nfs.input.server_write.delta=2424307712
nfs.input.read_pages.delta=494736
nfs.input.write_pages.delta=591872
--- stage_time ---
stage.fusion_stack_envi.elapsed_seconds=120.273
stage.mss_coregister_to_pan.elapsed_seconds=0.987
stage.mss_rad_quac_rpc.elapsed_seconds=68.053
stage.pan_merge_warp_square.elapsed_seconds=36.606
stage.pan_rad_toa.elapsed_seconds=35.265
stage.pan_rpc_warp_quarters.elapsed_seconds=474.891
stage.pansharpen_fusion.elapsed_seconds=216.333
stage.tiff_to_envi_mss.elapsed_seconds=14.911
stage.tiff_to_envi_pan.elapsed_seconds=17.875
--- stage_time_from_logs ---
stage.fusion_stack_envi.log_total_seconds=116.982
stage.mss_coregister_to_pan.log_total_seconds=0.384
stage.mss_rad_quac_rpc.log_total_seconds=67.508
stage.pan_merge_warp_square.log_total_seconds=36.156
stage.pan_rad_toa.log_total_seconds=34.646
stage.pan_rpc_warp_quarters.log_total_seconds=860.220
stage.pansharpen_fusion.log_total_seconds=574.859
stage.tiff_to_envi.log_total_seconds=31.476

root@k8s-master:/home/pcl/code# cat artifacts/benchmarks/step2_2_6/report.txt
run_id=step2_2_6
namespace=gitlab-runner
pod=satellite-backend-8dfcbddc5-42tdb
task_id=37
pre_time=2026-04-21 10:44:40 +0800
post_time=2026-04-21 14:26:58 +0800
since_seconds=13368
--- cpu_delta ---
cpu.nr_throttled.delta=2363
cpu.throttled_usec.delta=72393747
cpu.usage_usec.delta=1110513040
--- nfs_delta ---
nfs.output.normal_read.delta=2127555866
nfs.output.normal_write.delta=3279509578
nfs.output.direct_read.delta=0
nfs.output.direct_write.delta=0
nfs.output.server_read.delta=2024720402
nfs.output.server_write.delta=3279509578
nfs.output.read_pages.delta=494321
nfs.output.write_pages.delta=800664
nfs.input.normal_read.delta=2127555866
nfs.input.normal_write.delta=3279509578
nfs.input.direct_read.delta=0
nfs.input.direct_write.delta=0
nfs.input.server_read.delta=2024720402
nfs.input.server_write.delta=3279509578
nfs.input.read_pages.delta=494321
nfs.input.write_pages.delta=800664
--- stage_time ---
stage.fusion_stack_envi.elapsed_seconds=140.549
stage.mss_coregister_to_pan.elapsed_seconds=0.704
stage.mss_rad_quac_rpc.elapsed_seconds=65.129
stage.pan_merge_warp_square.elapsed_seconds=31.131
stage.pan_rad_toa.elapsed_seconds=33.865
stage.pan_rpc_warp_quarters.elapsed_seconds=467.212
stage.pansharpen_fusion.elapsed_seconds=207.424
stage.tiff_to_envi_mss.elapsed_seconds=5.441
stage.tiff_to_envi_pan.elapsed_seconds=15.132
--- stage_time_from_logs ---
stage.fusion_stack_envi.log_total_seconds=137.211
stage.mss_coregister_to_pan.log_total_seconds=0.102
stage.mss_rad_quac_rpc.log_total_seconds=64.632
stage.pan_merge_warp_square.log_total_seconds=30.792
stage.pan_rad_toa.log_total_seconds=33.262
stage.pan_rpc_warp_quarters.log_total_seconds=859.989
stage.pansharpen_fusion.log_total_seconds=553.711
stage.tiff_to_envi.log_total_seconds=19.480