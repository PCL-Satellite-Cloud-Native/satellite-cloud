package remotesensing

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"go.uber.org/zap"
	"gorm.io/datatypes"
	"gorm.io/gorm"

	"satellite-cloud/backend/internal/config"
	"satellite-cloud/backend/internal/model"
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

	StageTiffToEnviMSS = "tiff_to_envi_mss"
	StageTiffToEnviPAN = "tiff_to_envi_pan"
	StagePanRadToa     = "pan_rad_toa"
	StagePanRpcWarp    = "pan_rpc_warp_quarters"
	StagePanMerge      = "pan_merge_warp_square"
	StageMssRadQuac    = "mss_rad_quac_rpc"
	StageCoregister    = "mss_coregister_to_pan"
	StagePansharpen    = "pansharpen_fusion"
	StageFusionStack   = "fusion_stack_envi"
)

type stageDefinition struct {
	Name  string
	Title string
	Order int
}

var stageDefinitions = []stageDefinition{
	{Name: StageTiffToEnviMSS, Title: "TIFF → ENVI（MSS）", Order: 1},
	{Name: StageTiffToEnviPAN, Title: "TIFF → ENVI（PAN）", Order: 2},
	{Name: StagePanRadToa, Title: "PAN 辐射定标", Order: 3},
	{Name: StagePanRpcWarp, Title: "PAN RPC 分块", Order: 4},
	{Name: StagePanMerge, Title: "PAN 拼接裁切", Order: 5},
	{Name: StageMssRadQuac, Title: "MSS QUAC + RPC", Order: 6},
	{Name: StageCoregister, Title: "多光谱与全色配准", Order: 7},
	{Name: StagePansharpen, Title: "Pan-sharpen 融合", Order: 8},
	{Name: StageFusionStack, Title: "融合堆栈 ENVI", Order: 9},
}

type RemoteSensingStageEvent struct {
	TaskID     uint                   `json:"task_id"`
	StageName  string                 `json:"stage_name,omitempty"`
	Status     string                 `json:"status"`
	Message    string                 `json:"message,omitempty"`
	Details    map[string]interface{} `json:"details,omitempty"`
	TaskStatus string                 `json:"task_status,omitempty"`
	UpdatedAt  time.Time              `json:"updated_at"`
}

type CreateTaskRequest struct {
	Name           string `json:"name"`
	FilePrefix     string `json:"filePrefix"`
	InputDirectory string `json:"inputDirectory"`
	Sensor         string `json:"sensor"`
}

type stageExecutionResult struct {
	Details    map[string]interface{}
	OutputPath string
	Message    string
	Artifacts  []model.RemoteSensingTaskArtifact
}

type stageExecutor func(ctx context.Context, s *RemoteSensingService, taskID uint, req CreateTaskRequest) (*stageExecutionResult, error)

var stageExecutors = map[string]stageExecutor{
	StageTiffToEnviMSS: func(ctx context.Context, s *RemoteSensingService, taskID uint, req CreateTaskRequest) (*stageExecutionResult, error) {
		return s.executeTiffToEnvi(ctx, taskID, req, "MSS1", StageTiffToEnviMSS)
	},
	StageTiffToEnviPAN: func(ctx context.Context, s *RemoteSensingService, taskID uint, req CreateTaskRequest) (*stageExecutionResult, error) {
		return s.executeTiffToEnvi(ctx, taskID, req, "PAN1", StageTiffToEnviPAN)
	},
	StagePanRadToa: func(ctx context.Context, s *RemoteSensingService, taskID uint, req CreateTaskRequest) (*stageExecutionResult, error) {
		return s.executePanRadToa(ctx, taskID, req)
	},
	StagePanRpcWarp: func(ctx context.Context, s *RemoteSensingService, taskID uint, req CreateTaskRequest) (*stageExecutionResult, error) {
		return s.executePanRpc(ctx, taskID, req)
	},
	StagePanMerge: func(ctx context.Context, s *RemoteSensingService, taskID uint, req CreateTaskRequest) (*stageExecutionResult, error) {
		return s.executePanMerge(ctx, taskID, req)
	},
	StageMssRadQuac: func(ctx context.Context, s *RemoteSensingService, taskID uint, req CreateTaskRequest) (*stageExecutionResult, error) {
		return s.executeMssRadQuac(ctx, taskID, req)
	},
	StageCoregister: func(ctx context.Context, s *RemoteSensingService, taskID uint, req CreateTaskRequest) (*stageExecutionResult, error) {
		return s.executeMssCoregister(ctx, taskID, req)
	},
	StagePansharpen: func(ctx context.Context, s *RemoteSensingService, taskID uint, req CreateTaskRequest) (*stageExecutionResult, error) {
		return s.executePansharpen(ctx, taskID, req)
	},
	StageFusionStack: func(ctx context.Context, s *RemoteSensingService, taskID uint, req CreateTaskRequest) (*stageExecutionResult, error) {
		return s.executeFusionStack(ctx, taskID, req)
	},
}

type RemoteSensingService struct {
	db          *gorm.DB
	logger      *zap.Logger
	cfg         config.RemoteSensingConfig
	subsMu      sync.Mutex
	subscribers map[uint][]chan RemoteSensingStageEvent
}

func NewRemoteSensingService(db *gorm.DB, logger *zap.Logger, cfg config.RemoteSensingConfig) *RemoteSensingService {
	return &RemoteSensingService{
		db:          db,
		logger:      logger,
		cfg:         cfg,
		subscribers: make(map[uint][]chan RemoteSensingStageEvent),
	}
}

func (s *RemoteSensingService) CreateTask(ctx context.Context, req CreateTaskRequest) (*model.RemoteSensingTask, error) {
	if strings.TrimSpace(req.FilePrefix) == "" || strings.TrimSpace(req.InputDirectory) == "" {
		return nil, fmt.Errorf("filePrefix 和 inputDirectory 为必填项")
	}
	name := req.Name
	if strings.TrimSpace(name) == "" {
		name = req.FilePrefix
	}
	task := &model.RemoteSensingTask{
		Name:           name,
		Status:         TaskStatusPending,
		InputDirectory: req.InputDirectory,
		FilePrefix:     req.FilePrefix,
		Sensor:         req.Sensor,
	}
	if err := s.db.WithContext(ctx).Create(task).Error; err != nil {
		return nil, err
	}
	if err := s.createStagesForTask(ctx, task.ID); err != nil {
		s.logger.Error("创建阶段失败", zap.Error(err))
		s.db.Delete(task)
		return nil, err
	}
	go s.runPipeline(context.Background(), task.ID, req)
	return task, nil
}

func (s *RemoteSensingService) ListTasks(ctx context.Context) ([]model.RemoteSensingTask, error) {
	var tasks []model.RemoteSensingTask
	err := s.db.WithContext(ctx).Order("created_at DESC").Find(&tasks).Error
	return tasks, err
}

func (s *RemoteSensingService) GetTask(ctx context.Context, id uint) (*model.RemoteSensingTask, error) {
	var task model.RemoteSensingTask
	if err := s.db.WithContext(ctx).First(&task, id).Error; err != nil {
		return nil, err
	}
	return &task, nil
}

func (s *RemoteSensingService) ListStages(ctx context.Context, taskID uint) ([]model.RemoteSensingTaskStage, error) {
	var stages []model.RemoteSensingTaskStage
	err := s.db.WithContext(ctx).
		Where("task_id = ?", taskID).
		Order("stage_order ASC").
		Find(&stages).Error
	return stages, err
}

func (s *RemoteSensingService) ListLogs(ctx context.Context, taskID uint, limit int) ([]model.RemoteSensingTaskLog, error) {
	if limit <= 0 || limit > 500 {
		limit = 200
	}
	var logs []model.RemoteSensingTaskLog
	err := s.db.WithContext(ctx).
		Where("task_id = ?", taskID).
		Order("created_at DESC").
		Limit(limit).
		Find(&logs).Error
	return logs, err
}

func (s *RemoteSensingService) ListArtifacts(ctx context.Context, taskID uint) ([]model.RemoteSensingTaskArtifact, error) {
	var artifacts []model.RemoteSensingTaskArtifact
	err := s.db.WithContext(ctx).
		Where("task_id = ?", taskID).
		Order("created_at DESC").
		Find(&artifacts).Error
	return artifacts, err
}

func (s *RemoteSensingService) GetArtifact(ctx context.Context, taskID, artifactID uint) (*model.RemoteSensingTaskArtifact, error) {
	var art model.RemoteSensingTaskArtifact
	if err := s.db.WithContext(ctx).
		Where("task_id = ? AND id = ?", taskID, artifactID).
		First(&art).Error; err != nil {
		return nil, err
	}
	return &art, nil
}

func (s *RemoteSensingService) Subscribe(taskID uint) (<-chan RemoteSensingStageEvent, func()) {
	ch := make(chan RemoteSensingStageEvent, 8)
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

func (s *RemoteSensingService) ArtifactAbsolutePath(artifact *model.RemoteSensingTaskArtifact) (string, error) {
	rootAbs, err := filepath.Abs(s.cfg.RootPath)
	if err != nil {
		return "", err
	}
	target := filepath.Clean(filepath.Join(rootAbs, artifact.Path))
	if !strings.HasPrefix(target, rootAbs) {
		return "", fmt.Errorf("artifact path 越界")
	}
	return target, nil
}

func (s *RemoteSensingService) createStagesForTask(ctx context.Context, taskID uint) error {
	for _, def := range stageDefinitions {
		stage := model.RemoteSensingTaskStage{
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

func (s *RemoteSensingService) runPipeline(ctx context.Context, taskID uint, req CreateTaskRequest) {
	start := time.Now().UTC()
	if err := s.db.Model(&model.RemoteSensingTask{}).
		Where("id = ?", taskID).
		Updates(map[string]interface{}{
			"status":        TaskStatusRunning,
			"current_stage": "",
			"started_at":    start,
			"updated_at":    start,
		}).Error; err != nil {
		s.logger.Error("更新任务状态失败", zap.Error(err))
	}
	s.publishStageEvent(taskID, RemoteSensingStageEvent{TaskID: taskID, TaskStatus: TaskStatusRunning, UpdatedAt: time.Now().UTC()})

	for _, def := range stageDefinitions {
		if err := s.runStage(ctx, taskID, def, req); err != nil {
			s.finishTaskWithError(taskID, fmt.Sprintf("阶段 %s 失败: %v", def.Name, err))
			return
		}
	}
	s.finishTaskCompleted(taskID)
}

func (s *RemoteSensingService) runStage(ctx context.Context, taskID uint, def stageDefinition, req CreateTaskRequest) error {
	executor, ok := stageExecutors[def.Name]
	if !ok {
		return fmt.Errorf("未注册的阶段: %s", def.Name)
	}
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
	for attempt := 1; attempt <= maxAttempts; attempt++ {
		stageTimeout := s.stageTimeoutFor(def.Name)
		stageCtx, cancel := context.WithTimeout(ctx, stageTimeout)
		res, err = executor(stageCtx, s, taskID, req)
		cancel()
		if err == nil {
			break
		}
		if errors.Is(err, context.DeadlineExceeded) || errors.Is(stageCtx.Err(), context.DeadlineExceeded) {
			err = fmt.Errorf("阶段超时（%s）: %w", stageTimeout, err)
		}
		if attempt < maxAttempts {
			s.log(taskID, def.Name, "warn", fmt.Sprintf("阶段失败，准备重试（%d/%d）: %v", attempt, maxRetries, err))
			continue
		}
		s.updateStageStatus(taskID, def.Name, StageFailed, nil, "", err.Error())
		return err
	}
	details := res.Details
	message := res.Message
	output := res.OutputPath
	if err := s.updateStageStatus(taskID, def.Name, StageSuccess, details, output, message); err != nil {
		return err
	}
	for _, art := range res.Artifacts {
		art.TaskID = taskID
		if err := s.createArtifact(ctx, art); err != nil {
			s.logger.Warn("保存产物失败", zap.Error(err))
		}
	}
	if def.Name == StageFusionStack {
		s.persistFusionArtifactsAsync(taskID, req.FilePrefix)
	}
	return nil
}

func (s *RemoteSensingService) stageTimeoutFor(stageName string) time.Duration {
	seconds := s.cfg.StageTimeoutSec
	if stageName == StageFusionStack {
		seconds = s.cfg.FusionStageTimeoutSec
	}
	if seconds <= 0 {
		seconds = 1800
	}
	return time.Duration(seconds) * time.Second
}

func (s *RemoteSensingService) updateStageStatus(taskID uint, stageName, status string, details map[string]interface{}, outputPath, message string) error {
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
	if err := s.db.Model(&model.RemoteSensingTaskStage{}).
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
	if err := s.db.Model(&model.RemoteSensingTask{}).
		Where("id = ?", taskID).
		Updates(taskUpdates).Error; err != nil {
		return err
	}
	event := RemoteSensingStageEvent{
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

func (s *RemoteSensingService) finishTaskWithError(taskID uint, reason string) {
	now := time.Now().UTC()
	if err := s.db.Model(&model.RemoteSensingTask{}).
		Where("id = ?", taskID).
		Updates(map[string]interface{}{
			"status":        TaskStatusFailed,
			"current_stage": "",
			"error_message": reason,
			"finished_at":   now,
			"updated_at":    now,
		}).Error; err != nil {
		s.logger.Error("更新失败任务状态失败", zap.Error(err))
	}
	s.publishStageEvent(taskID, RemoteSensingStageEvent{TaskID: taskID, TaskStatus: TaskStatusFailed, Message: reason, UpdatedAt: now})
}

func (s *RemoteSensingService) finishTaskCompleted(taskID uint) {
	now := time.Now().UTC()
	if err := s.db.Model(&model.RemoteSensingTask{}).
		Where("id = ?", taskID).
		Updates(map[string]interface{}{
			"status":        TaskStatusCompleted,
			"current_stage": "",
			"finished_at":   now,
			"updated_at":    now,
		}).Error; err != nil {
		s.logger.Error("更新完成任务状态失败", zap.Error(err))
	}
	s.publishStageEvent(taskID, RemoteSensingStageEvent{TaskID: taskID, TaskStatus: TaskStatusCompleted, UpdatedAt: now})
}

func (s *RemoteSensingService) publishStageEvent(taskID uint, event RemoteSensingStageEvent) {
	s.subsMu.Lock()
	subs := append([]chan RemoteSensingStageEvent(nil), s.subscribers[taskID]...)
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

func (s *RemoteSensingService) createArtifact(ctx context.Context, artifact model.RemoteSensingTaskArtifact) error {
	return s.db.WithContext(ctx).Create(&artifact).Error
}

func (s *RemoteSensingService) runPython(ctx context.Context, taskID uint, stageName, script string, args []string) (string, error) {
	cmdArgs := append([]string{script}, args...)
	return s.runBinaryWithHeartbeat(ctx, taskID, stageName, s.cfg.PythonBin, script, cmdArgs, args)
}

func (s *RemoteSensingService) runCommand(ctx context.Context, taskID uint, stageName string, binary string, args []string) (string, error) {
	return s.runBinaryWithHeartbeat(ctx, taskID, stageName, binary, binary, args, args)
}

func (s *RemoteSensingService) runBinaryWithHeartbeat(
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

func (s *RemoteSensingService) log(taskID uint, stageName, level, content string) {
	s.db.Create(&model.RemoteSensingTaskLog{
		TaskID:    taskID,
		StageName: stageName,
		Level:     level,
		Content:   content,
	})
}

func (s *RemoteSensingService) executeTiffToEnvi(ctx context.Context, taskID uint, req CreateTaskRequest, sensor, stageName string) (*stageExecutionResult, error) {
	args := []string{
		"--data_directory", req.InputDirectory,
		"--file_prefix", req.FilePrefix,
		"--sensor", sensor,
		"--output_dir", filepath.Join("output_preprocessing", "tiff_to_envi"),
	}
	if _, err := s.runPython(ctx, taskID, stageName, "tiff_to_envi.py", args); err != nil {
		return nil, err
	}
	return &stageExecutionResult{Details: map[string]interface{}{"sensor": sensor}, OutputPath: filepath.Join("output_preprocessing", "tiff_to_envi"), Message: fmt.Sprintf("%s 生成完成", sensor)}, nil
}

func (s *RemoteSensingService) executePanRadToa(ctx context.Context, taskID uint, req CreateTaskRequest) (*stageExecutionResult, error) {
	args := []string{
		"--file_prefix", req.FilePrefix,
		"--input_dir", filepath.Join("output_preprocessing", "tiff_to_envi"),
		"--output_dir", filepath.Join("output_preprocessing", "pan_rad_toa"),
		"--radiance_unit_scale", "10000",
	}
	if _, err := s.runPython(ctx, taskID, StagePanRadToa, "pan_rad_toa.py", args); err != nil {
		return nil, err
	}
	return &stageExecutionResult{OutputPath: filepath.Join("output_preprocessing", "pan_rad_toa"), Message: "全色辐射定标完成"}, nil
}

func (s *RemoteSensingService) executePanRpc(ctx context.Context, taskID uint, req CreateTaskRequest) (*stageExecutionResult, error) {
	outputDir := filepath.Join("output_preprocessing", "pan_warp_quarters")
	demFile := s.cfg.DemFile
	cpuThreads := effectiveParallelism(s.cfg.PanRPCCPUThreads, 1, 4)
	parallelism := effectiveParallelism(s.cfg.PanRPCParallel, 1, 4)
	warpMemMB := s.cfg.PanRPCWarpMemMB
	maxTotalWarpMemMB := s.cfg.PanRPCMaxTotalWarpMB
	if warpMemMB <= 0 {
		warpMemMB = 1024
	}
	if maxTotalWarpMemMB <= 0 {
		maxTotalWarpMemMB = 2048
	}
	maxByMem := maxTotalWarpMemMB / warpMemMB
	if maxByMem < 1 {
		maxByMem = 1
	}
	if parallelism > maxByMem {
		s.log(taskID, StagePanRpcWarp, "warn", fmt.Sprintf(
			"PAN RPC 并行度按内存预算下调: parallelism=%d -> %d (warp_mem_mb=%d, max_total_warp_mem_mb=%d)",
			parallelism, maxByMem, warpMemMB, maxTotalWarpMemMB,
		))
		parallelism = maxByMem
	}
	if _, err := os.Stat(demFile); err != nil {
		return nil, fmt.Errorf("DEM 文件不存在或不可访问: %s", demFile)
	}
	// 分组执行：每组一次脚本调用（每次共享一次 VRT），在减少重复计算的同时保留并行能力。
	areaGroups := chunkAreaIndexes([]int{1, 2, 3, 4}, parallelism)
	absoluteOutputDir := filepath.Join(s.cfg.RootPath, outputDir)
	if err := os.MkdirAll(absoluteOutputDir, 0o755); err != nil {
		return nil, fmt.Errorf("创建 PAN RPC 输出目录失败: %w", err)
	}
	workerRootAbs := filepath.Join(absoluteOutputDir, "workers")
	if err := os.RemoveAll(workerRootAbs); err != nil {
		s.log(taskID, StagePanRpcWarp, "warn", fmt.Sprintf("清理旧 PAN RPC workers 目录失败: %v", err))
	}

	stageCtx, cancel := context.WithCancel(ctx)
	defer cancel()
	sem := make(chan struct{}, parallelism)
	errCh := make(chan error, len(areaGroups))
	var wg sync.WaitGroup

	for idx, group := range areaGroups {
		group := group
		groupID := idx + 1
		wg.Add(1)
		go func() {
			defer wg.Done()
			select {
			case sem <- struct{}{}:
			case <-stageCtx.Done():
				return
			}
			defer func() { <-sem }()

			workerOutputDir := filepath.Join(outputDir, "workers", fmt.Sprintf("group%d", groupID))
			workerAbsDir := filepath.Join(s.cfg.RootPath, workerOutputDir)
			if err := os.MkdirAll(workerAbsDir, 0o755); err != nil {
				errCh <- fmt.Errorf("创建 PAN RPC group%d 目录失败: %w", groupID, err)
				cancel()
				return
			}

			groupTokens := make([]string, 0, len(group))
			for _, area := range group {
				groupTokens = append(groupTokens, strconv.Itoa(area))
			}
			args := []string{
				"--file_prefix", req.FilePrefix,
				"--input_dir", filepath.Join("output_preprocessing", "pan_rad_toa"),
				"--output_dir", workerOutputDir,
				"--area_indexes", strings.Join(groupTokens, ","),
				"--dem_file", demFile,
				"--cpu_threads", strconv.Itoa(cpuThreads),
				"--warp_mem_mb", strconv.Itoa(warpMemMB),
				"--resample_alg", s.cfg.PanRPCResampleAlg,
			}
			if _, err := s.runPython(stageCtx, taskID, StagePanRpcWarp, "pan_rpc_warp_quarters.py", args); err != nil {
				errCh <- err
				cancel()
				return
			}

			for _, area := range group {
				srcPart := filepath.Join(workerAbsDir, fmt.Sprintf("%s-PAN1-wrap-part%d.tif", req.FilePrefix, area))
				dstPart := filepath.Join(absoluteOutputDir, fmt.Sprintf("%s-PAN1-wrap-part%d.tif", req.FilePrefix, area))
				if err := copyFile(srcPart, dstPart); err != nil {
					errCh <- fmt.Errorf("复制 PAN RPC area%d 结果失败: %w", area, err)
					cancel()
					return
				}
			}
			if err := os.RemoveAll(workerAbsDir); err != nil {
				s.log(taskID, StagePanRpcWarp, "warn", fmt.Sprintf("清理 PAN RPC group%d 临时目录失败: %v", groupID, err))
			}
		}()
	}

	wg.Wait()
	close(errCh)
	for err := range errCh {
		if err != nil {
			return nil, err
		}
	}
	if err := os.RemoveAll(workerRootAbs); err != nil {
		s.log(taskID, StagePanRpcWarp, "warn", fmt.Sprintf("清理 PAN RPC workers 根目录失败: %v", err))
	}

	details := map[string]interface{}{
		"area_indexes":          []int{1, 2, 3, 4},
		"completed":             4,
		"total":                 4,
		"parallelism":           parallelism,
		"cpu_threads":           cpuThreads,
		"warp_mem_mb":           warpMemMB,
		"max_total_warp_mem_mb": maxTotalWarpMemMB,
		"resample_alg":          s.cfg.PanRPCResampleAlg,
		"group_count":           len(areaGroups),
		"mode":                  "grouped_parallel_shared_vrt",
	}
	return &stageExecutionResult{Details: details, OutputPath: outputDir, Message: "RPC 分块完成"}, nil
}

func (s *RemoteSensingService) executePanMerge(ctx context.Context, taskID uint, req CreateTaskRequest) (*stageExecutionResult, error) {
	outputDir := filepath.Join("output_preprocessing", "pan_merge_warp_square")
	args := []string{
		"--file_prefix", req.FilePrefix,
		"--input_dir", filepath.Join("output_preprocessing", "pan_warp_quarters"),
		"--output_dir", outputDir,
	}
	if _, err := s.runPython(ctx, taskID, StagePanMerge, "pan_merge_warp_square.py", args); err != nil {
		return nil, err
	}
	return &stageExecutionResult{OutputPath: outputDir, Message: "全色拼接完成"}, nil
}

func (s *RemoteSensingService) executeMssRadQuac(ctx context.Context, taskID uint, req CreateTaskRequest) (*stageExecutionResult, error) {
	outputDir := filepath.Join("output_preprocessing", "mss_rad_quac_rpc")
	demFile := s.cfg.DemFile
	if _, err := os.Stat(demFile); err != nil {
		return nil, fmt.Errorf("DEM 文件不存在或不可访问: %s", demFile)
	}
	args := []string{
		"--file_prefix", req.FilePrefix,
		"--input_dir", filepath.Join("output_preprocessing", "tiff_to_envi"),
		"--output_dir", outputDir,
		"--radiance_unit_scale", "1",
		"--aero_profile", "Urban",
		"--dem_file", demFile,
	}
	if _, err := s.runPython(ctx, taskID, StageMssRadQuac, "mss_rad_quac_rpc.py", args); err != nil {
		return nil, err
	}
	return &stageExecutionResult{OutputPath: outputDir, Message: "多光谱 QUAC + RPC 完成"}, nil
}

func (s *RemoteSensingService) executeMssCoregister(ctx context.Context, taskID uint, req CreateTaskRequest) (*stageExecutionResult, error) {
	outputDir := filepath.Join("output_preprocessing", "mss_coregister_pan")
	details := map[string]interface{}{"completed": 0, "total": 4}
	for i := 1; i <= 4; i++ {
		args := []string{
			"--file_prefix", req.FilePrefix,
			"--input_dir_pan", filepath.Join("output_preprocessing", "pan_merge_warp_square"),
			"--input_dir_mss", filepath.Join("output_preprocessing", "mss_rad_quac_rpc"),
			"--output_dir", outputDir,
			"--bandidx", strconv.Itoa(i),
		}
		if _, err := s.runPython(ctx, taskID, StageCoregister, "mss_coregister_to_pan.py", args); err != nil {
			return nil, err
		}
		details["completed"] = details["completed"].(int) + 1
	}
	details["message"] = "四个波段注册完成"
	return &stageExecutionResult{Details: details, OutputPath: outputDir, Message: "多光谱配准完成"}, nil
}

func (s *RemoteSensingService) executePansharpen(ctx context.Context, taskID uint, req CreateTaskRequest) (*stageExecutionResult, error) {
	mode := strings.ToLower(strings.TrimSpace(s.cfg.PansharpenMode))
	if mode == "" {
		mode = "parallel"
	}
	switch mode {
	case "batch":
		return s.executePansharpenBatch(ctx, taskID, req)
	case "parallel":
		return s.executePansharpenParallel(ctx, taskID, req)
	default:
		s.log(taskID, StagePansharpen, "warn", fmt.Sprintf("未知 pansharpen 模式 %q，回退 parallel", mode))
		return s.executePansharpenParallel(ctx, taskID, req)
	}
}

func (s *RemoteSensingService) executePansharpenBatch(ctx context.Context, taskID uint, req CreateTaskRequest) (*stageExecutionResult, error) {
	outputDir := filepath.Join("output_preprocessing", "pansharpen")
	if err := os.MkdirAll(filepath.Join(s.cfg.RootPath, outputDir), 0o755); err != nil {
		return nil, fmt.Errorf("创建 Pan-sharpen 输出目录失败: %w", err)
	}
	args := []string{
		"--file_prefix", req.FilePrefix,
		"--input_dir_pan", filepath.Join("output_preprocessing", "pan_merge_warp_square"),
		"--input_dir_mss", filepath.Join("output_preprocessing", "mss_coregister_pan"),
		"--output_dir", outputDir,
		"--band_indexes", "1,2,3",
		"--gdal_num_threads", s.cfg.PansharpenGDALThread,
	}
	if _, err := s.runPython(ctx, taskID, StagePansharpen, "pansharpen_fusion.py", args); err != nil {
		return nil, err
	}
	if err := ensurePansharpenOutputs(s.cfg.RootPath, outputDir, req.FilePrefix); err != nil {
		return nil, err
	}
	details := map[string]interface{}{
		"completed":          3,
		"total":              3,
		"parallelism":        1,
		"requested_parallel": effectiveParallelism(s.cfg.PansharpenPar, 1, 3),
		"mode":               "single_process_batch_bands",
	}
	details["message"] = "三波段融合完成"
	return &stageExecutionResult{Details: details, OutputPath: outputDir, Message: "融合完成"}, nil
}

func (s *RemoteSensingService) executePansharpenParallel(ctx context.Context, taskID uint, req CreateTaskRequest) (*stageExecutionResult, error) {
	outputDir := filepath.Join("output_preprocessing", "pansharpen")
	absoluteOutputDir := filepath.Join(s.cfg.RootPath, outputDir)
	workerBaseDir := filepath.Join(absoluteOutputDir, "workers")
	if err := os.RemoveAll(workerBaseDir); err != nil {
		s.log(taskID, StagePansharpen, "warn", fmt.Sprintf("清理旧 Pansharpen workers 目录失败: %v", err))
	}
	if err := os.MkdirAll(workerBaseDir, 0o755); err != nil {
		return nil, fmt.Errorf("创建 Pan-sharpen 工作目录失败: %w", err)
	}
	stageCtx, cancel := context.WithCancel(ctx)
	defer cancel()
	parallelism := effectiveParallelism(s.cfg.PansharpenPar, 1, 3)
	sem := make(chan struct{}, parallelism)
	errCh := make(chan error, 3)
	var wg sync.WaitGroup
	for i := 1; i <= 3; i++ {
		i := i
		wg.Add(1)
		go func() {
			defer wg.Done()
			select {
			case sem <- struct{}{}:
			case <-stageCtx.Done():
				return
			}
			defer func() { <-sem }()
			workerOutputDir := filepath.Join(outputDir, "workers", fmt.Sprintf("band%d", i))
			workerOutputAbs := filepath.Join(s.cfg.RootPath, workerOutputDir)
			if err := os.MkdirAll(workerOutputAbs, 0o755); err != nil {
				errCh <- fmt.Errorf("创建 band%d 目录失败: %w", i, err)
				cancel()
				return
			}
			args := []string{
				"--file_prefix", req.FilePrefix,
				"--input_dir_pan", filepath.Join("output_preprocessing", "pan_merge_warp_square"),
				"--input_dir_mss", filepath.Join("output_preprocessing", "mss_coregister_pan"),
				"--output_dir", workerOutputDir,
				"--bandidx", strconv.Itoa(i),
				"--gdal_num_threads", s.cfg.PansharpenGDALThread,
			}
			if _, err := s.runPython(stageCtx, taskID, StagePansharpen, "pansharpen_fusion.py", args); err != nil {
				errCh <- err
				cancel()
				return
			}
			bandDatName := fmt.Sprintf("%s-MSS1_fused_band%d.dat", req.FilePrefix, i)
			srcBandDat := filepath.Join(workerOutputAbs, bandDatName)
			dstBandDat := filepath.Join(absoluteOutputDir, bandDatName)
			if err := copyFile(srcBandDat, dstBandDat); err != nil {
				errCh <- fmt.Errorf("复制 band%d dat 失败: %w", i, err)
				cancel()
				return
			}
			bandHdrName := fmt.Sprintf("%s-MSS1_fused_band%d.hdr", req.FilePrefix, i)
			srcBandHdr := filepath.Join(workerOutputAbs, bandHdrName)
			if _, err := os.Stat(srcBandHdr); err == nil {
				dstBandHdr := filepath.Join(absoluteOutputDir, bandHdrName)
				if err := copyFile(srcBandHdr, dstBandHdr); err != nil {
					errCh <- fmt.Errorf("复制 band%d hdr 失败: %w", i, err)
					cancel()
					return
				}
			}
			if err := os.RemoveAll(workerOutputAbs); err != nil {
				s.log(taskID, StagePansharpen, "warn", fmt.Sprintf("清理 Pansharpen band%d 临时目录失败: %v", i, err))
			}
		}()
	}
	wg.Wait()
	close(errCh)
	for err := range errCh {
		if err != nil {
			return nil, err
		}
	}
	if err := os.RemoveAll(workerBaseDir); err != nil {
		s.log(taskID, StagePansharpen, "warn", fmt.Sprintf("清理 Pansharpen workers 根目录失败: %v", err))
	}
	if err := ensurePansharpenOutputs(s.cfg.RootPath, outputDir, req.FilePrefix); err != nil {
		return nil, err
	}
	details := map[string]interface{}{
		"completed":   3,
		"total":       3,
		"parallelism": parallelism,
		"mode":        "multi_process_parallel_workers",
	}
	details["message"] = "三波段融合完成"
	return &stageExecutionResult{Details: details, OutputPath: outputDir, Message: "融合完成"}, nil
}

func ensurePansharpenOutputs(rootPath, outputDir, filePrefix string) error {
	for i := 1; i <= 3; i++ {
		bandDatName := fmt.Sprintf("%s-MSS1_fused_band%d.dat", filePrefix, i)
		if _, err := os.Stat(filepath.Join(rootPath, outputDir, bandDatName)); err != nil {
			return fmt.Errorf("pansharpen 输出不存在: %s", filepath.Join(outputDir, bandDatName))
		}
	}
	return nil
}

func (s *RemoteSensingService) executeFusionStack(ctx context.Context, taskID uint, req CreateTaskRequest) (*stageExecutionResult, error) {
	inputDir := filepath.Join("output_preprocessing", "pansharpen")
	outputDir := filepath.Join("output_preprocessing", "fusion_envi")
	s.log(taskID, StageFusionStack, "info", "开始执行 fusion_stack_envi")
	args := []string{
		"--file_prefix", req.FilePrefix,
		"--input_dir", inputDir,
		"--output_dir", outputDir,
	}
	fusionCtx, cancelFusion := context.WithTimeout(ctx, 20*time.Minute)
	defer cancelFusion()
	if _, err := s.runPython(fusionCtx, taskID, StageFusionStack, "fusion_stack_envi.py", args); err != nil {
		return nil, err
	}
	s.log(taskID, StageFusionStack, "info", "fusion_stack_envi 执行完成")
	finalDatName := fmt.Sprintf("%s-MSS1-fusion.dat", req.FilePrefix)
	finalDat := filepath.Join(outputDir, finalDatName)
	if _, err := os.Stat(filepath.Join(s.cfg.RootPath, finalDat)); err != nil {
		return nil, fmt.Errorf("融合输出不存在: %s", finalDat)
	}
	previewDir := filepath.Join("output_preprocessing", "imgshow")
	absolutePreviewDir := filepath.Join(s.cfg.RootPath, previewDir)
	os.MkdirAll(absolutePreviewDir, 0o755)
	previewPNG := filepath.Join(previewDir, fmt.Sprintf("%s-MSS1-fusion.png", req.FilePrefix))

	// 预览图是融合步骤的标准输出之一：显式串联并校验产物存在。
	previewCtx, cancel := context.WithTimeout(ctx, 3*time.Minute)
	defer cancel()
	previewArgs := []string{
		"--file_prefix", req.FilePrefix,
		"--input_dir", outputDir,
		"--output_dir", previewDir,
	}
	s.log(taskID, StageFusionStack, "info", "开始执行 imgshow")
	if _, err := s.runPython(previewCtx, taskID, StageFusionStack, "imgshow.py", previewArgs); err != nil {
		return nil, fmt.Errorf("imgshow 预览生成失败: %w", err)
	}
	s.log(taskID, StageFusionStack, "info", "imgshow 执行完成")
	if _, err := os.Stat(filepath.Join(s.cfg.RootPath, previewPNG)); err != nil {
		return nil, fmt.Errorf("imgshow 预览图未生成: %s", previewPNG)
	}

	artifacts := []model.RemoteSensingTaskArtifact{
		{
			Type:     "raw",
			Label:    "融合 ENVI",
			Path:     finalDat,
			Metadata: datatypes.JSONMap{"stage": StageFusionStack, "sensor": req.Sensor},
		},
	}
	artifacts = append(artifacts, model.RemoteSensingTaskArtifact{
		Type:     "preview",
		Label:    "融合预览图",
		Path:     previewPNG,
		Metadata: datatypes.JSONMap{"mime": "image/png", "generator": "imgshow.py"},
	})
	return &stageExecutionResult{
		OutputPath: outputDir,
		Message:    "融合堆栈与预览图生成完成（持久化后台进行）",
		Artifacts:  artifacts,
	}, nil
}

func copyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer func() {
		_ = out.Close()
	}()
	if _, err := io.Copy(out, in); err != nil {
		return err
	}
	return out.Close()
}

func (s *RemoteSensingService) persistFusionArtifactsAsync(taskID uint, filePrefix string) {
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 15*time.Minute)
		defer cancel()

		finalDatName := fmt.Sprintf("%s-MSS1-fusion.dat", filePrefix)
		finalHdrName := fmt.Sprintf("%s-MSS1-fusion.hdr", filePrefix)
		previewName := fmt.Sprintf("%s-MSS1-fusion.png", filePrefix)

		scratchFinalDatRel := filepath.Join("output_preprocessing", "fusion_envi", finalDatName)
		scratchFinalHdrRel := filepath.Join("output_preprocessing", "fusion_envi", finalHdrName)
		scratchPreviewRel := filepath.Join("output_preprocessing", "imgshow", previewName)

		persistFinalDatRel := filepath.Join(s.cfg.PersistOutputDir, "fusion_envi", finalDatName)
		persistFinalHdrRel := filepath.Join(s.cfg.PersistOutputDir, "fusion_envi", finalHdrName)
		persistPreviewRel := filepath.Join(s.cfg.PersistOutputDir, "imgshow", previewName)

		persistFusionDir := filepath.Join(s.cfg.RootPath, s.cfg.PersistOutputDir, "fusion_envi")
		persistPreviewDir := filepath.Join(s.cfg.RootPath, s.cfg.PersistOutputDir, "imgshow")
		if err := os.MkdirAll(persistFusionDir, 0o755); err != nil {
			s.log(taskID, StageFusionStack, "warn", fmt.Sprintf("持久化目录创建失败: %v", err))
			return
		}
		if err := os.MkdirAll(persistPreviewDir, 0o755); err != nil {
			s.log(taskID, StageFusionStack, "warn", fmt.Sprintf("持久化目录创建失败: %v", err))
			return
		}

		s.log(taskID, StageFusionStack, "info", fmt.Sprintf("后台持久化开始: %s", persistFinalDatRel))
		if err := copyFile(filepath.Join(s.cfg.RootPath, scratchFinalDatRel), filepath.Join(s.cfg.RootPath, persistFinalDatRel)); err != nil {
			s.log(taskID, StageFusionStack, "warn", fmt.Sprintf("后台持久化 dat 失败: %v", err))
			return
		}
		if _, err := os.Stat(filepath.Join(s.cfg.RootPath, scratchFinalHdrRel)); err == nil {
			if err := copyFile(filepath.Join(s.cfg.RootPath, scratchFinalHdrRel), filepath.Join(s.cfg.RootPath, persistFinalHdrRel)); err != nil {
				s.log(taskID, StageFusionStack, "warn", fmt.Sprintf("后台持久化 hdr 失败: %v", err))
			}
		}
		if err := copyFile(filepath.Join(s.cfg.RootPath, scratchPreviewRel), filepath.Join(s.cfg.RootPath, persistPreviewRel)); err != nil {
			s.log(taskID, StageFusionStack, "warn", fmt.Sprintf("后台持久化预览图失败: %v", err))
			return
		}

		_ = s.db.WithContext(ctx).Model(&model.RemoteSensingTaskArtifact{}).
			Where("task_id = ? AND path = ?", taskID, scratchFinalDatRel).
			Update("path", persistFinalDatRel).Error
		_ = s.db.WithContext(ctx).Model(&model.RemoteSensingTaskArtifact{}).
			Where("task_id = ? AND path = ?", taskID, scratchPreviewRel).
			Update("path", persistPreviewRel).Error

		s.log(taskID, StageFusionStack, "info", "后台持久化完成")
	}()
}

func effectiveParallelism(v, minV, maxV int) int {
	if v < minV {
		return minV
	}
	if v > maxV {
		return maxV
	}
	return v
}

func chunkAreaIndexes(areas []int, groups int) [][]int {
	if len(areas) == 0 {
		return nil
	}
	if groups <= 1 {
		return [][]int{areas}
	}
	if groups > len(areas) {
		groups = len(areas)
	}
	result := make([][]int, 0, groups)
	chunkSize := (len(areas) + groups - 1) / groups
	for i := 0; i < len(areas); i += chunkSize {
		end := i + chunkSize
		if end > len(areas) {
			end = len(areas)
		}
		part := make([]int, end-i)
		copy(part, areas[i:end])
		result = append(result, part)
	}
	return result
}
