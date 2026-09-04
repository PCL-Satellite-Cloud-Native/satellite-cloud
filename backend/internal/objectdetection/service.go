package objectdetection

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"go.uber.org/zap"
	"gorm.io/datatypes"
	"gorm.io/gorm"

	"satellite-cloud/backend/internal/config"
	"satellite-cloud/backend/internal/model"
	"satellite-cloud/backend/internal/storage"
)

const (
	TaskStatusPending   = "pending"
	TaskStatusRunning   = "running"
	TaskStatusCompleted = "completed"
	TaskStatusFailed    = "failed"

	StagePending = "pending"
	StageRunning = "running"
	StageSuccess = "success"
	StageFailed  = "failed"

	StageDetect = "detect"
)

type stageDefinition struct {
	Name  string
	Title string
	Order int
}

// StageDefinition 目标检测流水线阶段定义的导出形态（供声明式同步等外部模块复用，
// 保证"阶段清单"在 objectdetection 包内保持单一事实来源）。
type StageDefinition struct {
	Name  string
	Title string
	Order int
}

// StageDefinitions 返回目标检测流水线阶段定义的副本（当前仅 detect 一个阶段）。
func StageDefinitions() []StageDefinition {
	out := make([]StageDefinition, 0, len(stageDefinitions))
	for _, d := range stageDefinitions {
		out = append(out, StageDefinition{Name: d.Name, Title: d.Title, Order: d.Order})
	}
	return out
}

var stageDefinitions = []stageDefinition{
	{Name: StageDetect, Title: "YOLOv8 目标检测", Order: 1},
}

type ObjectDetectionStageEvent struct {
	TaskID     uint                   `json:"task_id"`
	StageName  string                 `json:"stage_name,omitempty"`
	Status     string                 `json:"status"`
	Message    string                 `json:"message,omitempty"`
	Details    map[string]interface{} `json:"details,omitempty"`
	TaskStatus string                 `json:"task_status,omitempty"`
	UpdatedAt  time.Time              `json:"updated_at"`
}

type CreateTaskRequest struct {
	Name       string `json:"name"`
	InputPath  string `json:"inputPath"`
	Classes    string `json:"classes"`
	DrawLabels bool   `json:"drawLabels"`
}

type ObjectDetectionService struct {
	db          *gorm.DB
	logger      *zap.Logger
	cfg         config.ObjectDetectionConfig
	storage     storage.Backend
	subsMu      sync.Mutex
	subscribers map[uint][]chan ObjectDetectionStageEvent
	queue       chan pipelineJob
}

type pipelineJob struct {
	TaskID uint
	Req    CreateTaskRequest
}

func NewObjectDetectionService(db *gorm.DB, logger *zap.Logger, cfg config.ObjectDetectionConfig, storageCfg config.StorageConfig) *ObjectDetectionService {
	if strings.TrimSpace(cfg.RootPath) == "" {
		return nil
	}
	store, err := storage.New(storageCfg)
	if err != nil {
		logger.Warn("storage backend 初始化失败，回退 nfs", zap.Error(err))
		store, _ = storage.New(config.StorageConfig{Backend: "nfs"})
	}
	queueSize := cfg.WorkerQueueSize
	if queueSize <= 0 {
		queueSize = 64
	}
	workerN := cfg.WorkerConcurrency
	if workerN <= 0 {
		workerN = 1
	}
	s := &ObjectDetectionService{
		db:          db,
		logger:      logger,
		cfg:         cfg,
		storage:     store,
		subscribers: make(map[uint][]chan ObjectDetectionStageEvent),
		queue:       make(chan pipelineJob, queueSize),
	}
	for i := 0; i < workerN; i++ {
		go s.workerLoop(i + 1)
	}
	s.bootstrapPendingTasks()
	return s
}

func (s *ObjectDetectionService) CreateTask(ctx context.Context, req CreateTaskRequest) (*model.ObjectDetectionTask, error) {
	if strings.TrimSpace(req.InputPath) == "" {
		return nil, fmt.Errorf("inputPath 为必填项")
	}
	name := req.Name
	if strings.TrimSpace(name) == "" {
		name = filepath.Base(strings.TrimSuffix(req.InputPath, filepath.Ext(req.InputPath)))
	}
	classes := strings.TrimSpace(req.Classes)
	if classes == "" {
		classes = strings.TrimSpace(s.cfg.DefaultClasses)
	}
	task := &model.ObjectDetectionTask{
		Name:       name,
		Status:     TaskStatusPending,
		InputPath:  req.InputPath,
		Classes:    classes,
		DrawLabels: req.DrawLabels,
	}
	if err := s.db.WithContext(ctx).Create(task).Error; err != nil {
		return nil, err
	}
	if err := s.createStagesForTask(ctx, task.ID); err != nil {
		s.db.Delete(task)
		return nil, err
	}
	s.enqueueTask(task.ID, req)
	return task, nil
}

func (s *ObjectDetectionService) enqueueTask(taskID uint, req CreateTaskRequest) {
	job := pipelineJob{TaskID: taskID, Req: req}
	select {
	case s.queue <- job:
	default:
		s.logger.Warn("检测任务队列已满，阻塞等待入队", zap.Uint("task_id", taskID))
		s.queue <- job
	}
}

func (s *ObjectDetectionService) workerLoop(workerID int) {
	for job := range s.queue {
		s.logger.Info("检测 worker 开始处理", zap.Int("worker_id", workerID), zap.Uint("task_id", job.TaskID))
		s.runPipeline(context.Background(), job.TaskID, job.Req)
	}
}

func (s *ObjectDetectionService) bootstrapPendingTasks() {
	var tasks []model.ObjectDetectionTask
	if err := s.db.Where("status = ?", TaskStatusPending).Order("created_at ASC").Find(&tasks).Error; err != nil {
		s.logger.Error("加载 pending 检测任务失败", zap.Error(err))
		return
	}
	for _, t := range tasks {
		req := CreateTaskRequest{
			Name:       t.Name,
			InputPath:  t.InputPath,
			Classes:    t.Classes,
			DrawLabels: t.DrawLabels,
		}
		s.enqueueTask(t.ID, req)
	}
	if len(tasks) > 0 {
		s.logger.Info("已恢复 pending 检测任务", zap.Int("count", len(tasks)))
	}
}

func (s *ObjectDetectionService) ListTasks(ctx context.Context) ([]model.ObjectDetectionTask, error) {
	var tasks []model.ObjectDetectionTask
	err := s.db.WithContext(ctx).Order("created_at DESC").Find(&tasks).Error
	return tasks, err
}

func (s *ObjectDetectionService) GetTask(ctx context.Context, id uint) (*model.ObjectDetectionTask, error) {
	var task model.ObjectDetectionTask
	if err := s.db.WithContext(ctx).First(&task, id).Error; err != nil {
		return nil, err
	}
	return &task, nil
}

func (s *ObjectDetectionService) ListStages(ctx context.Context, taskID uint) ([]model.ObjectDetectionTaskStage, error) {
	var stages []model.ObjectDetectionTaskStage
	err := s.db.WithContext(ctx).
		Where("task_id = ?", taskID).
		Order("stage_order ASC").
		Find(&stages).Error
	return stages, err
}

func (s *ObjectDetectionService) ListLogs(ctx context.Context, taskID uint, limit int) ([]model.ObjectDetectionTaskLog, error) {
	if limit <= 0 || limit > 500 {
		limit = 200
	}
	var logs []model.ObjectDetectionTaskLog
	err := s.db.WithContext(ctx).
		Where("task_id = ?", taskID).
		Order("created_at DESC").
		Limit(limit).
		Find(&logs).Error
	return logs, err
}

func (s *ObjectDetectionService) ListArtifacts(ctx context.Context, taskID uint) ([]model.ObjectDetectionTaskArtifact, error) {
	var artifacts []model.ObjectDetectionTaskArtifact
	err := s.db.WithContext(ctx).
		Where("task_id = ?", taskID).
		Order("created_at DESC").
		Find(&artifacts).Error
	return artifacts, err
}

func (s *ObjectDetectionService) GetArtifact(ctx context.Context, taskID, artifactID uint) (*model.ObjectDetectionTaskArtifact, error) {
	var art model.ObjectDetectionTaskArtifact
	if err := s.db.WithContext(ctx).
		Where("task_id = ? AND id = ?", taskID, artifactID).
		First(&art).Error; err != nil {
		return nil, err
	}
	return &art, nil
}

func (s *ObjectDetectionService) Subscribe(taskID uint) (<-chan ObjectDetectionStageEvent, func()) {
	ch := make(chan ObjectDetectionStageEvent, 8)
	s.subsMu.Lock()
	s.subscribers[taskID] = append(s.subscribers[taskID], ch)
	s.subsMu.Unlock()
	return ch, func() {
		s.subsMu.Lock()
		defer s.subsMu.Unlock()
		subs := s.subscribers[taskID]
		for i, c := range subs {
			if c == ch {
				subs = append(subs[:i], subs[i+1:]...)
				break
			}
		}
		if len(subs) == 0 {
			delete(s.subscribers, taskID)
		} else {
			s.subscribers[taskID] = subs
		}
		close(ch)
	}
}

func (s *ObjectDetectionService) ArtifactAbsolutePath(artifact *model.ObjectDetectionTaskArtifact) (string, error) {
	return s.storage.ResolveLocalPath(s.cfg.RootPath, artifact.Path)
}

func (s *ObjectDetectionService) OpenArtifact(ctx context.Context, artifact *model.ObjectDetectionTaskArtifact) (io.ReadCloser, error) {
	return s.storage.Open(ctx, s.cfg.RootPath, artifact.Path)
}

func (s *ObjectDetectionService) createStagesForTask(ctx context.Context, taskID uint) error {
	for _, def := range stageDefinitions {
		stage := model.ObjectDetectionTaskStage{
			TaskID: taskID,
			Name:   def.Name,
			Title:  def.Title,
			Order:  def.Order,
			Status: StagePending,
		}
		if err := s.db.WithContext(ctx).Create(&stage).Error; err != nil {
			return err
		}
	}
	return nil
}

func (s *ObjectDetectionService) runPipeline(ctx context.Context, taskID uint, req CreateTaskRequest) {
	start := time.Now().UTC()
	tx := s.db.Model(&model.ObjectDetectionTask{}).
		Where("id = ? AND status = ?", taskID, TaskStatusPending).
		Updates(map[string]interface{}{
			"status":        TaskStatusRunning,
			"current_stage": "",
			"started_at":    start,
			"updated_at":    start,
		})
	if tx.Error != nil {
		s.logger.Error("更新检测任务状态失败", zap.Error(tx.Error), zap.Uint("task_id", taskID))
		return
	}
	if tx.RowsAffected == 0 {
		return
	}
	s.publishStageEvent(taskID, ObjectDetectionStageEvent{TaskID: taskID, TaskStatus: TaskStatusRunning, UpdatedAt: time.Now().UTC()})

	for _, def := range stageDefinitions {
		if err := s.runStage(ctx, taskID, def, req); err != nil {
			s.finishTaskWithError(taskID, fmt.Sprintf("阶段 %s 失败: %v", def.Name, err))
			return
		}
	}
	s.finishTaskCompleted(taskID)
}

func (s *ObjectDetectionService) runStage(ctx context.Context, taskID uint, def stageDefinition, req CreateTaskRequest) error {
	if err := s.updateStageStatus(taskID, def.Name, StageRunning, nil, "", ""); err != nil {
		return err
	}
	maxRetries := s.cfg.StageMaxRetries
	if maxRetries < 0 {
		maxRetries = 0
	}
	maxAttempts := maxRetries + 1
	var (
		res *stageExecutionResult
		err error
	)
	timeout := time.Duration(s.cfg.StageTimeoutSec) * time.Second
	if timeout <= 0 {
		timeout = 4 * time.Hour
	}
	for attempt := 1; attempt <= maxAttempts; attempt++ {
		stageCtx, cancel := context.WithTimeout(ctx, timeout)
		res, err = s.executeDetect(stageCtx, taskID, req)
		cancel()
		if err == nil {
			break
		}
		if errors.Is(err, context.DeadlineExceeded) {
			err = fmt.Errorf("阶段超时（%s）: %w", timeout, err)
		}
		if attempt < maxAttempts {
			s.log(taskID, def.Name, "warn", fmt.Sprintf("阶段失败，准备重试（%d/%d）: %v", attempt, maxRetries, err))
			continue
		}
		s.updateStageStatus(taskID, def.Name, StageFailed, nil, "", err.Error())
		return err
	}
	if err := s.updateStageStatus(taskID, def.Name, StageSuccess, res.Details, res.OutputPath, res.Message); err != nil {
		return err
	}
	for _, art := range res.Artifacts {
		art.TaskID = taskID
		if err := s.createArtifact(ctx, art); err != nil {
			s.logger.Warn("保存检测产物失败", zap.Error(err))
		}
	}
	return nil
}

type stageExecutionResult struct {
	Details    map[string]interface{}
	OutputPath string
	Message    string
	Artifacts  []model.ObjectDetectionTaskArtifact
}

func (s *ObjectDetectionService) executeDetect(ctx context.Context, taskID uint, req CreateTaskRequest) (*stageExecutionResult, error) {
	inputPath := pathForWSLRunner(req.InputPath)
	statPath := pathForOSAccess(inputPath)
	if _, err := os.Stat(statPath); err != nil {
		return nil, fmt.Errorf("输入文件不存在: %s (%v)", statPath, err)
	}

	outDir := filepath.Join(s.cfg.OutputSubdir, fmt.Sprintf("task_%d", taskID))
	outFile := filepath.Join(outDir, "output.jpg")
	args := []string{
		"-input", inputPath,
		"-output", outFile,
	}
	if s.cfg.UseCPU() {
		args = append(args, "-cpu")
	}
	if strings.TrimSpace(req.Classes) != "" {
		args = append(args, "-classes", req.Classes)
	}
	if req.DrawLabels {
		args = append(args, "-labels")
	}

	output, err := s.runDetector(ctx, taskID, StageDetect, args)
	if err != nil {
		return nil, err
	}

	artifacts, err := s.collectArtifacts(outDir)
	if err != nil {
		s.logger.Warn("收集检测产物失败", zap.Error(err))
	}

	message := "检测完成"
	if strings.Contains(output, "未检测到任何目标") {
		message = "检测完成，未发现目标"
	}

	return &stageExecutionResult{
		OutputPath: outDir,
		Message:    message,
		Details: map[string]interface{}{
			"input_path":  inputPath,
			"output_dir":  outDir,
			"device_mode": s.cfg.Device,
			"use_cpu":     s.cfg.UseCPU(),
		},
		Artifacts: artifacts,
	}, nil
}

func (s *ObjectDetectionService) collectArtifacts(outDir string) ([]model.ObjectDetectionTaskArtifact, error) {
	entries, err := CollectArtifactEntries(s.cfg.RootPath, outDir, 0)
	if err != nil {
		return nil, err
	}
	artifacts := make([]model.ObjectDetectionTaskArtifact, 0, len(entries))
	for _, e := range entries {
		artType := e.Type
		switch e.Type {
		case "detection_summary":
			artType = "summary"
		case "detection_preview":
			artType = "preview"
		case "detection_tile":
			artType = "tile"
		}
		meta := datatypes.JSONMap{}
		for k, v := range e.Metadata {
			meta[k] = v
		}
		artifacts = append(artifacts, model.ObjectDetectionTaskArtifact{
			Type:     artType,
			Label:    e.Label,
			Path:     e.Path,
			Metadata: meta,
		})
	}
	return artifacts, nil
}

func (s *ObjectDetectionService) runDetector(ctx context.Context, taskID uint, stageName string, args []string) (string, error) {
	args = normalizeArgsForRunner(s.cfg.RunnerPath, args)
	return s.runBinaryWithHeartbeat(ctx, taskID, stageName, s.cfg.RunnerPath, "yolov8s", args, args)
}

func (s *ObjectDetectionService) runBinaryWithHeartbeat(
	ctx context.Context,
	taskID uint,
	stageName string,
	binary string,
	displayName string,
	cmdArgs []string,
	logArgs []string,
) (string, error) {
	cmd := exec.CommandContext(ctx, binary, cmdArgs...)
	cmd.Dir = s.cfg.RootPath
	var buf bytes.Buffer
	cmd.Stdout = &buf
	cmd.Stderr = &buf
	if err := cmd.Start(); err != nil {
		s.log(taskID, stageName, "error", fmt.Sprintf("启动失败: %v", err))
		return "", err
	}
	doneCh := make(chan error, 1)
	go func() {
		doneCh <- cmd.Wait()
	}()
	start := time.Now()
	heartbeatSec := s.cfg.CommandHeartbeatSec
	if heartbeatSec <= 0 {
		heartbeatSec = 60
	}
	ticker := time.NewTicker(time.Duration(heartbeatSec) * time.Second)
	defer ticker.Stop()
	var err error
waitLoop:
	for {
		select {
		case err = <-doneCh:
			break waitLoop
		case <-ticker.C:
			s.log(taskID, stageName, "info", fmt.Sprintf("心跳: %s 仍在运行（已耗时 %s）", displayName, time.Since(start).Round(time.Second)))
		case <-ctx.Done():
			_ = cmd.Process.Kill()
			err = <-doneCh
			break waitLoop
		}
	}
	output := buf.String()
	s.log(taskID, stageName, "info", fmt.Sprintf("执行 %s %v\n%s", displayName, logArgs, output))
	if err != nil {
		s.log(taskID, stageName, "error", fmt.Sprintf("执行失败: %v", err))
	}
	return output, err
}

func (s *ObjectDetectionService) updateStageStatus(taskID uint, stageName, status string, details map[string]interface{}, outputPath, message string) error {
	updates := map[string]interface{}{
		"status":     status,
		"updated_at": time.Now().UTC(),
	}
	if details != nil {
		updates["details"] = datatypes.JSONMap(details)
	}
	if outputPath != "" {
		updates["output_path"] = outputPath
	}
	if message != "" {
		updates["message"] = message
	}
	now := time.Now().UTC()
	if status == StageRunning {
		updates["started_at"] = now
		updates["finished_at"] = nil
	}
	if status == StageSuccess || status == StageFailed {
		updates["finished_at"] = now
	}
	if err := s.db.Model(&model.ObjectDetectionTaskStage{}).
		Where("task_id = ? AND name = ?", taskID, stageName).
		Updates(updates).Error; err != nil {
		return err
	}
	taskUpdates := map[string]interface{}{
		"current_stage": stageName,
		"updated_at":    time.Now().UTC(),
	}
	if status == StageFailed {
		taskUpdates["status"] = TaskStatusFailed
	}
	if err := s.db.Model(&model.ObjectDetectionTask{}).
		Where("id = ?", taskID).
		Updates(taskUpdates).Error; err != nil {
		return err
	}
	event := ObjectDetectionStageEvent{
		TaskID:     taskID,
		StageName:  stageName,
		Status:     status,
		Message:    message,
		Details:    details,
		TaskStatus: TaskStatusRunning,
		UpdatedAt:  time.Now().UTC(),
	}
	if status == StageFailed {
		event.TaskStatus = TaskStatusFailed
	}
	s.publishStageEvent(taskID, event)
	return nil
}

func (s *ObjectDetectionService) finishTaskWithError(taskID uint, reason string) {
	now := time.Now().UTC()
	_ = s.db.Model(&model.ObjectDetectionTask{}).
		Where("id = ?", taskID).
		Updates(map[string]interface{}{
			"status":        TaskStatusFailed,
			"current_stage": "",
			"error_message": reason,
			"finished_at":   now,
			"updated_at":    now,
		}).Error
	s.publishStageEvent(taskID, ObjectDetectionStageEvent{TaskID: taskID, TaskStatus: TaskStatusFailed, Message: reason, UpdatedAt: now})
}

func (s *ObjectDetectionService) finishTaskCompleted(taskID uint) {
	now := time.Now().UTC()
	_ = s.db.Model(&model.ObjectDetectionTask{}).
		Where("id = ?", taskID).
		Updates(map[string]interface{}{
			"status":        TaskStatusCompleted,
			"current_stage": "",
			"finished_at":   now,
			"updated_at":    now,
		}).Error
	s.publishStageEvent(taskID, ObjectDetectionStageEvent{TaskID: taskID, TaskStatus: TaskStatusCompleted, UpdatedAt: now})
}

func (s *ObjectDetectionService) publishStageEvent(taskID uint, event ObjectDetectionStageEvent) {
	s.subsMu.Lock()
	subs := append([]chan ObjectDetectionStageEvent(nil), s.subscribers[taskID]...)
	s.subsMu.Unlock()
	for _, ch := range subs {
		select {
		case ch <- event:
		default:
			select {
			case ch <- event:
			case <-time.After(time.Second):
			}
		}
	}
}

func (s *ObjectDetectionService) createArtifact(ctx context.Context, artifact model.ObjectDetectionTaskArtifact) error {
	return s.db.WithContext(ctx).Create(&artifact).Error
}

func (s *ObjectDetectionService) log(taskID uint, stageName, level, content string) {
	s.db.Create(&model.ObjectDetectionTaskLog{
		TaskID:    taskID,
		StageName: stageName,
		Level:     level,
		Content:   content,
	})
}
