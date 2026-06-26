package handlers

import (
	"encoding/csv"
	"errors"
	"fmt"
	"io"
	"math"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
	"gorm.io/gorm"

	"satellite-cloud/backend/internal/pilotcluster"
)

type TopologyHandler struct {
	db     *gorm.DB
	logger *zap.Logger
}

func NewTopologyHandler(db *gorm.DB, logger *zap.Logger) *TopologyHandler {
	return &TopologyHandler{
		db:     db,
		logger: logger,
	}
}

// TopoSatT0 对应 SatTopology.vue 中的 SatT0（去掉 mesh，仅保留渲染所需的物理量）。
type TopoSatT0 struct {
	ID              string     `json:"id"`
	Orbit           int        `json:"orbit"`
	Slot            int        `json:"slot"`
	HostNode        string     `json:"host_node,omitempty"`
	DisplayName     string     `json:"display_name,omitempty"`
	UTC             string     `json:"utc"`
	R               [3]float64 `json:"r"` // km
	LLALat          float64    `json:"lla_Lat"`
	LLALon          float64    `json:"lla_Lon"`
	LLAAlt          float64    `json:"lla_Alt"`
	COESemiMajor    float64    `json:"coe_SemiMajorAxis"`
	COEEccentricity float64    `json:"coe_Eccentricity"`
	COEInclination  float64    `json:"coe_Inclination"`
	COERAAN         float64    `json:"coe_RAAN"`
	COEArgPerigee   float64    `json:"coe_ArgPerigee"`
	COETrueAnomaly  float64    `json:"coe_TrueAnomaly"`
}

// DelayEdge 与前端 SatTopology.vue 中的 DelayEdge 一致。
type DelayEdge struct {
	AId    string  `json:"aId"`
	BId    string  `json:"bId"`
	DelayS float64 `json:"delayS"`
	DistKm float64 `json:"distKm"`
}

// TopologyT0Handler 返回 T0 卫星状态（优先从 DB 读取，无数据时回退到 CSV）。
//
// GET /api/topology/t0
func (h *TopologyHandler) TopologyT0Handler(c *gin.Context) {
	sats, err := loadT0FromDB(h.db)
	if err != nil {
		h.logger.Warn("Load T0 from DB failed, falling back to CSV", zap.Error(err))
		sats, err = loadT0FromCSVs()
	}
	if err != nil {
		h.logger.Error("Failed to load T0 topology", zap.Error(err))
		c.JSON(500, gin.H{"error": "Failed to load topology data"})
		return
	}
	if len(sats) == 0 {
		sats, err = loadT0FromCSVs()
		if err != nil {
			h.logger.Error("Failed to load T0 from CSV fallback", zap.Error(err))
			c.JSON(500, gin.H{"error": "Failed to load topology data"})
			return
		}
	}
	sats = applyPilotClusterT0(sats)
	if pilotcluster.Current().Enabled && !topoPilotHasPositions(sats) {
		if csvSats, csvErr := loadT0FromCSVs(); csvErr == nil && len(csvSats) > 0 {
			if remapped := applyPilotClusterT0(csvSats); topoPilotHasPositions(remapped) {
				sats = remapped
			}
		}
	}
	c.JSON(200, sats)
}

func topoPilotHasPositions(sats []TopoSatT0) bool {
	for _, s := range sats {
		if topoHasPosition(s) {
			return true
		}
	}
	return false
}

// TopologyPilotMapHandler 返回 Pilot 集群节点↔卫星映射（前端过滤与标签展示）。
//
// GET /api/topology/pilot-map
func (h *TopologyHandler) TopologyPilotMapHandler(c *gin.Context) {
	m := pilotcluster.Current()
	if !m.Enabled {
		c.JSON(200, gin.H{"enabled": false, "nodes": []any{}})
		return
	}
	c.JSON(200, gin.H{
		"enabled": true,
		"count":   len(m.Entries),
		"nodes":   m.Entries,
	})
}

// TopologyDelayHandler 返回 delay 矩阵对应的边集合。
//
// GET /api/topology/delay
func (h *TopologyHandler) TopologyDelayHandler(c *gin.Context) {
	edges, err := loadDelayEdgesFromDB(h.db)
	if err != nil {
		h.logger.Error("Failed to load delay matrix from DB", zap.Error(err))
		c.JSON(500, gin.H{"error": "Failed to load delay matrix"})
		return
	}
	c.JSON(200, applyPilotClusterDelay(edges))
}

type orbitSlotKey struct {
	orbit int
	slot  int
}

func topoHasPosition(s TopoSatT0) bool {
	return s.R[0] != 0 || s.R[1] != 0 || s.R[2] != 0
}

func buildEphemIndex(sats []TopoSatT0) (byID map[string]TopoSatT0, byOrbitSlot map[orbitSlotKey]TopoSatT0) {
	byID = make(map[string]TopoSatT0, len(sats)*2)
	byOrbitSlot = make(map[orbitSlotKey]TopoSatT0, len(sats))
	for _, s := range sats {
		byID[s.ID] = s
		if strings.HasPrefix(s.ID, "Sat_") {
			byID[s.ID] = s
		}
		if s.Orbit > 0 && s.Slot > 0 {
			byOrbitSlot[orbitSlotKey{s.Orbit, s.Slot}] = s
		}
	}
	return byID, byOrbitSlot
}

func lookupPilotEphem(pilot pilotcluster.Entry, byID map[string]TopoSatT0, byOrbitSlot map[orbitSlotKey]TopoSatT0) (TopoSatT0, bool) {
	if s, ok := byID[pilot.SatID]; ok && topoHasPosition(s) {
		return s, true
	}
	if s, ok := byID[pilot.SatName]; ok && topoHasPosition(s) {
		return s, true
	}
	ephemID := pilotcluster.EphemSTKName(pilot.Orbit, pilot.Slot)
	if s, ok := byID[ephemID]; ok {
		return s, true
	}
	ephO, ephS := pilotcluster.EphemOrbitSlot(pilot.Orbit, pilot.Slot)
	if s, ok := byOrbitSlot[orbitSlotKey{ephO, ephS}]; ok {
		return s, true
	}
	return TopoSatT0{}, false
}

func topoSatFromPilotEphem(src TopoSatT0, pilot pilotcluster.Entry) TopoSatT0 {
	return TopoSatT0{
		ID:              pilot.SatID,
		Orbit:           pilot.Orbit,
		Slot:            pilot.Slot,
		HostNode:        pilot.Node,
		DisplayName:     pilot.SatName,
		UTC:             src.UTC,
		R:               src.R,
		LLALat:          src.LLALat,
		LLALon:          src.LLALon,
		LLAAlt:          src.LLAAlt,
		COESemiMajor:    src.COESemiMajor,
		COEEccentricity: src.COEEccentricity,
		COEInclination:  src.COEInclination,
		COERAAN:         src.COERAAN,
		COEArgPerigee:   src.COEArgPerigee,
		COETrueAnomaly:  src.COETrueAnomaly,
	}
}

// applyPilotClusterT0 将 Pilot sat_id 与 STK 星历 Sat_6_6…Sat_8_10 对齐，避免 15 星叠在原点。
// 临时桥接；STK 更新后见 docs/archives/2026-06-11_phase5-ephem-id-bridge.md §6 回滚。
func applyPilotClusterT0(sats []TopoSatT0) []TopoSatT0 {
	m := pilotcluster.Current()
	if !m.Enabled {
		return sats
	}
	byID, byOrbitSlot := buildEphemIndex(sats)
	out := make([]TopoSatT0, 0, len(m.Entries))
	for _, e := range m.Entries {
		if src, ok := lookupPilotEphem(e, byID, byOrbitSlot); ok {
			out = append(out, topoSatFromPilotEphem(src, e))
			continue
		}
		out = append(out, TopoSatT0{
			ID:          e.SatID,
			Orbit:       e.Orbit,
			Slot:        e.Slot,
			HostNode:    e.Node,
			DisplayName: e.SatName,
		})
	}
	return out
}

func applyPilotClusterDelay(edges []DelayEdge) []DelayEdge {
	m := pilotcluster.Current()
	if !m.Enabled {
		return edges
	}
	ephemToPilot := make(map[string]string, len(m.Entries))
	for _, e := range m.Entries {
		ephemToPilot[pilotcluster.EphemSTKName(e.Orbit, e.Slot)] = e.SatID
	}
	out := make([]DelayEdge, 0, len(edges))
	for _, e := range edges {
		aID, bID := e.AId, e.BId
		if p, ok := ephemToPilot[e.AId]; ok {
			aID = p
		}
		if p, ok := ephemToPilot[e.BId]; ok {
			bID = p
		}
		if !m.ContainsSatID(aID) || !m.ContainsSatID(bID) {
			continue
		}
		out = append(out, DelayEdge{
			AId:    aID,
			BId:    bID,
			DelayS: e.DelayS,
			DistKm: e.DistKm,
		})
	}
	return out
}

// RouterGraphNode 与 RouterGraphEdge 用于 2D 拓扑图 API。
type RouterGraphNode struct {
	Name string `json:"name"`
}
type RouterGraphEdge struct {
	Source string `json:"source"`
	Target string `json:"target"`
	Label  string `json:"label,omitempty"`
}
type RouterGraphLayoutNode struct {
	X float64 `json:"x"`
	Y float64 `json:"y"`
}

// TopologyRouterHandler 返回以 center 为起点的 BFS 路由拓扑（节点展示名用 sat_id）。
//
// GET /api/topology/router?center=sat-1-1 或 center=r001001&scenario_name=Scenario5_full_36x22
func (h *TopologyHandler) TopologyRouterHandler(c *gin.Context) {
	center := strings.TrimSpace(c.Query("center"))
	if center == "" {
		c.JSON(400, gin.H{"error": "center is required (e.g. sat-1-1 or r001001)"})
		return
	}
	scenarioName := strings.TrimSpace(c.Query("scenario_name"))
	if scenarioName == "" {
		scenarioName = "Scenario5_full_36x22"
	}

	nodes, edges, layoutNodes, err := loadRouterGraphFromDB(h.db, scenarioName, center)
	if err != nil {
		h.logger.Error("Failed to load router graph from DB", zap.Error(err))
		c.JSON(500, gin.H{"error": "Failed to load router topology"})
		return
	}
	c.JSON(200, gin.H{
		"nodes":   nodes,
		"edges":   edges,
		"layouts": gin.H{"nodes": layoutNodes},
	})
}

// -------------------------------
// 内部加载逻辑（第一阶段：CSV）
// -------------------------------

// CSV 文件列表（需与前端旧实现保持一致）
var topoCSVFiles = []string{
	"Sat_6_6_ephem_ext.csv", "Sat_6_7_ephem_ext.csv", "Sat_6_8_ephem_ext.csv", "Sat_6_9_ephem_ext.csv", "Sat_6_10_ephem_ext.csv",
	"Sat_7_6_ephem_ext.csv", "Sat_7_7_ephem_ext.csv", "Sat_7_8_ephem_ext.csv", "Sat_7_9_ephem_ext.csv", "Sat_7_10_ephem_ext.csv",
	"Sat_8_6_ephem_ext.csv", "Sat_8_7_ephem_ext.csv", "Sat_8_8_ephem_ext.csv", "Sat_8_9_ephem_ext.csv", "Sat_8_10_ephem_ext.csv",
}

// topoDataBaseDir 返回拓扑 CSV 所在的基础目录。
// 目前仍使用 frontend/public/data/ephem_15 目录。
// 为便于本地与容器内运行，支持通过环境变量 SATELLITE_TOPOLOGY_DATA_DIR 覆盖。
func topoDataBaseDir() string {
	if v := os.Getenv("SATELLITE_TOPOLOGY_DATA_DIR"); v != "" {
		return v
	}
	// 默认：相对 backend 进程工作目录的路径
	// 本地开发时通常在仓库根目录运行，backend 当前工作目录为 backend/
	// 因此 "../frontend/public/data/ephem_15" 可找到 CSV。
	return filepath.Join("..", "frontend", "public", "data", "ephem_15")
}

func loadT0FromCSVs() ([]TopoSatT0, error) {
	baseDir := topoDataBaseDir()
	var result []TopoSatT0

	for _, name := range topoCSVFiles {
		path := filepath.Join(baseDir, name)
		f, err := os.Open(path)
		if err != nil {
			return nil, fmt.Errorf("open %s: %w", path, err)
		}
		defer f.Close()

		r := csv.NewReader(f)
		r.TrimLeadingSpace = true

		header, err := r.Read()
		if err != nil {
			return nil, fmt.Errorf("read header %s: %w", path, err)
		}
		colIdx := make(map[string]int, len(header))
		for i, h := range header {
			colIdx[normalizeHeader(h)] = i
		}

		// 读取第二行作为 T0
		row, err := r.Read()
		if err != nil {
			if errors.Is(err, io.EOF) {
				continue
			}
			return nil, fmt.Errorf("read first data row %s: %w", path, err)
		}

		orbit, slot := parseOrbitSlotFromFilename(name)
		id := trimEphemSuffix(name)

		getNum := func(col string) float64 {
			i, ok := colIdx[col]
			if !ok || i < 0 || i >= len(row) {
				return 0
			}
			v, _ := strconv.ParseFloat(row[i], 64)
			return v
		}
		getStr := func(col string) string {
			i, ok := colIdx[col]
			if !ok || i < 0 || i >= len(row) {
				return ""
			}
			return row[i]
		}

		rx := getNum("r_x")
		ry := getNum("r_y")
		rz := getNum("r_z")

		s := TopoSatT0{
			ID:    id,
			Orbit: orbit,
			Slot:  slot,
			UTC:   getStr("UTCG"),
			R:     [3]float64{rx, ry, rz},

			LLALat:          getNum("lla_Lat"),
			LLALon:          getNum("lla_Lon"),
			LLAAlt:          getNum("lla_Alt"),
			COESemiMajor:    getNum("coe_Semi-major_Axis"),
			COEEccentricity: getNum("coe_Eccentricity"),
			COEInclination:  getNum("coe_Inclination"),
			COERAAN:         getNum("coe_RAAN"),
			COEArgPerigee:   getNum("coe_Arg_of_Perigee"),
			COETrueAnomaly:  getNum("coe_True_Anomaly"),
		}
		result = append(result, s)
	}

	return result, nil
}

func normalizeHeader(h string) string {
	// 去掉 UTF-8 BOM 和前后空白
	return strings.TrimSpace(strings.TrimPrefix(h, "\uFEFF"))
}

func trimEphemSuffix(name string) string {
	const suffix = "_ephem_ext.csv"
	if strings.HasSuffix(name, suffix) {
		return strings.TrimSuffix(name, suffix)
	}
	return name
}

func parseOrbitSlotFromFilename(name string) (orbit int, slot int) {
	// 形如 Sat_6_6_ephem_ext.csv
	var o, s int
	_, err := fmt.Sscanf(name, "Sat_%d_%d_", &o, &s)
	if err != nil {
		return 0, 0
	}
	return o, s
}

func topoScenarioName() string {
	if v := os.Getenv("SATELLITE_TOPOLOGY_SCENARIO"); v != "" {
		return v
	}
	return "Scenario5_full_36x22"
}

// loadT0FromDB 从 satellite_states 读取 T0 状态，返回与 CSV 一致的 TopoSatT0 列表。
func loadT0FromDB(db *gorm.DB) ([]TopoSatT0, error) {
	scenarioName := topoScenarioName()
	var scenarioID int64
	if err := db.Raw(`SELECT id FROM public.scenarios WHERE name = ? LIMIT 1`, scenarioName).Scan(&scenarioID).Error; err != nil {
		return nil, fmt.Errorf("query scenario id: %w", err)
	}
	if scenarioID == 0 {
		return nil, nil
	}
	type row struct {
		SatID   string  `gorm:"column:sat_id"`
		TUTC    string  `gorm:"column:t_utc"`
		RX      float64 `gorm:"column:r_x"`
		RY      float64 `gorm:"column:r_y"`
		RZ      float64 `gorm:"column:r_z"`
		LLALat  float64 `gorm:"column:lla_lat"`
		LLALon  float64 `gorm:"column:lla_lon"`
		LLAAlt  float64 `gorm:"column:lla_alt"`
		COESMA  float64 `gorm:"column:coe_sma_km"`
		COEEcc  float64 `gorm:"column:coe_ecc"`
		COEInc  float64 `gorm:"column:coe_inc_deg"`
		COERaan float64 `gorm:"column:coe_raan_deg"`
		COEArgp float64 `gorm:"column:coe_argp_deg"`
		COETA   float64 `gorm:"column:coe_ta_deg"`
	}
	var rows []row
	if err := db.Raw(`SELECT sat_id, t_utc, r_x, r_y, r_z, lla_lat, lla_lon, lla_alt,
		coe_sma_km, coe_ecc, coe_inc_deg, coe_raan_deg, coe_argp_deg, coe_ta_deg
		FROM public.satellite_states WHERE scenario_id = ?`, scenarioID).Scan(&rows).Error; err != nil {
		return nil, fmt.Errorf("query satellite_states: %w", err)
	}
	out := make([]TopoSatT0, 0, len(rows))
	for _, r := range rows {
		orbit, slot := parseSatIDOrbitSlot(r.SatID)
		out = append(out, TopoSatT0{
			ID:              r.SatID,
			Orbit:           orbit,
			Slot:            slot,
			UTC:             r.TUTC,
			R:               [3]float64{r.RX, r.RY, r.RZ},
			LLALat:          r.LLALat,
			LLALon:          r.LLALon,
			LLAAlt:          r.LLAAlt,
			COESemiMajor:    r.COESMA,
			COEEccentricity: r.COEEcc,
			COEInclination:  r.COEInc,
			COERAAN:         r.COERaan,
			COEArgPerigee:   r.COEArgp,
			COETrueAnomaly:  r.COETA,
		})
	}
	return out, nil
}

// parseSatIDOrbitSlot 从 sat_id 如 "sat-1-1" 或 "Sat_6_6" 解析 orbit 与 slot。
func parseSatIDOrbitSlot(satID string) (orbit, slot int) {
	if _, err := fmt.Sscanf(satID, "sat-%d-%d", &orbit, &slot); err == nil && orbit > 0 {
		return orbit, slot
	}
	if _, err := fmt.Sscanf(satID, "Sat_%d_%d", &orbit, &slot); err == nil {
		return orbit, slot
	}
	return 0, 0
}

// 从 DB 中读取 delay 边（satellite_delay_edges），当前默认对场景 Scenario5_full_36x22 生效。
func loadDelayEdgesFromDB(db *gorm.DB) ([]DelayEdge, error) {
	scenarioName := topoScenarioName()

	var scenarioID int64
	if err := db.
		Raw(`SELECT id FROM public.scenarios WHERE name = ? LIMIT 1`, scenarioName).
		Scan(&scenarioID).Error; err != nil {
		return nil, fmt.Errorf("query scenario id: %w", err)
	}
	if scenarioID == 0 {
		// 没有找到对应场景时，返回空结果
		return []DelayEdge{}, nil
	}

	type row struct {
		AId    string  `gorm:"column:a_id"`
		BId    string  `gorm:"column:b_id"`
		DelayS float64 `gorm:"column:delay_s"`
		DistKm float64 `gorm:"column:dist_km"`
	}

	var rows []row
	if err := db.
		Raw(`SELECT a_id, b_id, delay_s, dist_km FROM public.satellite_delay_edges WHERE scenario_id = ?`, scenarioID).
		Scan(&rows).Error; err != nil {
		return nil, fmt.Errorf("query delay edges: %w", err)
	}

	edges := make([]DelayEdge, 0, len(rows))
	for _, r := range rows {
		edges = append(edges, DelayEdge{
			AId:    r.AId,
			BId:    r.BId,
			DelayS: r.DelayS,
			DistKm: r.DistKm,
		})
	}
	return edges, nil
}

// loadRouterGraphFromDB 从 router_nodes / router_links 做 BFS，返回 nodes/edges/layoutNodes（节点展示名用 sat_id）。
func loadRouterGraphFromDB(db *gorm.DB, scenarioName, center string) (
	nodes map[string]RouterGraphNode,
	edges map[string]RouterGraphEdge,
	layoutNodes map[string]RouterGraphLayoutNode,
	err error,
) {
	nodes = make(map[string]RouterGraphNode)
	edges = make(map[string]RouterGraphEdge)
	layoutNodes = make(map[string]RouterGraphLayoutNode)

	var scenarioID int64
	if err := db.Raw(`SELECT id FROM public.scenarios WHERE name = ? LIMIT 1`, scenarioName).Scan(&scenarioID).Error; err != nil {
		return nil, nil, nil, fmt.Errorf("query scenario: %w", err)
	}
	if scenarioID == 0 {
		return nodes, edges, layoutNodes, nil
	}

	type routerNodeRow struct {
		RouterID string `gorm:"column:router_id"`
		SatID    string `gorm:"column:sat_id"`
	}
	type routerLinkRow struct {
		Src string `gorm:"column:src_router"`
		Dst string `gorm:"column:dst_router"`
	}
	var nodeRows []routerNodeRow
	if err := db.Raw(`SELECT router_id, sat_id FROM public.router_nodes WHERE scenario_id = ?`, scenarioID).Scan(&nodeRows).Error; err != nil {
		return nil, nil, nil, fmt.Errorf("query router_nodes: %w", err)
	}
	routerToSat := make(map[string]string)
	for _, r := range nodeRows {
		routerToSat[r.RouterID] = r.SatID
	}

	var linkRows []routerLinkRow
	if err := db.Raw(`SELECT src_router, dst_router FROM public.router_links WHERE scenario_id = ?`, scenarioID).Scan(&linkRows).Error; err != nil {
		return nil, nil, nil, fmt.Errorf("query router_links: %w", err)
	}
	adj := make(map[string][]string)
	for _, l := range linkRows {
		adj[l.Src] = append(adj[l.Src], l.Dst)
	}

	centerRouter := center
	if strings.HasPrefix(center, "sat-") {
		for rid, sid := range routerToSat {
			if sid == center {
				centerRouter = rid
				break
			}
		}
		if centerRouter == center {
			return nodes, edges, layoutNodes, nil
		}
	}

	// BFS, max 16 hops
	reachable := make(map[string]struct{})
	queue := []struct{ r string; hops int }{{centerRouter, 0}}
	reachable[centerRouter] = struct{}{}
	for len(queue) > 0 {
		cur := queue[0]
		queue = queue[1:]
		if cur.hops >= 16 {
			continue
		}
		for _, next := range adj[cur.r] {
			if _, ok := reachable[next]; ok {
				continue
			}
			reachable[next] = struct{}{}
			queue = append(queue, struct{ r string; hops int }{next, cur.hops + 1})
		}
	}

	for r := range reachable {
		satID := routerToSat[r]
		if satID == "" {
			satID = r
		}
		display := pilotcluster.Current().SatName(satID)
		nodes[r] = RouterGraphNode{Name: display}
	}

	added := make(map[string]struct{})
	eid := 1
	for src := range reachable {
		for _, tgt := range adj[src] {
			if _, ok := reachable[tgt]; !ok {
				continue
			}
			key := src + "-" + tgt
			if src > tgt {
				key = tgt + "-" + src
			}
			if _, ok := added[key]; ok {
				continue
			}
			added[key] = struct{}{}
			edges["edge"+strconv.Itoa(eid)] = RouterGraphEdge{Source: src, Target: tgt, Label: "Link"}
			eid++
		}
	}

	orbitGroups := map[string][]string{"001": nil, "002": nil, "003": nil}
	for r := range reachable {
		if len(r) >= 4 {
			o := r[1:4]
			if orbitGroups[o] != nil {
				orbitGroups[o] = append(orbitGroups[o], r)
			}
		}
	}
	cx, cy := 0.0, 0.0
	cfg := map[string]struct{ r float64; off float64 }{
		"001": {250, 0},
		"002": {180, 3.141592653589793 / 6},
		"003": {110, 3.141592653589793 / 3},
	}
	for o, arr := range orbitGroups {
		if len(arr) == 0 {
			continue
		}
		step := 2 * math.Pi / float64(len(arr))
		c := cfg[o]
		for i, r := range arr {
			a := float64(i)*step + c.off
			layoutNodes[r] = RouterGraphLayoutNode{
				X: cx + c.r*math.Cos(a),
				Y: cy + c.r*math.Sin(a),
			}
		}
	}
	return nodes, edges, layoutNodes, nil
}

