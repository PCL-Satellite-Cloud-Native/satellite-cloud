#!/usr/bin/env bash
# Phase 4 验收：metrics 端点 + ServiceMonitor + HPA 存在性
set -euo pipefail

NAMESPACE="${NAMESPACE:-gitlab-runner}"
FAIL=0

usage() {
  cat <<'EOF'
用法:
  scripts/phase4_verify_metrics.sh [--namespace gitlab-runner]

检查:
  - rs-worker-metrics / od-worker-metrics Service 与 Endpoints
  - ServiceMonitor satellite-workers / satellite-backend
  - HPA rs-worker / od-worker
  - worker/backend /metrics 含 satellite_ 前缀指标（kubectl exec，适配 CI 无 TTY）
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace) NAMESPACE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1"; usage; exit 1 ;;
  esac
done

check() {
  local name="$1"
  shift
  if "$@"; then
    echo "  OK  ${name}"
  else
    echo "  FAIL ${name}"
    FAIL=1
  fi
}

wait_endpoints() {
  local svc="$1"
  local i=0
  while [[ $i -lt 30 ]]; do
    local n
    n="$(kubectl -n "${NAMESPACE}" get endpoints "${svc}" -o jsonpath='{.subsets[0].addresses}' 2>/dev/null || true)"
    if [[ -n "${n}" && "${n}" != "[]" && "${n}" != "" ]]; then
      return 0
    fi
    sleep 2
    i=$((i + 1))
  done
  return 1
}

fetch_metrics() {
  local label="$1"
  local url="$2"
  local pod
  pod="$(kubectl -n "${NAMESPACE}" get pod -l "${label}" \
    -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' 2>/dev/null | awk '{print $1}')"
  if [[ -z "${pod}" ]]; then
    return 1
  fi
  kubectl -n "${NAMESPACE}" exec "${pod}" -- \
    curl -sf --max-time 10 "${url}" 2>/dev/null
}

echo "== Phase 4 metrics verify (namespace=${NAMESPACE}) =="

check "rs-worker-metrics Service" \
  kubectl -n "${NAMESPACE}" get svc rs-worker-metrics >/dev/null 2>&1

check "od-worker-metrics Service" \
  kubectl -n "${NAMESPACE}" get svc od-worker-metrics >/dev/null 2>&1

check "ServiceMonitor satellite-workers" \
  kubectl -n "${NAMESPACE}" get servicemonitor satellite-workers >/dev/null 2>&1

check "ServiceMonitor satellite-backend" \
  kubectl -n "${NAMESPACE}" get servicemonitor satellite-backend >/dev/null 2>&1

check "HPA rs-worker" \
  kubectl -n "${NAMESPACE}" get hpa rs-worker >/dev/null 2>&1

check "HPA od-worker" \
  kubectl -n "${NAMESPACE}" get hpa od-worker >/dev/null 2>&1

echo ""
echo "-- rs-worker Pod / Endpoints --"
if kubectl -n "${NAMESPACE}" get deploy rs-worker >/dev/null 2>&1; then
  kubectl -n "${NAMESPACE}" get deploy rs-worker -o wide
  kubectl -n "${NAMESPACE}" get endpoints rs-worker-metrics 2>/dev/null || true
fi

if wait_endpoints rs-worker-metrics; then
  echo "  OK  rs-worker-metrics endpoints ready"
else
  echo "  FAIL rs-worker-metrics 无 endpoints（检查 rs-worker Pod 是否 Running）"
  kubectl -n "${NAMESPACE}" get pod -l app=rs-worker 2>/dev/null || true
  FAIL=1
fi

echo ""
echo "-- rs-worker /metrics (pod exec :9090) --"
RS_BODY="$(fetch_metrics "app=rs-worker" "http://127.0.0.1:9090/metrics" || true)"
if echo "${RS_BODY}" | grep -q 'satellite_queue_depth'; then
  echo "  OK  rs-worker satellite_queue_depth"
  echo "${RS_BODY}" | grep '^satellite_' | head -5
else
  echo "  FAIL rs-worker metrics（无 satellite_ 指标）"
  echo "  提示: 确认 rs-worker 与 backend 同镜像 tag；日志应有 metrics server listening port=9090"
  kubectl -n "${NAMESPACE}" logs deployment/rs-worker --tail=15 2>/dev/null || true
  FAIL=1
fi

echo ""
echo "-- od-worker /metrics (pod exec :9090) --"
OD_BODY="$(fetch_metrics "app=od-worker" "http://127.0.0.1:9090/metrics" || true)"
if echo "${OD_BODY}" | grep -q 'satellite_queue_depth'; then
  echo "  OK  od-worker satellite_queue_depth"
else
  echo "  WARN od-worker 无 satellite_queue_depth（与 rs-worker 同镜像时应一致）"
  kubectl -n "${NAMESPACE}" logs deployment/od-worker --tail=10 2>/dev/null || true
fi

echo ""
echo "-- satellite-backend /metrics --"
BE_BODY="$(fetch_metrics "app=satellite-backend" "http://127.0.0.1:8080/metrics" || true)"
if echo "${BE_BODY}" | grep -q 'satellite_queue_depth'; then
  echo "  OK  backend satellite_queue_depth"
else
  echo "  WARN backend 无 satellite_queue_depth"
fi

echo ""
echo "-- HPA 状态（CPU 可能短暂 unknown，minReplicas 应保持 ≥1）--"
kubectl -n "${NAMESPACE}" get hpa rs-worker od-worker 2>/dev/null || true

echo ""
echo "-- Prometheus 采集（约 30～60s 后生效）--"
echo "  NodePort: http://<node-ip>:30090"
echo "  查询: satellite_queue_depth"
echo "  查询: satellite_worker_jobs_active"
echo "  Grafana: http://<node-ip>:30001 → 导入 k8s/phase4/grafana/satellite-workers.json"

if [[ "${FAIL}" -ne 0 ]]; then
  echo ""
  echo "验收未通过。常见原因:"
  echo "  1) rs-worker 未 rollout 到含 metrics 的镜像（与 backend tag 应对齐）"
  echo "  2) rs-worker Pod 未 Running（HPA/资源/调度）"
  exit 1
fi

echo ""
echo "Phase 4 部署验收通过。下一步：phase4-test1 三路压测。"
