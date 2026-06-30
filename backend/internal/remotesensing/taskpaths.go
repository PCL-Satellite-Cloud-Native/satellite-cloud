package remotesensing

import (
	"fmt"
	"path/filepath"
	"strconv"
)

const taskDirName = "tasks"

// scratchPreprocessingDir 返回 scratch 相对路径：output_preprocessing[/tasks/{id}]/{parts...}
func scratchPreprocessingDir(taskID uint, isolated bool, parts ...string) string {
	elems := []string{"output_preprocessing"}
	if isolated && taskID > 0 {
		elems = append(elems, taskDirName, strconv.FormatUint(uint64(taskID), 10))
	}
	return filepath.Join(append(elems, parts...)...)
}

// persistPreprocessingDir 返回 persist 相对路径：{persistRoot}[/tasks/{id}]/{parts...}
func persistPreprocessingDir(taskID uint, persistRoot string, isolated bool, parts ...string) string {
	root := filepath.Clean(persistRoot)
	elems := []string{root}
	if isolated && taskID > 0 {
		elems = append(elems, taskDirName, strconv.FormatUint(uint64(taskID), 10))
	}
	return filepath.Join(append(elems, parts...)...)
}

// persistTaskPathPrefix 供 Argo Workflow 参数：空串表示 legacy 全局路径；否则 "tasks/{id}/"
func persistTaskPathPrefix(taskID uint, isolated bool) string {
	if !isolated || taskID == 0 {
		return ""
	}
	return fmt.Sprintf("%s/%d/", taskDirName, taskID)
}

func (s *RemoteSensingService) scratchDir(taskID uint, parts ...string) string {
	return scratchPreprocessingDir(taskID, s.cfg.TaskPathIsolation, parts...)
}

func (s *RemoteSensingService) persistRel(taskID uint, parts ...string) string {
	return persistPreprocessingDir(taskID, s.cfg.PersistOutputDir, s.cfg.TaskPathIsolation, parts...)
}
