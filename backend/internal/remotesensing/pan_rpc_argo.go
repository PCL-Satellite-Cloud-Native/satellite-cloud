package remotesensing

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"time"

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

	outputDir := filepath.Join(s.cfg.PersistOutputDir, "pan_warp_quarters")
	persistOutputDir := filepath.Join(s.cfg.PersistOutputDir, "pan_warp_quarters")
	cpuThreads, warpMemMB := argoPanRpcTuning(s.cfg)
	resampleAlg := s.cfg.PanRPCResampleAlg
	if resampleAlg == "" {
		resampleAlg = "near"
	}

	if err := s.preparePanRpcOutputDir(persistOutputDir, req.FilePrefix); err != nil {
		return nil, fmt.Errorf("准备 PAN RPC 输出目录: %w", err)
	}

	wfName, err := argoClient.SubmitPanRPCWorkflow(ctx, argo.PanRPCWorkflowParams{
		TemplateName: s.argoCfg.PanRPCTemplate,
		TaskID:       taskID,
		FilePrefix:   req.FilePrefix,
		RSImage:      s.argoCfg.WorkflowImage,
		CPUThreads:   cpuThreads,
		WarpMemMB:    warpMemMB,
		ResampleAlg:  resampleAlg,
	})
	if err != nil {
		return nil, err
	}
	s.log(taskID, StagePanRpcWarp, "info", fmt.Sprintf("已提交 Argo Workflow: %s", wfName))

	waitCtx, cancel := context.WithTimeout(ctx, s.stageTimeoutFor(StagePanRpcWarp))
	defer cancel()
	if err := argoClient.WaitWorkflowCompleted(waitCtx, wfName, 2*time.Second); err != nil {
		return nil, fmt.Errorf("Argo Workflow 失败: %w", err)
	}
	s.log(taskID, StagePanRpcWarp, "info", fmt.Sprintf("Argo Workflow 完成: %s", wfName))

	if err := s.verifyPanRpcPartsOnPersist(req.FilePrefix, persistOutputDir); err != nil {
		return nil, err
	}

	details := map[string]interface{}{
		"area_indexes":   []int{1, 2, 3, 4},
		"completed":      4,
		"total":          4,
		"parallelism":    4,
		"cpu_threads":    cpuThreads,
		"warp_mem_mb":    warpMemMB,
		"resample_alg":   resampleAlg,
		"mode":           "argo_workflow_parallel",
		"direct_output":  true,
		"workflow":       wfName,
		"p3_04":          true,
		"p3_04c":         true,
	}
	return &stageExecutionResult{
		Details:    details,
		OutputPath: outputDir,
		Message:    "RPC 分块完成（Argo 4 路直写）",
	}, nil
}

// argoPanRpcTuning：Argo step 为独立 Pod，每 Pod 单独占用 warp 内存预算（非 rs-worker 进程内合计）。
func argoPanRpcTuning(cfg config.RemoteSensingConfig) (cpuThreads, warpMemMB int) {
	cpuThreads = effectiveParallelism(cfg.PanRPCCPUThreads, 1, 4)
	if cpuThreads < 2 {
		cpuThreads = 2
	}
	warpMemMB = cfg.PanRPCWarpMemMB
	if warpMemMB <= 0 {
		warpMemMB = 512
	}
	if warpMemMB < 1024 {
		warpMemMB = 1024
	}
	return cpuThreads, warpMemMB
}

func (s *RemoteSensingService) preparePanRpcOutputDir(persistOutputRel, filePrefix string) error {
	base := filepath.Join(s.cfg.RootPath, persistOutputRel)
	if err := os.MkdirAll(base, 0o755); err != nil {
		return err
	}
	if err := os.RemoveAll(filepath.Join(base, "workers")); err != nil {
		return err
	}
	for area := 1; area <= 4; area++ {
		part := filepath.Join(base, fmt.Sprintf("%s-PAN1-wrap-part%d.tif", filePrefix, area))
		if err := os.Remove(part); err != nil && !os.IsNotExist(err) {
			return err
		}
	}
	return nil
}

func (s *RemoteSensingService) verifyPanRpcPartsOnPersist(filePrefix, persistOutputRel string) error {
	base := filepath.Join(s.cfg.RootPath, persistOutputRel)
	for area := 1; area <= 4; area++ {
		part := filepath.Join(base, fmt.Sprintf("%s-PAN1-wrap-part%d.tif", filePrefix, area))
		if _, err := os.Stat(part); err != nil {
			return fmt.Errorf("Argo 产物缺失 area%d: %w", area, err)
		}
	}
	return nil
}

func (s *RemoteSensingService) panWarpQuartersInputDir() string {
	if s.argoCfg.UseArgoPanRPC {
		return filepath.Join(s.cfg.PersistOutputDir, "pan_warp_quarters")
	}
	return filepath.Join("output_preprocessing", "pan_warp_quarters")
}

func (s *RemoteSensingService) panRadToaOutputDir() string {
	if s.argoCfg.UseArgoPanRPC {
		return filepath.Join(s.cfg.PersistOutputDir, "pan_rad_toa")
	}
	return filepath.Join("output_preprocessing", "pan_rad_toa")
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
