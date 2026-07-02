package remotesensing

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"go.uber.org/zap"

	"satellite-cloud/backend/internal/model"
)

// BootstrapStaleRunningTasks rs-worker 启动时将 DB running 任务重新入队（配合 runPipeline resume）
func (s *RemoteSensingService) BootstrapStaleRunningTasks(ctx context.Context) {
	if s.metricsWorker != "rs-worker" {
		return
	}
	var tasks []model.RemoteSensingTask
	if err := s.db.Where("status = ?", TaskStatusRunning).Order("updated_at ASC").Find(&tasks).Error; err != nil {
		s.logger.Error("加载 running 任务失败", zap.Error(err))
		return
	}
	for _, t := range tasks {
		if err := s.enqueueRedis(ctx, t.ID, createTaskRequestFromModel(t)); err != nil {
			s.logger.Error("恢复 running 任务入队失败", zap.Uint("task_id", t.ID), zap.Error(err))
			continue
		}
		s.logger.Info("已重新入队 running 任务（resume）", zap.Uint("task_id", t.ID))
	}
	if len(tasks) > 0 {
		s.logger.Info("running 任务恢复入队完成", zap.Int("count", len(tasks)))
	}
}

func (s *RemoteSensingService) successStages(ctx context.Context, taskID uint) map[string]bool {
	out := make(map[string]bool)
	var stages []model.RemoteSensingTaskStage
	if err := s.db.WithContext(ctx).Where("task_id = ? AND status = ?", taskID, StageSuccess).Find(&stages).Error; err != nil {
		s.logger.Warn("加载已完成阶段失败", zap.Uint("task_id", taskID), zap.Error(err))
		return out
	}
	for _, st := range stages {
		out[st.Name] = true
	}
	return out
}

func panRpcMergedPartsExist(rootPath, persistOutputRel, filePrefix string) bool {
	destBase := filepath.Join(rootPath, persistOutputRel)
	for area := 1; area <= 4; area++ {
		partName := fmt.Sprintf("%s-PAN1-wrap-part%d.tif", filePrefix, area)
		if _, err := os.Stat(filepath.Join(destBase, partName)); err != nil {
			return false
		}
	}
	return true
}

func (s *RemoteSensingService) stageOutputStillValid(taskID uint, stageName string) bool {
	var st model.RemoteSensingTaskStage
	if err := s.db.Where("task_id = ? AND name = ?", taskID, stageName).First(&st).Error; err != nil {
		return false
	}
	if st.Status != StageSuccess || strings.TrimSpace(st.OutputPath) == "" {
		return false
	}
	abs := filepath.Join(s.cfg.RootPath, filepath.FromSlash(st.OutputPath))
	info, err := os.Stat(abs)
	if err != nil {
		return false
	}
	if info.IsDir() {
		entries, err := os.ReadDir(abs)
		return err == nil && len(entries) > 0
	}
	return info.Size() > 0
}

func panRpcWorkerPartsReady(rootPath, persistOutputRel, filePrefix string) bool {
	workersBase := filepath.Join(rootPath, persistOutputRel, "workers")
	for area := 1; area <= 4; area++ {
		partName := fmt.Sprintf("%s-PAN1-wrap-part%d.tif", filePrefix, area)
		if _, err := findPanRpcPartOnPersist(workersBase, partName); err != nil {
			return false
		}
	}
	return true
}
