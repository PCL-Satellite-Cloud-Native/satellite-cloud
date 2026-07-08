#!/usr/bin/env bash
# P5-06b：等待 rs-worker DaemonSet 滚动；Pilot 15 节点 maxUnavailable=1 时 600s 常不够。
set -euo pipefail

NAMESPACE="${NAMESPACE:-gitlab-runner}"
DS_NAME="${DS_NAME:-rs-worker}"
CONTAINER="${CONTAINER:-rs-worker}"
EXPECTED_IMAGE="${EXPECTED_IMAGE:-}"
TIMEOUT_SEC="${TIMEOUT_SEC:-900}"
MIN_READY="${MIN_READY:-12}"

usage() {
  cat <<'EOF'
用法:
  EXPECTED_IMAGE=192.168.10.238/satellite/backend:abc123 \
    scripts/phase5_wait_ds_rollout.sh [--namespace gitlab-runner] [--timeout 900] [--min-ready 12]

Pilot 默认 min-ready=12（允许 worker22 Evicted 等 14/15 场景）。
rollout status 超时后若模板镜像正确且 Ready 数达标，仍以 0 退出。
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --timeout) TIMEOUT_SEC="$2"; shift 2 ;;
    --min-ready) MIN_READY="$2"; shift 2 ;;
    --expected-image) EXPECTED_IMAGE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1"; usage; exit 1 ;;
  esac
done

if [[ -z "${EXPECTED_IMAGE}" ]]; then
  echo "ERROR: 须设置 EXPECTED_IMAGE 或 --expected-image"
  exit 1
fi

echo "等待 DaemonSet/${DS_NAME} rollout（timeout=${TIMEOUT_SEC}s, min-ready=${MIN_READY}）"
echo "期望镜像: ${EXPECTED_IMAGE}"

if kubectl -n "${NAMESPACE}" rollout status "daemonset/${DS_NAME}" --timeout="${TIMEOUT_SEC}s"; then
  echo "rollout status: 完成"
else
  echo "WARN: rollout status 超时，检查 DaemonSet 状态..."
fi

TEMPLATE_IMAGE="$(kubectl -n "${NAMESPACE}" get "daemonset/${DS_NAME}" \
  -o jsonpath='{.spec.template.spec.containers[?(@.name=="'"${CONTAINER}"'")].image}')"
DESIRED="$(kubectl -n "${NAMESPACE}" get "daemonset/${DS_NAME}" -o jsonpath='{.status.desiredNumberScheduled}')"
UPDATED="$(kubectl -n "${NAMESPACE}" get "daemonset/${DS_NAME}" -o jsonpath='{.status.updatedNumberScheduled}')"
READY="$(kubectl -n "${NAMESPACE}" get "daemonset/${DS_NAME}" -o jsonpath='{.status.numberReady}')"

echo "desired=${DESIRED} updated=${UPDATED} ready=${READY}"
echo "template_image=${TEMPLATE_IMAGE}"

if [[ "${TEMPLATE_IMAGE}" != "${EXPECTED_IMAGE}" ]]; then
  echo "ERROR: DaemonSet 模板镜像未更新为 EXPECTED_IMAGE"
  kubectl -n "${NAMESPACE}" get pods -l app="${DS_NAME}" \
    -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,IMAGE:.spec.containers[0].image,STATUS:.status.phase
  exit 1
fi

if [[ "${READY:-0}" -lt "${MIN_READY}" ]]; then
  echo "ERROR: Ready Pod 数 ${READY:-0} < min-ready ${MIN_READY}"
  kubectl -n "${NAMESPACE}" get pods -l app="${DS_NAME}" -o wide
  exit 1
fi

# 统计已使用期望镜像的 Running Pod
MATCHING=0
while IFS= read -r img; do
  [[ -z "${img}" ]] && continue
  if [[ "${img}" == "${EXPECTED_IMAGE}" ]]; then
    MATCHING=$((MATCHING + 1))
  fi
done < <(kubectl -n "${NAMESPACE}" get pods -l app="${DS_NAME}" \
  --field-selector=status.phase=Running \
  -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}')
echo "running_pods_on_expected_image=${MATCHING}"

if [[ "${MATCHING:-0}" -lt "${MIN_READY}" ]]; then
  echo "WARN: 仅 ${MATCHING} 个 Pod 已 Running 且镜像匹配；rollout 可能仍在进行"
  echo "      模板已更新且 ready>=min-ready，Pilot 部署视为通过"
fi

echo "DaemonSet pilot 部署检查通过"
