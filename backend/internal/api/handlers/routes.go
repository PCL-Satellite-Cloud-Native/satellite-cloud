package handlers

import (
	"gorm.io/gorm"
	"go.uber.org/zap"

	"github.com/gin-gonic/gin"
)

// RegisterRoutes 注册所有 API 路由
func RegisterRoutes(router *gin.RouterGroup, db *gorm.DB, logger *zap.Logger) {
	// 场景处理器
	scenarioHandler := NewScenarioHandler(db, logger)
	router.GET("/scenarios", scenarioHandler.List)
	router.GET("/scenarios/:id", scenarioHandler.Get)
	router.GET("/scenarios/:id/satellites", scenarioHandler.GetSatellites)

	// 卫星处理器
	satelliteHandler := NewSatelliteHandler(db, logger)
	router.GET("/satellites", satelliteHandler.List)
	router.GET("/satellites/:id", satelliteHandler.Get)

	// 拓扑（后端统一提供 API，底层数据逐步迁移到数据库）
	topologyHandler := NewTopologyHandler(db, logger)
	router.GET("/topology/t0", topologyHandler.TopologyT0Handler)
	router.GET("/topology/delay", topologyHandler.TopologyDelayHandler)
	router.GET("/topology/router", topologyHandler.TopologyRouterHandler)
}
