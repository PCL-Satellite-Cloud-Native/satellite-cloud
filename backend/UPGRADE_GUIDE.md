# Go 版本升级指南：1.18 → 1.25.7

## 📋 升级概览

本次升级将 Go 版本从 1.18 升级到 1.25.7，并同步升级所有依赖包到最新兼容版本。

## ✅ 已完成的更改

### 1. 核心文件更新
- ✅ `go.mod`: Go 版本更新为 `1.25.7`
- ✅ `Dockerfile`: 构建镜像更新为 `golang:1.25.7-alpine`
- ✅ 主要依赖包已升级到最新版本：
  - `gin-gonic/gin`: v1.9.1 → v1.11.0
  - `spf13/viper`: v1.16.0 → v1.21.0
  - `go.uber.org/zap`: v1.24.0 → v1.27.1
  - `gorm.io/gorm`: v1.25.0 → v1.31.1
  - `gorm.io/driver/postgres`: v1.5.0 → v1.6.0
- ✅ 移除了所有 Go 1.18 兼容性的 `replace` 指令

## 🔄 升级步骤

### 步骤 1: 更新依赖包

在 `backend` 目录下运行：

```bash
cd backend

# 删除旧的 go.sum，让 Go 重新计算依赖
rm go.sum

# 更新所有依赖到最新兼容版本
go mod tidy

# 验证依赖更新
go mod verify
```

### 步骤 2: 本地构建测试

```bash
# 清理之前的构建缓存
go clean -cache

# 构建应用
go build ./cmd/server

# 如果构建成功，运行测试（如果有）
go test ./...
```

### 步骤 3: Docker 构建测试

```bash
# 从 backend 目录构建 Docker 镜像
cd backend
docker build -t satellite-backend:test .

# 测试运行容器
docker run -p 8080:8080 satellite-backend:test
```

### 步骤 4: 验证功能

1. **健康检查**:
   ```bash
   curl http://localhost:8080/health
   # 预期: {"status":"ok"}
   ```

2. **就绪检查**:
   ```bash
   curl http://localhost:8080/ready
   # 预期: {"status":"ready"} 或 {"status":"not ready"}
   ```

3. **API 端点测试**:
   ```bash
   curl http://localhost:8080/api/scenarios
   curl http://localhost:8080/api/satellites
   ```

## 🚨 可能遇到的问题及解决方案

### 问题 1: 依赖包版本冲突

**症状**: `go mod tidy` 报错或警告

**解决**:
```bash
# 查看依赖树
go mod graph

# 强制更新特定依赖
go get -u package@latest

# 重新整理
go mod tidy
```

### 问题 2: 构建错误

**症状**: 编译时出现类型错误或 API 变更

**解决**:
- 检查 Go 1.25.7 的[发布说明](https://go.dev/doc/go1.25)
- 查看是否有废弃的 API
- 更新相关代码以适配新版本

### 问题 3: 运行时错误

**症状**: 应用启动失败或运行时崩溃

**解决**:
- 检查日志输出
- 验证数据库连接配置
- 确认所有环境变量正确设置

## 📊 Go 1.18 → 1.25.7 主要变更

### 语言特性
- **Go 1.19+**: 新增 `slices`、`maps`、`cmp` 标准库包
- **Go 1.20+**: 新增 `context.WithoutCancel`、`context.Cause`
- **Go 1.21+**: 新增 `log/slog` 结构化日志包
- **Go 1.22+**: 增强的 `for` 循环语义
- **Go 1.23+**: 新增 `iter` 包用于迭代器
- **Go 1.25+**: 性能优化和工具链改进

### 标准库变更
- `strings.Cut()`: Go 1.18+
- `time.Compare()`: Go 1.20+
- `http.NewResponseController()`: Go 1.23+
- `atomic.Bool`: Go 1.19+

## 🔍 代码审查检查清单

- [ ] 所有测试通过
- [ ] 构建无警告
- [ ] Docker 镜像构建成功
- [ ] 健康检查端点正常
- [ ] API 端点功能正常
- [ ] 日志输出正常
- [ ] 数据库连接正常
- [ ] 性能无明显下降

## 📝 回滚方案

如果升级后出现问题，可以快速回滚：

```bash
# 1. 恢复 go.mod
git checkout HEAD -- backend/go.mod

# 2. 恢复 Dockerfile
git checkout HEAD -- backend/Dockerfile

# 3. 重新下载依赖
cd backend
rm go.sum
go mod tidy
```

## 🎯 后续优化建议

1. **依赖管理**:
   - 定期运行 `go mod tidy` 保持依赖更新
   - 使用 `go list -m -u all` 检查可更新的依赖

2. **CI/CD 集成**:
   - 在 CI 流程中添加版本检查
   - 自动化依赖安全扫描

3. **性能监控**:
   - 对比升级前后的性能指标
   - 监控内存使用和响应时间

## 📚 参考资源

- [Go 1.25 Release Notes](https://go.dev/doc/go1.25)
- [Go Modules 文档](https://go.dev/ref/mod)
- [Go 版本兼容性](https://go.dev/doc/devel/release)

---

**升级日期**: $(date +%Y-%m-%d)  
**升级版本**: Go 1.18 → Go 1.25.7  
**负责人**: [填写你的名字]
