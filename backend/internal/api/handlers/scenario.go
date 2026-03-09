package handlers

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
	"gorm.io/gorm"

	"satellite-cloud/backend/internal/model"
)

type ScenarioHandler struct {
	db     *gorm.DB
	logger *zap.Logger
}

func NewScenarioHandler(db *gorm.DB, logger *zap.Logger) *ScenarioHandler {
	return &ScenarioHandler{
		db:     db,
		logger: logger,
	}
}

// List 获取场景列表
func (h *ScenarioHandler) List(c *gin.Context) {
	var results []model.ScenarioListResponse
	err := h.db.Model(&model.Scenario{}).
		Select(`scenarios.id, scenarios.name, scenarios.epoch, scenarios.start_time, scenarios.end_time,
			scenarios.alt_km, scenarios.inc_deg, scenarios.n_planes, scenarios.n_sats_per_plane,
			COUNT(satellites.id) AS satellites_count`).
		Joins("LEFT JOIN satellites ON satellites.scenario_id = scenarios.id").
		Group("scenarios.id, scenarios.name, scenarios.epoch, scenarios.start_time, scenarios.end_time, scenarios.alt_km, scenarios.inc_deg, scenarios.n_planes, scenarios.n_sats_per_plane").
		Order("scenarios.id DESC").
		Scan(&results).Error

	if err != nil {
		h.logger.Error("Failed to list scenarios", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to fetch scenarios",
			"detail":  err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"count":    len(results),
		"results":  results,
		"next":     nil,
		"previous": nil,
	})
}

// Get 获取场景详情
func (h *ScenarioHandler) Get(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid scenario ID"})
		return
	}

	var scenario model.Scenario
	if err := h.db.First(&scenario, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": "Scenario not found"})
			return
		}
		h.logger.Error("Failed to get scenario", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch scenario"})
		return
	}

	// 获取卫星数量
	var count int64
	h.db.Model(&model.Satellite{}).Where("scenario_id = ?", id).Count(&count)
	
	response := gin.H{
		"id":              scenario.ID,
		"name":             scenario.Name,
		"epoch":            scenario.Epoch,
		"start_time":       scenario.StartTime,
		"end_time":         scenario.EndTime,
		"alt_km":          scenario.AltKm,
		"inc_deg":         scenario.IncDeg,
		"n_planes":        scenario.NPlanes,
		"n_sats_per_plane": scenario.NSatsPerPlane,
		"sensor_config":    scenario.SensorConfig,
		"satellites_count": count,
		"created_at":       scenario.CreatedAt,
		"updated_at":       scenario.UpdatedAt,
	}

	c.JSON(http.StatusOK, response)
}

// GetSatellites 获取场景下的所有卫星
func (h *ScenarioHandler) GetSatellites(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid scenario ID"})
		return
	}

	var satellites []model.Satellite
	if err := h.db.Where("scenario_id = ?", id).
		Order("plane_index, sat_index_in_plane").
		Find(&satellites).Error; err != nil {
		h.logger.Error("Failed to get satellites", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch satellites"})
		return
	}

	c.JSON(http.StatusOK, satellites)
}
