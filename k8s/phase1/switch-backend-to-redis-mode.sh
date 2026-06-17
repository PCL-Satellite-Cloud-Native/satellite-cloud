# Pilot：将 satellite-backend 切换为 Redis 入队模式（rs-worker 执行流水线）
#
# 前置：kubectl apply -k k8s/phase1/ 且 rs-worker Running
#
kubectl -n gitlab-runner set env deployment/satellite-backend \
  SATELLITE_USE_INPROCESS_PIPELINE=false \
  SATELLITE_REDIS_ADDR=redis:6379 \
  SATELLITE_REDIS_STREAM_RS=rs.jobs \
  SATELLITE_REDIS_CONSUMER_GROUP=rs-workers

kubectl -n gitlab-runner rollout status deployment/satellite-backend

# 回滚单 Pod 模式：
# kubectl -n gitlab-runner set env deployment/satellite-backend SATELLITE_USE_INPROCESS_PIPELINE=true
# kubectl -n gitlab-runner scale deployment/rs-worker --replicas=0
