package declarative

// 清单文件的在线查看 / 修改 / 单文件执行支持。
//
// 提供三类能力（供 CRDHandler 的 HTTP 入口使用）：
//   - ListManifestFiles：列出清单目录下所有 *.yaml / *.yml 文件（名称/大小/修改时间）；
//   - LoadManifestFile：安全加载单个清单文件并解析（防目录穿越，仅允许 yaml 扩展名）；
//   - ApplyFile：对单个清单文件执行 reconcile（幂等，与 ApplyAll 共用 applyManifest）。
//
// 单文件执行不做跨清单排序：依赖关系（存储 → 队列 → 场景 → 拓扑 → 卫星 → 任务）
// 由用户选择文件顺序保证，或者直接使用 POST /api/crd/sync 做整目录排序同步。
import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"gorm.io/gorm"
)

// ManifestFileInfo 清单文件的基础信息。
type ManifestFileInfo struct {
	Name    string `json:"name"`
	Kind    string `json:"kind"`
	Size    int64  `json:"size"`
	Path    string `json:"path"`
	ModTime string `json:"modified"`
}

// ListManifestFiles 列出目录下所有 *.yaml / *.yml 清单文件（按文件名排序）。
func ListManifestFiles(dir string) ([]ManifestFileInfo, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, fmt.Errorf("read config dir: %w", err)
	}
	var files []ManifestFileInfo
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		name := e.Name()
		if !strings.HasSuffix(name, ".yaml") && !strings.HasSuffix(name, ".yml") {
			continue
		}
		info, err := e.Info()
		if err != nil {
			return nil, fmt.Errorf("stat %s: %w", name, err)
		}
		fi := ManifestFileInfo{
			Name:    name,
			Size:    info.Size(),
			Path:    filepath.Join(dir, name),
			ModTime: info.ModTime().Format("2006-01-02 15:04:05"),
		}
		// 尝试识别 kind（解析失败不阻断列表，kind 留空）
		if data, rerr := os.ReadFile(filepath.Join(dir, name)); rerr == nil {
			if m, perr := ParseManifest(data); perr == nil {
				fi.Kind = m.Kind
			}
		}
		files = append(files, fi)
	}
	sort.Slice(files, func(i, j int) bool { return files[i].Name < files[j].Name })
	return files, nil
}

// sanitizeManifestFilename 校验并规整文件名：只允许纯文件名（去路径）、
// yaml/yml 后缀，防目录穿越。
func sanitizeManifestFilename(filename string) (string, error) {
	base := filepath.Base(filename)
	if base == "." || base == string(filepath.Separator) || strings.Contains(base, "..") {
		return "", fmt.Errorf("invalid manifest filename: %q", filename)
	}
	if !strings.HasSuffix(base, ".yaml") && !strings.HasSuffix(base, ".yml") {
		return "", fmt.Errorf("invalid manifest filename %q: must end with .yaml or .yml", filename)
	}
	return base, nil
}

// LoadManifestFile 安全加载单个清单文件并解析（返回文件内容 + 解析结果）。
func LoadManifestFile(dir, filename string) ([]byte, *Manifest, error) {
	base, err := sanitizeManifestFilename(filename)
	if err != nil {
		return nil, nil, err
	}
	path := filepath.Join(dir, base)
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, nil, fmt.Errorf("read %s: %w", path, err)
	}
	m, err := ParseManifest(data)
	if err != nil {
		return nil, nil, fmt.Errorf("%s: %w", path, err)
	}
	return data, m, nil
}

// SaveManifestFile 保存（覆盖）单个清单文件。写入前做 YAML 结构校验，
// 保证只允许合法且受支持的清单落地。
func SaveManifestFile(dir, filename string, data []byte) (*ManifestFileInfo, error) {
	base, err := sanitizeManifestFilename(filename)
	if err != nil {
		return nil, err
	}
	if _, err := ParseManifest(data); err != nil {
		return nil, fmt.Errorf("manifest validation failed: %w", err)
	}
	path := filepath.Join(dir, base)
	if err := os.WriteFile(path, data, 0o644); err != nil {
		return nil, fmt.Errorf("write %s: %w", path, err)
	}
	info, err := os.Stat(path)
	if err != nil {
		return nil, fmt.Errorf("stat %s: %w", path, err)
	}
	return &ManifestFileInfo{
		Name:    base,
		Size:    info.Size(),
		Path:    path,
		ModTime: info.ModTime().Format("2006-01-02 15:04:05"),
	}, nil
}

// ApplyFile 应用单个清单文件（幂等），返回该文件对应的同步结果。
func ApplyFile(db *gorm.DB, dir, filename string) ([]ApplyResult, error) {
	_, m, err := LoadManifestFile(dir, filename)
	if err != nil {
		return nil, err
	}
	res := applyManifest(db, m)
	return []ApplyResult{res}, nil
}
