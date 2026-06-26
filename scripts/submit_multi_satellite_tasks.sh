#!/usr/bin/env bash
# Phase 5：3 个 task × 3 个不同 satelliteId × 同一 filePrefix（多星并行 pilot）
set -euo pipefail

usage() {
  cat <<'EOF'
用法:
  scripts/submit_multi_satellite_tasks.sh \
    --run-id p5-multi-3 \
    [--api-base http://127.0.0.1:8080] \
    [--scenario-id 2] \
    [--count 3] \
    [--satellite-ids 42,43,44] \
    [--file-prefix GF2_PMS1_...] \
    [--poll-interval 30] \
    [--timeout 7200]

说明:
  1) 从场景取前 N 颗不同卫星（satellites.id 主键）
  2) 并行提交 N 个遥感任务（enableDetection=true，带 scenarioId + satelliteId）
  3) 轮询直到全部 completed / failed / 超时

警告: 同一 filePrefix 仍共享 NFS 中间目录（P5-05 未完成前可能 path 冲突）。
      本脚本用于验证拓扑绑定 + 调度日志；生产并行同景请先完成 P5-05。
EOF
}

RUN_ID=""
COUNT=3
SCENARIO_ID=""
SATELLITE_IDS=""
API_BASE="${SATELLITE_API_BASE:-http://127.0.0.1:8080}"
FILE_PREFIX="GF2_PMS1_E118.6_N37.4_20160826_L1A0001792619"
POLL_INTERVAL=30
TIMEOUT_SEC=7200

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id) RUN_ID="$2"; shift 2 ;;
    --count) COUNT="$2"; shift 2 ;;
    --scenario-id) SCENARIO_ID="$2"; shift 2 ;;
    --satellite-ids) SATELLITE_IDS="$2"; shift 2 ;;
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

for cmd in curl jq python3; do
  command -v "${cmd}" >/dev/null || { echo "需要 ${cmd}"; exit 1; }
done

if [[ -z "${SCENARIO_ID}" ]]; then
  SCENARIO_ID="$(curl -sf "${API_BASE}/api/scenarios" | jq -r '.results[0].id // empty')"
fi
if [[ -z "${SCENARIO_ID}" ]]; then
  echo "无法解析 scenario_id"
  exit 1
fi

OUT_DIR="artifacts/benchmarks/${RUN_ID}"
mkdir -p "${OUT_DIR}"

if [[ -n "${SATELLITE_IDS}" ]]; then
  IFS=',' read -r -a SAT_PK_LIST <<< "${SATELLITE_IDS}"
  if [[ ${#SAT_PK_LIST[@]} -lt ${COUNT} ]]; then
    COUNT=${#SAT_PK_LIST[@]}
  fi
  SAT_ROWS=()
  for (( i=0; i<COUNT; i++ )); do
    pk="${SAT_PK_LIST[$i]}"
    row="$(curl -sf "${API_BASE}/api/satellites/${pk}")"
    SAT_ROWS+=("${row}")
  done
else
# 从 pilot-map 取前 N 颗 Pilot 星，再在场景卫星列表中按 sat_id / stk_name / legacy 星历名解析 DB 主键
mapfile -t SAT_ROWS < <(python3 - "${API_BASE}" "${SCENARIO_ID}" "${COUNT}" <<'PY'
import json, sys, urllib.error, urllib.request

api, scenario_id, count = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])

def fetch(url):
    req = urllib.request.Request(url)
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)

def ephem_stk(orbit, slot):
    return f"Sat_{orbit + 5}_{slot + 5}"

try:
    pilot = fetch(f"{api}/api/topology/pilot-map")
    sats = fetch(f"{api}/api/scenarios/{scenario_id}/satellites")
except urllib.error.URLError as e:
    print(f"API 请求失败: {e}", file=sys.stderr)
    sys.exit(1)

if isinstance(sats, dict):
    sats = sats.get("results") or sats.get("satellites") or []

nodes = (pilot.get("nodes") or [])[:count]
if len(nodes) < count:
    print(f"pilot-map 不足 {count} 颗（enabled={pilot.get('enabled')}）", file=sys.stderr)
    sys.exit(1)

by_key = {}
for s in sats:
    for key in (s.get("sat_id"), s.get("stk_name")):
        if key:
            by_key[key] = s

selected = []
for e in nodes:
    sid = e["sat_id"]
    cand = by_key.get(sid) or by_key.get(e.get("sat_name")) or by_key.get(ephem_stk(e["orbit"], e["slot"]))
    if not cand:
        print(f"场景 {scenario_id} 未找到卫星 {sid} ({e.get('sat_name')} / {ephem_stk(e['orbit'], e['slot'])})", file=sys.stderr)
        sys.exit(1)
    selected.append(cand)

for row in selected:
    print(json.dumps(row, ensure_ascii=False))
PY
)
fi

if [[ ${#SAT_ROWS[@]} -lt ${COUNT} ]]; then
  echo "场景 ${SCENARIO_ID} 卫星不足 ${COUNT} 颗（解析到 ${#SAT_ROWS[@]} 颗）"
  echo "诊断: curl -s ${API_BASE}/api/scenarios/${SCENARIO_ID}/satellites | jq 'length'"
  exit 1
fi

echo "run_id=${RUN_ID} scenario_id=${SCENARIO_ID} count=${COUNT}"
echo "警告: 同 filePrefix 并行可能 NFS 冲突（P5-05 前请谨慎解读结果）"

TASK_IDS=()
for row in "${SAT_ROWS[@]}"; do
  sat_pk="$(echo "${row}" | jq -r '.id')"
  sat_label="$(echo "${row}" | jq -r '.sat_id')"
  resp="$(curl -sf -X POST "${API_BASE}/api/remote-sensing/tasks" \
    -H 'Content-Type: application/json' \
    -d "{\"filePrefix\":\"${FILE_PREFIX}\",\"inputDirectory\":\"input\",\"enableDetection\":true,\"scenarioId\":${SCENARIO_ID},\"satelliteId\":${sat_pk}}")"
  tid="$(echo "${resp}" | jq -r '.id')"
  TASK_IDS+=("${tid}")
  echo "submitted task_id=${tid} satellite_id=${sat_pk} (${sat_label})"
  echo "${resp}" | jq -c '{id,satellite_id,scenario_id,status}' >> "${OUT_DIR}/submitted.jsonl"
done

printf '%s\n' "${TASK_IDS[@]}" > "${OUT_DIR}/task_ids.txt"

deadline=$((SECONDS + TIMEOUT_SEC))
declare -A FINAL_STATUS

while (( SECONDS < deadline )); do
  pending=0
  for tid in "${TASK_IDS[@]}"; do
    st="${FINAL_STATUS[$tid]:-}"
    if [[ "${st}" == "completed" || "${st}" == "failed" ]]; then
      continue
    fi
    body="$(curl -sf "${API_BASE}/api/remote-sensing/tasks/${tid}")"
    st="$(echo "${body}" | jq -r '.status')"
    FINAL_STATUS["${tid}"]="${st}"
    if [[ "${st}" != "completed" && "${st}" != "failed" ]]; then
      pending=$((pending + 1))
    fi
  done
  if [[ ${pending} -eq 0 ]]; then
    break
  fi
  echo "$(date -Is) pending=${pending}/${#TASK_IDS[@]}"
  sleep "${POLL_INTERVAL}"
done

{
  echo "run_id,task_id,satellite_id,scenario_id,status"
  for tid in "${TASK_IDS[@]}"; do
    body="$(curl -sf "${API_BASE}/api/remote-sensing/tasks/${tid}")"
    echo "${RUN_ID},${tid},$(echo "${body}" | jq -r '.satellite_id'),$(echo "${body}" | jq -r '.scenario_id'),$(echo "${body}" | jq -r '.status')"
  done
} > "${OUT_DIR}/summary.csv"

completed=0
failed=0
for tid in "${TASK_IDS[@]}"; do
  st="${FINAL_STATUS[$tid]:-unknown}"
  [[ "${st}" == "completed" ]] && completed=$((completed + 1))
  [[ "${st}" == "failed" ]] && failed=$((failed + 1))
done

cat > "${OUT_DIR}/report.txt" <<EOF
run_id=${RUN_ID}
scenario_id=${SCENARIO_ID}
tasks=${#TASK_IDS[@]}
completed=${completed}
failed=${failed}
file_prefix=${FILE_PREFIX}
EOF

echo "完成: ${OUT_DIR}/summary.csv (${completed}/${#TASK_IDS[@]} completed, ${failed} failed)"
