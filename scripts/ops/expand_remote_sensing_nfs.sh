#!/usr/bin/env bash
# 扩容 remote-sensing NFS（方案 C）
# 在 NFS 服务器（当前集群：192.168.10.112）上执行 §1；在 k8s-master 上执行 §2。
#
# 背景：P5-05 全链路中间产物写入 persist/output_preprocessing/tasks/{id}/，
#       单 task ≈14G，3 task 并行/串行压测需 ≥50G 余量；98G 总盘易 100% 满。
#
# 目标：NFS 可用空间 ≥200G（推荐 export 总容量 500G）。
set -euo pipefail

TARGET_GIB="${TARGET_GIB:-500}"
NFS_EXPORT="${NFS_EXPORT:-/export/remote-sensing-data}"
NAMESPACE="${NAMESPACE:-gitlab-runner}"
PVC_NAME="${PVC_NAME:-remote-sensing-data}"
PV_NAME="${PV_NAME:-remote-sensing-data-pv}"

usage() {
  cat <<EOF
用法:
  # NFS 服务器 (112) — 诊断
  sudo bash expand_remote_sensing_nfs.sh diagnose

  # NFS 服务器 — LVM 扩容示例（需 VG 有 free space 或已 pvresize 物理卷）
  sudo VG=vg0 LV=lv_remote_sensing bash expand_remote_sensing_nfs.sh lvm-grow

  # NFS 服务器 — XFS 根文件系统 grow（整盘为 /export 且挂在同一 FS 时）
  sudo bash expand_remote_sensing_nfs.sh xfs-grow /dev/mapper/vg0-lv_remote_sensing

  # k8s-master — 同步 K8s PV/PVC 声明容量 + 验证
  bash expand_remote_sensing_nfs.sh k8s-verify
  bash expand_remote_sensing_nfs.sh k8s-patch-pv ${TARGET_GIB}

  # k8s-master — 查看占用（不删数据）
  bash expand_remote_sensing_nfs.sh du-report
EOF
}

cmd_diagnose() {
  echo "=== NFS 服务器诊断 ==="
  echo "export: ${NFS_EXPORT}"
  df -h "${NFS_EXPORT}" || df -h /
  echo ""
  du -sh "${NFS_EXPORT}"/* 2>/dev/null | sort -h || true
  echo ""
  if command -v lvs >/dev/null 2>&1; then
    echo "--- LVM ---"
    vgs || true
    lvs || true
    pvs || true
  fi
  echo ""
  echo "exports:"
  exportfs -v 2>/dev/null || grep remote-sensing /etc/exports 2>/dev/null || true
}

cmd_lvm_grow() {
  local vg="${VG:?设置 VG=volume_group 名}"
  local lv="${LV:?设置 LV=logical_volume 名}"
  local dev="/dev/${vg}/${lv}"
  local add="${ADD_GIB:-200}G"

  echo "扩展 LV ${dev} +${add} ..."
  lvextend -L "+${add}" "${dev}"
  local fstype
  fstype="$(findmnt -no FSTYPE "${NFS_EXPORT}" || findmnt -no FSTYPE "${dev}")"
  case "${fstype}" in
    xfs)
      xfs_growfs "${NFS_EXPORT}"
      ;;
    ext4|ext3)
      resize2fs "${dev}"
      ;;
    *)
      echo "未知 FS ${fstype}，请手动 grow"
      exit 1
      ;;
  esac
  df -h "${NFS_EXPORT}"
}

cmd_xfs_grow() {
  local mount="${1:?设备或挂载点}"
  xfs_growfs "${mount}"
  df -h "${NFS_EXPORT}"
}

cmd_k8s_verify() {
  echo "=== K8s PV/PVC ==="
  kubectl get pv "${PV_NAME}" -o wide 2>/dev/null || true
  kubectl -n "${NAMESPACE}" get pvc "${PVC_NAME}" -o wide
  echo ""
  echo "=== Pod 内 df (rs-worker) ==="
  kubectl -n "${NAMESPACE}" exec deploy/rs-worker -- df -h /opt/remote-sensing/persist_output_preprocessing
}

cmd_k8s_patch_pv() {
  local gib="${1:-${TARGET_GIB}}"
  echo "Patch PV/PVC capacity -> ${gib}Gi (仅 K8s 元数据；实际容量以 NFS 服务器 df 为准)"
  kubectl patch pv "${PV_NAME}" --type merge -p "{\"spec\":{\"capacity\":{\"storage\":\"${gib}Gi\"}}}"
  kubectl -n "${NAMESPACE}" patch pvc "${PVC_NAME}" --type merge \
    -p "{\"spec\":{\"resources\":{\"requests\":{\"storage\":\"${gib}Gi\"}}}}"
  kubectl get pv "${PV_NAME}" -o jsonpath='PV capacity={.spec.capacity.storage}{"\n"}'
  kubectl -n "${NAMESPACE}" get pvc "${PVC_NAME}" -o jsonpath='PVC request={.spec.resources.requests.storage}{"\n"}'
}

cmd_du_report() {
  kubectl -n "${NAMESPACE}" exec deploy/rs-worker -- sh -c '
    echo "=== df ==="
    df -h /opt/remote-sensing/persist_output_preprocessing
    echo ""
    echo "=== top-level ==="
    du -sh /opt/remote-sensing/persist_output_preprocessing/* 2>/dev/null | sort -h
    echo ""
    echo "=== tasks/ (P5-05) ==="
    du -sh /opt/remote-sensing/persist_output_preprocessing/tasks/* 2>/dev/null | sort -h | tail -15
  '
}

main() {
  local cmd="${1:-usage}"
  shift || true
  case "${cmd}" in
    diagnose) cmd_diagnose ;;
    lvm-grow) cmd_lvm_grow ;;
    xfs-grow) cmd_xfs_grow "$@" ;;
    k8s-verify) cmd_k8s_verify ;;
    k8s-patch-pv) cmd_k8s_patch_pv "$@" ;;
    du-report) cmd_du_report ;;
    usage|help|-h|--help) usage ;;
    *) echo "未知子命令: ${cmd}"; usage; exit 1 ;;
  esac
}

main "$@"
