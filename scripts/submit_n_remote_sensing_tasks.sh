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
    [--max-in-flight 3] \
    [--poll-interval 30] \
    [--timeout 7200]

说明:
  1) POST /api/remote-sensing/tasks（enableDetection=true）
  2) 同一 filePrefix 时中间产物路径全局共享（persist/pan_warp_quarters 等），
     **必须 --max-in-flight 1**（默认已为 1）：上一 task completed 后才提交下一 task。
     测的是「队列堆积 + Prometheus 指标」，不是 10 路同时写 NFS。
  3) --max-in-flight >1 仅在同 prefix 已做 task 级目录隔离后使用（Phase 5+）
  4) 输出 artifacts/benchmarks/<run-id>/summary.csv 与 report.txt

压测前建议:
  kubectl -n gitlab-runner scale deploy/rs-worker --replicas=1
  kubectl -n gitlab-runner patch hpa rs-worker -p '{"spec":{"maxReplicas":1}}'
  # 若刚跑过失败 burst，清理共享中间目录（见 PHASE4_RUNBOOK §2.1）
EOF
}

RUN_ID=""
COUNT=3
API_BASE="${SATELLITE_API_BASE:-http://127.0.0.1:8080}"
FILE_PREFIX="GF2_PMS1_E118.6_N37.4_20160826_L1A0001792619"
MAX_IN_FLIGHT=""
POLL_INTERVAL=30
TIMEOUT_SEC=7200

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id) RUN_ID="$2"; shift 2 ;;
    --count) COUNT="$2"; shift 2 ;;
    --api-base) API_BASE="$2"; shift 2 ;;
    --file-prefix) FILE_PREFIX="$2"; shift 2 ;;
    --max-in-flight) MAX_IN_FLIGHT="$2"; shift 2 ;;
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

if [[ -z "${MAX_IN_FLIGHT}" ]]; then
  # 同 filePrefix 共享 NFS 路径；>1 会 pan_merge / Argo workers 互相覆盖
  MAX_IN_FLIGHT=1
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

PY_TIME_HELPER='
import json, re, sys
from datetime import datetime

def normalize_iso(s):
    if not s:
        return s
    s = s.replace("Z", "+00:00")
    m = re.match(r"^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(\.\d+)?([+-]\d{2}:\d{2})$", s)
    if not m:
        return s
    base, frac, tz = m.groups()
    if frac:
        digits = (frac[1:] + "000000")[:6]
        frac = "." + digits
    else:
        frac = ""
    return base + frac + tz

def parse_iso(s):
    return datetime.fromisoformat(normalize_iso(s))
'

iso_elapsed() {
  python3 -c "${PY_TIME_HELPER}
obj=json.loads(sys.argv[1])
st,ft=obj.get('started_at'),obj.get('finished_at')
if not st or not ft:
    print(0); raise SystemExit
a=parse_iso(st); b=parse_iso(ft)
print(max(0,(b-a).total_seconds()))
" "$1"
}

stage_elapsed() {
  python3 -c "${PY_TIME_HELPER}
stages=json.loads(sys.argv[1])
name=sys.argv[2]
for item in stages:
    if item.get('name')!=name:
        continue
    st,ft=item.get('started_at'),item.get('finished_at')
    if not st or not ft:
        print(0); raise SystemExit
    a=parse_iso(st); b=parse_iso(ft)
    print(max(0,(b-a).total_seconds())); raise SystemExit
print(0)
" "$1" "$2"
}

task_status() {
  local tid="$1"
  curl -sf "${API_BASE}/api/remote-sensing/tasks/${tid}" 2>/dev/null | jq -r '.status // empty' || echo ""
}

count_in_flight() {
  local tid st n=0
  for tid in "$@"; do
    st="$(task_status "${tid}")"
    case "${st}" in
      pending|running|queued|"") n=$((n + 1)) ;;
    esac
  done
  echo "${n}"
}

record_terminal_task() {
  local tid="$1"
  local task stages elapsed pan_rpc detection status
  task="$(curl -sf "${API_BASE}/api/remote-sensing/tasks/${tid}")"
  status="$(echo "${task}" | jq -r '.status // empty')"
  elapsed="$(iso_elapsed "${task}")"
  stages="$(curl -sf "${API_BASE}/api/remote-sensing/tasks/${tid}/stages" 2>/dev/null || echo '[]')"
  pan_rpc="$(stage_elapsed "${stages}" "pan_rpc_warp_quarters")"
  detection="$(stage_elapsed "${stages}" "object_detection")"
  echo "${tid},${status},${elapsed},${pan_rpc},${detection}" >> "${CSV}"
  echo "  task ${tid} -> ${status}" | tee -a "${REPORT}"
}

RUN_DIR="artifacts/benchmarks/${RUN_ID}"
if [[ -e "${RUN_DIR}" && ! -w "${RUN_DIR}" ]]; then
  echo "错误: ${RUN_DIR} 不可写（常见原因：曾用 sudo 运行脚本，目录属 root）"
  echo "修复: sudo chown -R \"\$(whoami):\$(whoami)\" artifacts/benchmarks"
  echo "  或: sudo rm -rf \"${RUN_DIR}\""
  exit 1
fi
mkdir -p "${RUN_DIR}" || { echo "无法创建 ${RUN_DIR}"; exit 1; }
TASK_IDS_FILE="${RUN_DIR}/task_ids.txt"
CSV="${RUN_DIR}/summary.csv"
REPORT="${RUN_DIR}/report.txt"
: > "${TASK_IDS_FILE}" || { echo "无法写入 ${TASK_IDS_FILE}（检查目录权限）"; exit 1; }

echo "run_id=${RUN_ID}" | tee "${REPORT}"
echo "api_base=${API_BASE}" | tee -a "${REPORT}"
echo "count=${COUNT}" | tee -a "${REPORT}"
echo "max_in_flight=${MAX_IN_FLIGHT}" | tee -a "${REPORT}"
echo "file_prefix=${FILE_PREFIX}" | tee -a "${REPORT}"
echo "started_at=$(date '+%Y-%m-%d %H:%M:%S %z')" | tee -a "${REPORT}"
if (( COUNT > 1 && MAX_IN_FLIGHT <= 1 )); then
  echo "note=同 filePrefix 串行执行(in-flight=1)；10 路验收=10 条依次完成+队列指标" | tee -a "${REPORT}"
elif (( MAX_IN_FLIGHT > 1 )); then
  echo "warn=max-in-flight=${MAX_IN_FLIGHT}>1 同 prefix 可能 NFS 冲突" | tee -a "${REPORT}"
fi

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

declare -a TASK_IDS=()
declare -A RECORDED=()
next_submit_idx=1
submitted_total=0

echo "task_id,status,elapsed_seconds,pan_rpc_seconds,detection_seconds" > "${CSV}"

deadline=$(( $(date +%s) + TIMEOUT_SEC ))

submit_batch() {
  local tid resp
  echo "提交任务 idx=${next_submit_idx}（已提交 ${submitted_total}/${COUNT}，max-in-flight=${MAX_IN_FLIGHT}）..."
  resp="$(submit_one "${next_submit_idx}")" || { echo "提交失败 idx=${next_submit_idx}"; exit 1; }
  tid="$(echo "${resp}" | jq -r '.id // .ID // empty')"
  if [[ -z "${tid}" ]]; then
    echo "无法解析 task id: ${resp}"
    exit 1
  fi
  TASK_IDS+=("${tid}")
  echo "${tid}" >> "${TASK_IDS_FILE}"
  echo "  submitted task_id=${tid}"
  submitted_total=$((submitted_total + 1))
  next_submit_idx=$((next_submit_idx + 1))
}

echo "开始提交（in-flight 上限 ${MAX_IN_FLIGHT}）..."
while (( submitted_total < COUNT )); do
  in_flight=0
  if ((${#TASK_IDS[@]} > 0)); then
    in_flight="$(count_in_flight "${TASK_IDS[@]}")"
  fi
  if (( in_flight < MAX_IN_FLIGHT && submitted_total < COUNT )); then
    submit_batch
  else
    break
  fi
done

echo "task_ids=${TASK_IDS[*]:-}" | tee -a "${REPORT}"

while true; do
  now=$(date +%s)
  if (( now >= deadline )); then
    echo "timeout after ${TIMEOUT_SEC}s" | tee -a "${REPORT}"
    echo "pending task_ids: ${TASK_IDS[*]}" | tee -a "${REPORT}"
    exit 1
  fi

  # 记录已终态 task
  pending_terminal=0
  for tid in "${TASK_IDS[@]}"; do
    if [[ -n "${RECORDED[$tid]+x}" ]]; then
      continue
    fi
    st="$(task_status "${tid}")"
    case "${st}" in
      completed|failed|cancelled)
        record_terminal_task "${tid}"
        RECORDED[$tid]=1
        ;;
      *)
        pending_terminal=$((pending_terminal + 1))
        ;;
    esac
  done

  # 有空位则继续提交
  if (( submitted_total < COUNT )); then
    in_flight="$(count_in_flight "${TASK_IDS[@]}")"
    while (( in_flight < MAX_IN_FLIGHT && submitted_total < COUNT )); do
      submit_batch
      in_flight="$(count_in_flight "${TASK_IDS[@]}")"
    done
  fi

  if (( submitted_total >= COUNT )); then
    all_recorded=1
    for tid in "${TASK_IDS[@]}"; do
      if [[ -z "${RECORDED[$tid]+x}" ]]; then
        all_recorded=0
        break
      fi
    done
    if (( all_recorded )); then
      break
    fi
  fi

  echo "waiting in-flight=${pending_terminal} submitted=${submitted_total}/${COUNT}..."
  sleep "${POLL_INTERVAL}"
done

echo "finished_at=$(date '+%Y-%m-%d %H:%M:%S %z')" | tee -a "${REPORT}"
echo "summary_csv=${CSV}" | tee -a "${REPORT}"
echo "完成。查看 ${REPORT} 与 ${CSV}"
