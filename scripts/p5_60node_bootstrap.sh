#!/usr/bin/env bash
# P5 60 节点：一次性集群准备（在 sat10-m1 执行；需 cluster-admin / nodes 打标权限）
#
# 用法:
#   export PILOT_MAP=/path/to/pilot-map-60.json
#   bash scripts/p5_60node_bootstrap.sh [--skip-label] [--skip-import] [--dry-run]
#
# 前置：
#   - sat57 已 mkdir /export/remote-sensing-data 与 /export/topology-import（见 manifest 注释）
#   - satellite-db-secret 已存在（P2.C）
#   - 拓扑 CSV 已在 sat57:/export/topology-import/
set -euo pipefail

NAMESPACE="${NAMESPACE:-gitlab-runner}"
PILOT_MAP="${PILOT_MAP:-k8s/backend/pilot-map-60.json}"
SKIP_LABEL=false
SKIP_IMPORT=false
DRY_RUN=false

usage() {
  cat <<'EOF'
用法: scripts/p5_60node_bootstrap.sh [选项]

选项:
  --skip-label    跳过 phase5_label_nodes（已打标时）
  --skip-import   跳过 import-topology-60 Job
  --dry-run       只打印将执行的 kubectl 命令
  -h, --help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-label) SKIP_LABEL=true; shift ;;
    --skip-import) SKIP_IMPORT=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1"; usage; exit 1 ;;
  esac
done

run() {
  echo "+ $*"
  if [[ "${DRY_RUN}" != true ]]; then
    "$@"
  fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

if [[ ! -f "${PILOT_MAP}" ]]; then
  echo "缺少 pilot-map: ${PILOT_MAP}（export PILOT_MAP=...）"
  exit 1
fi

echo "== P5 60-node bootstrap namespace=${NAMESPACE} =="

echo "── 1) remote-sensing-data PV/PVC（sat57 hostPath）"
run kubectl apply -f k8s/backend/remote-sensing-pv-pvc-60.yaml
run kubectl -n "${NAMESPACE}" get pvc remote-sensing-data

echo "── 2) satellite-backend-env（60 节点；若已存在则 apply 更新）"
run kubectl apply -f k8s/backend/satellite-backend-env-60.example.yaml

echo "── 3) pilot-map ConfigMap"
if [[ "${DRY_RUN}" == true ]]; then
  echo "+ kubectl -n ${NAMESPACE} create configmap pilot-map-60 --from-file=pilot-map-60.json=${PILOT_MAP} --dry-run=client -o yaml | kubectl apply -f -"
else
  kubectl -n "${NAMESPACE}" create configmap pilot-map-60 \
    --from-file=pilot-map-60.json="${PILOT_MAP}" \
    --dry-run=client -o yaml | kubectl apply -f -
fi

if [[ "${SKIP_LABEL}" != true ]]; then
  echo "── 4) 节点打标"
  run bash scripts/phase5_label_nodes.sh --map-file "${PILOT_MAP}" --apply
else
  echo "── 4) 跳过打标"
fi

if [[ "${SKIP_IMPORT}" != true ]]; then
  echo "── 5) 拓扑导入 Job（delay + t0；无 router）"
  run kubectl -n "${NAMESPACE}" delete job import-topology-60 --ignore-not-found
  run kubectl apply -f k8s/backend/import-topology-job-60.yaml
  if [[ "${DRY_RUN}" != true ]]; then
    kubectl -n "${NAMESPACE}" wait --for=condition=complete --timeout=600s job/import-topology-60
    kubectl -n "${NAMESPACE}" logs job/import-topology-60 --tail=80
  fi
else
  echo "── 5) 跳过拓扑导入"
fi

echo ""
echo "bootstrap 完成。下一步：见 docs/CLUSTER120_SAT10_STEPS.md（mirror → import → deploy-cluster-120）"
