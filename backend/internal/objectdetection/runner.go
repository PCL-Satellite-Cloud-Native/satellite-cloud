package objectdetection

import (
	"bytes"
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"satellite-cloud/backend/internal/config"
)

// ArtifactEntry 检测产物（路径相对于 Object-Detection 根目录）
type ArtifactEntry struct {
	Type     string
	Label    string
	Path     string
	Metadata map[string]interface{}
}

// ExecuteParams 单次检测执行参数
type ExecuteParams struct {
	InputPath  string // 融合 .dat，可为绝对路径或 /mnt/ 路径
	OutputDir  string // 相对于 Object-Detection 根目录
	Classes    string
	DrawLabels bool
}

// ExecuteResult 检测执行结果
type ExecuteResult struct {
	Output   string
	Message  string
	OutDir   string
	Artifacts []ArtifactEntry
}

// Runner 封装 yolov8s 子进程调用（本地 WSL / Linux K8s 共用，路径由 config 决定）
type Runner struct {
	Cfg config.ObjectDetectionConfig
}

func NewRunner(cfg config.ObjectDetectionConfig) *Runner {
	return &Runner{Cfg: cfg}
}

func (r *Runner) Execute(ctx context.Context, params ExecuteParams, logFn func(level, content string)) (*ExecuteResult, error) {
	inputPath := pathForWSLRunner(params.InputPath)
	statPath := pathForOSAccess(inputPath)
	if _, err := os.Stat(statPath); err != nil {
		return nil, fmt.Errorf("检测输入不存在: %s (%v)", statPath, err)
	}

	outFile := filepath.Join(params.OutputDir, "output.jpg")
	args := []string{"-input", inputPath, "-output", outFile}
	if r.Cfg.UseCPU() {
		args = append(args, "-cpu")
	}
	if strings.TrimSpace(params.Classes) != "" {
		args = append(args, "-classes", params.Classes)
	}
	if params.DrawLabels {
		args = append(args, "-labels")
	}

	output, err := r.run(ctx, args, logFn)
	if err != nil {
		return nil, err
	}

	artifacts, _ := r.collectArtifacts(params.OutputDir)
	message := "目标识别完成"
	if strings.Contains(output, "未检测到任何目标") {
		message = "目标识别完成，未发现目标"
	}

	return &ExecuteResult{
		Output:    output,
		Message:   message,
		OutDir:    params.OutputDir,
		Artifacts: artifacts,
	}, nil
}

// FusionDatPathForRunner 将遥感融合产物绝对路径转为检测器可访问的路径
func FusionDatPathForRunner(rsRoot, fusionRel string) string {
	abs := filepath.Join(rsRoot, filepath.FromSlash(fusionRel))
	abs, _ = filepath.Abs(abs)
	return pathForWSLRunner(filepath.ToSlash(abs))
}

func (r *Runner) run(ctx context.Context, args []string, logFn func(level, content string)) (string, error) {
	args = normalizeArgsForRunner(r.Cfg.RunnerPath, args)
	cmd := exec.CommandContext(ctx, r.Cfg.RunnerPath, args...)
	cmd.Dir = r.Cfg.RootPath
	var buf bytes.Buffer
	cmd.Stdout = &buf
	cmd.Stderr = &buf
	if err := cmd.Start(); err != nil {
		return "", err
	}
	done := make(chan error, 1)
	go func() { done <- cmd.Wait() }()

	heartbeat := time.NewTicker(time.Duration(max(r.Cfg.CommandHeartbeatSec, 60)) * time.Second)
	defer heartbeat.Stop()

	var err error
loop:
	for {
		select {
		case err = <-done:
			break loop
		case <-heartbeat.C:
			if logFn != nil {
				logFn("info", "心跳: yolov8s 仍在运行")
			}
		case <-ctx.Done():
			_ = cmd.Process.Kill()
			err = <-done
			break loop
		}
	}

	out := buf.String()
	if logFn != nil {
		logFn("info", fmt.Sprintf("yolov8s %v\n%s", args, out))
	}
	return out, err
}

func (r *Runner) collectArtifacts(outDir string) ([]ArtifactEntry, error) {
	return CollectArtifactEntries(r.Cfg.RootPath, outDir, 0)
}

func copyMeta(src map[string]interface{}) map[string]interface{} {
	dst := make(map[string]interface{}, len(src))
	for k, v := range src {
		dst[k] = v
	}
	return dst
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
