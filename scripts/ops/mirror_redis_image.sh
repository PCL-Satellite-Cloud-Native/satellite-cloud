#!/usr/bin/env bash
# 将 Redis 7 alpine 推入内网 Harbor（Phase 1 前置）
# 在有外网/docker hub 访问的机器上执行；238 若可 docker pull 也可在 238 执行
#
# 用法：
#   export HARBOR=192.168.10.238
#   export HARBOR_USER=admin
#   export HARBOR_PASSWORD='***'
#   bash scripts/ops/mirror_redis_image.sh
set -euo pipefail

HARBOR="${HARBOR:-192.168.10.238}"
SRC_IMAGE="${SRC_IMAGE:-redis:7-alpine}"
TARGET_IMAGE="${TARGET_IMAGE:-${HARBOR}/library/redis:7-alpine-amd64-r1}"

echo "Pull ${SRC_IMAGE} (linux/amd64)..."
docker pull --platform linux/amd64 "${SRC_IMAGE}"

echo "Tag -> ${TARGET_IMAGE}"
docker tag "${SRC_IMAGE}" "${TARGET_IMAGE}"

if [[ -n "${HARBOR_USER:-}" && -n "${HARBOR_PASSWORD:-}" ]]; then
  echo "Login ${HARBOR}..."
  docker login "${HARBOR}" -u "${HARBOR_USER}" -p "${HARBOR_PASSWORD}"
fi

echo "Push ${TARGET_IMAGE}..."
docker push "${TARGET_IMAGE}"

echo "Done. Verify on a cluster node:"
echo "  docker pull ${TARGET_IMAGE}"
