#!/usr/bin/env bash
# 在可访问 GitHub 的机器上下载 CI 构建依赖，再上传到内网 HTTP 静态目录。
# 用法见下方「上传后」说明。
set -euo pipefail

ORT_VERSION="${ORT_VERSION:-1.24.4}"
OUT_DIR="${OUT_DIR:-./build-deps-mirror}"
ORT_FILE="onnxruntime-linux-x64-${ORT_VERSION}.tgz"
ORT_URL="https://github.com/microsoft/onnxruntime/releases/download/v${ORT_VERSION}/${ORT_FILE}"
FONT_FILE="NotoSansCJKsc-Regular.otf"
FONT_URL="https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/OTF/SimplifiedChinese/${FONT_FILE}"

mkdir -p "$OUT_DIR"

download() {
  local url="$1" dest="$2"
  echo "下载 $dest"
  curl -fSL --http1.1 --retry 5 --retry-delay 5 -o "$dest" "$url"
  test -s "$dest"
}

if [ ! -s "$OUT_DIR/$ORT_FILE" ]; then
  download "$ORT_URL" "$OUT_DIR/$ORT_FILE"
fi
ls -lh "$OUT_DIR/$ORT_FILE"

if [ ! -s "$OUT_DIR/$FONT_FILE" ]; then
  download "$FONT_URL" "$OUT_DIR/$FONT_FILE"
fi
ls -lh "$OUT_DIR/$FONT_FILE"

cat <<EOF

下载完成。请将 $OUT_DIR 下两个文件放到内网 HTTP 可访问路径。

本集群示例（238 上 python3 -m http.server 18080）：
  ORT_DOWNLOAD_URL  = http://192.168.10.238:18080/${ORT_FILE}
  FONT_DOWNLOAD_URL = http://192.168.10.238:18080/${FONT_FILE}

在 satellite-cloud → Settings → CI/CD → Variables 配置上述变量。
详见 docs/K8S_BASELINE_RUNBOOK.md §5.2。
EOF
