ARG BASE_IMAGE_REGISTRY=192.168.10.238/library
FROM ${BASE_IMAGE_REGISTRY}/node:22-alpine AS builder

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm ci || npm install

COPY . .

# 可选：K8s 部署时传入 Grafana 地址，主页「性能监控中台」将直跳 Grafana
ARG VITE_GRAFANA_URL
ENV VITE_GRAFANA_URL=$VITE_GRAFANA_URL

# 构建静态文件
RUN npm run build

# 运行阶段：使用 Nginx 提供静态文件
ARG BASE_IMAGE_REGISTRY=192.168.10.238/library
FROM ${BASE_IMAGE_REGISTRY}/nginx:alpine

WORKDIR /usr/share/nginx/html

COPY --from=builder /app/dist/ .

# 可选：自定义 Nginx 配置（例如单页应用路由）
# COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
