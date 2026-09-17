#!/usr/bin/env bash
# ============================================================================
# setup-gitlab-runner.sh —— 在 k3s 集群中部署 GitLab Runner（kubernetes executor）
#
# 背景：5 节点 k8s → k3s 迁移后，原运行在旧集群内的 GitLab Runner（kubernetes
#       executor）随之消失，导致推送到 238 GitLab 的代码无法自动触发流水线。
#       本脚本用 GitLab API 注册一个 project-type Runner，并把它作为 Deployment
#       部署进本 k3s 集群，使其自动接管 tag=`k8s-3node-runner` 的 CI 任务。
#
# 前置：
#   - 本机能访问 GitLab（默认 https://192.168.10.238:8444）
#   - 持有 GitLab 访问令牌（PAT 或 OAuth token，scope 含 api）；通过环境变量传入
#     （切勿把令牌写死进本脚本 / 提交进 git）
#   - 本机已配置好指向目标 k3s 集群的 kubeconfig（kubectl 可用）
#
# 用法：
#   GITLAB_TOKEN='<token>' [GITLAB_URL=...] [GITLAB_PROJECT=root/satellite-cloud] \
#     [RUNNER_TAG=k8s-3node-runner] [RUNNER_NS=gitlab-runner] bash setup-gitlab-runner.sh
# ============================================================================
set -euo pipefail

GITLAB_URL="${GITLAB_URL:-https://192.168.10.238:8444}"
GITLAB_TOKEN="${GITLAB_TOKEN:?需要提供 GitLab 访问令牌（PAT 或 OAuth token，scope=api），例如 GITLAB_TOKEN='...' bash $0}"
GITLAB_PROJECT="${GITLAB_PROJECT:-root/satellite-cloud}"
RUNNER_TAG="${RUNNER_TAG:-k8s-3node-runner}"
RUNNER_NAME="${RUNNER_NAME:-k3s-5node-runner}"
NS="${RUNNER_NS:-gitlab-runner}"

RUNNER_IMG="${RUNNER_IMG:-192.168.10.238/library/gitlab-runner:alpine-v17.10.1}"
HELPER_IMG="${HELPER_IMG:-192.168.10.238/library/gitlab-runner-helper:x86_64-v17.10.1}"
DIND_IMG="${DIND_IMG:-192.168.10.238/library/docker:25.0-dind}"
BUILDER_IMG="${BUILDER_IMG:-192.168.10.238/library/alpine:3.19-amd64-r1}"

GITLAB_HOST="${GITLAB_URL#https://}"
GITLAB_HOST="${GITLAB_HOST%:*}"   # 去掉端口，仅主机名/IP

echo "== 1. 查询项目 ID ($GITLAB_PROJECT) =="
PROJECT_ID=$(curl -sk -H "Authorization: Bearer $GITLAB_TOKEN" \
  "$GITLAB_URL/api/v4/projects/$(printf %s "$GITLAB_PROJECT" | sed 's#/#%2F#g')" \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["id"])')
echo "project_id=$PROJECT_ID"

echo "== 2. 创建 Runner（GitLab 16+：POST /api/v4/user/runners，用 Bearer 令牌） =="
RESP=$(curl -sk -X POST -H "Authorization: Bearer $GITLAB_TOKEN" \
  "$GITLAB_URL/api/v4/user/runners" \
  --data "runner_type=project_type" \
  --data "project_id=$PROJECT_ID" \
  --data "description=$RUNNER_NAME" \
  --data "tag_list[]=$RUNNER_TAG" \
  --data "run_untagged=false" \
  --data "locked=false" \
  --data "access_level=not_protected")
echo "$RESP" | tee /tmp/runner_create.json
RID=$(echo "$RESP" | python3 -c 'import sys,json;print(json.load(sys.stdin)["id"])')
RUNNER_TOKEN=$(echo "$RESP" | python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])')
echo "runner id=$RID，auth token 已获取（长度 ${#RUNNER_TOKEN}）"
echo "== 2b. 绑定 Runner 到项目 $GITLAB_PROJECT（若创建时已绑定可忽略报错） =="
curl -sk -X POST -H "Authorization: Bearer $GITLAB_TOKEN" \
  "$GITLAB_URL/api/v4/projects/$PROJECT_ID/runners" \
  --data "runner_id=$RID" | tee /tmp/runner_assign.json || true
echo

echo "== 3. 获取 GitLab CA 证书链 =="
openssl s_client -connect ${GITLAB_HOST}:8444 -servername "${GITLAB_HOST}" </dev/null 2>/dev/null \
  | sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' > /tmp/gitlab-fullchain.pem
echo "cert lines: $(wc -l < /tmp/gitlab-fullchain.pem)"

echo "== 4. 部署 Runner 到 k3s（namespace=$NS） =="
kubectl -n "$NS" create secret generic gitlab-cert \
  --from-file=gitlab.crt=/tmp/gitlab-fullchain.pem --dry-run=client -o yaml | kubectl apply -f -

# config.toml（含 runner token，放进 Secret 而非 ConfigMap）
kubectl -n "$NS" create secret generic gitlab-runner-config \
  --from-literal=config.toml="$(cat <<EOF
concurrent = 10
check_interval = 3

[[runners]]
  name = "$RUNNER_NAME"
  url = "$GITLAB_URL"
  token = "$RUNNER_TOKEN"
  executor = "kubernetes"
  helper_image = "$HELPER_IMG"
  tls-ca-file = "/etc/gitlab-runner/certs/gitlab.crt"
  tags = ["$RUNNER_TAG"]
  run_untagged = false
  [runners.kubernetes]
    namespace = "$NS"
    image = "$BUILDER_IMG"
    privileged = true
    poll_interval = 3
    poll_timeout = 600
    service_account = "gitlab-runner"
    [[runners.kubernetes.services]]
      name = "$DIND_IMG"
      alias = "docker"
    cpu_limit = "2000m"
    memory_limit = "4Gi"
    service_cpu_limit = "1000m"
    service_memory_limit = "2Gi"
    helper_cpu_limit = "500m"
    helper_memory_limit = "1Gi"
    [runners.kubernetes.container_env_vars]
      DOCKER_HOST = "tcp://docker:2375"
      DOCKER_TLS_CERTDIR = ""
    [[runners.kubernetes.volumes.empty_dir]]
      name = "docker-certs"
      mount_path = "/certs/client"
      medium = "Memory"
    [[runners.kubernetes.volumes.empty_dir]]
      name = "builds"
      mount_path = "/builds"
      medium = "Memory"
    [[runners.kubernetes.volumes.empty_dir]]
      name = "cache"
      mount_path = "/cache"
      medium = "Memory"
EOF
)" --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "$NS" apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gitlab-runner
  namespace: $NS
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: gitlab-runner-deploy
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
  - nonResourceURLs: ["*"]
    verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: gitlab-runner-deploy
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: gitlab-runner-deploy
subjects:
  - kind: ServiceAccount
    name: gitlab-runner
    namespace: $NS
EOF

kubectl -n "$NS" apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gitlab-runner
  namespace: $NS
  labels:
    app: gitlab-runner
spec:
  replicas: 2
  selector:
    matchLabels:
      app: gitlab-runner
  template:
    metadata:
      labels:
        app: gitlab-runner
    spec:
      serviceAccountName: gitlab-runner
      containers:
        - name: gitlab-runner
          image: $RUNNER_IMG
          imagePullPolicy: IfNotPresent
          args: ["run", "--working-directory=/home/gitlab-runner"]
          volumeMounts:
            - name: config
              mountPath: /etc/gitlab-runner
            - name: certs
              mountPath: /etc/gitlab-runner/certs
              readOnly: true
          resources:
            requests:
              cpu: 250m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
      volumes:
        - name: config
          secret:
            secretName: gitlab-runner-config
            items:
              - key: config.toml
                path: config.toml
        - name: certs
          secret:
            secretName: gitlab-cert
            items:
              - key: gitlab.crt
                path: gitlab.crt
EOF

kubectl -n "$NS" rollout status deploy/gitlab-runner --timeout=300s
kubectl -n "$NS" get pods -l app=gitlab-runner -o wide

echo "== 5. 校验 Runner 在 GitLab 上的在线状态 =="
curl -sk -H "Authorization: Bearer $GITLAB_TOKEN" "$GITLAB_URL/api/v4/runners" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); [print('id=%s tag_list=%s contacted_at=%s status=%s'%(r.get('id'),r.get('tag_list'),r.get('contacted_at'),r.get('status'))) for r in d]"
echo "完成。若上面的列表中出现本 Runner 且 status=online，则流水线即可自动触发。"
