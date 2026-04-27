#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
用法:
  scripts/remote_sensing_stage1_benchmark.sh pre  --run-id <id> [--namespace gitlab-runner] [--selector app=satellite-backend] [--clean-scratch]
  scripts/remote_sensing_stage1_benchmark.sh post --run-id <id> --task-id <id> [--namespace gitlab-runner] [--selector app=satellite-backend]

说明:
  1) pre: 采集任务开始前快照（CPU cgroup + NFS mountstats bytes）
          可选 --clean-scratch 会先清空 /opt/remote-sensing/output_preprocessing/*
  2) post: 采集任务结束后快照，并输出 delta 报告与阶段耗时汇总
EOF
}

MODE="${1:-}"
if [[ -z "${MODE}" ]]; then
  usage
  exit 1
fi
shift || true

NAMESPACE="gitlab-runner"
SELECTOR="app=satellite-backend"
RUN_ID=""
TASK_ID=""
BASE_DIR="artifacts/benchmarks"
CLEAN_SCRATCH="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace)
      NAMESPACE="$2"; shift 2 ;;
    --selector)
      SELECTOR="$2"; shift 2 ;;
    --run-id)
      RUN_ID="$2"; shift 2 ;;
    --task-id)
      TASK_ID="$2"; shift 2 ;;
    --clean-scratch)
      CLEAN_SCRATCH="true"; shift 1 ;;
    *)
      echo "未知参数: $1"
      usage
      exit 1 ;;
  esac
done

if [[ -z "${RUN_ID}" ]]; then
  echo "必须提供 --run-id"
  exit 1
fi

RUN_DIR="${BASE_DIR}/${RUN_ID}"
mkdir -p "${RUN_DIR}"

POD="$(kubectl -n "${NAMESPACE}" get pod -l "${SELECTOR}" -o jsonpath='{.items[0].metadata.name}')"
if [[ -z "${POD}" ]]; then
  echo "未找到后端 Pod: namespace=${NAMESPACE}, selector=${SELECTOR}"
  exit 1
fi

collect_cpu_stat() {
  kubectl -n "${NAMESPACE}" exec "${POD}" -- sh -lc 'cat /sys/fs/cgroup/cpu.stat 2>/dev/null || cat /sys/fs/cgroup/cpu/cpu.stat'
}

collect_nfs_bytes() {
  kubectl -n "${NAMESPACE}" exec "${POD}" -- sh -lc 'cat /proc/self/mountstats' | awk '
    $1=="device" && $2 ~ /:\/export\/remote-sensing-data\/input$/ {section="input"; next}
    $1=="device" && $2 ~ /:\/export\/remote-sensing-data\/output_preprocessing$/ {section="output"; next}
    $1=="device" {section=""}
    section!="" && $1=="bytes:" {print section":"$2","$3","$4","$5","$6","$7","$8","$9; section=""}
  '
}

collect_runtime_config() {
  kubectl -n "${NAMESPACE}" exec "${POD}" -- sh -lc '
    env | grep -E "^SATELLITE_REMOTE_SENSING_(PAN_RPC|PANSHARPEN|FUSION|DEM_FILE|PERSIST_OUTPUT_DIR|STAGE_TIMEOUT_SECONDS|FUSION_STAGE_TIMEOUT_SECONDS|STAGE_MAX_RETRIES|COMMAND_HEARTBEAT_SECONDS)" | sort
  '
}

clean_scratch_dir() {
  kubectl -n "${NAMESPACE}" exec "${POD}" -- sh -lc '
    rm -rf /opt/remote-sensing/output_preprocessing/* /opt/remote-sensing/output_preprocessing/.[!.]* /opt/remote-sensing/output_preprocessing/..?* 2>/dev/null || true
  '
}

write_snapshot() {
  local prefix="$1"
  date '+%F %T %z' > "${RUN_DIR}/${prefix}_timestamp.txt"
  date +%s > "${RUN_DIR}/${prefix}_epoch.txt"
  collect_cpu_stat > "${RUN_DIR}/${prefix}_cpu.stat"
  collect_nfs_bytes > "${RUN_DIR}/${prefix}_nfs.bytes"
}

if [[ "${MODE}" == "pre" ]]; then
  if [[ "${CLEAN_SCRATCH}" == "true" ]]; then
    clean_scratch_dir
    echo "已清理 scratch: /opt/remote-sensing/output_preprocessing/*"
  fi
  write_snapshot "pre"
  echo "已写入 pre 快照: ${RUN_DIR}"
  exit 0
fi

if [[ "${MODE}" != "post" ]]; then
  usage
  exit 1
fi

if [[ -z "${TASK_ID}" ]]; then
  echo "post 模式必须提供 --task-id"
  exit 1
fi

if [[ ! -f "${RUN_DIR}/pre_epoch.txt" ]]; then
  echo "缺少 pre 快照，请先执行 pre"
  exit 1
fi

write_snapshot "post"

PRE_EPOCH="$(cat "${RUN_DIR}/pre_epoch.txt")"
NOW_EPOCH="$(date +%s)"
SINCE_SEC=$((NOW_EPOCH - PRE_EPOCH + 30))
if [[ "${SINCE_SEC}" -lt 60 ]]; then
  SINCE_SEC=60
fi

calc_cpu_delta() {
  awk '
    FNR==NR {pre[$1]=$2; next}
    {post[$1]=$2}
    END {
      if (("nr_throttled" in pre) && ("nr_throttled" in post)) {
        printf("cpu.nr_throttled.delta=%d\n", post["nr_throttled"]-pre["nr_throttled"])
      }
      if (("throttled_usec" in pre) && ("throttled_usec" in post)) {
        printf("cpu.throttled_usec.delta=%d\n", post["throttled_usec"]-pre["throttled_usec"])
      }
      if (("usage_usec" in pre) && ("usage_usec" in post)) {
        printf("cpu.usage_usec.delta=%d\n", post["usage_usec"]-pre["usage_usec"])
      }
    }
  ' "${RUN_DIR}/pre_cpu.stat" "${RUN_DIR}/post_cpu.stat"
}

calc_nfs_delta() {
  awk -F'[: ,]+' '
    FNR==NR {
      if ($1=="input" || $1=="output") {
        for(i=2;i<=9;i++) pre[$1,i]=$i
      }
      next
    }
    {
      if ($1=="input" || $1=="output") {
        for(i=2;i<=9;i++) post[$1,i]=$i
      }
    }
    END {
      labels[2]="normal_read"; labels[3]="normal_write";
      labels[4]="direct_read"; labels[5]="direct_write";
      labels[6]="server_read"; labels[7]="server_write";
      labels[8]="read_pages"; labels[9]="write_pages";
      for (m in post) { }
      for (mount in mounts) { }
      split("input output", ms, " ")
      for (j in ms) {
        mount=ms[j]
        for(i=2;i<=9;i++){
          if ((mount SUBSEP i) in pre && (mount SUBSEP i) in post) {
            delta=post[mount,i]-pre[mount,i]
            printf("nfs.%s.%s.delta=%.0f\n", mount, labels[i], delta)
          }
        }
      }
    }
  ' "${RUN_DIR}/pre_nfs.bytes" "${RUN_DIR}/post_nfs.bytes"
}

collect_stage_times() {
  kubectl -n "${NAMESPACE}" exec "${POD}" -- sh -lc "
    curl -fsS http://127.0.0.1:8080/api/remote-sensing/tasks/${TASK_ID}/stages \
    | /opt/remote-sensing/.venv/bin/python -c '
import json,sys
from datetime import datetime
s=json.load(sys.stdin)
for item in s:
    st=item.get(\"started_at\")
    ft=item.get(\"finished_at\")
    name=item.get(\"name\")
    if not st or not ft or not name:
        continue
    try:
        a=datetime.fromisoformat(st.replace(\"Z\",\"+00:00\"))
        b=datetime.fromisoformat(ft.replace(\"Z\",\"+00:00\"))
    except Exception:
        continue
    sec=(b-a).total_seconds()
    if sec < 0:
        continue
    print(f\"stage.{name}.elapsed_seconds={sec:.3f}\")
'
  " | sort
}

collect_stage_times_from_logs() {
  kubectl -n "${NAMESPACE}" exec "${POD}" -- sh -lc "
    curl -fsS 'http://127.0.0.1:8080/api/remote-sensing/tasks/${TASK_ID}/logs?limit=500' \
    | /opt/remote-sensing/.venv/bin/python -c '
import json,re,sys

data=json.load(sys.stdin)

# 脚本名到阶段名映射
script_to_stage={
    \"tiff_to_envi\":\"tiff_to_envi\",
    \"pan_rad_toa\":\"pan_rad_toa\",
    \"pan_rpc_warp_quarters\":\"pan_rpc_warp_quarters\",
    \"pan_merge_warp_square\":\"pan_merge_warp_square\",
    \"mss_rad_quac_rpc\":\"mss_rad_quac_rpc\",
    \"mss_coregister_to_pan\":\"mss_coregister_to_pan\",
    \"pansharpen_fusion\":\"pansharpen_fusion\",
    \"fusion_stack_envi\":\"fusion_stack_envi\",
    \"imgshow\":\"fusion_stack_envi\",
}

totals={}
pat=re.compile(r\"([a-zA-Z0-9_]+) 总时间:\\s*([0-9]+(?:\\.[0-9]+)?)\")

for item in data:
    content=item.get(\"content\") or \"\"
    for line in content.splitlines():
        m=pat.search(line)
        if not m:
            continue
        script_name=m.group(1)
        sec=float(m.group(2))
        stage=script_to_stage.get(script_name)
        if not stage:
            continue
        totals[stage]=totals.get(stage,0.0)+sec

for stage in sorted(totals.keys()):
    print(f\"stage.{stage}.log_total_seconds={totals[stage]:.3f}\")
'
  " | sort
}

collect_task_summary() {
  kubectl -n "${NAMESPACE}" exec "${POD}" -- sh -lc "
    curl -fsS 'http://127.0.0.1:8080/api/remote-sensing/tasks' \
    | /opt/remote-sensing/.venv/bin/python -c '
import json,sys
from datetime import datetime

target=int(\"${TASK_ID}\")
tasks=json.load(sys.stdin)
task=None
for item in tasks:
    if int(item.get(\"id\", -1)) == target:
        task=item
        break
if task is None:
    print(\"task.status=not_found\")
    raise SystemExit(0)

print(\"task.status=%s\" % task.get(\"status\", \"\"))
print(\"task.current_stage=%s\" % task.get(\"current_stage\", \"\"))
print(\"task.created_at=%s\" % task.get(\"created_at\", \"\"))
print(\"task.started_at=%s\" % task.get(\"started_at\", \"\"))
print(\"task.finished_at=%s\" % task.get(\"finished_at\", \"\"))

st=task.get(\"started_at\")
ft=task.get(\"finished_at\")
if st and ft:
    try:
        a=datetime.fromisoformat(st.replace(\"Z\",\"+00:00\"))
        b=datetime.fromisoformat(ft.replace(\"Z\",\"+00:00\"))
        sec=(b-a).total_seconds()
        if sec >= 0:
            print(\"task.elapsed_seconds=%.3f\" % sec)
    except Exception:
        pass
'
  "
}

{
  echo "run_id=${RUN_ID}"
  echo "namespace=${NAMESPACE}"
  echo "pod=${POD}"
  echo "task_id=${TASK_ID}"
  echo "pre_time=$(cat "${RUN_DIR}/pre_timestamp.txt")"
  echo "post_time=$(cat "${RUN_DIR}/post_timestamp.txt")"
  echo "since_seconds=${SINCE_SEC}"
  echo "--- runtime_config ---"
  collect_runtime_config
  echo "--- task_summary ---"
  collect_task_summary
  echo "--- cpu_delta ---"
  calc_cpu_delta
  echo "--- nfs_delta ---"
  calc_nfs_delta
  echo "--- stage_time ---"
  collect_stage_times
  echo "--- stage_time_from_logs ---"
  collect_stage_times_from_logs
} > "${RUN_DIR}/report.txt"

echo "已生成报告: ${RUN_DIR}/report.txt"
