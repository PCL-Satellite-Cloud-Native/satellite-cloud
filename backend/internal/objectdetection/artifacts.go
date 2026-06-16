package objectdetection

import (
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// CollectArtifactEntries 按类别子目录收集检测产物（每类全部瓦片）。
// perClassLimit <= 0 表示不限制；> 0 时仅用于调试截断。
func CollectArtifactEntries(rootPath, outDir string, perClassLimit int) ([]ArtifactEntry, error) {

	rootAbs, err := filepath.Abs(rootPath)
	if err != nil {
		return nil, err
	}
	absOut, err := filepath.Abs(filepath.Join(rootAbs, outDir))
	if err != nil {
		return nil, err
	}

	metaRoot := map[string]interface{}{"artifact_root": "object_detection"}
	var artifacts []ArtifactEntry

	summaryPath := filepath.Join(absOut, "detections.txt")
	if _, err := os.Stat(summaryPath); err == nil {
		if rel, err := filepath.Rel(rootAbs, summaryPath); err == nil {
			artifacts = append(artifacts, ArtifactEntry{
				Type:     "detection_summary",
				Label:    "检测摘要 detections.txt",
				Path:     filepath.ToSlash(rel),
				Metadata: copyMeta(metaRoot),
			})
		}
	}

	entries, err := os.ReadDir(absOut)
	if err != nil {
		if os.IsNotExist(err) {
			return artifacts, nil
		}
		return nil, err
	}

	type classImages struct {
		dir   string
		paths []string
	}
	var classes []classImages

	for _, ent := range entries {
		if !ent.IsDir() || strings.HasPrefix(ent.Name(), ".") {
			continue
		}
		classDir := filepath.Join(absOut, ent.Name())
		jpgPaths, err := collectJPGsInDir(classDir, perClassLimit)
		if err != nil || len(jpgPaths) == 0 {
			continue
		}
		sort.Strings(jpgPaths)
		classes = append(classes, classImages{dir: ent.Name(), paths: jpgPaths})
	}

	sort.Slice(classes, func(i, j int) bool {
		return classes[i].dir < classes[j].dir
	})

	previewAssigned := false
	for _, cl := range classes {
		for _, path := range cl.paths {
			rel, err := filepath.Rel(rootAbs, path)
			if err != nil {
				continue
			}
			artType := "detection_tile"
			if !previewAssigned {
				artType = "detection_preview"
				previewAssigned = true
			}
			m := copyMeta(metaRoot)
			m["class_dir"] = cl.dir
			artifacts = append(artifacts, ArtifactEntry{
				Type:     artType,
				Label:    filepath.Base(path),
				Path:     filepath.ToSlash(rel),
				Metadata: m,
			})
		}
	}
	return artifacts, nil
}

func collectJPGsInDir(dir string, limit int) ([]string, error) {
	var paths []string
	err := filepath.WalkDir(dir, func(path string, d fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if d.IsDir() {
			return nil
		}
		if !strings.EqualFold(filepath.Ext(path), ".jpg") {
			return nil
		}
		paths = append(paths, path)
		if limit > 0 && len(paths) >= limit {
			return fs.SkipAll
		}
		return nil
	})
	return paths, err
}
