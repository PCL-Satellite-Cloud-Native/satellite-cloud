#!/usr/bin/env bash
# 中止 Phase 4 压测残留：DB 标记 failed + 清空 Redis 队列 + 缩容 worker + 删 Argo Workflow
set -euo pipefail

NAMESPACE="${NAMESPACE:-gitlab-runner}"
POSTGRES_NS="${POSTGRES_NS:-postgres}"
TASK_IDS=()
SKIP_REDIS=false
SKIP_ARGO=false
SKIP_RESTART=false

usage() {
  cat <<'EOF'
用法:
  scripts/phase4_abort_benchmark.sh --tasks 155,157,159
  scripts/phase4_abort_benchmark.sh --tasks 155 157 159

步骤:
  1) PostgreSQL：pending/running → failed
  2) Redis：删除 rs.jobs / od.jobs（清空积压；worker 重启后会重建 consumer group）
  3) rs-worker / od-worker 缩容为 1 并 rollout restart
  4) 删除 gitlab-runner 内 Succeeded/Failed/Running 的 rs-pan-rpc Workflow（可选）

之后执行新的 phase4-test10（带 --max-in-flight 3）。
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tasks)
      shift
      while [[ $# -gt 0 && ! "$1" =~ ^-- ]]; do
        if [[ "$1" == *","* ]]; then
          IFS=',' read -ra parts <<< "$1"
          for p in "${parts[@]}"; do TASK_IDS+=("$p"); done
        else
          TASK_IDS+=("$1")
        fi
        shift
      done
      ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --skip-redis) SKIP_REDIS=true; shift ;;
    --skip-argo) SKIP_ARGO=true; shift ;;
    --skip-restart) SKIP_RESTART=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1"; usage; exit 1 ;;
  esac
done

if ((${#TASK_IDS[@]} == 0)); then
  echo "必须提供 --tasks（逗号或空格分隔 task id）"
  exit 1
fi

IDS_SQL="$(printf "%s," "${TASK_IDS[@]}")"
IDS_SQL="${IDS_SQL%,}"

echo "== Phase 4 abort benchmark =="
echo "namespace=${NAMESPACE}"
echo "task_ids=${TASK_IDS[*]}"

PG_POD="$(kubectl -n "${POSTGRES_NS}" get pod -l app=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || \
  kubectl -n "${POSTGRES_NS}" get pod postgres-0 -o jsonpath='{.metadata.name}' 2>/dev/null || true)"
if [[ -z "${PG_POD}" ]]; then
  echo "未找到 postgres Pod（namespace=${POSTGRES_NS}）"
  exit 1
fi

DB_USER="$(kubectl -n "${NAMESPACE}" get secret satellite-db-secret -o jsonpath='{.data.user}' | base64 -d)"
DB_PASS="$(kubectl -n "${NAMESPACE}" get secret satellite-db-secret -o jsonpath='{.data.password}' | base64 -d)"
DB_NAME="$(kubectl -n "${NAMESPACE}" get secret satellite-db-secret -o jsonpath='{.data.dbname}' | base64 -d)"

echo ""
echo "-- 1) PostgreSQL 标记 failed --"
kubectl -n "${POSTGRES_NS}" exec "${PG_POD}" -- env PGPASSWORD="${DB_PASS}" psql -U "${DB_USER}" -d "${DB_NAME}" -v ON_ERROR_STOP=1 -c "
UPDATE remote_sensing_tasks
SET status = 'failed',
    error_message = 'phase4 压测手动中止',
    finished_at = NOW(),
    current_stage = '',
    updated_at = NOW()
WHERE id IN (${IDS_SQL})
  AND status IN ('pending', 'running');
"
kubectl -n "${POSTGRES_NS}" exec "${PG_POD}" -- env PGPASSWORD="${DB_PASS}" psql -U "${DB_USER}" -d "${DB_NAME}" -c \
  "SELECT id, status, current_stage FROM remote_sensing_tasks WHERE id IN (${IDS_SQL}) ORDER BY id;"

if [[ "${SKIP_REDIS}" != "true" ]]; then
  echo ""
  echo "-- 2) 清空 Redis rs.jobs / od.jobs --"
  REDIS_POD="$(kubectl -n "${NAMESPACE}" get pod -l app=redis -o jsonpath='{.items[0].metadata.name}')"
  kubectl -n "${NAMESPACE}" exec "${REDIS_POD}" -- redis-cli DEL rs.jobs od.jobs
  echo "  DEL rs.jobs od.jobs 完成（consumer group 随 worker 重启自动创建）"
fi

if [[ "${SKIP_ARGO}" != "true" ]]; then
  echo ""
  echo "-- 3) 删除 Argo Workflow（rs-pan-rpc-*）--"
  mapfile -t WFS < <(kubectl -n "${NAMESPACE}" get workflows -o name 2>/dev/null | grep 'rs-pan-rpc' || true)
  if ((${#WFS[@]} > 0)); then
    kubectl -n "${NAMESPACE}" delete "${WFS[@]}" --ignore-not-found --wait=false
    echo "  已请求删除 ${#WFS[@]} 个 Workflow"
  else
    echo "  无 rs-pan-rpc Workflow"
  fi
fi

if [[ "${SKIP_RESTART}" != "true" ]]; then
  echo ""
  echo "-- 4) worker 缩容 1 + rollout restart --"
  kubectl -n "${NAMESPACE}" scale deployment/rs-worker deployment/od-worker --replicas=1
  kubectl -n "${NAMESPACE}" rollout restart deployment/rs-worker deployment/od-worker
  kubectl -n "${NAMESPACE}" rollout status deployment/rs-worker --timeout=180s
  kubectl -n "${NAMESPACE}" rollout status deployment/od-worker --timeout=180s
fi

echo ""
echo "清理完成。可开始新的门禁 C，例如:"
echo "  bash scripts/submit_n_remote_sensing_tasks.sh \\"
echo "    --run-id phase4-test10 --count 10 --max-in-flight 3 \\"
echo "    --api-base http://127.0.0.1:8080 --timeout 14400"
