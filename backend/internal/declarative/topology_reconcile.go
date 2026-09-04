package declarative

import (
	"fmt"

	"gorm.io/gorm"

	"satellite-cloud/backend/internal/topology"
)

// SyncTopologyDataSources 把拓扑数据源同步到数据库（幂等 delete+insert）。
// 供两类入口共用：
//   - ReconcileConstellation（spec.topology 一体化声明，向后兼容）；
//   - ReconcileTopology（独立 NetworkTopology 清单）。
//
// 返回实际执行的拓扑数据源列表（delay / t0 / router 中已声明的子集）。
func SyncTopologyDataSources(db *gorm.DB, scenarioName string, spec TopologySpec) ([]string, error) {
	var synced []string
	if spec.DelayMatrixCSV != "" {
		if err := topology.ImportDelayFromCSV(db, scenarioName, spec.DelayMatrixCSV); err != nil {
			return nil, fmt.Errorf("sync delay matrix: %w", err)
		}
		synced = append(synced, "delay")
	}
	if spec.T0CsvDir != "" {
		if err := topology.ImportSatStatesFromCSV(db, scenarioName, spec.T0CsvDir); err != nil {
			return nil, fmt.Errorf("sync t0 states: %w", err)
		}
		synced = append(synced, "t0")
	}
	if spec.RouterCsvDir != "" {
		if err := topology.ImportRouterFromCSV(db, scenarioName, spec.RouterCsvDir); err != nil {
			return nil, fmt.Errorf("sync router topology: %w", err)
		}
		synced = append(synced, "router")
	}
	return synced, nil
}

// TopologyResult 汇报一次独立拓扑清单（NetworkTopology）的同步结果。
type TopologyResult struct {
	CRName      string
	ScenarioID  uint
	Scenario    string
	Synced      []string // 实际执行的拓扑数据源：delay/t0/router
	DelayEdges  int64    // 同步后 satellite_delay_edges 行数
	T0States    int64    // 同步后 satellite_states 行数
	RouterNodes int64    // 同步后 router_nodes 行数
	RouterLinks int64    // 同步后 router_links 行数
}

// ReconcileTopology 把一份 NetworkTopology 清单同步到 PostgreSQL（幂等）。
//
// 语义：
//  1. 按 spec.scenarioName 解析所属场景（必须已存在，不自动建场景）；
//  2. 对 spec.dataSources 声明的数据源逐项调用 topology.Import*
//     （内部 delete+insert，多次执行结果一致）。
//
// 可作为未来 K8s Controller 对 NetworkTopology CR 的 Reconcile 核心逻辑。
func ReconcileTopology(db *gorm.DB, cr *NetworkTopology) (*TopologyResult, error) {
	if cr == nil {
		return nil, fmt.Errorf("nil manifest")
	}
	name := cr.Spec.ScenarioName
	var scenarioID uint
	if err := db.Raw(`SELECT id FROM public.scenarios WHERE name = ? LIMIT 1`, name).Scan(&scenarioID).Error; err != nil {
		return nil, fmt.Errorf("query scenario %q: %w", name, err)
	}
	if scenarioID == 0 {
		return nil, fmt.Errorf("scenario %q not found (先同步 SatelliteConstellation 清单创建场景)", name)
	}

	synced, err := SyncTopologyDataSources(db, name, cr.Spec.DataSources)
	if err != nil {
		return nil, err
	}
	res := &TopologyResult{
		CRName:     cr.Metadata.Name,
		ScenarioID: scenarioID,
		Scenario:   name,
		Synced:     synced,
	}
	for _, s := range synced {
		switch s {
		case "delay":
			res.DelayEdges, _ = countRows(db, "public.satellite_delay_edges", scenarioID)
		case "t0":
			res.T0States, _ = countRows(db, "public.satellite_states", scenarioID)
		case "router":
			res.RouterNodes, _ = countRows(db, "public.router_nodes", scenarioID)
			res.RouterLinks, _ = countRows(db, "public.router_links", scenarioID)
		}
	}
	return res, nil
}

// countRows 统计某拓扑表在场景下的行数（表名为常量，非用户输入）。
func countRows(db *gorm.DB, table string, scenarioID uint) (int64, error) {
	var count int64
	err := db.Raw(fmt.Sprintf(`SELECT COUNT(*) FROM %s WHERE scenario_id = ?`, table), scenarioID).Scan(&count).Error
	return count, err
}
