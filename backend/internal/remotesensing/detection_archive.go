package remotesensing

import (
	"archive/zip"
	"context"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
)

// DetectionOutputAbsDir 返回任务检测输出目录绝对路径。
func (s *RemoteSensingService) DetectionOutputAbsDir(taskID uint) (string, error) {
	if s.detectionCfg.RootPath == "" {
		return "", fmt.Errorf("目标识别未配置")
	}
	outDir := filepath.Join(s.detectionCfg.OutputSubdir, fmt.Sprintf("rs_task_%d", taskID))
	absOut, err := filepath.Abs(filepath.Join(s.detectionCfg.RootPath, outDir))
	if err != nil {
		return "", err
	}
	if _, err := os.Stat(absOut); err != nil {
		return "", fmt.Errorf("检测输出目录不存在")
	}
	return absOut, nil
}

// WriteDetectionTilesArchive 将 rs_task_<id> 下全部检测瓦片（含 detections.txt）打包为 zip。
func (s *RemoteSensingService) WriteDetectionTilesArchive(ctx context.Context, taskID uint, w io.Writer) (int, error) {
	absOut, err := s.DetectionOutputAbsDir(taskID)
	if err != nil {
		return 0, err
	}

	zw := zip.NewWriter(w)
	defer zw.Close()

	added := 0
	err = filepath.WalkDir(absOut, func(path string, d fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if d.IsDir() {
			return nil
		}
		base := strings.ToLower(filepath.Base(path))
		if !strings.HasSuffix(base, ".jpg") && base != "detections.txt" {
			return nil
		}

		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}

		rel, err := filepath.Rel(absOut, path)
		if err != nil {
			return err
		}
		rel = filepath.ToSlash(rel)

		info, err := d.Info()
		if err != nil {
			return err
		}
		header, err := zip.FileInfoHeader(info)
		if err != nil {
			return err
		}
		header.Name = rel
		header.Method = zip.Deflate

		writer, err := zw.CreateHeader(header)
		if err != nil {
			return err
		}
		file, err := os.Open(path)
		if err != nil {
			return err
		}
		_, copyErr := io.Copy(writer, file)
		closeErr := file.Close()
		if copyErr != nil {
			return copyErr
		}
		if closeErr != nil {
			return closeErr
		}
		added++
		return nil
	})
	if err != nil {
		return added, err
	}
	if added == 0 {
		return 0, fmt.Errorf("没有可打包的检测瓦片")
	}
	return added, nil
}
