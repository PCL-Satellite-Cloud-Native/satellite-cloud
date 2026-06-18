#!/usr/bin/env bash
# 将 Argo Workflows 控制器镜像推入内网 Harbor（Phase 3 前置）
#
# 用法：
#   export HARBOR=192.168.10.238
#   export HARBOR_USER=admin
#   export HARBOR_PASSWORD='***'
#   export ARGO_VERSION=v3.5.12
#   bash scripts/ops/mirror_argo_workflows_images.sh
set -euo pipefail

HARBOR="${HARBOR:-192.168.10.238}"
ARGO_VERSION="${ARGO_VERSION:-v3.5.12}"
PLATFORM="${PLATFORM:-linux/amd64}"
TAG_SUFFIX="${TAG_SUFFIX:-amd64-r1}"

login_harbor() {
  if [[ -n "${HARBOR_USER:-}" && -n "${HARBOR_PASSWORD:-}" ]]; then
    echo "Login ${HARBOR}..."
    docker login "${HARBOR}" -u "${HARBOR_USER}" -p "${HARBOR_PASSWORD}"
  fi
}

mirror_one() {
  local src="$1"
  local name="$2"
  local target="${HARBOR}/library/${name}:${ARGO_VERSION#v}-${TAG_SUFFIX}"
  echo "=== ${src} -> ${target} ==="
  docker pull --platform "${PLATFORM}" "${src}"
  docker tag "${src}" "${target}"
  docker push "${target}"
  echo "OK: ${target}"
}

login_harbor

mirror_one "quay.io/argoproj/workflow-controller:${ARGO_VERSION}" "argo-workflow-controller"
mirror_one "quay.io/argoproj/argoexec:${ARGO_VERSION}" "argoexec"

echo ""
echo "Done. Update k8s/phase3/argo/controller deployment image to:"
echo "  ${HARBOR}/library/argo-workflow-controller:${ARGO_VERSION#v}-${TAG_SUFFIX}"
echo "  ${HARBOR}/library/argoexec:${ARGO_VERSION#v}-${TAG_SUFFIX}"
