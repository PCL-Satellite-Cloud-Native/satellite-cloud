ARG BASE_IMAGE_REGISTRY=192.168.10.238/library
FROM ${BASE_IMAGE_REGISTRY}/node:22-alpine-amd64-r1 AS builder

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm ci || npm install

COPY . .

# 可选：K8s 部署时传入 Grafana 地址，主页「性能监控中台」将直跳 Grafana
ARG VITE_GRAFANA_URL
ENV VITE_GRAFANA_URL=$VITE_GRAFANA_URL

# 若仓库未提交瓦片包，构建阶段尝试生成（需 sharp，失败不阻断构建）
RUN npm run prepare:tiles || true

# 构建静态文件
RUN npm run build

# 运行阶段：使用 Nginx 提供静态文件
ARG BASE_IMAGE_REGISTRY=192.168.10.238/library
FROM ${BASE_IMAGE_REGISTRY}/nginx:alpine-amd64-r1

WORKDIR /usr/share/nginx/html

COPY --from=builder /app/dist/ .

COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
