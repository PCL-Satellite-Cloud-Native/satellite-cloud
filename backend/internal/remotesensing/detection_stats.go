package remotesensing

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"

	"satellite-cloud/backend/internal/model"
)

// DetectionClassStats 单类别瓦片数与检出目标数（一张瓦片可含多个目标）。
type DetectionClassStats struct {
	ClassDir       string `json:"class_dir"`
	Label          string `json:"label"`
	TileCount      int    `json:"tile_count"`
	DetectionCount int    `json:"detection_count"`
}

// DetectionSummaryStats 任务级检测统计。
type DetectionSummaryStats struct {
	TotalTiles      int                   `json:"total_tiles"`
	TotalDetections int                   `json:"total_detections"`
	ByClass         []DetectionClassStats `json:"by_class"`
}

var (
	detectionTotalHeaderRe = regexp.MustCompile(`共检测到\s+(\d+)\s+个目标`)
	detectionDataLineRe    = regexp.MustCompile(`^\s*\d+\s+(.+?\([^)]+\))\s+\d+(?:\.\d+)?\s+`)
)

var detectionClassLabels = map[string]string{
	"oil":                "油罐",
	"bridge":             "桥梁",
	"basketball court":   "篮球场",
	"ground track field": "田径场",
	"roundabout":         "环形交叉口",
	"harbor":             "码头",
	"other court":        "其他球场",
	"soccer ball field":  "足球场",
}

var detectionClassOrder = map[string]int{
	"oil": 0, "bridge": 1, "basketball court": 2, "ground track field": 3,
	"roundabout": 4, "harbor": 5, "other court": 6, "soccer ball field": 7,
}

func classDirFromSummaryField(field string) string {
	idx := strings.LastIndex(field, "(")
	if idx <= 0 {
		return strings.TrimSpace(field)
	}
	return strings.TrimSpace(field[:idx])
}

func parseDetectionsTxt(data []byte) (total int, byClass map[string]int) {
	byClass = make(map[string]int)
	text := string(data)
	if m := detectionTotalHeaderRe.FindStringSubmatch(text); len(m) == 2 {
		if n, err := strconv.Atoi(m[1]); err == nil {
			total = n
		}
	}
	for _, line := range strings.Split(text, "\n") {
		line = strings.TrimRight(line, "\r")
		if line == "" || strings.HasPrefix(strings.TrimSpace(line), "#") {
			continue
		}
		m := detectionDataLineRe.FindStringSubmatch(line)
		if len(m) != 2 {
			continue
		}
		classDir := classDirFromSummaryField(m[1])
		if classDir == "" {
			continue
		}
		byClass[classDir]++
	}
	if total == 0 {
		for _, n := range byClass {
			total += n
		}
	}
	return total, byClass
}

func (s *RemoteSensingService) countDetectionTilesByClass(ctx context.Context, taskID uint) map[string]int {
	var arts []model.RemoteSensingTaskArtifact
	_ = s.db.WithContext(ctx).
		Select("metadata").
		Where("task_id = ? AND type IN ?", taskID, []string{"detection_preview", "detection_tile"}).
		Find(&arts).Error

	byClass := make(map[string]int)
	for _, art := range arts {
		if art.Metadata == nil {
			continue
		}
		raw, ok := art.Metadata["class_dir"]
		if !ok {
			continue
		}
		classDir, ok := raw.(string)
		if !ok || classDir == "" {
			continue
		}
		byClass[classDir]++
	}
	return byClass
}

// GetDetectionStats 汇总各类别瓦片张数（含目标瓦片图）与检出目标个数（来自 detections.txt）。
func (s *RemoteSensingService) GetDetectionStats(ctx context.Context, taskID uint) (*DetectionSummaryStats, error) {
	tileByClass := s.countDetectionTilesByClass(ctx, taskID)

	detectByClass := make(map[string]int)
	totalDetections := 0

	if s.detectionCfg.RootPath != "" {
		outDir := filepath.Join(s.detectionCfg.OutputSubdir, fmt.Sprintf("rs_task_%d", taskID))
		summaryPath := filepath.Join(s.detectionCfg.RootPath, outDir, "detections.txt")
		if data, err := os.ReadFile(summaryPath); err == nil {
			totalDetections, detectByClass = parseDetectionsTxt(data)
		}
	}

	classSet := make(map[string]struct{})
	for k := range tileByClass {
		classSet[k] = struct{}{}
	}
	for k := range detectByClass {
		classSet[k] = struct{}{}
	}

	byClass := make([]DetectionClassStats, 0, len(classSet))
	totalTiles := 0
	for classDir := range classSet {
		tiles := tileByClass[classDir]
		detections := detectByClass[classDir]
		totalTiles += tiles
		label := detectionClassLabels[classDir]
		if label == "" {
			label = classDir
		}
		byClass = append(byClass, DetectionClassStats{
			ClassDir:       classDir,
			Label:          label,
			TileCount:      tiles,
			DetectionCount: detections,
		})
	}

	sort.Slice(byClass, func(i, j int) bool {
		oi, oj := detectionClassOrder[byClass[i].ClassDir], detectionClassOrder[byClass[j].ClassDir]
		if oi != oj {
			return oi < oj
		}
		return byClass[i].ClassDir < byClass[j].ClassDir
	})

	if totalDetections == 0 {
		for _, item := range byClass {
			totalDetections += item.DetectionCount
		}
	}

	return &DetectionSummaryStats{
		TotalTiles:      totalTiles,
		TotalDetections: totalDetections,
		ByClass:         byClass,
	}, nil
}
