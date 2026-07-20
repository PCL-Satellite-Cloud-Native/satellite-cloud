package handlers

import (
	"fmt"
	"io"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
	"gorm.io/gorm"

	"satellite-cloud/backend/internal/remotesensing"
)

// RemoteSensingHandler 处理遥感任务 API
type RemoteSensingHandler struct {
	svc    *remotesensing.RemoteSensingService
	logger *zap.Logger
}

// NewRemoteSensingHandler 创建实例
func NewRemoteSensingHandler(svc *remotesensing.RemoteSensingService, logger *zap.Logger) *RemoteSensingHandler {
	return &RemoteSensingHandler{svc: svc, logger: logger}
}

func (h *RemoteSensingHandler) CreateTask(c *gin.Context) {
	var body remotesensing.CreateTaskRequest
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	task, err := h.svc.CreateTask(c.Request.Context(), body)
	if err != nil {
		h.logger.Error("创建遥感任务失败", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, task)
}

func (h *RemoteSensingHandler) ListTasks(c *gin.Context) {
	filter := remotesensing.TaskListFilter{Status: c.Query("status")}
	if v := c.Query("scenario_id"); v != "" {
		id, err := strconv.ParseUint(v, 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid scenario_id"})
			return
		}
		u := uint(id)
		filter.ScenarioID = &u
	}
	if v := c.Query("satellite_id"); v != "" {
		id, err := strconv.ParseUint(v, 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid satellite_id"})
			return
		}
		u := uint(id)
		filter.SatelliteID = &u
	}
	tasks, err := h.svc.ListTasks(c.Request.Context(), filter)
	if err != nil {
		h.logger.Error("拉取任务列表失败", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, tasks)
}

func (h *RemoteSensingHandler) GetTask(c *gin.Context) {
	taskID, err := parseUintParam(c, "id")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	task, err := h.svc.GetTask(c.Request.Context(), taskID)
	if err != nil {
		h.logger.Error("获取任务失败", zap.Error(err))
		c.JSON(http.StatusNotFound, gin.H{"error": "task not found"})
		return
	}
	c.JSON(http.StatusOK, task)
}

func (h *RemoteSensingHandler) ListStages(c *gin.Context) {
	taskID, err := parseUintParam(c, "id")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	stages, err := h.svc.ListStages(c.Request.Context(), taskID)
	if err != nil {
		h.logger.Error("获取阶段失败", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, stages)
}

func (h *RemoteSensingHandler) ListLogs(c *gin.Context) {
	taskID, err := parseUintParam(c, "id")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	limit := 200
	if limitStr := c.Query("limit"); limitStr != "" {
		if l, err := strconv.Atoi(limitStr); err == nil {
			limit = l
		}
	}
	logs, err := h.svc.ListLogs(c.Request.Context(), taskID, limit)
	if err != nil {
		h.logger.Error("获取日志失败", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, logs)
}

func (h *RemoteSensingHandler) GetDetectionStats(c *gin.Context) {
	taskID, err := parseUintParam(c, "id")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	stats, err := h.svc.GetDetectionStats(c.Request.Context(), taskID)
	if err != nil {
		h.logger.Error("获取检测统计失败", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, stats)
}

func (h *RemoteSensingHandler) ListArtifacts(c *gin.Context) {
	taskID, err := parseUintParam(c, "id")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	artifacts, err := h.svc.ListArtifacts(c.Request.Context(), taskID)
	if err != nil {
		h.logger.Error("获取产物失败", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, artifacts)
}

func (h *RemoteSensingHandler) StreamEvents(c *gin.Context) {
	taskID, err := parseUintParam(c, "id")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	eventCh, cancel := h.svc.Subscribe(taskID)
	defer cancel()
	c.Writer.Header().Set("Cache-Control", "no-cache")
	c.Writer.Header().Set("Content-Type", "text/event-stream")
	c.Writer.Header().Set("Connection", "keep-alive")
	c.Stream(func(w io.Writer) bool {
		select {
		case <-c.Request.Context().Done():
			return false
		case ev, ok := <-eventCh:
			if !ok {
				return false
			}
			c.SSEvent("stage_update", ev)
			return true
		}
	})
}

func (h *RemoteSensingHandler) DownloadDetectionTilesArchive(c *gin.Context) {
	taskID, err := parseUintParam(c, "id")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	task, err := h.svc.GetTask(c.Request.Context(), taskID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "task not found"})
		return
	}
	if !task.EnableDetection {
		c.JSON(http.StatusBadRequest, gin.H{"error": "该任务未启用目标识别"})
		return
	}
	if _, err := h.svc.DetectionOutputAbsDir(taskID); err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}

	filename := fmt.Sprintf("rs_task_%d_detection_tiles.zip", taskID)
	c.Header("Content-Type", "application/zip")
	c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=%q", filename))

	count, err := h.svc.WriteDetectionTilesArchive(c.Request.Context(), taskID, c.Writer)
	if err != nil {
		h.logger.Error("打包检测瓦片失败", zap.Uint("task_id", taskID), zap.Error(err))
		if !c.Writer.Written() {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		}
		return
	}
	h.logger.Info("检测瓦片打包完成", zap.Uint("task_id", taskID), zap.Int("files", count))
}

func (h *RemoteSensingHandler) DownloadArtifact(c *gin.Context) {
	taskID, err := parseUintParam(c, "id")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	artifactID, err := parseUintParam(c, "artifactId")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	artifact, err := h.svc.GetArtifact(c.Request.Context(), taskID, artifactID)
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			task, taskErr := h.svc.GetTask(c.Request.Context(), taskID)
			if taskErr == nil && task.Status == remotesensing.TaskStatusRunning {
				h.logger.Info("产物尚未生成（任务运行中）", zap.Uint("task_id", taskID), zap.Uint("artifact_id", artifactID))
			} else {
				h.logger.Warn("查询产物失败", zap.Error(err))
			}
		} else {
			h.logger.Error("查询产物失败", zap.Error(err))
		}
		c.JSON(http.StatusNotFound, gin.H{"error": "artifact not found"})
		return
	}
	// minio 模式优先走 Open，避免误用本地 Resolve（sat57 PVC 无锚点文件）。
	if h.svc.StorageMode() != "minio" {
		absPath, err := h.svc.ArtifactAbsolutePath(artifact)
		if err == nil {
			serveArtifactFile(c, h.logger, absPath, artifact.Path, artifact.Type)
			return
		}
	}
	rc, openErr := h.svc.OpenArtifact(c.Request.Context(), artifact)
	if openErr != nil {
		h.logger.Error("打开产物失败", zap.Error(openErr), zap.String("storage", h.svc.StorageMode()))
		c.JSON(http.StatusInternalServerError, gin.H{"error": openErr.Error()})
		return
	}
	serveArtifactStream(c, h.logger, rc, artifact.Path, artifact.Type)
}

func parseUintParam(c *gin.Context, name string) (uint, error) {
	raw := c.Param(name)
	if raw == "" {
		return 0, fmt.Errorf("missing %s", name)
	}
	id, err := strconv.ParseUint(raw, 10, 64)
	if err != nil {
		return 0, fmt.Errorf("invalid %s", name)
	}
	return uint(id), nil
}
