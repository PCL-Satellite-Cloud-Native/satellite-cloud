#!/usr/bin/env sh
set -eu

usage() {
  cat <<'EOF'
用途：
  遥感部署前置检查，避免因节点磁盘压力导致 satellite-backend 被 Evicted。

用法：
  scripts/remote_sensing_preflight.sh [--namespace gitlab-runner] [--deployment satellite-backend] [--pvc remote-sensing-data] [--deployment-manifest k8s/backend/deployment.yaml]
EOF
}

NAMESPACE="gitlab-runner"
DEPLOYMENT="satellite-backend"
PVC_NAME="remote-sensing-data"
DEPLOYMENT_MANIFEST="k8s/backend/deployment.yaml"

while [ $# -gt 0 ]; do
  case "$1" in
    --namespace)
      NAMESPACE="${2:-}"
      shift 2
      ;;
    --deployment)
      DEPLOYMENT="${2:-}"
      shift 2
      ;;
    --pvc)
      PVC_NAME="${2:-}"
      shift 2
      ;;
    --deployment-manifest)
      DEPLOYMENT_MANIFEST="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "未知参数: $1"
      usage
      exit 2
      ;;
  esac
done

echo "[preflight] namespace=${NAMESPACE} deployment=${DEPLOYMENT} pvc=${PVC_NAME}"

echo "[preflight] 1/4 检查 PVC 是否 Bound..."
PVC_PHASE="$(kubectl -n "${NAMESPACE}" get pvc "${PVC_NAME}" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
if [ "${PVC_PHASE}" != "Bound" ]; then
  echo "[preflight][FAIL] PVC ${NAMESPACE}/${PVC_NAME} 状态不是 Bound（当前: ${PVC_PHASE:-N/A}）"
  exit 1
fi
echo "[preflight][OK] PVC Bound"

echo "[preflight] 2/4 检查部署清单是否声明 ephemeral-storage request..."
if [ ! -f "${DEPLOYMENT_MANIFEST}" ]; then
  echo "[preflight][FAIL] 未找到部署清单: ${DEPLOYMENT_MANIFEST}"
  exit 1
fi
if ! grep -Eq 'ephemeral-storage:[[:space:]]*"[0-9]+Gi"' "${DEPLOYMENT_MANIFEST}"; then
  echo "[preflight][FAIL] ${DEPLOYMENT_MANIFEST} 未配置 resources.requests/limits.ephemeral-storage"
  exit 1
fi
echo "[preflight][OK] manifest 已声明 ephemeral-storage 资源约束"

echo "[preflight] 3/4 检查 Ready 节点是否存在 DiskPressure=True..."
NODES_OUTPUT="$(kubectl get nodes --no-headers 2>&1 || true)"
if echo "${NODES_OUTPUT}" | grep -Eq 'Forbidden|forbidden|cannot list resource "nodes"|Unauthorized|unauthorized'; then
  echo "[preflight][WARN] 当前 CI 账号无 nodes 读取权限，跳过 DiskPressure 节点级检查"
  READY_NODES=""
else
  READY_NODES="$(printf '%s\n' "${NODES_OUTPUT}" | awk '$2 ~ /Ready/ {print $1}')"
  if [ -z "${READY_NODES}" ]; then
    echo "[preflight][FAIL] 未发现 Ready 节点"
    exit 1
  fi
fi

DISK_PRESSURE_NODES=""
if [ -n "${READY_NODES}" ]; then
  for node in ${READY_NODES}; do
    disk_pressure="$(kubectl get node "${node}" -o jsonpath='{.status.conditions[?(@.type=="DiskPressure")].status}' 2>/dev/null || true)"
    if [ "${disk_pressure}" = "True" ]; then
      DISK_PRESSURE_NODES="${DISK_PRESSURE_NODES} ${node}"
    fi
  done

  if [ -n "${DISK_PRESSURE_NODES}" ]; then
    echo "[preflight][FAIL] 以下 Ready 节点存在 DiskPressure=True:${DISK_PRESSURE_NODES}"
    exit 1
  fi
  echo "[preflight][OK] Ready 节点均无 DiskPressure"
else
  echo "[preflight][WARN] DiskPressure 节点级检查已跳过"
fi

echo "[preflight] 4/4 检查最近是否出现 satellite-backend Evicted（仅告警）..."
EVICT_COUNT="$(kubectl -n "${NAMESPACE}" get pods -l app=satellite-backend -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.status.reason}{"\n"}{end}' 2>/dev/null | grep -c '|Evicted' || true)"
if [ "${EVICT_COUNT}" -gt 0 ]; then
  echo "[preflight][WARN] 当前列表中发现 ${EVICT_COUNT} 个 Evicted 的 satellite-backend Pod，请确认节点磁盘空间后再发起长任务"
else
  echo "[preflight][OK] 未发现 Evicted 的 satellite-backend Pod"
fi

echo "[preflight] 全部硬性检查通过"
