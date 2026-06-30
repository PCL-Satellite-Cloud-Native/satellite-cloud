package remotesensing

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"gorm.io/datatypes"

	"satellite-cloud/backend/internal/model"
	"satellite-cloud/backend/internal/objectdetection"
)

func (s *RemoteSensingService) executeObjectDetection(ctx context.Context, taskID uint, req CreateTaskRequest) (*stageExecutionResult, error) {
	if s.detectionRunner == nil {
		return nil, fmt.Errorf("目标识别未配置（缺少 SATELLITE_OBJECT_DETECTION_ROOT）")
	}

	fusionRel := strings.TrimSpace(req.FusionDatRel)
	if fusionRel == "" {
		fusionRel = s.scratchDir(taskID, "fusion_envi", fmt.Sprintf("%s-MSS1-fusion.dat", req.FilePrefix))
	}
	inputPath := objectdetection.FusionDatPathForRunner(s.cfg.RootPath, fusionRel)
	outDir := filepath.Join(s.detectionCfg.OutputSubdir, fmt.Sprintf("rs_task_%d", taskID))

	classes := req.DetectionClasses
	if classes == "" {
		classes = s.detectionCfg.DefaultClasses
	}

	s.log(taskID, StageObjectDetection, "info", fmt.Sprintf("开始目标识别，输入: %s", inputPath))
	result, err := s.detectionRunner.Execute(ctx, objectdetection.ExecuteParams{
		InputPath:  inputPath,
		OutputDir:  outDir,
		Classes:    classes,
		DrawLabels: req.DetectionDrawLabels,
	}, func(level, content string) {
		s.log(taskID, StageObjectDetection, level, content)
	})
	if err != nil {
		return nil, err
	}

	artifacts := make([]model.RemoteSensingTaskArtifact, 0, len(result.Artifacts))
	for _, a := range result.Artifacts {
		artifacts = append(artifacts, model.RemoteSensingTaskArtifact{
			Type:     a.Type,
			Label:    a.Label,
			Path:     a.Path,
			Metadata: datatypes.JSONMap(a.Metadata),
		})
	}

	return &stageExecutionResult{
		OutputPath: outDir,
		Message:    result.Message,
		Details: map[string]interface{}{
			"input_path":  inputPath,
			"output_dir":  outDir,
			"device_mode": s.detectionCfg.Device,
			"use_cpu":     s.detectionCfg.UseCPU(),
		},
		Artifacts: artifacts,
	}, nil
}

func (s *RemoteSensingService) initDetectionRunner() {
	if s.detectionCfg.RootPath == "" {
		s.logger.Warn("目标识别未启用：未配置 SATELLITE_OBJECT_DETECTION_ROOT")
		return
	}
	s.detectionRunner = objectdetection.NewRunner(s.detectionCfg)
}

func (s *RemoteSensingService) syncDetectionArtifactsFromDisk(ctx context.Context, taskID uint) error {
	if s.detectionRunner == nil || s.detectionCfg.RootPath == "" {
		return nil
	}

	outDir := filepath.Join(s.detectionCfg.OutputSubdir, fmt.Sprintf("rs_task_%d", taskID))
	absOut := filepath.Join(s.detectionCfg.RootPath, outDir)
	if _, err := os.Stat(absOut); os.IsNotExist(err) {
		return nil
	}

	entries, err := objectdetection.CollectArtifactEntries(s.detectionCfg.RootPath, outDir, 0)
	if err != nil {
		return err
	}

	detectionTypes := []string{"detection_summary", "detection_preview", "detection_tile"}
	var existing []model.RemoteSensingTaskArtifact
	if err := s.db.WithContext(ctx).
		Where("task_id = ? AND type IN ?", taskID, detectionTypes).
		Find(&existing).Error; err != nil {
		return err
	}

	if len(existing) == len(entries) && len(entries) > 0 {
		existingPaths := make(map[string]struct{}, len(existing))
		for _, art := range existing {
			existingPaths[art.Path] = struct{}{}
		}
		allMatch := true
		for _, e := range entries {
			if _, ok := existingPaths[e.Path]; !ok {
				allMatch = false
				break
			}
		}
		if allMatch {
			return nil
		}
	}

	existingByPath := make(map[string]model.RemoteSensingTaskArtifact, len(existing))
	for _, art := range existing {
		existingByPath[art.Path] = art
	}

	wantPaths := make(map[string]objectdetection.ArtifactEntry, len(entries))
	for _, e := range entries {
		wantPaths[e.Path] = e
		if ex, ok := existingByPath[e.Path]; ok {
			if ex.Type != e.Type || ex.Label != e.Label {
				_ = s.db.WithContext(ctx).Model(&ex).Updates(map[string]interface{}{
					"type":  e.Type,
					"label": e.Label,
				}).Error
			}
			continue
		}
		art := model.RemoteSensingTaskArtifact{
			TaskID:   taskID,
			Type:     e.Type,
			Label:    e.Label,
			Path:     e.Path,
			Metadata: datatypes.JSONMap(e.Metadata),
		}
		if err := s.createArtifact(ctx, art); err != nil {
			return err
		}
	}

	for path, art := range existingByPath {
		if _, ok := wantPaths[path]; !ok {
			if err := s.db.WithContext(ctx).Delete(&art).Error; err != nil {
				return err
			}
		}
	}
	return nil
}
