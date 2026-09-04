package handlers

// StorageBackendHandler 提供声明式产物存储（kind: StorageBackend）的查询入口。
// 存储声明由 apply-config / POST /api/crd/sync 幂等同步到 storage_backends 表。
import (
	"net/http"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
	"gorm.io/gorm"

	"satellite-cloud/backend/internal/model"
)

type StorageBackendHandler struct {
	db     *gorm.DB
	logger *zap.Logger
}

func NewStorageBackendHandler(db *gorm.DB, logger *zap.Logger) *StorageBackendHandler {
	return &StorageBackendHandler{db: db, logger: logger}
}

// List 返回 storage_backends 表中的全部存储声明（GET /api/storage-backends）。
// MinIO 私有密钥返回时脱敏为 ******，避免泄露到前端。
func (h *StorageBackendHandler) List(c *gin.Context) {
	var backends []model.StorageBackend
	if err := h.db.Order("name asc").Find(&backends).Error; err != nil {
		h.logger.Error("Failed to list storage backends", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	for i := range backends {
		if backends[i].MinioSecretKey != "" {
			backends[i].MinioSecretKey = "******"
		}
	}
	c.JSON(http.StatusOK, gin.H{"storage_backends": backends})
}
