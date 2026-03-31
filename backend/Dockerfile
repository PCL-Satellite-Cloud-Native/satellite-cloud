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
    CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o bin/import_topology ./tools

# 运行阶段：Go 服务 + Python 遥感运行时
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
    && rm -rf /var/lib/apt/lists/*

# 从构建阶段复制二进制文件（server + 拓扑导入 CLI）
COPY --from=builder /build/bin/server .
COPY --from=builder /build/bin/import_topology .

# 复制 GitLab CI 拉取的遥感项目源码
COPY remote-sensing-src /opt/remote-sensing

# 创建并安装遥感虚拟环境依赖
RUN python3 -m venv /opt/remote-sensing/.venv && \
    /opt/remote-sensing/.venv/bin/pip install --no-cache-dir --upgrade pip && \
    /opt/remote-sensing/.venv/bin/pip install --no-cache-dir numpy && \
    /opt/remote-sensing/.venv/bin/pip install --no-cache-dir -r /opt/remote-sensing/requirements.txt && \
    CPLUS_INCLUDE_PATH=/usr/include/gdal C_INCLUDE_PATH=/usr/include/gdal \
    /opt/remote-sensing/.venv/bin/pip install --no-cache-dir --no-binary=GDAL "GDAL==$(gdal-config --version)" && \
    /opt/remote-sensing/.venv/bin/python -c "from osgeo import gdal, gdal_array; import numpy as np; print(gdal.__version__)"

# 创建运行用户
RUN groupadd -g 1000 appuser && \
    useradd -m -u 1000 -g appuser appuser && \
    chown -R appuser:appuser /app /opt/remote-sensing

USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -fsS http://localhost:8080/health || exit 1

CMD ["./server"]
