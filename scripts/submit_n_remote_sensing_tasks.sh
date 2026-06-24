#!/usr/bin/env bash
# Phase 4：并行提交 N 条 GF2 全链路任务，轮询完成并输出 CSV 报告
set -euo pipefail

usage() {
  cat <<'EOF'
用法:
  scripts/submit_n_remote_sensing_tasks.sh \
    --run-id phase4-test1 \
    --count 3 \
    [--api-base http://127.0.0.1:8080] \
    [--file-prefix GF2_PMS1_E118.6_N37.4_20160826_L1A0001792619] \
    [--poll-interval 30] \
    [--timeout 7200]

说明:
  1) 并行 POST /api/remote-sensing/tasks（enableDetection=true）
  2) 轮询 GET /api/remote-sensing/tasks/:id 直到全部 completed 或 failed/timeout
  3) 输出 artifacts/benchmarks/<run-id>/summary.csv 与 report.txt

API 基址默认从 kubectl port-forward 或 NodePort 获取；集群内可:
  --api-base http://satellite-backend.gitlab-runner.svc.cluster.local:8080
EOF
}

RUN_ID=""
COUNT=3
API_BASE="${SATELLITE_API_BASE:-http://127.0.0.1:8080}"
FILE_PREFIX="GF2_PMS1_E118.6_N37.4_20160826_L1A0001792619"
POLL_INTERVAL=30
TIMEOUT_SEC=7200

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id) RUN_ID="$2"; shift 2 ;;
    --count) COUNT="$2"; shift 2 ;;
    --api-base) API_BASE="$2"; shift 2 ;;
    --file-prefix) FILE_PREFIX="$2"; shift 2 ;;
    --poll-interval) POLL_INTERVAL="$2"; shift 2 ;;
    --timeout) TIMEOUT_SEC="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1"; usage; exit 1 ;;
  esac
done

if [[ -z "${RUN_ID}" ]]; then
  echo "必须提供 --run-id"
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "需要 curl"
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "需要 jq"
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "需要 python3（解析 ISO8601 时间）"
  exit 1
fi

iso_elapsed() {
  python3 -c '
import json,sys
from datetime import datetime
obj=json.loads(sys.argv[1])
st,ft=obj.get("started_at"),obj.get("finished_at")
if not st or not ft:
    print(0); raise SystemExit
a=datetime.fromisoformat(st.replace("Z","+00:00"))
b=datetime.fromisoformat(ft.replace("Z","+00:00"))
print(max(0,(b-a).total_seconds()))
' "$1"
}

stage_elapsed() {
  python3 -c '
import json,sys
from datetime import datetime
stages=json.loads(sys.argv[1])
name=sys.argv[2]
for item in stages:
    if item.get("name")!=name:
        continue
    st,ft=item.get("started_at"),item.get("finished_at")
    if not st or not ft:
        print(0); raise SystemExit
    a=datetime.fromisoformat(st.replace("Z","+00:00"))
    b=datetime.fromisoformat(ft.replace("Z","+00:00"))
    print(max(0,(b-a).total_seconds())); raise SystemExit
print(0)
' "$1" "$2"
}

RUN_DIR="artifacts/benchmarks/${RUN_ID}"
mkdir -p "${RUN_DIR}"
TASK_IDS_FILE="${RUN_DIR}/task_ids.txt"
CSV="${RUN_DIR}/summary.csv"
REPORT="${RUN_DIR}/report.txt"
: > "${TASK_IDS_FILE}"

echo "run_id=${RUN_ID}" | tee "${REPORT}"
echo "api_base=${API_BASE}" | tee -a "${REPORT}"
echo "count=${COUNT}" | tee -a "${REPORT}"
echo "file_prefix=${FILE_PREFIX}" | tee -a "${REPORT}"
echo "started_at=$(date '+%Y-%m-%d %H:%M:%S %z')" | tee -a "${REPORT}"

submit_one() {
  local idx="$1"
  local body
  body=$(jq -n \
    --arg name "${RUN_ID}-task-${idx}" \
    --arg fp "${FILE_PREFIX}" \
    '{name: $name, filePrefix: $fp, inputDirectory: "input", sensor: "GF2", enableDetection: true, detectionDrawLabels: true}')
  curl -sf -X POST "${API_BASE}/api/remote-sensing/tasks" \
    -H "Content-Type: application/json" \
    -d "${body}"
}

echo "提交 ${COUNT} 条任务..."
for i in $(seq 1 "${COUNT}"); do
  resp="$(submit_one "${i}")" || { echo "提交失败 idx=${i}"; exit 1; }
  tid="$(echo "${resp}" | jq -r '.id // .ID // empty')"
  if [[ -z "${tid}" ]]; then
    echo "无法解析 task id: ${resp}"
    exit 1
  fi
  echo "${tid}" >> "${TASK_IDS_FILE}"
  echo "  submitted task_id=${tid}"
done

mapfile -t TASK_IDS < "${TASK_IDS_FILE}"
echo "task_ids=${TASK_IDS[*]}" | tee -a "${REPORT}"

echo "task_id,status,elapsed_seconds,pan_rpc_seconds,detection_seconds" > "${CSV}"

deadline=$(( $(date +%s) + TIMEOUT_SEC ))
pending=("${TASK_IDS[@]}")

while ((${#pending[@]} > 0)); do
  now=$(date +%s)
  if (( now >= deadline )); then
    echo "timeout after ${TIMEOUT_SEC}s; pending: ${pending[*]}" | tee -a "${REPORT}"
    exit 1
  fi
  still=()
  for tid in "${pending[@]}"; do
    task="$(curl -sf "${API_BASE}/api/remote-sensing/tasks/${tid}")" || { still+=("${tid}"); continue; }
    status="$(echo "${task}" | jq -r '.status // empty')"
    case "${status}" in
      completed|failed|cancelled)
        elapsed="$(iso_elapsed "${task}")"
        stages="$(curl -sf "${API_BASE}/api/remote-sensing/tasks/${tid}/stages" 2>/dev/null || echo '[]')"
        pan_rpc="$(stage_elapsed "${stages}" "pan_rpc_warp_quarters")"
        detection="$(stage_elapsed "${stages}" "object_detection")"
        echo "${tid},${status},${elapsed},${pan_rpc},${detection}" >> "${CSV}"
        echo "  task ${tid} -> ${status}" | tee -a "${REPORT}"
        ;;
      *)
        still+=("${tid}")
        ;;
    esac
  done
  pending=("${still[@]}")
  if ((${#pending[@]} > 0)); then
    echo "waiting ${#pending[@]} tasks... (${pending[*]})"
    sleep "${POLL_INTERVAL}"
  fi
done

echo "finished_at=$(date '+%Y-%m-%d %H:%M:%S %z')" | tee -a "${REPORT}"
echo "summary_csv=${CSV}" | tee -a "${REPORT}"
echo "完成。查看 ${REPORT} 与 ${CSV}"
