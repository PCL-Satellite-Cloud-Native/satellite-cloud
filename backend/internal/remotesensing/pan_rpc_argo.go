package remotesensing

import (
	"context"
	"fmt"
	"os"
	"path/filepath"

	"go.uber.org/zap"

	"satellite-cloud/backend/internal/argo"
	"satellite-cloud/backend/internal/config"
)

func (s *RemoteSensingService) executePanRpcViaArgo(ctx context.Context, taskID uint, req CreateTaskRequest) (*stageExecutionResult, error) {
	if s.argoCfg.WorkflowImage == "" {
		return nil, fmt.Errorf("SATELLITE_RS_WORKFLOW_IMAGE 未配置")
	}
	demFile := s.cfg.DemFile
	if _, err := os.Stat(pathForOSAccess(demFile)); err != nil {
		return nil, fmt.Errorf("DEM 文件不存在或不可访问: %s", demFile)
	}
	argoClient, err := argo.NewInCluster(s.argoCfg.Namespace)
	if err != nil {
		return nil, fmt.Errorf("Argo 客户端: %w", err)
	}

	outputDir := s.persistRel(taskID, "pan_warp_quarters")
	persistOutputDir := s.persistRel(taskID, "pan_warp_quarters")
	taskPathPrefix := persistTaskPathPrefix(taskID, s.cfg.TaskPathIsolation)

	cpuThreads := effectiveParallelism(s.cfg.PanRPCCPUThreads, 1, 4)
	warpMemMB := s.cfg.PanRPCWarpMemMB
	if warpMemMB <= 0 {
		warpMemMB = 512
	}
	resampleAlg := s.cfg.PanRPCResampleAlg
	if resampleAlg == "" {
		resampleAlg = "near"
	}

	if err := s.preparePanRpcPersistWorkerDirs(persistOutputDir); err != nil {
		return nil, fmt.Errorf("准备 PAN RPC persist 目录: %w", err)
	}

	wfName, err := argoClient.SubmitPanRPCWorkflow(ctx, argo.PanRPCWorkflowParams{
		TemplateName:        s.argoCfg.PanRPCTemplate,
		TaskID:              taskID,
		FilePrefix:          req.FilePrefix,
		TaskPathPrefix:      taskPathPrefix,
		RSImage:             s.argoCfg.WorkflowImage,
		CPUThreads:          cpuThreads,
		WarpMemMB:           warpMemMB,
		ResampleAlg:         resampleAlg,
		SatelliteAffinityID: s.satelliteSatID(ctx, req.SatelliteID),
	})
	if err != nil {
		return nil, err
	}
	s.log(taskID, StagePanRpcWarp, "info", fmt.Sprintf("已提交 Argo Workflow: %s", wfName))

	waitCtx, cancel := context.WithTimeout(ctx, s.stageTimeoutFor(StagePanRpcWarp))
	defer cancel()
	if err := argoClient.WaitWorkflowCompleted(waitCtx, wfName, 0); err != nil {
		return nil, fmt.Errorf("Argo Workflow 失败: %w", err)
	}
	s.log(taskID, StagePanRpcWarp, "info", fmt.Sprintf("Argo Workflow 完成: %s", wfName))

	if err := s.mergePanRpcOnPersist(taskID, req.FilePrefix, persistOutputDir); err != nil {
		return nil, err
	}

	details := map[string]interface{}{
		"area_indexes": []int{1, 2, 3, 4},
		"completed":    4,
		"total":        4,
		"parallelism":  4,
		"cpu_threads":  cpuThreads,
		"warp_mem_mb":  warpMemMB,
		"resample_alg": resampleAlg,
		"mode":         "argo_workflow_parallel",
		"workflow":     wfName,
		"p3_04":        true,
		"p3_04b":       true,
	}
	return &stageExecutionResult{
		Details:    details,
		OutputPath: outputDir,
		Message:    "RPC 分块完成（Argo 4 路并行）",
	}, nil
}

func (s *RemoteSensingService) preparePanRpcPersistWorkerDirs(persistOutputRel string) error {
	base := filepath.Join(s.cfg.RootPath, persistOutputRel)
	if err := os.MkdirAll(base, 0o755); err != nil {
		return err
	}
	workers := filepath.Join(base, "workers")
	if !s.cfg.TaskPathIsolation {
		if err := os.RemoveAll(workers); err != nil {
			return err
		}
	}
	for group := 1; group <= 4; group++ {
		if err := os.MkdirAll(filepath.Join(workers, fmt.Sprintf("group%d", group)), 0o755); err != nil {
			return err
		}
	}
	return nil
}

func (s *RemoteSensingService) mergePanRpcOnPersist(taskID uint, filePrefix, persistOutputRel string) error {
	workersBase := filepath.Join(s.cfg.RootPath, persistOutputRel, "workers")
	destBase := filepath.Join(s.cfg.RootPath, persistOutputRel)
	for area := 1; area <= 4; area++ {
		partName := fmt.Sprintf("%s-PAN1-wrap-part%d.tif", filePrefix, area)
		src, err := findPanRpcPartOnPersist(workersBase, partName)
		if err != nil {
			return fmt.Errorf("Argo 产物缺失 area%d: %w", area, err)
		}
		dst := filepath.Join(destBase, partName)
		if err := os.Rename(src, dst); err != nil {
			if err := copyFile(src, dst); err != nil {
				return fmt.Errorf("合并 area%d: %w", area, err)
			}
		}
	}
	if err := os.RemoveAll(workersBase); err != nil {
		s.log(taskID, StagePanRpcWarp, "warn", fmt.Sprintf("清理 persist workers: %v", err))
	}
	return nil
}

func findPanRpcPartOnPersist(workersBase, partName string) (string, error) {
	for group := 1; group <= 4; group++ {
		candidate := filepath.Join(workersBase, fmt.Sprintf("group%d", group), partName)
		if _, err := os.Stat(candidate); err == nil {
			return candidate, nil
		}
	}
	return "", fmt.Errorf("%s", partName)
}

func (s *RemoteSensingService) panWarpQuartersInputDir(taskID uint) string {
	if s.argoCfg.UseArgoPanRPC {
		return s.persistRel(taskID, "pan_warp_quarters")
	}
	return s.scratchDir(taskID, "pan_warp_quarters")
}

func (s *RemoteSensingService) panRadToaOutputDir(taskID uint) string {
	if s.argoCfg.UseArgoPanRPC {
		return s.persistRel(taskID, "pan_rad_toa")
	}
	return s.scratchDir(taskID, "pan_rad_toa")
}

func (s *RemoteSensingService) initArgoFromConfig(cfg config.ArgoConfig, logger *zap.Logger) {
	s.argoCfg = cfg
	if cfg.UseArgoPanRPC {
		logger.Info("Argo PAN RPC enabled",
			zap.String("namespace", cfg.Namespace),
			zap.String("template", cfg.PanRPCTemplate),
			zap.String("workflow_image", cfg.WorkflowImage),
		)
	}
}
