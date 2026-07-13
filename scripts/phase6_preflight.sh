#!/usr/bin/env bash
# Phase 6 preflight：MinIO 试点 + Phase 5+ 稳态（可选）
set -euo pipefail

NAMESPACE="${NAMESPACE:-gitlab-runner}"
CHECK_P5="${CHECK_P5:-true}"

usage() {
  cat <<'EOF'
用法: scripts/phase6_preflight.sh [选项]

选项:
  --namespace gitlab-runner   K8s namespace
  --skip-p5                   跳过 Phase 5+ preflight

检查项:
  - minio Deployment 1/1 Ready
  - minio-init-bucket Job 已完成（若存在）
  - 可选：phase5_acceptance.sh --preflight-only
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --skip-p5) CHECK_P5=false; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1"; usage; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAIL=0

echo "== Phase 6 preflight (namespace=${NAMESPACE}) =="

if ! command -v kubectl >/dev/null; then
  echo "需要 kubectl"
  exit 1
fi

if ! kubectl -n "${NAMESPACE}" get deploy minio >/dev/null 2>&1; then
  echo "  FAIL minio Deployment 不存在（kubectl apply -k k8s/phase6/）"
  exit 1
fi

ready="$(kubectl -n "${NAMESPACE}" get deploy minio -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")"
desired="$(kubectl -n "${NAMESPACE}" get deploy minio -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")"
echo "       minio ready=${ready:-0}/${desired:-0}"
if [[ "${ready:-0}" -ge 1 && "${ready}" == "${desired}" ]]; then
  echo "  OK   minio Deployment ready"
else
  echo "  FAIL minio Deployment 未 Ready"
  FAIL=1
fi

if kubectl -n "${NAMESPACE}" get job minio-init-bucket >/dev/null 2>&1; then
  complete="$(kubectl -n "${NAMESPACE}" get job minio-init-bucket -o jsonpath='{.status.succeeded}' 2>/dev/null || echo "0")"
  if [[ "${complete:-0}" -ge 1 ]]; then
    echo "  OK   minio-init-bucket Job 完成"
  else
    echo "  FAIL minio-init-bucket Job 未完成"
    FAIL=1
  fi
else
  echo "  WARN minio-init-bucket Job 不存在（请 apply k8s/phase6/）"
fi

if [[ "${CHECK_P5}" == true && -f "${SCRIPT_DIR}/phase5_acceptance.sh" ]]; then
  echo ""
  bash "${SCRIPT_DIR}/phase5_acceptance.sh" --preflight-only --namespace "${NAMESPACE}" || FAIL=1
fi

if [[ "${FAIL}" -ne 0 ]]; then
  echo ""
  echo "Phase 6 preflight 未通过。见 docs/PHASE6_RUNBOOK.md"
  exit 1
fi
echo ""
echo "Phase 6 preflight 通过"
