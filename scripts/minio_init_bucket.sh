#!/usr/bin/env bash
# 在 k8s-master 上手动创建 MinIO bucket（无需 mc 容器镜像）
# 依赖：本机已安装 mc 二进制，或已通过 docker load 导入 mc 镜像后 docker run
set -euo pipefail

NAMESPACE="${NAMESPACE:-gitlab-runner}"
BUCKET="${BUCKET:-satellite-artifacts}"
MINIO_SVC="${MINIO_SVC:-minio:9000}"
USE_PORT_FORWARD="${USE_PORT_FORWARD:-true}"
LOCAL_PORT="${LOCAL_PORT:-19000}"

usage() {
  cat <<'EOF'
用法: scripts/minio_init_bucket.sh [选项]

在 MinIO Deployment Ready 后创建 bucket satellite-artifacts。

选项:
  --namespace gitlab-runner
  --bucket NAME
  --no-port-forward    已在集群内且能解析 minio:9000 时使用

方式 A — 本机 mc 二进制（推荐，绕过 mc 镜像 pull）:
  curl -fsSL https://dl.min.io/client/mc/release/linux-amd64/mc -o /tmp/mc
  chmod +x /tmp/mc
  bash scripts/minio_init_bucket.sh

方式 B — 离线导入 mc 镜像后 docker run:
  docker run --rm --network host \
    -e MINIO_ROOT_USER -e MINIO_ROOT_PASSWORD \
    192.168.10.238/library/mc:RELEASE.2024-01-16T16-07-38Z \
    /bin/sh -c 'mc alias set local http://127.0.0.1:19000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" && mc mb --ignore-existing local/satellite-artifacts'
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --bucket) BUCKET="$2"; shift 2 ;;
    --no-port-forward) USE_PORT_FORWARD=false; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1"; usage; exit 1 ;;
  esac
done

if ! command -v kubectl >/dev/null; then
  echo "需要 kubectl"
  exit 1
fi

USER="$(kubectl -n "${NAMESPACE}" get secret minio-credentials -o jsonpath='{.data.MINIO_ROOT_USER}' | base64 -d)"
PASS="$(kubectl -n "${NAMESPACE}" get secret minio-credentials -o jsonpath='{.data.MINIO_ROOT_PASSWORD}' | base64 -d)"
export MINIO_ROOT_USER="${USER}"
export MINIO_ROOT_PASSWORD="${PASS}"

ENDPOINT="http://${MINIO_SVC}"
PF_PID=""

cleanup() {
  if [[ -n "${PF_PID}" ]]; then
    kill "${PF_PID}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

if [[ "${USE_PORT_FORWARD}" == true ]]; then
  kubectl -n "${NAMESPACE}" port-forward "svc/minio" "${LOCAL_PORT}:9000" >/dev/null 2>&1 &
  PF_PID=$!
  sleep 2
  ENDPOINT="http://127.0.0.1:${LOCAL_PORT}"
fi

MC=""
if command -v mc >/dev/null; then
  MC=mc
elif [[ -x /tmp/mc ]]; then
  MC=/tmp/mc
else
  echo "未找到 mc。请安装："
  echo "  curl -fsSL https://dl.min.io/client/mc/release/linux-amd64/mc -o /tmp/mc && chmod +x /tmp/mc"
  echo "或使用离线 docker load 后的 mc 镜像（见 docs/PHASE6_RUNBOOK.md §2.1）"
  exit 1
fi

"${MC}" alias set local "${ENDPOINT}" "${MINIO_ROOT_USER}" "${MINIO_ROOT_PASSWORD}"
"${MC}" mb --ignore-existing "local/${BUCKET}"
"${MC}" anonymous set none "local/${BUCKET}"
echo "bucket ${BUCKET} ready @ ${ENDPOINT}"
