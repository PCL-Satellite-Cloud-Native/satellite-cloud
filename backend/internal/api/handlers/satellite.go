package handlers

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
	"gorm.io/gorm"

	"satellite-cloud/backend/internal/model"
)

type SatelliteHandler struct {
	db     *gorm.DB
	logger *zap.Logger
}

func NewSatelliteHandler(db *gorm.DB, logger *zap.Logger) *SatelliteHandler {
	return &SatelliteHandler{
		db:     db,
		logger: logger,
	}
}

// List 获取卫星列表
func (h *SatelliteHandler) List(c *gin.Context) {
	var satellites []model.Satellite
	query := h.db.Model(&model.Satellite{})

	// 支持通过 scenario_id 过滤
	if scenarioID := c.Query("scenario_id"); scenarioID != "" {
		id, err := strconv.ParseUint(scenarioID, 10, 32)
		if err == nil {
			query = query.Where("scenario_id = ?", id)
		}
	}

	if err := query.Order("plane_index, sat_index_in_plane").Find(&satellites).Error; err != nil {
		h.logger.Error("Failed to list satellites", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch satellites"})
		return
	}

	c.JSON(http.StatusOK, filterPilotSatellites(satellites))
}

// Get 获取卫星详情
func (h *SatelliteHandler) Get(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid satellite ID"})
		return
	}

	var satellite model.Satellite
	if err := h.db.First(&satellite, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": "Satellite not found"})
			return
		}
		h.logger.Error("Failed to get satellite", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch satellite"})
		return
	}

	c.JSON(http.StatusOK, satellite)
}
