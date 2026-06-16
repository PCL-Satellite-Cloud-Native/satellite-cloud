package handlers

import (
	"fmt"
	"io"
	"mime"
	"net/http"
	"path/filepath"
	"strconv"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
	"gorm.io/gorm"

	"satellite-cloud/backend/internal/objectdetection"
)

type ObjectDetectionHandler struct {
	svc    *objectdetection.ObjectDetectionService
	logger *zap.Logger
}

func NewObjectDetectionHandler(svc *objectdetection.ObjectDetectionService, logger *zap.Logger) *ObjectDetectionHandler {
	return &ObjectDetectionHandler{svc: svc, logger: logger}
}

func (h *ObjectDetectionHandler) CreateTask(c *gin.Context) {
	var body objectdetection.CreateTaskRequest
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	task, err := h.svc.CreateTask(c.Request.Context(), body)
	if err != nil {
		h.logger.Error("创建检测任务失败", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, task)
}

func (h *ObjectDetectionHandler) ListTasks(c *gin.Context) {
	tasks, err := h.svc.ListTasks(c.Request.Context())
	if err != nil {
		h.logger.Error("拉取检测任务列表失败", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, tasks)
}

func (h *ObjectDetectionHandler) GetTask(c *gin.Context) {
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
	c.JSON(http.StatusOK, task)
}

func (h *ObjectDetectionHandler) ListStages(c *gin.Context) {
	taskID, err := parseUintParam(c, "id")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	stages, err := h.svc.ListStages(c.Request.Context(), taskID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, stages)
}

func (h *ObjectDetectionHandler) ListLogs(c *gin.Context) {
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
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, logs)
}

func (h *ObjectDetectionHandler) ListArtifacts(c *gin.Context) {
	taskID, err := parseUintParam(c, "id")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	artifacts, err := h.svc.ListArtifacts(c.Request.Context(), taskID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, artifacts)
}

func (h *ObjectDetectionHandler) StreamEvents(c *gin.Context) {
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

func (h *ObjectDetectionHandler) DownloadArtifact(c *gin.Context) {
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
			if taskErr == nil && task.Status == objectdetection.TaskStatusRunning {
				h.logger.Info("检测产物尚未生成", zap.Uint("task_id", taskID), zap.Uint("artifact_id", artifactID))
			}
		}
		c.JSON(http.StatusNotFound, gin.H{"error": "artifact not found"})
		return
	}
	absPath, err := h.svc.ArtifactAbsolutePath(artifact)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	contentType := http.DetectContentType([]byte{})
	if ext := filepath.Ext(absPath); ext != "" {
		if mt := mime.TypeByExtension(ext); mt != "" {
			contentType = mt
		}
	}
	disposition := "attachment"
	if artifact.Type == "preview" || artifact.Type == "tile" {
		disposition = "inline"
	}
	c.Header("Content-Disposition", fmt.Sprintf("%s; filename=%q", disposition, filepath.Base(absPath)))
	c.Header("Content-Type", contentType)
	c.File(absPath)
}
