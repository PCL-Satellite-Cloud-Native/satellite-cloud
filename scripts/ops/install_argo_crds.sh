#!/usr/bin/env bash
# 一次性安装 Argo Workflows CRD（Phase 3 前置；Controller 见 k8s/phase3/argo/）
set -euo pipefail

ARGO_VERSION="${ARGO_VERSION:-v3.5.12}"
URL="https://github.com/argoproj/argo-workflows/releases/download/${ARGO_VERSION}/install.yaml"

echo "Applying Argo CRDs + cluster resources from ${URL}"
echo "（若 Controller 已由 k8s/phase3/argo/ 管理，可只提取 CRD 段或跳过重复 Deployment）"

tmp=$(mktemp)
curl -fsSL "${URL}" -o "${tmp}"

# 仅 CRD（避免覆盖 Harbor 镜像的 controller deployment）
kubectl apply -f "${tmp}" --dry-run=client -o yaml | \
  awk 'BEGIN{RS="---"} /kind: CustomResourceDefinition/' | \
  kubectl apply -f -

rm -f "${tmp}"
echo "CRD apply done. Verify:"
echo "  kubectl get crd | grep argoproj.io"
