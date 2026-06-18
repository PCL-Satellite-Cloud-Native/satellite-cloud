#!/usr/bin/env bash
# 遗留脚本：Redis 入队 env 已写入 k8s/backend/deployment.yaml（Phase 1 收口 2026-06-18）
# 正常发版由 GitLab deploy job apply deployment.yaml 即可，无需再跑本脚本。
#
# 仅当集群 env 被手动改乱、需快速修复时使用：
set -euo pipefail

echo "提示：推荐 git pull 后 kubectl apply -f k8s/backend/deployment.yaml"
echo "本脚本仅临时 set env（下次 deploy apply 会被 manifest 覆盖为正确值）"

kubectl -n gitlab-runner set env deployment/satellite-backend \
  SATELLITE_USE_INPROCESS_PIPELINE=false \
  SATELLITE_REDIS_ADDR=redis:6379 \
  SATELLITE_REDIS_STREAM_RS=rs.jobs \
  SATELLITE_REDIS_CONSUMER_GROUP=rs-workers

kubectl -n gitlab-runner rollout status deployment/satellite-backend
