package remotesensing

import (
	"context"
	"fmt"
	"time"

	"go.uber.org/zap"

	"satellite-cloud/backend/internal/config"
	"satellite-cloud/backend/internal/metrics"
	"satellite-cloud/backend/internal/model"
	"satellite-cloud/backend/internal/queue"
)

// Options 控制 API / Worker 两种运行模式
type Options struct {
	Queue            config.QueueConfig
	BootstrapPending bool   // API 默认 true；rs-worker 设为 false
	MetricsWorker    string // rs-worker | od-worker | 空=不上报
}

// DefaultOptions API 进程默认选项
func DefaultOptions(queueCfg config.QueueConfig) Options {
	return Options{Queue: queueCfg, BootstrapPending: true}
}

// WorkerOptions rs-worker 进程选项（仅消费 Redis，不启动内进程 worker）
func WorkerOptions(queueCfg config.QueueConfig) Options {
	queueCfg.UseInProcessPipeline = false
	return Options{Queue: queueCfg, BootstrapPending: false, MetricsWorker: "rs-worker"}
}

func createTaskRequestFromJob(job queue.RSJobPayload) CreateTaskRequest {
	return CreateTaskRequest{
		Name:                job.Name,
		FilePrefix:          job.FilePrefix,
		InputDirectory:      job.InputDirectory,
		Sensor:              job.Sensor,
		EnableDetection:     job.EnableDetection,
		DetectionClasses:    job.DetectionClasses,
		DetectionDrawLabels: job.DetectionDrawLabels,
	}
}

func createTaskRequestFromModel(t model.RemoteSensingTask) CreateTaskRequest {
	return CreateTaskRequest{
		Name:                t.Name,
		FilePrefix:          t.FilePrefix,
		InputDirectory:      t.InputDirectory,
		Sensor:              t.Sensor,
		EnableDetection:     t.EnableDetection,
		DetectionClasses:    t.DetectionClasses,
		DetectionDrawLabels: t.DetectionDrawLabels,
	}
}

func (s *RemoteSensingService) getRedisClient() (*queue.Client, error) {
	s.redisMu.Lock()
	defer s.redisMu.Unlock()
	if s.redisClient != nil {
		return s.redisClient, nil
	}
	addr := s.queueCfg.RedisAddr
	if addr == "" {
		return nil, fmt.Errorf("SATELLITE_REDIS_ADDR 未配置")
	}
	client, err := queue.NewClient(
		addr,
		s.queueCfg.StreamRS,
		s.queueCfg.ConsumerGroup,
		"satellite-api-enqueue",
	)
	if err != nil {
		return nil, err
	}
	s.redisClient = client
	return client, nil
}

func (s *RemoteSensingService) enqueueRedis(ctx context.Context, taskID uint, req CreateTaskRequest) error {
	client, err := s.getRedisClient()
	if err != nil {
		return err
	}
	streamID, err := client.EnqueueRSJob(ctx, queue.RSJobPayload{
		TaskID:              taskID,
		Name:                req.Name,
		FilePrefix:          req.FilePrefix,
		InputDirectory:      req.InputDirectory,
		Sensor:              req.Sensor,
		EnableDetection:     req.EnableDetection,
		DetectionClasses:    req.DetectionClasses,
		DetectionDrawLabels: req.DetectionDrawLabels,
		EnqueuedAt:          time.Now().UTC().Format(time.RFC3339),
	})
	if err != nil {
		return err
	}
	s.logger.Info("任务已入队 Redis",
		zap.Uint("task_id", taskID),
		zap.String("stream", s.queueCfg.StreamRS),
		zap.String("stream_id", streamID),
	)
	return nil
}

func (s *RemoteSensingService) bootstrapPendingToRedis() {
	var tasks []model.RemoteSensingTask
	if err := s.db.Where("status = ?", TaskStatusPending).Order("created_at ASC").Find(&tasks).Error; err != nil {
		s.logger.Error("加载 pending 任务失败", zap.Error(err))
		return
	}
	ctx := context.Background()
	for _, t := range tasks {
		if err := s.enqueueRedis(ctx, t.ID, createTaskRequestFromModel(t)); err != nil {
			s.logger.Error("恢复 pending 任务入 Redis 失败", zap.Uint("task_id", t.ID), zap.Error(err))
		}
	}
	if len(tasks) > 0 {
		s.logger.Info("已恢复 pending 任务到 Redis", zap.Int("count", len(tasks)))
	}
}

// RunPipeline 执行完整 RS 流水线（供 rs-worker 或内进程 worker 调用）
func (s *RemoteSensingService) RunPipeline(ctx context.Context, taskID uint, req CreateTaskRequest) {
	s.runPipeline(ctx, taskID, req)
}

// RunPipelineFromJob 从 Redis job payload 执行流水线
func (s *RemoteSensingService) RunPipelineFromJob(ctx context.Context, job queue.RSJobPayload) {
	if s.metricsWorker != "" {
		metrics.WorkerJobsActive.WithLabelValues(s.metricsWorker).Inc()
		defer metrics.WorkerJobsActive.WithLabelValues(s.metricsWorker).Dec()
	}
	start := time.Now()
	defer s.recordWorkerMetrics(start, job.TaskID, true)

	s.RunPipeline(ctx, job.TaskID, createTaskRequestFromJob(job))
}

func (s *RemoteSensingService) recordWorkerMetrics(start time.Time, taskID uint, rsPartial bool) {
	if s.metricsWorker == "" {
		return
	}
	var t model.RemoteSensingTask
	if err := s.db.Select("status").First(&t, taskID).Error; err != nil {
		return
	}
	outcome := t.Status
	if rsPartial && s.metricsWorker == "rs-worker" && t.Status == TaskStatusRunning {
		outcome = "od_enqueued"
	}
	metrics.ObserveWorkerTask(s.metricsWorker, outcome, time.Since(start))
}
