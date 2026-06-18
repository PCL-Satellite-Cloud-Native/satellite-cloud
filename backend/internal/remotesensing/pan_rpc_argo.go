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

	outputDir := filepath.Join("output_preprocessing", "pan_warp_quarters")
	persistOutputDir := filepath.Join(s.cfg.PersistOutputDir, "pan_warp_quarters")
	persistRadDir := filepath.Join(s.cfg.PersistOutputDir, "pan_rad_toa")
	scratchRadDir := filepath.Join("output_preprocessing", "pan_rad_toa")

	s.log(taskID, StagePanRpcWarp, "info", "Argo PAN RPC：同步 pan_rad_toa 至 NFS")
	if err := s.syncDirToPersist(scratchRadDir, persistRadDir); err != nil {
		return nil, fmt.Errorf("同步 pan_rad_toa: %w", err)
	}

	absoluteOutputDir := filepath.Join(s.cfg.RootPath, outputDir)
	if err := os.MkdirAll(absoluteOutputDir, 0o755); err != nil {
		return nil, fmt.Errorf("创建 PAN RPC 输出目录失败: %w", err)
	}
	persistWorkers := filepath.Join(s.cfg.RootPath, persistOutputDir, "workers")
	if err := os.RemoveAll(persistWorkers); err != nil {
		s.log(taskID, StagePanRpcWarp, "warn", fmt.Sprintf("清理 persist workers: %v", err))
	}

	wfName, err := argoClient.SubmitPanRPCWorkflow(ctx, s.argoCfg.PanRPCTemplate, taskID, req.FilePrefix, s.argoCfg.WorkflowImage)
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

	if err := s.mergePanRpcFromPersist(taskID, req.FilePrefix, persistOutputDir, outputDir); err != nil {
		return nil, err
	}

	details := map[string]interface{}{
		"area_indexes": []int{1, 2, 3, 4},
		"completed":    4,
		"total":        4,
		"parallelism":  4,
		"mode":         "argo_workflow_parallel",
		"workflow":     wfName,
	}
	return &stageExecutionResult{
		Details:    details,
		OutputPath: outputDir,
		Message:    "RPC 分块完成（Argo 4 路并行）",
	}, nil
}

func (s *RemoteSensingService) syncDirToPersist(scratchRel, persistRel string) error {
	src := filepath.Join(s.cfg.RootPath, scratchRel)
	dst := filepath.Join(s.cfg.RootPath, persistRel)
	if err := os.MkdirAll(dst, 0o755); err != nil {
		return err
	}
	return copyDirContents(src, dst)
}

func copyDirContents(srcDir, dstDir string) error {
	entries, err := os.ReadDir(srcDir)
	if err != nil {
		return err
	}
	for _, e := range entries {
		src := filepath.Join(srcDir, e.Name())
		dst := filepath.Join(dstDir, e.Name())
		if e.IsDir() {
			if err := os.MkdirAll(dst, 0o755); err != nil {
				return err
			}
			if err := copyDirContents(src, dst); err != nil {
				return err
			}
			continue
		}
		if err := copyFile(src, dst); err != nil {
			return err
		}
	}
	return nil
}

func (s *RemoteSensingService) mergePanRpcFromPersist(taskID uint, filePrefix, persistOutputRel, scratchOutputRel string) error {
	persistBase := filepath.Join(s.cfg.RootPath, persistOutputRel, "workers")
	scratchBase := filepath.Join(s.cfg.RootPath, scratchOutputRel)
	for area := 1; area <= 4; area++ {
		partName := fmt.Sprintf("%s-PAN1-wrap-part%d.tif", filePrefix, area)
		src := filepath.Join(persistBase, fmt.Sprintf("group%d", area), partName)
		dst := filepath.Join(scratchBase, partName)
		if _, err := os.Stat(src); os.IsNotExist(err) {
			return fmt.Errorf("Argo 产物缺失: %s", src)
		}
		if err := copyFile(src, dst); err != nil {
			return fmt.Errorf("合并 area%d: %w", area, err)
		}
	}
	if err := os.RemoveAll(persistBase); err != nil {
		s.log(taskID, StagePanRpcWarp, "warn", fmt.Sprintf("清理 persist workers: %v", err))
	}
	return nil
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
