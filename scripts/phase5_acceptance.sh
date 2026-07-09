#!/usr/bin/env bash
# P5-08：Phase 5+ Pilot 回归 — 集群 preflight + 三锚点星提交 + 落点断言
set -euo pipefail

NAMESPACE="${NAMESPACE:-gitlab-runner}"
API_BASE="${SATELLITE_API_BASE:-http://127.0.0.1:8080}"
SCENARIO_ID="${SCENARIO_ID:-2}"
SATELLITE_IDS="${SATELLITE_IDS:-4,26,48}"
RUN_ID=""
TIMEOUT_SEC="${TIMEOUT_SEC:-7200}"
PREFLIGHT_ONLY=false
SKIP_PREFLIGHT=false
SUBMIT=true
MIN_DS_READY="${MIN_DS_READY:-12}"
FAIL=0

# satellite_id -> expected executed_sat_id:host_node
declare -A EXPECT_SAT EXPECT_NODE
EXPECT_SAT[4]="sat-1-1"
EXPECT_NODE[4]="k8s-worker11"
EXPECT_SAT[26]="sat-2-1"
EXPECT_NODE[26]="k8s-worker21"
EXPECT_SAT[48]="sat-3-1"
EXPECT_NODE[48]="k8s-worker31"

usage() {
  cat <<'EOF'
用法:
  scripts/phase5_acceptance.sh [--run-id p5-regression-MMDD] [选项]

选项:
  --namespace gitlab-runner   K8s namespace
  --api-base URL              backend API（默认 http://127.0.0.1:8080，需 port-forward）
  --scenario-id N             场景 ID（默认 2）
  --satellite-ids 4,26,48     三锚点 satellite 主键
  --timeout SEC               任务轮询超时（默认 7200）
  --min-ds-ready N            DaemonSet 最少 Ready Pod（默认 12）
  --preflight-only            仅集群 preflight，不提交任务
  --skip-preflight            跳过 preflight（仅提交+断言）
  --no-submit                 不提交；对已有 summary 断言（需 --run-id）

通过标准:
  - 无 hpa/rs-worker；Deployment/rs-worker 0/0；DaemonSet ready>=min
  - Redis PONG；od.jobs 消费者组 od-workers 存在
  - 3/3 completed；executed_sat_id / host_node_name 与 pilot-map 锚点一致

示例（k8s-master）:
  kubectl -n gitlab-runner port-forward svc/satellite-backend 8080:8080 &
  bash scripts/phase5_acceptance.sh --run-id p5-regression-$(date +%m%d)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --api-base) API_BASE="$2"; shift 2 ;;
    --scenario-id) SCENARIO_ID="$2"; shift 2 ;;
    --satellite-ids) SATELLITE_IDS="$2"; shift 2 ;;
    --run-id) RUN_ID="$2"; shift 2 ;;
    --timeout) TIMEOUT_SEC="$2"; shift 2 ;;
    --min-ds-ready) MIN_DS_READY="$2"; shift 2 ;;
    --preflight-only) PREFLIGHT_ONLY=true; SUBMIT=false; shift ;;
    --skip-preflight) SKIP_PREFLIGHT=true; shift ;;
    --no-submit) SUBMIT=false; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1"; usage; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

check() {
  local name="$1"
  shift
  if "$@"; then
    echo "  OK   ${name}"
  else
    echo "  FAIL ${name}"
    FAIL=1
  fi
}

preflight() {
  echo "== Phase 5+ preflight (namespace=${NAMESPACE}) =="

  if ! command -v kubectl >/dev/null; then
    echo "需要 kubectl"
    exit 1
  fi

  check "hpa/rs-worker 不存在（P5-06b DaemonSet 模式）" \
    ! kubectl -n "${NAMESPACE}" get hpa rs-worker >/dev/null 2>&1

  local dep_ready dep_spec
  dep_spec="$(kubectl -n "${NAMESPACE}" get deploy rs-worker -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "missing")"
  dep_ready="$(kubectl -n "${NAMESPACE}" get deploy rs-worker -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")"
  if [[ "${dep_spec}" == "0" || "${dep_spec}" == "missing" ]]; then
    echo "  OK   Deployment/rs-worker replicas=${dep_spec} ready=${dep_ready:-0}"
  else
    echo "  FAIL Deployment/rs-worker replicas=${dep_spec}（期望 0）"
    FAIL=1
  fi

  local ds_ready ds_desired
  ds_ready="$(kubectl -n "${NAMESPACE}" get ds rs-worker -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")"
  ds_desired="$(kubectl -n "${NAMESPACE}" get ds rs-worker -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "0")"
  echo "       DaemonSet rs-worker ready=${ds_ready}/${ds_desired}"
  if [[ "${ds_ready:-0}" -ge "${MIN_DS_READY}" ]]; then
    echo "  OK   DaemonSet ready>=${MIN_DS_READY}"
  else
    echo "  FAIL DaemonSet ready=${ds_ready} < ${MIN_DS_READY}"
    FAIL=1
  fi

  local redis_pod
  redis_pod="$(kubectl -n "${NAMESPACE}" get pod -l app=redis --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  if [[ -n "${redis_pod}" ]]; then
    check "Redis PONG" \
      kubectl -n "${NAMESPACE}" exec "${redis_pod}" -c redis -- redis-cli PONG 2>/dev/null | grep -q PONG
    check "od.jobs 消费者组 od-workers" \
      kubectl -n "${NAMESPACE}" exec "${redis_pod}" -c redis -- redis-cli XINFO GROUPS od.jobs 2>/dev/null | grep -q od-workers
  else
    echo "  FAIL Redis Pod 未 Running"
    FAIL=1
  fi

  if [[ "${FAIL}" -ne 0 ]]; then
    echo ""
    echo "preflight 未通过。见 docs/PHASE5_PLUS_RUNBOOK.md §2.6"
    exit 1
  fi
  echo "preflight 通过"
}

assert_summary() {
  local summary="$1"
  if [[ ! -f "${summary}" ]]; then
    echo "缺少 ${summary}"
    exit 1
  fi
  echo ""
  echo "== 断言 summary: ${summary} =="
  cat "${summary}"

  local line sat_pk exec_sat host st
  while IFS=',' read -r _run tid sat_pk exec_sat host _sc st; do
    [[ "${tid}" == "task_id" ]] && continue
    [[ -z "${tid}" ]] && continue
    local exp_sat="${EXPECT_SAT[$sat_pk]:-}"
    local exp_node="${EXPECT_NODE[$sat_pk]:-}"
    if [[ "${st}" != "completed" ]]; then
      echo "  FAIL task ${tid} satellite_id=${sat_pk} status=${st}（期望 completed）"
      FAIL=1
      continue
    fi
    if [[ "${exec_sat}" != "${exp_sat}" ]]; then
      echo "  FAIL task ${tid} executed_sat_id=${exec_sat}（期望 ${exp_sat}）"
      FAIL=1
    else
      echo "  OK   task ${tid} executed_sat_id=${exec_sat}"
    fi
    if [[ "${host}" != "${exp_node}" ]]; then
      echo "  FAIL task ${tid} host_node_name=${host}（期望 ${exp_node}）"
      FAIL=1
    else
      echo "  OK   task ${tid} host_node_name=${host}"
    fi
  done < "${summary}"

  if [[ "${FAIL}" -ne 0 ]]; then
    echo ""
    echo "验收未通过"
    exit 1
  fi
  echo ""
  echo "Phase 5+ 回归验收通过"
}

if [[ "${SKIP_PREFLIGHT}" != true ]]; then
  preflight
fi

if [[ "${PREFLIGHT_ONLY}" == true ]]; then
  exit 0
fi

if [[ "${SUBMIT}" == true ]]; then
  if [[ -z "${RUN_ID}" ]]; then
    RUN_ID="p5-regression-$(date +%m%d)"
  fi
  echo ""
  echo "== 提交三锚点任务 run_id=${RUN_ID} =="
  bash "${SCRIPT_DIR}/submit_multi_satellite_tasks.sh" \
    --run-id "${RUN_ID}" \
    --api-base "${API_BASE}" \
    --scenario-id "${SCENARIO_ID}" \
    --satellite-ids "${SATELLITE_IDS}" \
    --timeout "${TIMEOUT_SEC}"
  SUMMARY="${REPO_ROOT}/artifacts/benchmarks/${RUN_ID}/summary.csv"
else
  if [[ -z "${RUN_ID}" ]]; then
    echo " --no-submit 需要 --run-id"
    exit 1
  fi
  SUMMARY="${REPO_ROOT}/artifacts/benchmarks/${RUN_ID}/summary.csv"
fi

assert_summary "${SUMMARY}"
