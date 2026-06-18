# 构建阶段：编译 Go 二进制
ARG BASE_IMAGE_REGISTRY=192.168.10.238/library
FROM ${BASE_IMAGE_REGISTRY}/golang:1.25.7-bookworm-amd64-r1 AS builder

WORKDIR /build
ENV GOPROXY=https://goproxy.cn,direct \
    GOSUMDB=off

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o bin/server ./cmd/server && \
    CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o bin/rs-worker ./cmd/rs-worker && \
    CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o bin/od-worker ./cmd/od-worker && \
    CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o bin/import_topology ./tools

# 构建阶段：编译 yolov8s（Linux + CGO + 内嵌字体）
FROM ${BASE_IMAGE_REGISTRY}/golang:1.25.7-bookworm-amd64-r1 AS detection-builder

WORKDIR /detection

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc g++ curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ENV GOPROXY=https://goproxy.cn,direct \
    GOSUMDB=off

COPY object-detection-src/go.mod object-detection-src/go.sum ./
RUN go mod download

COPY object-detection-src/ .

ARG FONT_DOWNLOAD_URL=
ARG CURL_INSECURE=
ENV FONT_DOWNLOAD_URL=${FONT_DOWNLOAD_URL} CURL_INSECURE=${CURL_INSECURE}
RUN bash scripts/fetch_font.sh

ARG ORT_VERSION=1.24.4
ARG ORT_DOWNLOAD_URL=
ENV ORT_VERSION=${ORT_VERSION} ORT_DOWNLOAD_URL=${ORT_DOWNLOAD_URL}
COPY scripts/download_ort.sh /tmp/download_ort.sh
RUN bash /tmp/download_ort.sh && rm -f /tmp/download_ort.sh

ENV CGO_ENABLED=1 \
    LD_LIBRARY_PATH=/detection/third_party

RUN go build -o yolov8s .

# 运行阶段：Go 服务 + Python 遥感运行时 + 目标检测运行时
ARG BASE_IMAGE_REGISTRY=192.168.10.238/library
FROM ${BASE_IMAGE_REGISTRY}/python:3.11-slim-bookworm-amd64-r1

ENV TZ=Asia/Shanghai
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    tzdata \
    curl \
    gdal-bin \
    libgdal-dev \
    python3-dev \
    build-essential \
    fonts-noto-cjk \
    && rm -rf /var/lib/apt/lists/*

# 从构建阶段复制二进制文件（server + rs-worker + 拓扑导入 CLI）
COPY --from=builder /build/bin/server .
COPY --from=builder /build/bin/rs-worker .
COPY --from=builder /build/bin/od-worker .
COPY --from=builder /build/bin/import_topology .

# 复制 GitLab CI 拉取的遥感项目源码
COPY remote-sensing-src /opt/remote-sensing

# 目标检测：yolov8s + ONNX Runtime + 内嵌字体（模型 yolov8m-obb.onnx 需另行挂载或 COPY）
COPY --from=detection-builder /detection/yolov8s /opt/object-detection/yolov8s
COPY --from=detection-builder /detection/third_party /opt/object-detection/third_party
COPY --from=detection-builder /detection/assets/fonts /opt/object-detection/assets/fonts
COPY --from=detection-builder /detection/config.env /opt/object-detection/config.env
RUN chmod +x /opt/object-detection/yolov8s

# 创建并安装遥感虚拟环境依赖
RUN python3 -m venv /opt/remote-sensing/.venv && \
    /opt/remote-sensing/.venv/bin/pip install --no-cache-dir --upgrade pip && \
    /opt/remote-sensing/.venv/bin/pip install --no-cache-dir "numpy<2" && \
    grep -viE '^[[:space:]]*gdal([[:space:]]*[<>=!~].*)?[[:space:]]*$' /opt/remote-sensing/requirements.txt > /tmp/remote-sensing-requirements.no-gdal.txt && \
    /opt/remote-sensing/.venv/bin/pip install --no-cache-dir -r /tmp/remote-sensing-requirements.no-gdal.txt && \
    CPLUS_INCLUDE_PATH=/usr/include/gdal C_INCLUDE_PATH=/usr/include/gdal \
    /opt/remote-sensing/.venv/bin/pip install --no-cache-dir --no-build-isolation --no-binary=GDAL "GDAL==$(gdal-config --version)" && \
    /opt/remote-sensing/.venv/bin/python -c "from osgeo import gdal, gdal_array; import numpy as np; print(gdal.__version__)"

# 创建运行用户
RUN groupadd -g 1000 appuser && \
    useradd -m -u 1000 -g appuser appuser && \
    chown -R appuser:appuser /app /opt/remote-sensing /opt/object-detection

USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -fsS http://localhost:8080/health || exit 1

CMD ["./server"]
