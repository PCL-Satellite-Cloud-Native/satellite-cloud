#!/usr/bin/env bash
# 将 frontend/public/data 中的 60 节点拓扑同步到 MinIO satellite-inputs。
# 在 GitLab CI（k8s-120-runner + mc 镜像）或 sat10-m1 上执行。
#
# 环境变量：
#   MINIO_ENDPOINT   默认 http://minio.gitlab-runner.svc:9000（集群内）
#   MINIO_ROOT_USER / MINIO_ROOT_PASSWORD（或 mc alias 已配置）
#   MINIO_INPUTS_BUCKET  默认 satellite-inputs
set -euo pipefail

ENDPOINT="${MINIO_ENDPOINT:-http://minio.gitlab-runner.svc:9000}"
BUCKET="${MINIO_INPUTS_BUCKET:-satellite-inputs}"
ALIAS="${MINIO_ALIAS:-local}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA="${REPO_ROOT}/frontend/public/data"

if [[ -z "${MINIO_ROOT_USER:-}" || -z "${MINIO_ROOT_PASSWORD:-}" ]]; then
  echo "需要 MINIO_ROOT_USER 与 MINIO_ROOT_PASSWORD（或预先 mc alias set）"
  exit 1
fi

if [[ ! -d "${DATA}/ephem_60" || ! -f "${DATA}/delay_60x60.csv" ]]; then
  echo "缺少 ${DATA}/ephem_60 或 delay_60x60.csv（仅 cluster-120 分支）"
  exit 1
fi

mc alias set "${ALIAS}" "${ENDPOINT}" "${MINIO_ROOT_USER}" "${MINIO_ROOT_PASSWORD}"
mc mb --ignore-existing "${ALIAS}/${BUCKET}"

echo "mirror ephem_60 → ${BUCKET}/topology/ephem_60/"
mc mirror --overwrite "${DATA}/ephem_60/" "${ALIAS}/${BUCKET}/topology/ephem_60/"

echo "upload delay_60x60.csv"
mc cp "${DATA}/delay_60x60.csv" "${ALIAS}/${BUCKET}/topology/delay_60x60.csv"

echo "done. 验证："
mc ls "${ALIAS}/${BUCKET}/topology/" | head
mc ls "${ALIAS}/${BUCKET}/topology/ephem_60/" | wc -l
