#!/usr/bin/env bash
# Phase 5 Pilot：为 K8s Node 打 satellite.io/id 标签（软亲和 pilot）
# 用法示例（15 节点集群，按节点顺序映射前 N 颗 sat_id）：
#   scripts/phase5_label_nodes.sh --dry-run
#   scripts/phase5_label_nodes.sh --apply
set -euo pipefail

APPLY=false
SCENARIO_ID=""
API_BASE="${SATELLITE_API_BASE:-http://127.0.0.1:8080}"

usage() {
  cat <<'EOF'
用法:
  scripts/phase5_label_nodes.sh [--apply] [--scenario-id N] [--api-base URL]

默认 dry-run：打印将执行的 kubectl label 命令。
--apply 时实际打标签（kubectl label node ...）。

标签键: satellite.io/id
标签值: satellites.sat_id（如 sat-1-1），按节点名字典序与卫星列表顺序一一对应。
Pilot 环境节点数通常少于卫星数，仅映射 min(nodes, satellites) 个。
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=true; shift ;;
    --scenario-id) SCENARIO_ID="$2"; shift 2 ;;
    --api-base) API_BASE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1"; usage; exit 1 ;;
  esac
done

command -v kubectl >/dev/null || { echo "需要 kubectl"; exit 1; }
command -v jq >/dev/null || { echo "需要 jq"; exit 1; }
command -v curl >/dev/null || { echo "需要 curl"; exit 1; }

if [[ -z "${SCENARIO_ID}" ]]; then
  SCENARIO_ID="$(curl -sf "${API_BASE}/api/scenarios" | jq -r '.results[0].id // empty')"
fi
if [[ -z "${SCENARIO_ID}" ]]; then
  echo "无法解析 scenario_id，请传 --scenario-id"
  exit 1
fi

mapfile -t NODES < <(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | sort)
mapfile -t SAT_IDS < <(curl -sf "${API_BASE}/api/satellites?scenario_id=${SCENARIO_ID}" | jq -r '.[].sat_id')

if [[ ${#NODES[@]} -eq 0 ]]; then
  echo "未找到 K8s 节点"
  exit 1
fi
if [[ ${#SAT_IDS[@]} -eq 0 ]]; then
  echo "场景 ${SCENARIO_ID} 下无卫星"
  exit 1
fi

LIMIT=${#NODES[@]}
if [[ ${#SAT_IDS[@]} -lt ${LIMIT} ]]; then
  LIMIT=${#SAT_IDS[@]}
fi

echo "scenario_id=${SCENARIO_ID} nodes=${#NODES[@]} satellites=${#SAT_IDS[@]} mapping=${LIMIT}"

for ((i=0; i<LIMIT; i++)); do
  node="${NODES[$i]}"
  sat_id="${SAT_IDS[$i]}"
  cmd=(kubectl label node "${node}" "satellite.io/id=${sat_id}" --overwrite)
  echo "${cmd[*]}"
  if [[ "${APPLY}" == true ]]; then
    "${cmd[@]}"
  fi
done

echo "完成。Argo PAN RPC Workflow 将 preferred 调度到 satellite.io/id 匹配的节点。"
