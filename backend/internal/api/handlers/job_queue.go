package handlers

// JobQueueHandler 提供声明式任务队列（kind: JobQueue）的查询入口。
// 队列声明由 apply-config / POST /api/crd/sync 幂等同步到 job_queues 表。
import (
	"net/http"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
	"gorm.io/gorm"

	"satellite-cloud/backend/internal/model"
)

type JobQueueHandler struct {
	db     *gorm.DB
	logger *zap.Logger
}

func NewJobQueueHandler(db *gorm.DB, logger *zap.Logger) *JobQueueHandler {
	return &JobQueueHandler{db: db, logger: logger}
}

// List 返回 job_queues 表中的全部队列声明（GET /api/job-queues）。
func (h *JobQueueHandler) List(c *gin.Context) {
	var queues []model.JobQueue
	if err := h.db.Order("name asc").Find(&queues).Error; err != nil {
		h.logger.Error("Failed to list job queues", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"queues": queues})
}
