#!/usr/bin/env bash
set -euo pipefail

# 用途：在可访问 GitHub 与内网 GitLab 的中转机上执行，
# 将 Satellite-Remote-Sensing 同步到内网 GitLab 私有仓库。
#
# 必填环境变量：
#   GITHUB_REPO_SSH    例如: git@github.com:PCL-Satellite-Cloud-Native/Satellite-Remote-Sensing.git
#   GITLAB_REPO_HTTPS  例如: https://gitlab.example.local/space/Satellite-Remote-Sensing.git
#   GITLAB_USERNAME
#   GITLAB_TOKEN       建议使用 Personal Access Token 或 Project Access Token（具备写仓库权限）
#
# 可选环境变量：
#   WORKDIR            默认: /tmp/rs-mirror-work

: "${GITHUB_REPO_SSH:?GITHUB_REPO_SSH is required}"
: "${GITLAB_REPO_HTTPS:?GITLAB_REPO_HTTPS is required}"
: "${GITLAB_USERNAME:?GITLAB_USERNAME is required}"
: "${GITLAB_TOKEN:?GITLAB_TOKEN is required}"

WORKDIR="${WORKDIR:-/tmp/rs-mirror-work}"
TARGET_DIR="$WORKDIR/Satellite-Remote-Sensing"

mkdir -p "$WORKDIR"
rm -rf "$TARGET_DIR"

printf '[1/4] 克隆 GitHub 源仓库...\n'
git clone --mirror "$GITHUB_REPO_SSH" "$TARGET_DIR"

printf '[2/4] 组装 GitLab 认证地址...\n'
AUTH_GITLAB_URL="$(echo "$GITLAB_REPO_HTTPS" | sed "s#^https://#https://${GITLAB_USERNAME}:${GITLAB_TOKEN}@#")"

printf '[3/4] 推送所有分支与标签到 GitLab...\n'
git -C "$TARGET_DIR" remote add gitlab "$AUTH_GITLAB_URL"
git -C "$TARGET_DIR" push --mirror gitlab

printf '[4/4] 同步完成。建议核对默认分支与保护规则。\n'
