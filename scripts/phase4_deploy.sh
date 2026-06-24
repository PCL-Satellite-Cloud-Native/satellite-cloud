#!/usr/bin/env bash
# Phase 4 实施：部署 metrics 埋点镜像 + ServiceMonitor + HPA
set -euo pipefail

NAMESPACE="${NAMESPACE:-gitlab-runner}"
BACKEND_IMAGE="${BACKEND_IMAGE:-}"

usage() {
  cat <<'EOF'
用法:
  BACKEND_IMAGE=192.168.10.238/satellite/backend:<tag> \
    scripts/phase4_deploy.sh

  scripts/phase4_deploy.sh --image 192.168.10.238/satellite/backend:<tag>

步骤:
  1) apply phase1/phase2 + backend deployment（metrics 端口）
  2) 滚动 rs-worker / od-worker / satellite-backend
  3) 保持 Argo P3-04b 环境变量
  4) apply k8s/phase4/（metrics Service、ServiceMonitor、HPA）
  5) 调用 phase4_verify_metrics.sh
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image) BACKEND_IMAGE="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1"; usage; exit 1 ;;
  esac
done

if [[ -z "${BACKEND_IMAGE}" ]]; then
  echo "必须设置 BACKEND_IMAGE 或 --image"
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

echo "== Phase 4 deploy =="
echo "namespace=${NAMESPACE}"
echo "backend_image=${BACKEND_IMAGE}"

if ! kubectl auth can-i create horizontalpodautoscalers.autoscaling \
  --as=system:serviceaccount:${NAMESPACE}:gitlab-runner -n "${NAMESPACE}" 2>/dev/null | grep -q yes; then
  echo ""
  echo "WARN: gitlab-runner SA 无 HPA/ServiceMonitor 权限。"
  echo "      集群管理员执行: kubectl apply -f k8s/gitlab-runner-ci-rbac-phase4.yaml"
  echo ""
fi

kubectl apply -k k8s/phase1/
kubectl apply -k k8s/phase2/
kubectl -n "${NAMESPACE}" apply -f k8s/backend/deployment.yaml

kubectl -n "${NAMESPACE}" set image deployment/rs-worker rs-worker="${BACKEND_IMAGE}"
kubectl -n "${NAMESPACE}" set image deployment/od-worker od-worker="${BACKEND_IMAGE}"
kubectl -n "${NAMESPACE}" set image deployment/satellite-backend satellite-backend="${BACKEND_IMAGE}"

kubectl -n "${NAMESPACE}" set env deployment/rs-worker \
  SATELLITE_USE_ARGO_PAN_RPC=true \
  SATELLITE_RS_WORKFLOW_IMAGE="${BACKEND_IMAGE}"

kubectl -n "${NAMESPACE}" rollout status deployment/rs-worker --timeout=300s
kubectl -n "${NAMESPACE}" rollout status deployment/od-worker --timeout=300s
kubectl -n "${NAMESPACE}" rollout status deployment/satellite-backend --timeout=300s

kubectl apply -k k8s/phase4/

echo ""
echo "== 资源清单 =="
kubectl -n "${NAMESPACE}" get deploy rs-worker od-worker satellite-backend
kubectl -n "${NAMESPACE}" get svc rs-worker-metrics od-worker-metrics satellite-backend
kubectl -n "${NAMESPACE}" get servicemonitor satellite-workers satellite-backend
kubectl -n "${NAMESPACE}" get hpa rs-worker od-worker

echo ""
bash scripts/phase4_verify_metrics.sh --namespace "${NAMESPACE}"
