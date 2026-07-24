#!/usr/bin/env bash
# 60 节点日常巡检（Post-P5 / N2）：rs-worker Ready、镜像一致性、Redis 队列深度。
# 在 sat10-m1 执行：
#   bash scripts/ops_patrol_60.sh
#   bash scripts/ops_patrol_60.sh --expect-digest 3f0ec26d88b505bfdc1e22653942313fd2f98e11d1675633b541982a1b000966
set -euo pipefail

NAMESPACE="${NAMESPACE:-gitlab-runner}"
MIN_DS_READY="${MIN_DS_READY:-50}"
EXPECT_DIGEST=""
WARN_XLEN="${WARN_XLEN:-500}"
FAIL_XLEN="${FAIL_XLEN:-10000}"

usage() {
  sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --min-ds-ready) MIN_DS_READY="$2"; shift 2 ;;
    --expect-digest) EXPECT_DIGEST="$2"; shift 2 ;;
    --warn-xlen) WARN_XLEN="$2"; shift 2 ;;
    --fail-xlen) FAIL_XLEN="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

FAIL=0
warn() { echo "  WARN $*" >&2; }
ok() { echo "  OK   $*"; }
fail() { echo "  FAIL $*"; FAIL=1; }

echo "== ops_patrol_60 ns=${NAMESPACE} =="

# --- rs-worker Ready ---
echo ""
echo "-- rs-worker DaemonSet --"
DESIRED="$(kubectl -n "${NAMESPACE}" get ds rs-worker -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo 0)"
READY="$(kubectl -n "${NAMESPACE}" get ds rs-worker -o jsonpath='{.status.numberReady}' 2>/dev/null || echo 0)"
echo "  info desired=${DESIRED} ready=${READY}"
if [[ "${READY}" =~ ^[0-9]+$ ]] && [[ "${READY}" -ge "${MIN_DS_READY}" ]]; then
  ok "Ready ${READY} >= ${MIN_DS_READY}"
else
  fail "Ready ${READY} < ${MIN_DS_READY}"
fi
NOT_READY="$(kubectl -n "${NAMESPACE}" get pod -l app=rs-worker --field-selector=status.phase!=Running -o name 2>/dev/null | wc -l | tr -d ' ')"
if [[ "${NOT_READY}" != "0" ]]; then
  warn "非 Running rs-worker Pod 数=${NOT_READY}"
  kubectl -n "${NAMESPACE}" get pod -l app=rs-worker --field-selector=status.phase!=Running -o wide 2>/dev/null | head -20 || true
fi

# --- image digest ---
echo ""
echo "-- rs-worker imageID --"
mapfile -t IMAGES < <(kubectl -n "${NAMESPACE}" get pod -l app=rs-worker -o jsonpath='{range .items[*]}{.status.containerStatuses[?(@.name=="rs-worker")].imageID}{"\n"}{end}' 2>/dev/null | sed '/^$/d' | sort | uniq -c | sort -rn)
if [[ ${#IMAGES[@]} -eq 0 ]]; then
  fail "无法读取 rs-worker imageID"
else
  for line in "${IMAGES[@]}"; do
    echo "  info ${line}"
  done
  if [[ ${#IMAGES[@]} -gt 1 ]]; then
    warn "存在多个 imageID（滚动未齐或混版）"
  fi
  if [[ -n "${EXPECT_DIGEST}" ]]; then
    if printf '%s\n' "${IMAGES[@]}" | grep -q "${EXPECT_DIGEST}"; then
      ok "含期望 digest ${EXPECT_DIGEST:0:12}…"
    else
      fail "未找到期望 digest ${EXPECT_DIGEST:0:12}…"
    fi
  fi
fi

# --- Redis ---
echo ""
echo "-- Redis rs.jobs --"
REDIS_POD="$(kubectl -n "${NAMESPACE}" get pod -l app=redis -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -z "${REDIS_POD}" ]]; then
  warn "未找到 redis Pod"
else
  XLEN="$(kubectl -n "${NAMESPACE}" exec "${REDIS_POD}" -c redis -- redis-cli XLEN rs.jobs 2>/dev/null || echo err)"
  PENDING="$(kubectl -n "${NAMESPACE}" exec "${REDIS_POD}" -c redis -- redis-cli XPENDING rs.jobs rs-workers 2>/dev/null | head -1 || true)"
  echo "  info XLEN(rs.jobs)=${XLEN}"
  echo "  info XPENDING: ${PENDING}"
  if [[ "${XLEN}" =~ ^[0-9]+$ ]]; then
    if [[ "${XLEN}" -ge "${FAIL_XLEN}" ]]; then
      fail "XLEN=${XLEN} >= ${FAIL_XLEN}（疑似风暴）"
    elif [[ "${XLEN}" -ge "${WARN_XLEN}" ]]; then
      warn "XLEN=${XLEN} >= ${WARN_XLEN}（积压偏高，关注）"
    else
      ok "XLEN=${XLEN} < ${WARN_XLEN}"
    fi
  else
    warn "无法读取 XLEN"
  fi
fi

# --- ServiceMonitor（可选）---
echo ""
echo "-- optional Prometheus --"
if kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1; then
  if kubectl -n "${NAMESPACE}" get servicemonitor satellite-workers >/dev/null 2>&1; then
    ok "ServiceMonitor satellite-workers 存在"
  else
    warn "有 Prometheus Operator，但无 satellite-workers ServiceMonitor（可 apply k8s/phase4/）"
  fi
else
  echo "  info 无 Prometheus Operator CRD — 使用本脚本手工巡检即可"
fi

echo ""
if [[ "${FAIL}" -ne 0 ]]; then
  echo "ops_patrol_60 未通过"
  exit 1
fi
echo "ops_patrol_60 通过"
