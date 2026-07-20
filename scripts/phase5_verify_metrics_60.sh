#!/usr/bin/env bash
# P1 / 60 节点：最小监控验收（DaemonSet rs-worker，无 HPA rs-worker）
set -euo pipefail

NAMESPACE="${NAMESPACE:-gitlab-runner}"
MIN_DS_READY="${MIN_DS_READY:-50}"
MIN_METRICS_EPS="${MIN_METRICS_EPS:-10}"
FAIL=0

usage() {
  cat <<'EOF'
用法:
  scripts/phase5_verify_metrics_60.sh [--namespace gitlab-runner] [--min-ds-ready 50]

检查（相对 phase4_verify_metrics.sh 的 60 节点差异）:
  - Deployment/rs-worker replicas=0；DaemonSet rs-worker Ready>=min
  - 无 hpa/rs-worker（P5-06b）
  - rs-worker-metrics Service + Endpoints 数量 >= MIN_METRICS_EPS
  - 抽样 1 个 rs-worker Pod /metrics 含 satellite_queue_depth
  - Redis XLEN rs.jobs（信息项；告警阈值由运维约定）
  - od-worker / backend metrics：可选 WARN（od scale 0；sat57 exec 可能坏）
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --min-ds-ready) MIN_DS_READY="$2"; shift 2 ;;
    --min-metrics-eps) MIN_METRICS_EPS="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1"; usage; exit 1 ;;
  esac
done

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

warn() {
  echo "  WARN ${1}"
}

echo "== Phase 5 / 60node metrics verify (ns=${NAMESPACE}) =="

# --- workload shape ---
if kubectl -n "${NAMESPACE}" get hpa rs-worker >/dev/null 2>&1; then
  echo "  FAIL hpa/rs-worker 仍存在（60 节点应为 DaemonSet，无此 HPA）"
  FAIL=1
else
  echo "  OK   hpa/rs-worker 不存在"
fi

dep_spec="$(kubectl -n "${NAMESPACE}" get deploy rs-worker -o jsonpath='{.spec.replicas}' 2>/dev/null || echo missing)"
if [[ "${dep_spec}" == "0" || "${dep_spec}" == "missing" ]]; then
  echo "  OK   Deployment/rs-worker replicas=${dep_spec}"
else
  echo "  FAIL Deployment/rs-worker replicas=${dep_spec}（期望 0）"
  FAIL=1
fi

ds_ready="$(kubectl -n "${NAMESPACE}" get ds rs-worker -o jsonpath='{.status.numberReady}' 2>/dev/null || echo 0)"
ds_desired="$(kubectl -n "${NAMESPACE}" get ds rs-worker -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo 0)"
if [[ "${ds_ready}" -ge "${MIN_DS_READY}" ]]; then
  echo "  OK   DaemonSet/rs-worker ready=${ds_ready}/${ds_desired} (>=${MIN_DS_READY})"
else
  echo "  FAIL DaemonSet/rs-worker ready=${ds_ready}/${ds_desired} (<${MIN_DS_READY})"
  FAIL=1
fi

# --- metrics service ---
check "rs-worker-metrics Service" \
  kubectl -n "${NAMESPACE}" get svc rs-worker-metrics >/dev/null 2>&1

eps_count="$(kubectl -n "${NAMESPACE}" get endpoints rs-worker-metrics -o jsonpath='{range .subsets[*].addresses[*]}{.ip}{"\n"}{end}' 2>/dev/null | grep -c . || true)"
if [[ "${eps_count}" -ge "${MIN_METRICS_EPS}" ]]; then
  echo "  OK   rs-worker-metrics endpoints=${eps_count} (>=${MIN_METRICS_EPS})"
else
  echo "  FAIL rs-worker-metrics endpoints=${eps_count} (<${MIN_METRICS_EPS})"
  FAIL=1
fi

# --- sample metrics from one Ready rs-worker ---
echo ""
echo "-- sample rs-worker /metrics --"
SAMPLE_POD="$(kubectl -n "${NAMESPACE}" get pod -l app=rs-worker --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -z "${SAMPLE_POD}" ]]; then
  echo "  FAIL 无 Running rs-worker Pod"
  FAIL=1
else
  NODE="$(kubectl -n "${NAMESPACE}" get pod "${SAMPLE_POD}" -o jsonpath='{.spec.nodeName}')"
  echo "  sample pod=${SAMPLE_POD} node=${NODE}"
  RS_BODY="$(kubectl -n "${NAMESPACE}" exec -c rs-worker "${SAMPLE_POD}" -- \
    wget -qO- http://127.0.0.1:9090/metrics 2>/dev/null \
    || kubectl -n "${NAMESPACE}" exec -c rs-worker "${SAMPLE_POD}" -- \
    curl -sf --max-time 10 http://127.0.0.1:9090/metrics 2>/dev/null \
    || true)"
  if echo "${RS_BODY}" | grep -q 'satellite_queue_depth'; then
    echo "  OK   satellite_queue_depth 存在"
    echo "${RS_BODY}" | grep -E '^satellite_(queue_depth|worker_jobs_active)' | head -10
  else
    echo "  FAIL 无 satellite_queue_depth（镜像是否含 metrics？）"
    FAIL=1
  fi
fi

# --- Redis XLEN（信息 + 软阈值）---
echo ""
echo "-- Redis rs.jobs --"
REDIS_POD="$(kubectl -n "${NAMESPACE}" get pod -l app=redis -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -z "${REDIS_POD}" ]]; then
  warn "未找到 redis Pod"
else
  XLEN="$(kubectl -n "${NAMESPACE}" exec "${REDIS_POD}" -c redis -- redis-cli XLEN rs.jobs 2>/dev/null || echo err)"
  PENDING="$(kubectl -n "${NAMESPACE}" exec "${REDIS_POD}" -c redis -- redis-cli XPENDING rs.jobs rs-workers 2>/dev/null | head -1 || true)"
  echo "  info XLEN(rs.jobs)=${XLEN}"
  echo "  info XPENDING(rs-workers) first line: ${PENDING}"
  if [[ "${XLEN}" =~ ^[0-9]+$ ]] && [[ "${XLEN}" -lt 10000 ]]; then
    echo "  OK   XLEN < 10000（无风暴量级）"
  elif [[ "${XLEN}" =~ ^[0-9]+$ ]]; then
    warn "XLEN=${XLEN} 偏高（历史积压或异常）；对比 P0-1 修复前百万级"
  else
    warn "无法读取 XLEN"
  fi
fi

# --- optional ---
echo ""
echo "-- optional --"
if kubectl -n "${NAMESPACE}" get deploy od-worker >/dev/null 2>&1; then
  od_r="$(kubectl -n "${NAMESPACE}" get deploy od-worker -o jsonpath='{.spec.replicas}')"
  if [[ "${od_r}" == "0" ]]; then
    echo "  OK   od-worker replicas=0（60 节点 P5 预期）"
  else
    warn "od-worker replicas=${od_r}（P5 首通建议 0）"
  fi
fi

if kubectl -n "${NAMESPACE}" get servicemonitor satellite-workers >/dev/null 2>&1; then
  echo "  OK   ServiceMonitor satellite-workers 存在"
else
  warn "无 ServiceMonitor satellite-workers（Prometheus Operator 未装或未 apply phase4）"
fi

echo ""
if [[ "${FAIL}" -ne 0 ]]; then
  echo "60node metrics 验收未通过"
  exit 1
fi
echo "60node metrics 最小验收通过"
echo "下一步: Prometheus 查 satellite_queue_depth / satellite_worker_jobs_active；或导入 grafana/satellite-workers.json"
