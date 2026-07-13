#!/usr/bin/env bash
# 将已 pull 的 minio/minio 推送到内网 Harbor（在 k8s-repository 上执行）
set -euo pipefail

HARBOR="${HARBOR:-192.168.10.238}"
TAG="${TAG:-RELEASE.2024-01-16T16-07-38Z}"
MINIO_SRC="${MINIO_SRC:-minio/minio:${TAG}}"

echo "== push minio -> ${HARBOR}/library/minio:${TAG} =="
docker tag "${MINIO_SRC}" "${HARBOR}/library/minio:${TAG}"
docker push "${HARBOR}/library/minio:${TAG}"
echo "OK"

if docker image inspect "minio/mc:${TAG}" >/dev/null 2>&1; then
  echo "== push mc -> ${HARBOR}/library/mc:${TAG} =="
  docker tag "minio/mc:${TAG}" "${HARBOR}/library/mc:${TAG}"
  docker push "${HARBOR}/library/mc:${TAG}"
  echo "OK"
else
  echo ""
  echo "WARN: 本地无 minio/mc:${TAG}，跳过 mc push。"
  echo "      部署 MinIO 后请用: bash scripts/minio_init_bucket.sh"
  echo "      或离线导入 mc 镜像（见 docs/PHASE6_RUNBOOK.md §2.1）"
fi
