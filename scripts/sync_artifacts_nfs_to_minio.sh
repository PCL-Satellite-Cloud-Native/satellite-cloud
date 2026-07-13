#!/usr/bin/env bash
# P6-04：将 NFS 任务产物镜像到 MinIO（Worker 仍写 NFS；API 试点下载前执行）
#
# 对象键与 backend internal/storage/minio.go 一致：
#   output_preprocessing/          → remote_sensing/persist_output_preprocessing/
#   object_detection_output/       → object_detection/output_detection/
set -euo pipefail

NAMESPACE="${NAMESPACE:-gitlab-runner}"
BUCKET="${MINIO_BUCKET:-satellite-artifacts}"
MC_IMAGE="${MC_IMAGE:-192.168.10.238/library/mc:RELEASE.2024-01-16T16-06-34Z-cpuv1}"
JOB_NAME="${JOB_NAME:-minio-artifact-sync}"
WAIT_TIMEOUT="${WAIT_TIMEOUT:-3600s}"
DRY_RUN=false
RS_ONLY=false
OD_ONLY=false
VERIFY_ONLY=false

usage() {
  cat <<'EOF'
用法: scripts/sync_artifacts_nfs_to_minio.sh [选项]

将 remote-sensing-data PVC 上的产物同步到 MinIO bucket（增量 mirror）。

选项:
  --namespace NS       K8s namespace（默认 gitlab-runner）
  --bucket NAME        bucket 名（默认 satellite-artifacts）
  --job-name NAME      Job 名（默认 minio-artifact-sync）
  --timeout DURATION   wait Job 超时（默认 3600s）
  --rs-only            仅同步 remote_sensing 产物
  --od-only            仅同步 object_detection 产物
  --verify-only        仅列出 bucket 摘要（不跑 sync Job）
  --dry-run            打印将执行的 kubectl 命令
  -h, --help

示例:
  bash scripts/sync_artifacts_nfs_to_minio.sh
  bash scripts/sync_artifacts_nfs_to_minio.sh --verify-only
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --bucket) BUCKET="$2"; shift 2 ;;
    --job-name) JOB_NAME="$2"; shift 2 ;;
    --timeout) WAIT_TIMEOUT="$2"; shift 2 ;;
    --rs-only) RS_ONLY=true; shift ;;
    --od-only) OD_ONLY=true; shift ;;
    --verify-only) VERIFY_ONLY=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1"; usage; exit 1 ;;
  esac
done

if [[ "${RS_ONLY}" == true && "${OD_ONLY}" == true ]]; then
  echo "不能同时 --rs-only 与 --od-only"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v kubectl >/dev/null; then
  echo "需要 kubectl"
  exit 1
fi

if ! kubectl -n "${NAMESPACE}" get deploy minio >/dev/null 2>&1; then
  echo "minio Deployment 不存在（先 kubectl apply -k k8s/phase6/）"
  exit 1
fi

sync_rs="true"
sync_od="true"
[[ "${RS_ONLY}" == true ]] && sync_od="false"
[[ "${OD_ONLY}" == true ]] && sync_rs="false"

run_mc_verify() {
  local name="${JOB_NAME}-verify-$$"

  if [[ "${DRY_RUN}" == true ]]; then
    echo "[dry-run] kubectl apply verify job ${name}"
    return 0
  fi

  kubectl -n "${NAMESPACE}" delete job "${name}" --ignore-not-found >/dev/null 2>&1 || true

  cat <<EOF | kubectl -n "${NAMESPACE}" apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: ${name}
spec:
  ttlSecondsAfterFinished: 300
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: mc
          image: ${MC_IMAGE}
          imagePullPolicy: IfNotPresent
          env:
            - name: MINIO_ROOT_USER
              valueFrom:
                secretKeyRef:
                  name: minio-credentials
                  key: MINIO_ROOT_USER
            - name: MINIO_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: minio-credentials
                  key: MINIO_ROOT_PASSWORD
            - name: MINIO_BUCKET
              value: "${BUCKET}"
            - name: SYNC_RS
              value: "${sync_rs}"
            - name: SYNC_OD
              value: "${sync_od}"
          command:
            - /bin/sh
            - -c
            - |
              set -e
              mc alias set local http://minio:9000 "\$MINIO_ROOT_USER" "\$MINIO_ROOT_PASSWORD"
              echo "== bucket ${BUCKET} summary =="
              mc du local/\${MINIO_BUCKET} || true
              if [ "\$SYNC_RS" = "true" ]; then
                echo ""
                echo "-- remote_sensing/persist_output_preprocessing (top-level) --"
                mc ls local/\${MINIO_BUCKET}/remote_sensing/persist_output_preprocessing/ 2>/dev/null | head -20 || echo "(empty or missing)"
              fi
              if [ "\$SYNC_OD" = "true" ]; then
                echo ""
                echo "-- object_detection/output_detection (top-level) --"
                mc ls local/\${MINIO_BUCKET}/object_detection/output_detection/ 2>/dev/null | head -20 || echo "(empty or missing)"
              fi
              echo ""
              echo "verify complete"
EOF

  kubectl -n "${NAMESPACE}" wait --for=condition=complete "job/${name}" --timeout=120s
  kubectl -n "${NAMESPACE}" logs "job/${name}"
  kubectl -n "${NAMESPACE}" delete job "${name}" --ignore-not-found
}

if [[ "${VERIFY_ONLY}" == true ]]; then
  run_mc_verify
  exit 0
fi

echo "== P6-04 NFS → MinIO artifact sync =="
echo "   namespace=${NAMESPACE} bucket=${BUCKET} job=${JOB_NAME} rs=${sync_rs} od=${sync_od}"

if [[ "${DRY_RUN}" == true ]]; then
  echo "[dry-run] kubectl -n ${NAMESPACE} delete job ${JOB_NAME} --ignore-not-found"
  echo "[dry-run] kubectl apply Job ${JOB_NAME} (inline manifest, rs=${sync_rs} od=${sync_od})"
  echo "[dry-run] kubectl wait job/${JOB_NAME} --timeout=${WAIT_TIMEOUT}"
  exit 0
fi

kubectl -n "${NAMESPACE}" delete job "${JOB_NAME}" --ignore-not-found

cat <<EOF | kubectl -n "${NAMESPACE}" apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: ${JOB_NAME}
spec:
  ttlSecondsAfterFinished: 600
  backoffLimit: 1
  template:
    spec:
      restartPolicy: OnFailure
      containers:
        - name: mc
          image: ${MC_IMAGE}
          imagePullPolicy: IfNotPresent
          env:
            - name: MINIO_ROOT_USER
              valueFrom:
                secretKeyRef:
                  name: minio-credentials
                  key: MINIO_ROOT_USER
            - name: MINIO_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: minio-credentials
                  key: MINIO_ROOT_PASSWORD
            - name: MINIO_BUCKET
              value: "${BUCKET}"
            - name: SYNC_RS
              value: "${sync_rs}"
            - name: SYNC_OD
              value: "${sync_od}"
          volumeMounts:
            - name: remote-sensing-data
              mountPath: /nfs/output_preprocessing
              subPath: output_preprocessing
            - name: remote-sensing-data
              mountPath: /nfs/object_detection_output
              subPath: object_detection_output
          command:
            - /bin/sh
            - -c
            - |
              set -e
              mc alias set local http://minio:9000 "\$MINIO_ROOT_USER" "\$MINIO_ROOT_PASSWORD"
              if [ "\$SYNC_RS" = "true" ]; then
                echo "mirror RS: /nfs/output_preprocessing → \${MINIO_BUCKET}/remote_sensing/persist_output_preprocessing"
                mc mirror --overwrite /nfs/output_preprocessing \
                  "local/\${MINIO_BUCKET}/remote_sensing/persist_output_preprocessing"
              fi
              if [ "\$SYNC_OD" = "true" ]; then
                echo "mirror OD: /nfs/object_detection_output → \${MINIO_BUCKET}/object_detection/output_detection"
                mc mirror --overwrite /nfs/object_detection_output \
                  "local/\${MINIO_BUCKET}/object_detection/output_detection"
              fi
              echo "artifact sync complete"
              mc du "local/\${MINIO_BUCKET}/remote_sensing" 2>/dev/null || true
              mc du "local/\${MINIO_BUCKET}/object_detection" 2>/dev/null || true
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: "2"
              memory: 1Gi
      volumes:
        - name: remote-sensing-data
          persistentVolumeClaim:
            claimName: remote-sensing-data
EOF

kubectl -n "${NAMESPACE}" wait --for=condition=complete "job/${JOB_NAME}" --timeout="${WAIT_TIMEOUT}"
kubectl -n "${NAMESPACE}" logs "job/${JOB_NAME}"

echo ""
echo "同步完成。验证：bash ${SCRIPT_DIR}/sync_artifacts_nfs_to_minio.sh --verify-only"
echo "启用 API MinIO 下载见 docs/PHASE6_RUNBOOK.md §3（确认对象已存在后再 patch backend）"
