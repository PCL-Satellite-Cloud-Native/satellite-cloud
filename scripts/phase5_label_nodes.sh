#!/usr/bin/env bash
# 按 pilot-map.json 为 K8s 节点打 satellite.io/id 标签（Pilot 15 节点集群）
set -euo pipefail

APPLY=false
MAP_FILE=""

usage() {
  cat <<'EOF'
用法:
  scripts/phase5_label_nodes.sh [--apply] [--map-file PATH]

映射文件查找顺序（未指定 --map-file 时）：
  1) 脚本同目录 pilot-map.json（master 部署包 p5-deploy/）
  2) backend/internal/pilotcluster/pilot-map.json（仓库根目录）

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

resolve_map_file() {
  if [[ -n "${MAP_FILE}" ]]; then
    echo "${MAP_FILE}"
    return
  fi
  if [[ -n "${SATELLITE_PILOT_MAP_FILE:-}" ]]; then
    echo "${SATELLITE_PILOT_MAP_FILE}"
    return
  fi
  local candidate
  for candidate in \
    "${SCRIPT_DIR}/pilot-map.json" \
    "${REPO_ROOT}/backend/internal/pilotcluster/pilot-map.json"; do
    if [[ -f "${candidate}" ]]; then
      echo "${candidate}"
      return
    fi
  done
  echo "${REPO_ROOT}/backend/internal/pilotcluster/pilot-map.json"
}

MAP_FILE="$(resolve_map_file)"
if [[ ! -f "${MAP_FILE}" ]]; then
  echo "映射文件不存在: ${MAP_FILE}"
  echo "提示: 将 pilot-map.json 放到脚本同目录，或 --map-file PATH"
  echo "  scp backend/internal/pilotcluster/pilot-map.json pcl@k8s-master:~/code/p5-deploy/pilot-map.json"
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
