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
  - rs-worker-metrics / od-worker-metrics Service
  - ServiceMonitor satellite-workers / satellite-backend
  - HPA rs-worker / od-worker
  - /metrics 含 satellite_ 前缀指标
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
echo "-- rs-worker /metrics (cluster DNS) --"
RS_BODY="$(kubectl -n "${NAMESPACE}" run p4-verify-rs-"$(date +%s)" \
  --rm -i --restart=Never --image=curlimages/curl -- \
  curl -sf --max-time 15 http://rs-worker-metrics:9090/metrics 2>/dev/null || true)"
if echo "${RS_BODY}" | grep -q 'satellite_queue_depth'; then
  echo "  OK  rs-worker satellite_queue_depth"
  echo "${RS_BODY}" | grep '^satellite_' | head -5
else
  echo "  FAIL rs-worker metrics（无 satellite_ 指标；确认已部署含 metrics 的新镜像）"
  FAIL=1
fi

echo ""
echo "-- satellite-backend /metrics --"
BE_POD="$(kubectl -n "${NAMESPACE}" get pod -l app=satellite-backend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -n "${BE_POD}" ]]; then
  BE_BODY="$(kubectl -n "${NAMESPACE}" exec "${BE_POD}" -- \
    curl -sf --max-time 10 http://127.0.0.1:8080/metrics 2>/dev/null || true)"
  if echo "${BE_BODY}" | grep -q 'satellite_queue_depth'; then
    echo "  OK  backend satellite_queue_depth"
  else
    echo "  WARN backend 无 satellite_queue_depth（worker 指标仍可用；backend 需同镜像 rollout）"
  fi
else
  echo "  WARN 未找到 satellite-backend Pod"
fi

echo ""
echo "-- Prometheus 采集（约 30～60s 后生效）--"
echo "  NodePort: http://<node-ip>:30090"
echo "  查询: satellite_queue_depth"
echo "  查询: satellite_worker_jobs_active"
echo "  Grafana: http://<node-ip>:30001 → 导入 k8s/phase4/grafana/satellite-workers.json"

if [[ "${FAIL}" -ne 0 ]]; then
  echo ""
  echo "验收未通过，请检查 rollout 镜像 tag 与 phase4 manifest。"
  exit 1
fi

echo ""
echo "Phase 4 部署验收通过。下一步：phase4-test1 三路压测。"
