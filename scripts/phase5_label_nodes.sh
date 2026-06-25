#!/usr/bin/env bash
# 按 pilot-map.json 为 K8s 节点打 satellite.io/id 标签（Pilot 15 节点集群）
set -euo pipefail

APPLY=false
MAP_FILE=""

usage() {
  cat <<'EOF'
用法:
  scripts/phase5_label_nodes.sh [--apply] [--map-file PATH]

默认读取 backend/internal/pilotcluster/pilot-map.json（与后端嵌入文件一致）。
--apply 时执行 kubectl label node ...

扩展至 120 颗：替换 pilot-map.json 并设置 SATELLITE_PILOT_CLUSTER=false 或更新映射后重新 apply。
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=true; shift ;;
    --map-file) MAP_FILE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1"; usage; exit 1 ;;
  esac
done

command -v kubectl >/dev/null || { echo "需要 kubectl"; exit 1; }
command -v jq >/dev/null || { echo "需要 jq"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
if [[ -z "${MAP_FILE}" ]]; then
  MAP_FILE="${REPO_ROOT}/backend/internal/pilotcluster/pilot-map.json"
fi
if [[ ! -f "${MAP_FILE}" ]]; then
  echo "映射文件不存在: ${MAP_FILE}"
  exit 1
fi

COUNT="$(jq '.nodes | length' "${MAP_FILE}")"
echo "map=${MAP_FILE} entries=${COUNT}"

while IFS=$'\t' read -r node sat_id; do
  [[ -z "${node}" ]] && continue
  cmd=(kubectl label node "${node}" "satellite.io/id=${sat_id}" --overwrite)
  echo "${cmd[*]}"
  if [[ "${APPLY}" == true ]]; then
    "${cmd[@]}"
  fi
done < <(jq -r '.nodes[] | [.node, .sat_id] | @tsv' "${MAP_FILE}")

echo "完成。节点标签 satellite.io/id 与 pilot-map.json 一致。"
