#!/usr/bin/env bash
# 在 k8s-repository（192.168.10.238）上安装 :18080 静态 HTTP systemd 单元
#
# 用法（在 satellite-cloud 仓库根目录）：
#   sudo bash scripts/ops/install-static-http-18080.sh
#
# 或指定脚本绝对路径（须与 static-http-18080.service 同目录）：
#   sudo bash /path/to/satellite-cloud/scripts/ops/install-static-http-18080.sh
set -euo pipefail

STATIC_DIR="${STATIC_DIR:-/usr/share/nginx/html/static}"
SERVICE_NAME="static-http-18080"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNIT_SRC="${SCRIPT_DIR}/static-http-18080.service"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "请使用 root 或 sudo 运行"
  exit 1
fi

if [[ ! -f "$UNIT_SRC" ]]; then
  echo "错误: 找不到 ${UNIT_SRC}"
  echo "请从 satellite-cloud 仓库运行，或把 install-static-http-18080.sh 与 static-http-18080.service 放在同一目录"
  exit 1
fi

mkdir -p "$STATIC_DIR"
for f in onnxruntime-linux-x64-1.24.4.tgz NotoSansCJKsc-Regular.otf; do
  if [[ ! -f "${STATIC_DIR}/${f}" ]]; then
    echo "警告: 缺少 ${STATIC_DIR}/${f} — CI 构建会失败，请先放入 ORT/字体"
  fi
done

cp "$UNIT_SRC" "/etc/systemd/system/${SERVICE_NAME}.service"
systemctl daemon-reload
systemctl enable "${SERVICE_NAME}"

# 先停 systemd，再清掉占用 18080 的旧进程（常见：Phase 0 的 nohup python3 -m http.server）
echo "停止 ${SERVICE_NAME} 并释放 18080..."
systemctl stop "${SERVICE_NAME}" 2>/dev/null || true
sleep 1
if command -v fuser >/dev/null 2>&1; then
  fuser -k 18080/tcp 2>/dev/null || true
  sleep 1
fi
if ss -tlnp 2>/dev/null | grep -q ':18080 '; then
  echo "警告: 18080 仍被占用，进程信息："
  ss -tlnp | grep 18080 || true
  ps aux | grep -E '[h]ttp\.server 18080' || true
fi

systemctl start "${SERVICE_NAME}"
sleep 2

if ! systemctl is-active --quiet "${SERVICE_NAME}"; then
  echo "错误: ${SERVICE_NAME} 未处于 active (running)"
  journalctl -u "${SERVICE_NAME}" -n 15 --no-pager || true
  exit 1
fi
if curl -sf -o /tmp/ort-check.tgz "http://127.0.0.1:18080/onnxruntime-linux-x64-1.24.4.tgz"; then
  ls -lh /tmp/ort-check.tgz
  echo "OK: :18080 本地可达（systemd: $(systemctl is-active ${SERVICE_NAME})）"
  ss -tlnp | grep 18080 || true
else
  echo "错误: :18080 未响应，检查 journalctl -u ${SERVICE_NAME}"
  exit 1
fi

systemctl status "${SERVICE_NAME}" --no-pager || true
