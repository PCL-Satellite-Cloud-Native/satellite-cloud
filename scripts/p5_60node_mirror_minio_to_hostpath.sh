#!/usr/bin/env bash
# 将 MinIO satellite-inputs 镜像到 sat57 hostPath（拓扑 import + RS 首通）。
# 在 sat10-m1 执行；MinIO 须 Ready，凭据来自 minio-credentials。
set -euo pipefail

NAMESPACE="${NAMESPACE:-gitlab-runner}"
NODE="${MIRROR_NODE:-sat57}"
JOB_NAME="${JOB_NAME:-mc-mirror-inputs-hostpath}"
WAIT_TIMEOUT="${WAIT_TIMEOUT:-1800s}"

usage() {
  cat <<'EOF'
用法: scripts/p5_60node_mirror_minio_to_hostpath.sh [--node sat57] [--dry-run]

镜像:
  satellite-inputs/topology/     → /export/topology-import/
  satellite-inputs/dem/          → /export/remote-sensing-data/dem/
  satellite-inputs/models/       → /export/remote-sensing-data/models/
  satellite-inputs/input/        → /export/remote-sensing-data/input/
EOF
}

DRY_RUN=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --node) NODE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1"; usage; exit 1 ;;
  esac
done

run() {
  echo "+ $*"
  [[ "${DRY_RUN}" != true ]] && "$@"
}

echo "== MinIO → hostPath mirror (node=${NODE}) =="

run kubectl -n "${NAMESPACE}" delete job "${JOB_NAME}" --ignore-not-found

if [[ "${DRY_RUN}" == true ]]; then
  echo "(dry-run) would apply Job ${JOB_NAME}"
  exit 0
fi

kubectl -n "${NAMESPACE}" apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: ${JOB_NAME}
spec:
  ttlSecondsAfterFinished: 600
  backoffLimit: 2
  activeDeadlineSeconds: 3600
  template:
    metadata:
      labels:
        job: ${JOB_NAME}
      annotations:
        sidecar.istio.io/inject: "false"
    spec:
      restartPolicy: Never
      nodeSelector:
        kubernetes.io/hostname: ${NODE}
      containers:
        - name: mc
          image: 192.168.10.238/library/mc:RELEASE.2024-01-16T16-06-34Z-cpuv1
          imagePullPolicy: IfNotPresent
          envFrom:
            - secretRef:
                name: minio-credentials
          command:
            - /bin/sh
            - -c
            - |
              set -ex
              mkdir -p /export/topology-import /export/remote-sensing-data/dem \
                /export/remote-sensing-data/models /export/remote-sensing-data/input
              for i in \$(seq 1 60); do
                mc alias set local http://minio:9000 "\$MINIO_ROOT_USER" "\$MINIO_ROOT_PASSWORD" && break
                echo "wait minio... \$i/60"; sleep 5
              done
              mc mirror --overwrite local/satellite-inputs/topology/ephem_60/ /export/topology-import/ephem_60/
              mc cp local/satellite-inputs/topology/delay_60x60.csv /export/topology-import/delay_60x60.csv
              mc mirror --overwrite local/satellite-inputs/dem/ /export/remote-sensing-data/dem/
              mc mirror --overwrite local/satellite-inputs/models/ /export/remote-sensing-data/models/
              mc mirror --overwrite local/satellite-inputs/input/ /export/remote-sensing-data/input/
              ls -la /export/topology-import/ /export/remote-sensing-data/models/ | head
              echo MIRROR_OK
          volumeMounts:
            - name: topology
              mountPath: /export/topology-import
            - name: rs-data
              mountPath: /export/remote-sensing-data
      volumes:
        - name: topology
          hostPath:
            path: /export/topology-import
            type: DirectoryOrCreate
        - name: rs-data
          hostPath:
            path: /export/remote-sensing-data
            type: DirectoryOrCreate
EOF

if ! kubectl -n "${NAMESPACE}" wait --for=condition=complete --timeout="${WAIT_TIMEOUT}" "job/${JOB_NAME}"; then
  echo "Job 未在 ${WAIT_TIMEOUT} 内 Complete，查看状态与 mc 容器日志："
  kubectl -n "${NAMESPACE}" get job "${JOB_NAME}"
  kubectl -n gitlab-runner get pods -l "job=${JOB_NAME}" -o wide 2>/dev/null \
    || kubectl -n "${NAMESPACE}" get pods -l "job-name=${JOB_NAME}" -o wide
  kubectl -n "${NAMESPACE}" logs "job/${JOB_NAME}" -c mc --tail=50 2>/dev/null \
    || kubectl -n "${NAMESPACE}" logs "job/${JOB_NAME}" --tail=50
  exit 1
fi
kubectl -n "${NAMESPACE}" logs "job/${JOB_NAME}" -c mc --tail=30 2>/dev/null \
  || kubectl -n "${NAMESPACE}" logs "job/${JOB_NAME}" | tail -30
echo "mirror 完成"
