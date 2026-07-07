package remotesensing

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"go.uber.org/zap"

	"satellite-cloud/backend/internal/config"
	"satellite-cloud/backend/internal/metrics"
	"satellite-cloud/backend/internal/model"
	"satellite-cloud/backend/internal/queue"
)

// ODWorkerOptions od-worker 进程选项（仅消费 od.jobs）
func ODWorkerOptions(queueCfg config.QueueConfig) Options {
	queueCfg.UseInProcessPipeline = false
	return Options{Queue: queueCfg, BootstrapPending: false, MetricsWorker: "od-worker"}
}

func fusionDatRelPersist(cfg config.RemoteSensingConfig, taskID uint, filePrefix string) string {
	return persistPreprocessingDir(taskID, cfg.PersistOutputDir, cfg.TaskPathIsolation, "fusion_envi", fmt.Sprintf("%s-MSS1-fusion.dat", filePrefix))
}

func createTaskRequestFromODJob(job queue.ODJobPayload) CreateTaskRequest {
	return CreateTaskRequest{
		FilePrefix:          job.FilePrefix,
		DetectionClasses:    job.DetectionClasses,
		DetectionDrawLabels: job.DetectionDrawLabels,
		EnableDetection:     true,
	}
}

func (s *RemoteSensingService) enqueueOD(ctx context.Context, taskID uint, req CreateTaskRequest, fusionDatRel string) error {
	client, err := s.getRedisClient()
	if err != nil {
		return err
	}
	satID := uint(0)
	if req.SatelliteID != nil {
		satID = *req.SatelliteID
	}
	streamID, err := client.EnqueueODJob(ctx, s.queueCfg.StreamOD, queue.ODJobPayload{
		TaskID:              taskID,
		SatelliteID:         satID,
		FilePrefix:          req.FilePrefix,
		FusionDatRel:        fusionDatRel,
		DetectionClasses:    req.DetectionClasses,
		DetectionDrawLabels: req.DetectionDrawLabels,
		EnqueuedAt:          time.Now().UTC().Format(time.RFC3339),
	})
	if err != nil {
		return err
	}
	s.logger.Info("检测任务已入队 Redis",
		zap.Uint("task_id", taskID),
		zap.String("stream", s.queueCfg.StreamOD),
		zap.String("stream_id", streamID),
		zap.String("fusion_dat_rel", fusionDatRel),
	)
	return nil
}

// enqueueODWithRetry 向 od.jobs 入队；Redis LOADING（重启/AOF 加载）时退避重试。
func (s *RemoteSensingService) enqueueODWithRetry(ctx context.Context, taskID uint, req CreateTaskRequest, fusionDatRel string) error {
	const maxAttempts = 10
	var lastErr error
	for attempt := 1; attempt <= maxAttempts; attempt++ {
		err := s.enqueueOD(ctx, taskID, req, fusionDatRel)
		if err == nil {
			s.log(taskID, StageObjectDetection, "info", "检测任务已入队 od.jobs，等待 od-worker 消费")
			return nil
		}
		lastErr = err
		msg := err.Error()
		if strings.Contains(msg, "LOADING") {
			wait := time.Duration(attempt) * 3 * time.Second
			s.log(taskID, StageObjectDetection, "warn",
				fmt.Sprintf("Redis LOADING，%ds 后重试入队 od.jobs（%d/%d）", wait/time.Second, attempt, maxAttempts))
			select {
			case <-ctx.Done():
				return ctx.Err()
			case <-time.After(wait):
			}
			continue
		}
		return err
	}
	return lastErr
}

// RunDetectionFromJob od-worker 消费 od.jobs 后执行阶段 10
func (s *RemoteSensingService) RunDetectionFromJob(ctx context.Context, job queue.ODJobPayload) {
	if s.metricsWorker != "" {
		metrics.WorkerJobsActive.WithLabelValues(s.metricsWorker).Inc()
		defer metrics.WorkerJobsActive.WithLabelValues(s.metricsWorker).Dec()
	}
	start := time.Now()
	defer s.recordWorkerMetrics(start, job.TaskID, false)

	s.recordTaskPlacement(ctx, job.TaskID)
	taskID := job.TaskID
	req := createTaskRequestFromODJob(job)
	req.FusionDatRel = job.FusionDatRel
	def := stageDefinition{Name: StageObjectDetection, Title: "YOLOv8 目标识别", Order: 10}

	if err := s.runStage(ctx, taskID, def, req); err != nil {
		s.finishTaskWithError(taskID, fmt.Sprintf("阶段 %s 失败: %v", def.Name, err))
		return
	}
	s.finishTaskCompleted(taskID)
}

// persistFusionArtifactsSync 阶段 9 完成后同步持久化融合产物（od-worker 跨 Pod 需读 NFS）
func (s *RemoteSensingService) persistFusionArtifactsSync(taskID uint, filePrefix string) error {
	if s.isolatedWorkOnPersist() {
		s.log(taskID, StageFusionStack, "info", "task_path_isolation：融合产物已在 NFS persist，跳过同步复制")
		return nil
	}
	finalDatName := fmt.Sprintf("%s-MSS1-fusion.dat", filePrefix)
	finalHdrName := fmt.Sprintf("%s-MSS1-fusion.hdr", filePrefix)
	previewName := fmt.Sprintf("%s-MSS1-fusion.png", filePrefix)

	scratchFinalDatRel := s.scratchDir(taskID, "fusion_envi", finalDatName)
	scratchFinalHdrRel := s.scratchDir(taskID, "fusion_envi", finalHdrName)
	scratchPreviewRel := s.scratchDir(taskID, "imgshow", previewName)

	persistFinalDatRel := s.persistRel(taskID, "fusion_envi", finalDatName)
	persistFinalHdrRel := s.persistRel(taskID, "fusion_envi", finalHdrName)
	persistPreviewRel := s.persistRel(taskID, "imgshow", previewName)

	persistFusionDir := filepath.Join(s.cfg.RootPath, s.persistRel(taskID, "fusion_envi"))
	persistPreviewDir := filepath.Join(s.cfg.RootPath, s.persistRel(taskID, "imgshow"))
	if err := os.MkdirAll(persistFusionDir, 0o755); err != nil {
		return fmt.Errorf("持久化目录创建失败: %w", err)
	}
	if err := os.MkdirAll(persistPreviewDir, 0o755); err != nil {
		return fmt.Errorf("持久化目录创建失败: %w", err)
	}

	s.log(taskID, StageFusionStack, "info", fmt.Sprintf("同步持久化开始: %s", persistFinalDatRel))
	if err := copyFile(filepath.Join(s.cfg.RootPath, scratchFinalDatRel), filepath.Join(s.cfg.RootPath, persistFinalDatRel)); err != nil {
		return fmt.Errorf("持久化 dat 失败: %w", err)
	}
	if _, err := os.Stat(filepath.Join(s.cfg.RootPath, scratchFinalHdrRel)); err == nil {
		if err := copyFile(filepath.Join(s.cfg.RootPath, scratchFinalHdrRel), filepath.Join(s.cfg.RootPath, persistFinalHdrRel)); err != nil {
			return fmt.Errorf("持久化 hdr 失败: %w", err)
		}
	}
	if err := copyFile(filepath.Join(s.cfg.RootPath, scratchPreviewRel), filepath.Join(s.cfg.RootPath, persistPreviewRel)); err != nil {
		return fmt.Errorf("持久化预览图失败: %w", err)
	}

	ctx := context.Background()
	_ = s.db.WithContext(ctx).Model(&model.RemoteSensingTaskArtifact{}).
		Where("task_id = ? AND path = ?", taskID, scratchFinalDatRel).
		Update("path", persistFinalDatRel).Error
	_ = s.db.WithContext(ctx).Model(&model.RemoteSensingTaskArtifact{}).
		Where("task_id = ? AND path = ?", taskID, scratchPreviewRel).
		Update("path", persistPreviewRel).Error

	s.log(taskID, StageFusionStack, "info", "同步持久化完成")
	return nil
}
