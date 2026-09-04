package handlers

import (
	"go.uber.org/zap"
	"gorm.io/gorm"

	"github.com/gin-gonic/gin"

	"satellite-cloud/backend/internal/objectdetection"
	"satellite-cloud/backend/internal/remotesensing"
)

// RegisterRoutes 注册所有 API 路由
// crdConfigDir：声明式清单（CRD）目录，用于 POST /api/crd/sync；
// 传空字符串则该端点要求请求体携带 config_dir。
func RegisterRoutes(router *gin.RouterGroup, db *gorm.DB, logger *zap.Logger, remoteSvc *remotesensing.RemoteSensingService, detectionSvc *objectdetection.ObjectDetectionService, crdConfigDir string) {
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
	router.GET("/topology/router-links", topologyHandler.TopologyRouterLinksHandler)
	router.GET("/topology/pilot-map", topologyHandler.TopologyPilotMapHandler)

	if remoteSvc != nil {
		remoteHandler := NewRemoteSensingHandler(remoteSvc, logger)
		remote := router.Group("/remote-sensing")
		remote.POST("/tasks", remoteHandler.CreateTask)
		remote.GET("/tasks", remoteHandler.ListTasks)
		remote.GET("/tasks/:id", remoteHandler.GetTask)
		remote.GET("/tasks/:id/stages", remoteHandler.ListStages)
		remote.GET("/tasks/:id/logs", remoteHandler.ListLogs)
		remote.GET("/tasks/:id/artifacts", remoteHandler.ListArtifacts)
		remote.GET("/tasks/:id/detection-stats", remoteHandler.GetDetectionStats)
		remote.GET("/tasks/:id/detection-tiles.zip", remoteHandler.DownloadDetectionTilesArchive)
		remote.GET("/tasks/:id/artifacts/:artifactId", remoteHandler.DownloadArtifact)
		remote.GET("/tasks/:id/events", remoteHandler.StreamEvents)
	}

	if detectionSvc != nil {
		detectionHandler := NewObjectDetectionHandler(detectionSvc, logger)
		detection := router.Group("/object-detection")
		detection.POST("/tasks", detectionHandler.CreateTask)
		detection.GET("/tasks", detectionHandler.ListTasks)
		detection.GET("/tasks/:id", detectionHandler.GetTask)
		detection.GET("/tasks/:id/stages", detectionHandler.ListStages)
		detection.GET("/tasks/:id/logs", detectionHandler.ListLogs)
		detection.GET("/tasks/:id/artifacts", detectionHandler.ListArtifacts)
		detection.GET("/tasks/:id/artifacts/:artifactId", detectionHandler.DownloadArtifact)
		detection.GET("/tasks/:id/events", detectionHandler.StreamEvents)
	}

	// 声明式任务队列（kind: JobQueue）
	jobQueueHandler := NewJobQueueHandler(db, logger)
	router.GET("/job-queues", jobQueueHandler.List)

	// 声明式产物存储（kind: StorageBackend）
	storageBackendHandler := NewStorageBackendHandler(db, logger)
	router.GET("/storage-backends", storageBackendHandler.List)

	// CRD 清单同步（SatelliteConstellation / Satellite / NetworkTopology /
	// JobQueue / StorageBackend / RemoteSensingTask / ObjectDetectionTask）
	crdHandler := NewCRDHandler(db, logger, crdConfigDir)
	router.POST("/crd/sync", crdHandler.Sync)

	// CRD 清单文件在线查看 / 修改 / 单文件执行
	router.GET("/crd/manifests", crdHandler.ListManifests)
	router.GET("/crd/manifests/:filename", crdHandler.GetManifest)
	router.PUT("/crd/manifests/:filename", crdHandler.SaveManifest)
	router.POST("/crd/manifests/:filename/apply", crdHandler.ApplyManifest)
}
