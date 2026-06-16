#!/usr/bin/env bash
# 在 detection-builder 阶段下载 ONNX Runtime CPU 包（支持内网镜像 URL）
set -eu

ORT_VERSION="${ORT_VERSION:-1.24.4}"
ORT_TGZ="onnxruntime-linux-x64-${ORT_VERSION}.tgz"
ORT_DIR="onnxruntime-linux-x64-${ORT_VERSION}"
GITHUB_URL="https://github.com/microsoft/onnxruntime/releases/download/v${ORT_VERSION}/${ORT_TGZ}"

download_one() {
  local url="$1"
  rm -f /tmp/ort.tgz
  echo "下载 ORT: $url"
  local curl_opts=( -fSL --http1.1 --connect-timeout 60 --max-time 900 --retry 5 --retry-delay 10 --retry-all-errors )
  if [ "${CURL_INSECURE:-}" = "true" ]; then
    curl_opts+=( -k )
  fi
  curl "${curl_opts[@]}" -o /tmp/ort.tgz "$url"
  if [ ! -s /tmp/ort.tgz ]; then
    echo "ORT 下载结果为空" >&2
    return 1
  fi
  local size
  size="$(wc -c < /tmp/ort.tgz)"
  if [ "$size" -lt 5000000 ]; then
    echo "ORT 包过小 (${size} bytes)，可能下载到了 HTML 重定向/404 页面而非 .tgz" >&2
    echo "请检查：1) CI 变量用 https:// 而非 http://  2) 文件在 238 nginx 静态目录  3) 设 CURL_INSECURE=true" >&2
    echo "响应内容前 200 字节：" >&2
    head -c 200 /tmp/ort.tgz >&2 || true
    echo >&2
    return 1
  fi
}

if [ -n "${ORT_DOWNLOAD_URL:-}" ]; then
  download_one "${ORT_DOWNLOAD_URL}"
else
  echo "未设置 ORT_DOWNLOAD_URL，尝试从 GitHub 下载（内网 CI 建议配置内网镜像 URL）"
  download_one "${GITHUB_URL}" || download_one "${GITHUB_URL}"
fi

tar -xzf /tmp/ort.tgz -C /tmp
mkdir -p third_party
cp "/tmp/${ORT_DIR}/lib/"*.so third_party/
if [ -f third_party/libonnxruntime.so ] && [ ! -e third_party/onnxruntime.so ]; then
  ln -s libonnxruntime.so third_party/onnxruntime.so
fi
if [ -f third_party/libonnxruntime_providers_shared.so ] && [ ! -e third_party/onnxruntime_providers_shared.so ]; then
  ln -s libonnxruntime_providers_shared.so third_party/onnxruntime_providers_shared.so
fi
rm -rf /tmp/ort.tgz "/tmp/${ORT_DIR}"
echo "ORT third_party 就绪"
