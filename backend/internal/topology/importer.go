package topology

import (
	"encoding/csv"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"

	"gorm.io/gorm"
)

// ImportDelayFromCSV 将 delay_XXxXX.csv 导入到 satellite_delay_edges 表。
// - db: 共享的 gorm.DB 连接
// - scenarioName: 场景名称（scenarios.name），如 "Scenario5_full_36x22"
// - filePath: delay 矩阵 CSV 路径
func ImportDelayFromCSV(db *gorm.DB, scenarioName, filePath string) error {
	if scenarioName == "" {
		return fmt.Errorf("scenarioName is empty")
	}
	if filePath == "" {
		return fmt.Errorf("filePath is empty")
	}

	var scenarioID int64
	if err := db.
		Raw(`SELECT id FROM public.scenarios WHERE name = ? LIMIT 1`, scenarioName).
		Scan(&scenarioID).Error; err != nil {
		return fmt.Errorf("query scenario id: %w", err)
	}
	if scenarioID == 0 {
		return fmt.Errorf("scenario %q not found", scenarioName)
	}

	parsed, err := LoadDelayEdgesFromCSV(filePath)
	if err != nil {
		return err
	}

	return db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Exec(`DELETE FROM public.satellite_delay_edges WHERE scenario_id = ?`, scenarioID).Error; err != nil {
			return fmt.Errorf("delete old edges: %w", err)
		}
		for _, e := range parsed {
			if err := tx.Exec(`
				INSERT INTO public.satellite_delay_edges (
					scenario_id, a_id, b_id, delay_s, dist_km
				) VALUES (?, ?, ?, ?, ?)`,
				scenarioID, e.AId, e.BId, e.DelayS, e.DistKm,
			).Error; err != nil {
				return fmt.Errorf("insert edge (%s,%s): %w", e.AId, e.BId, err)
			}
		}
		return nil
	})
}

// DelayEdgeCSV 从 delay 矩阵 CSV 解析出的一条边。
type DelayEdgeCSV struct {
	AId    string
	BId    string
	DelayS float64
	DistKm float64
}

const speedOfLightKmPerS = 299792.458

// DefaultDelayCSVPath 返回 delay 矩阵 CSV 默认路径。
func DefaultDelayCSVPath() string {
	if v := os.Getenv("SATELLITE_DELAY_CSV_PATH"); v != "" {
		return v
	}
	return filepath.Join("..", "frontend", "public", "data", "delay_15x15.csv")
}

// LoadDelayEdgesFromCSV 解析 delay 矩阵 CSV（非零项，a_id < b_id 去重）。
func LoadDelayEdgesFromCSV(filePath string) ([]DelayEdgeCSV, error) {
	if filePath == "" {
		return nil, fmt.Errorf("filePath is empty")
	}
	f, err := os.Open(filePath)
	if err != nil {
		return nil, fmt.Errorf("open csv: %w", err)
	}
	defer f.Close()

	r := csv.NewReader(f)
	r.TrimLeadingSpace = true
	rows, err := r.ReadAll()
	if err != nil {
		return nil, fmt.Errorf("read csv: %w", err)
	}
	if len(rows) < 2 {
		return nil, fmt.Errorf("csv rows too short")
	}

	header := rows[0]
	if len(header) < 2 {
		return nil, fmt.Errorf("csv header too short")
	}
	colNames := header[1:]

	var edges []DelayEdgeCSV
	for i := 1; i < len(rows); i++ {
		row := rows[i]
		if len(row) < 2 {
			continue
		}
		rowName := strings.TrimSpace(row[0])
		if rowName == "" {
			continue
		}
		for j := 1; j < len(row) && j-1 < len(colNames); j++ {
			colName := strings.TrimSpace(colNames[j-1])
			if colName == "" {
				continue
			}
			vStr := strings.TrimSpace(row[j])
			if vStr == "" {
				continue
			}
			var v float64
			if _, err := fmt.Sscanf(vStr, "%f", &v); err != nil || v == 0 {
				continue
			}
			if rowName < colName {
				edges = append(edges, DelayEdgeCSV{
					AId:    rowName,
					BId:    colName,
					DelayS: v,
					DistKm: v * speedOfLightKmPerS,
				})
			}
		}
	}
	return edges, nil
}

// Pilot 15 星 legacy 星历文件名（Sat_6_6 … Sat_8_10）；目录扫描为空时回退。
var t0EphemFilesLegacy = []string{
	"Sat_6_6_ephem_ext.csv", "Sat_6_7_ephem_ext.csv", "Sat_6_8_ephem_ext.csv", "Sat_6_9_ephem_ext.csv", "Sat_6_10_ephem_ext.csv",
	"Sat_7_6_ephem_ext.csv", "Sat_7_7_ephem_ext.csv", "Sat_7_8_ephem_ext.csv", "Sat_7_9_ephem_ext.csv", "Sat_7_10_ephem_ext.csv",
	"Sat_8_6_ephem_ext.csv", "Sat_8_7_ephem_ext.csv", "Sat_8_8_ephem_ext.csv", "Sat_8_9_ephem_ext.csv", "Sat_8_10_ephem_ext.csv",
}

var ephemExtPattern = regexp.MustCompile(`^Sat_\d+_\d+_ephem_ext\.csv$`)

// listT0EphemFiles 扫描 dirPath 下全部 Sat_*_ephem_ext.csv；无匹配时回退 legacy 15 星列表。
func listT0EphemFiles(dirPath string) ([]string, error) {
	entries, err := os.ReadDir(dirPath)
	if err != nil {
		return nil, fmt.Errorf("read dir: %w", err)
	}
	var names []string
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		name := e.Name()
		if ephemExtPattern.MatchString(name) {
			names = append(names, name)
		}
	}
	if len(names) == 0 {
		return append([]string(nil), t0EphemFilesLegacy...), nil
	}
	sort.Strings(names)
	return names, nil
}

// ImportSatStatesFromCSV 将星历 CSV 的第 2 行（T0）导入 satellite_states。
// - dirPath: 存放 Sat_*_ephem_ext.csv 的目录（如 ephem_15/ 或 ephem_60/）
func ImportSatStatesFromCSV(db *gorm.DB, scenarioName, dirPath string) error {
	if scenarioName == "" {
		return fmt.Errorf("scenarioName is empty")
	}
	if dirPath == "" {
		return fmt.Errorf("dirPath is empty")
	}

	var scenarioID int64
	if err := db.
		Raw(`SELECT id FROM public.scenarios WHERE name = ? LIMIT 1`, scenarioName).
		Scan(&scenarioID).Error; err != nil {
		return fmt.Errorf("query scenario id: %w", err)
	}
	if scenarioID == 0 {
		return fmt.Errorf("scenario %q not found", scenarioName)
	}

	// 解析 UTCG 为 timestamptz，格式如 "15 Dec 2025 00:00:00.000"
	parseUTC := func(s string) (time.Time, error) {
		s = strings.TrimSpace(s)
		if idx := strings.LastIndex(s, "."); idx != -1 {
			s = s[:idx]
		}
		return time.Parse("2 Jan 2006 15:04:05", s)
	}

	type stateRow struct {
		satID       string
		tUTC        time.Time
		rX, rY, rZ  float64
		llaLat      float64
		llaLon      float64
		llaAlt      float64
		coeSMA      float64
		coeEcc      float64
		coeInc      float64
		coeRaan     float64
		coeArgp     float64
		coeTA       float64
	}

	ephemFiles, err := listT0EphemFiles(dirPath)
	if err != nil {
		return err
	}

	var rows []stateRow
	for _, name := range ephemFiles {
		path := filepath.Join(dirPath, name)
		f, err := os.Open(path)
		if err != nil {
			return fmt.Errorf("open %s: %w", path, err)
		}
		r := csv.NewReader(f)
		r.TrimLeadingSpace = true
		header, err := r.Read()
		f.Close()
		if err != nil {
			return fmt.Errorf("read header %s: %w", path, err)
		}
		colIdx := make(map[string]int)
		for i, h := range header {
			colIdx[strings.TrimSpace(strings.TrimPrefix(h, "\uFEFF"))] = i
		}
		// 第 2 行
		f, _ = os.Open(path)
		r = csv.NewReader(f)
		r.TrimLeadingSpace = true
		_, _ = r.Read()
		row, err := r.Read()
		f.Close()
		if err != nil || len(row) == 0 {
			continue
		}
		getNum := func(col string) float64 {
			i, ok := colIdx[col]
			if !ok || i >= len(row) {
				return 0
			}
			v, _ := strconv.ParseFloat(strings.TrimSpace(row[i]), 64)
			return v
		}
		getStr := func(col string) string {
			i, ok := colIdx[col]
			if !ok || i >= len(row) {
				return ""
			}
			return strings.TrimSpace(row[i])
		}
		satID := strings.TrimSuffix(name, "_ephem_ext.csv")
		utcStr := getStr("UTCG")
		tUTC, err := parseUTC(utcStr)
		if err != nil {
			tUTC = time.Now().UTC()
		}
		rows = append(rows, stateRow{
			satID:   satID,
			tUTC:    tUTC,
			rX:      getNum("r_x"),
			rY:      getNum("r_y"),
			rZ:      getNum("r_z"),
			llaLat:  getNum("lla_Lat"),
			llaLon:  getNum("lla_Lon"),
			llaAlt:  getNum("lla_Alt"),
			coeSMA:  getNum("coe_Semi-major_Axis"),
			coeEcc:  getNum("coe_Eccentricity"),
			coeInc:  getNum("coe_Inclination"),
			coeRaan: getNum("coe_RAAN"),
			coeArgp: getNum("coe_Arg_of_Perigee"),
			coeTA:   getNum("coe_True_Anomaly"),
		})
	}

	return db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Exec(`DELETE FROM public.satellite_states WHERE scenario_id = ?`, scenarioID).Error; err != nil {
			return fmt.Errorf("delete old states: %w", err)
		}
		for _, r := range rows {
			if err := tx.Exec(`
				INSERT INTO public.satellite_states (
					scenario_id, sat_id, t_utc, r_x, r_y, r_z,
					lla_lat, lla_lon, lla_alt,
					coe_sma_km, coe_ecc, coe_inc_deg, coe_raan_deg, coe_argp_deg, coe_ta_deg
				) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
				scenarioID, r.satID, r.tUTC, r.rX, r.rY, r.rZ,
				r.llaLat, r.llaLon, r.llaAlt,
				r.coeSMA, r.coeEcc, r.coeInc, r.coeRaan, r.coeArgp, r.coeTA,
			).Error; err != nil {
				return fmt.Errorf("insert state %s: %w", r.satID, err)
			}
		}
		return nil
	})
}

var routerCSVPattern = regexp.MustCompile(`^r(\d{3})(\d{3})_net_qos\.csv$`)

// ImportRouterFromCSV 扫描 dirPath 下 r??????_net_qos.csv，解析直连节点，写入 router_nodes 与 router_links。
// router_id 与 sat_id 约定：r001001 -> sat-1-1（orbit=1, slot=1）
func ImportRouterFromCSV(db *gorm.DB, scenarioName, dirPath string) error {
	if scenarioName == "" {
		return fmt.Errorf("scenarioName is empty")
	}
	if dirPath == "" {
		return fmt.Errorf("dirPath is empty")
	}

	var scenarioID int64
	if err := db.
		Raw(`SELECT id FROM public.scenarios WHERE name = ? LIMIT 1`, scenarioName).
		Scan(&scenarioID).Error; err != nil {
		return fmt.Errorf("query scenario id: %w", err)
	}
	if scenarioID == 0 {
		return fmt.Errorf("scenario %q not found", scenarioName)
	}

	entries, err := os.ReadDir(dirPath)
	if err != nil {
		return fmt.Errorf("read dir: %w", err)
	}

	type node struct {
		routerID string
		plane    int
		slot     int
		satID    string
	}
	nodesMap := make(map[string]node)
	var links []struct{ src, dst string }

	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		name := e.Name()
		m := routerCSVPattern.FindStringSubmatch(name)
		if m == nil {
			continue
		}
		plane, _ := strconv.Atoi(m[1])
		slot, _ := strconv.Atoi(m[2])
		routerID := "r" + m[1] + m[2]
		satID := fmt.Sprintf("sat-%d-%d", plane, slot)
		nodesMap[routerID] = node{routerID: routerID, plane: plane, slot: slot, satID: satID}

		path := filepath.Join(dirPath, name)
		f, err := os.Open(path)
		if err != nil {
			continue
		}
		r := csv.NewReader(f)
		r.TrimLeadingSpace = true
		recs, err := r.ReadAll()
		f.Close()
		if err != nil || len(recs) < 2 {
			continue
		}
		header := recs[0]
		colIdx := -1
		for i, h := range header {
			if strings.TrimSpace(h) == "直连节点" {
				colIdx = i
				break
			}
		}
		if colIdx < 0 {
			continue
		}
		for i := 1; i < len(recs); i++ {
			parts := recs[i]
			if colIdx >= len(parts) {
				continue
			}
			dst := strings.TrimSpace(parts[colIdx])
			if dst != "" && dst != routerID {
				links = append(links, struct{ src, dst string }{routerID, dst})
			}
		}
	}

	return db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Exec(`DELETE FROM public.router_links WHERE scenario_id = ?`, scenarioID).Error; err != nil {
			return fmt.Errorf("delete old router_links: %w", err)
		}
		if err := tx.Exec(`DELETE FROM public.router_nodes WHERE scenario_id = ?`, scenarioID).Error; err != nil {
			return fmt.Errorf("delete old router_nodes: %w", err)
		}
		for _, n := range nodesMap {
			if err := tx.Exec(`
				INSERT INTO public.router_nodes (scenario_id, router_id, sat_id, plane_index, sat_index_in_plane)
				VALUES (?, ?, ?, ?, ?)`,
				scenarioID, n.routerID, n.satID, n.plane, n.slot,
			).Error; err != nil {
				return fmt.Errorf("insert router_node %s: %w", n.routerID, err)
			}
		}
		for _, l := range links {
			if err := tx.Exec(`
				INSERT INTO public.router_links (scenario_id, src_router, dst_router) VALUES (?, ?, ?)`,
				scenarioID, l.src, l.dst,
			).Error; err != nil {
				return fmt.Errorf("insert link %s->%s: %w", l.src, l.dst, err)
			}
		}
		return nil
	})
}

// DefaultRouterCSVDir 返回 router CSV 默认目录（可用 SATELLITE_ROUTER_CSV_DIR 覆盖）。
func DefaultRouterCSVDir() string {
	if v := os.Getenv("SATELLITE_ROUTER_CSV_DIR"); v != "" {
		return v
	}
	return filepath.Join("..", "frontend", "public", "data", "router")
}

// RouterNodeCount 返回场景下 router_nodes 行数。
func RouterNodeCount(db *gorm.DB, scenarioName string) (int64, error) {
	var count int64
	err := db.Raw(`
		SELECT COUNT(*) FROM public.router_nodes rn
		INNER JOIN public.scenarios s ON s.id = rn.scenario_id
		WHERE s.name = ?`, scenarioName).Scan(&count).Error
	return count, err
}

// EnsureRouterImported 若 DB 无路由节点则从 CSV 导入；返回是否执行了导入。
func EnsureRouterImported(db *gorm.DB, scenarioName, dirPath string) (bool, error) {
	count, err := RouterNodeCount(db, scenarioName)
	if err != nil {
		return false, err
	}
	if count > 0 {
		return false, nil
	}
	if dirPath == "" {
		dirPath = DefaultRouterCSVDir()
	}
	if _, err := os.Stat(dirPath); err != nil {
		return false, fmt.Errorf("router csv dir: %w", err)
	}
	if err := ImportRouterFromCSV(db, scenarioName, dirPath); err != nil {
		return false, err
	}
	return true, nil
}

