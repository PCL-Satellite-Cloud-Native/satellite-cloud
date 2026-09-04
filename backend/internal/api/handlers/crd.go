package handlers

// CRDHandler 提供声明式清单（CRD）同步的 HTTP 入口。
//
// 集成路径：kubectl 风格的 YAML 清单（SatelliteConstellation / Satellite
// / NetworkTopology / JobQueue / StorageBackend / RemoteSensingTask /
// ObjectDetectionTask）→ POST /api/crd/sync → PostgreSQL。
// 前端/运维可通过该端点把声明式配置应用到运行中的后端，而无需重启服务。
import (
	"net/http"
	"path/filepath"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
	"gorm.io/gorm"

	"satellite-cloud/backend/internal/declarative"
)

type CRDHandler struct {
	db        *gorm.DB
	logger    *zap.Logger
	configDir string
}

func NewCRDHandler(db *gorm.DB, logger *zap.Logger, configDir string) *CRDHandler {
	return &CRDHandler{db: db, logger: logger, configDir: configDir}
}

// Sync 执行 CRD 清单同步（POST /api/crd/sync）。
// 请求体可选：{"config_dir": "config/declarative"}；缺省使用启动时目录。
func (h *CRDHandler) Sync(c *gin.Context) {
	var req struct {
		ConfigDir string `json:"config_dir"`
	}
	_ = c.ShouldBindJSON(&req)
	dir := req.ConfigDir
	if dir == "" {
		dir = h.configDir
	}
	if dir == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "config_dir is required: start server with SATELLITE_CRD_CONFIG_DIR or pass config_dir in body",
		})
		return
	}

	results, err := declarative.ApplyAll(h.db, dir)
	if err != nil {
		h.logger.Error("CRD sync failed", zap.String("dir", dir), zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"config_dir": dir, "error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"config_dir": dir, "results": results})
}

// resolveDir 解析清单目录：请求体 config_dir 优先，否则用启动时目录。
func (h *CRDHandler) resolveDir(c *gin.Context, reqDir string) (string, bool) {
	dir := reqDir
	if dir == "" {
		dir = h.configDir
	}
	if dir == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "config_dir is required: start server with SATELLITE_CRD_CONFIG_DIR or pass config_dir in body",
		})
		return "", false
	}
	return dir, true
}

// ListManifests 列出清单目录下所有 YAML 文件（GET /api/crd/manifests）。
func (h *CRDHandler) ListManifests(c *gin.Context) {
	var req struct {
		ConfigDir string `json:"config_dir"`
	}
	_ = c.ShouldBindJSON(&req)
	dir, ok := h.resolveDir(c, req.ConfigDir)
	if !ok {
		return
	}
	files, err := declarative.ListManifestFiles(dir)
	if err != nil {
		h.logger.Error("CRD list manifests failed", zap.String("dir", dir), zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"config_dir": dir, "files": files})
}

// GetManifest 读取单个清单文件内容（GET /api/crd/manifests/:filename）。
func (h *CRDHandler) GetManifest(c *gin.Context) {
	dir, ok := h.resolveDir(c, "")
	if !ok {
		return
	}
	filename := filepath.Base(c.Param("filename"))
	data, m, err := declarative.LoadManifestFile(dir, filename)
	if err != nil {
		h.logger.Warn("CRD get manifest failed",
			zap.String("file", filename), zap.Error(err))
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"name":    filename,
		"kind":    m.Kind,
		"content": string(data),
	})
}

// SaveManifest 保存（覆盖）单个清单文件（PUT /api/crd/manifests/:filename）。
// 写入前做 YAML 结构校验；保存后不会自动执行，需再调用 ApplyManifest。
func (h *CRDHandler) SaveManifest(c *gin.Context) {
	dir, ok := h.resolveDir(c, "")
	if !ok {
		return
	}
	filename := filepath.Base(c.Param("filename"))
	var req struct {
		Content string `json:"content"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "body must be JSON: {\"content\": \"...\"}"})
		return
	}
	info, err := declarative.SaveManifestFile(dir, filename, []byte(req.Content))
	if err != nil {
		h.logger.Warn("CRD save manifest failed",
			zap.String("file", filename), zap.Error(err))
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	h.logger.Info("CRD manifest saved", zap.String("file", filename))
	c.JSON(http.StatusOK, gin.H{"saved": true, "file": info})
}

// ApplyManifest 执行单个清单文件（POST /api/crd/manifests/:filename/apply）。
func (h *CRDHandler) ApplyManifest(c *gin.Context) {
	var req struct {
		ConfigDir string `json:"config_dir"`
	}
	_ = c.ShouldBindJSON(&req)
	dir, ok := h.resolveDir(c, req.ConfigDir)
	if !ok {
		return
	}
	filename := filepath.Base(c.Param("filename"))
	results, err := declarative.ApplyFile(h.db, dir, filename)
	if err != nil {
		h.logger.Warn("CRD apply manifest failed",
			zap.String("file", filename), zap.Error(err))
		c.JSON(http.StatusBadRequest, gin.H{"file": filename, "error": err.Error()})
		return
	}
	h.logger.Info("CRD manifest applied", zap.String("file", filename))
	c.JSON(http.StatusOK, gin.H{"config_dir": dir, "file": filename, "results": results})
}
