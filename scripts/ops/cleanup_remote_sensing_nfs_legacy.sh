#!/usr/bin/env bash
# 清理 NFS 上 legacy 全局中间产物（P5-05 前）及指定 tasks/{id} 目录。
# 在 k8s-master 执行；会修改 NFS 数据，执行前确认无 running 任务。
set -euo pipefail

NAMESPACE="${NAMESPACE:-gitlab-runner}"
DRY_RUN="${DRY_RUN:-1}"

usage() {
  cat <<EOF
用法:
  bash cleanup_remote_sensing_nfs_legacy.sh report
  DRY_RUN=0 bash cleanup_remote_sensing_nfs_legacy.sh legacy-stages
  DRY_RUN=0 TASK_IDS="217 218" bash cleanup_remote_sensing_nfs_legacy.sh tasks
EOF
}

exec_rs() {
  kubectl -n "${NAMESPACE}" exec deploy/rs-worker -- sh -c "$1"
}

cmd_report() {
  exec_rs '
    base=/opt/remote-sensing/persist_output_preprocessing
    echo "=== df ==="
    df -h "$base"
    echo ""
    echo "=== top ==="
    du -sh "$base"/* 2>/dev/null | sort -h
    echo ""
    echo "=== tasks ==="
    du -sh "$base"/tasks/* 2>/dev/null | sort -h | tail -20
  '
}

cmd_legacy_stages() {
  local dry="${DRY_RUN}"
  exec_rs "
    base=/opt/remote-sensing/persist_output_preprocessing
    dry=${dry}
    for d in pan_rad_toa pan_warp_quarters pan_merge_warp_square mss_rad_quac_rpc \
             mss_coregister_pan pansharpen fusion_envi imgshow tiff_to_envi; do
      p=\"\${base}/\${d}\"
      if [ \"\${dry}\" = 1 ]; then
        echo \"[dry-run] would rm -rf \${p}\"
      elif [ -d \"\${p}\" ]; then
        echo \"rm -rf \${p}\"
        rm -rf \"\${p}\"
      fi
    done
    df -h \"\${base}\"
  "
}

cmd_tasks() {
  local ids="${TASK_IDS:?设置 TASK_IDS=\"217 218\"}"
  local dry="${DRY_RUN}"
  exec_rs "
    base=/opt/remote-sensing/persist_output_preprocessing
    dry=${dry}
    for id in ${ids}; do
      p=\"\${base}/tasks/\${id}\"
      if [ \"\${dry}\" = 1 ]; then
        echo \"[dry-run] would rm -rf \${p}\"
      elif [ -d \"\${p}\" ]; then
        echo \"rm -rf \${p}\"
        rm -rf \"\${p}\"
      fi
    done
    df -h \"\${base}\"
  "
}

main() {
  case "${1:-report}" in
    report) cmd_report ;;
    legacy-stages) cmd_legacy_stages ;;
    tasks) cmd_tasks ;;
    *) usage; exit 1 ;;
  esac
}

main "$@"
