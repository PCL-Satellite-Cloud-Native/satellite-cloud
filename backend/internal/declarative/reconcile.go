package declarative

import (
	"errors"
	"fmt"

	"gorm.io/datatypes"
	"gorm.io/gorm"

	"satellite-cloud/backend/internal/model"
)

// ReconcileOptions 控制同步行为。
type ReconcileOptions struct {
	// PruneSatellites 为 true 时，删除 DB 中该场景下但清单未声明的卫星（软删除）。
	// 默认 false：只做 upsert，保护 remote_sensing_tasks 对 satellite_id 的引用。
	PruneSatellites bool
	// SkipTopology 为 true 时跳过 spec.topology 声明的数据源导入。
	SkipTopology bool
}

// ReconcileResult 汇报单次同步结果。
type ReconcileResult struct {
	CRName            string
	ScenarioID        uint
	Scenario          string
	SatellitesDesired int
	SatellitesCreated int
	SatellitesUpdated int
	SatellitesPruned  int
	TopologySynced    []string // 实际执行的拓扑数据源：delay/t0/router
}

// ReconcileConstellation 把一份 SatelliteConstellation 清单同步到 PostgreSQL（幂等）。
//
// 语义：
//  1. scenarios 按 name upsert（清单字段为空时不覆盖已有值）；
//  2. satellites 全量对齐期望状态（批量 upsert，可选 prune）；
//  3. spec.topology 声明的数据源调用 topology.Import*（内部 delete+insert，幂等）。
//
// 多次执行结果一致，可作为 K8s Controller Reconcile 的核心逻辑。
func ReconcileConstellation(db *gorm.DB, cr *SatelliteConstellation, opts ReconcileOptions) (*ReconcileResult, error) {
	if cr == nil {
		return nil, fmt.Errorf("nil manifest")
	}
	res := &ReconcileResult{CRName: cr.Metadata.Name, Scenario: cr.Spec.Scenario.Name}

	// 1. 期望卫星集合
	desired, err := DesiredSatellites(cr.Spec)
	if err != nil {
		return nil, fmt.Errorf("desired satellites: %w", err)
	}
	res.SatellitesDesired = len(desired)

	// 2. scenario upsert + 卫星对齐（同一事务）
	err = db.Transaction(func(tx *gorm.DB) error {
		scenarioID, err := upsertScenario(tx, cr.Spec.Scenario)
		if err != nil {
			return err
		}
		res.ScenarioID = scenarioID

		created, updated, pruned, err := syncSatellites(tx, scenarioID, desired, opts.PruneSatellites)
		if err != nil {
			return err
		}
		res.SatellitesCreated, res.SatellitesUpdated, res.SatellitesPruned = created, updated, pruned
		return nil
	})
	if err != nil {
		return nil, fmt.Errorf("reconcile scenario/satellites: %w", err)
	}

	// 3. 拓扑数据源（复用共享函数：SyncTopologyDataSources，内部各自带事务，幂等）
	if !opts.SkipTopology && cr.Spec.Topology != nil {
		synced, err := SyncTopologyDataSources(db, cr.Spec.Scenario.Name, *cr.Spec.Topology)
		if err != nil {
			return nil, err
		}
		res.TopologySynced = synced
	}

	return res, nil
}

// upsertScenario 按 name 幂等写入 scenarios 行，返回 scenario id。
// 清单中为空/零值的字段不覆盖数据库已有值（声明式"未声明则不管理"）。
func upsertScenario(tx *gorm.DB, sc ScenarioSpec) (uint, error) {
	var existing model.Scenario
	err := tx.Where("name = ?", sc.Name).First(&existing).Error
	if err == nil {
		updates := map[string]interface{}{}
		if sc.Epoch != "" {
			updates["epoch"] = sc.Epoch
		}
		if sc.StartTime != "" {
			updates["start_time"] = sc.StartTime
		}
		if sc.EndTime != "" {
			updates["end_time"] = sc.EndTime
		}
		if sc.AltKm > 0 {
			updates["alt_km"] = sc.AltKm
		}
		if sc.IncDeg > 0 {
			updates["inc_deg"] = sc.IncDeg
		}
		if sc.NPlanes > 0 {
			updates["n_planes"] = sc.NPlanes
		}
		if sc.NSatsPerPlane > 0 {
			updates["n_sats_per_plane"] = sc.NSatsPerPlane
		}
		if len(sc.SensorConfig) > 0 {
			updates["sensor_config"] = datatypes.JSONMap(sc.SensorConfig)
		}
		if len(updates) > 0 {
			if err := tx.Model(&existing).Updates(updates).Error; err != nil {
				return 0, fmt.Errorf("update scenario %q: %w", sc.Name, err)
			}
		}
		return existing.ID, nil
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return 0, fmt.Errorf("query scenario %q: %w", sc.Name, err)
	}

	scenario := model.Scenario{
		Name:          sc.Name,
		Epoch:         sc.Epoch,
		StartTime:     sc.StartTime,
		EndTime:       sc.EndTime,
		AltKm:         sc.AltKm,
		IncDeg:        sc.IncDeg,
		NPlanes:       sc.NPlanes,
		NSatsPerPlane: sc.NSatsPerPlane,
		SensorConfig:  datatypes.JSONMap(sc.SensorConfig),
	}
	if err := tx.Create(&scenario).Error; err != nil {
		return 0, fmt.Errorf("create scenario %q: %w", sc.Name, err)
	}
	return scenario.ID, nil
}

// syncSatellites 把期望卫星集合对齐到场景下（批量 upsert + 可选 prune）。
func syncSatellites(tx *gorm.DB, scenarioID uint, desired []model.Satellite, prune bool) (created, updated, pruned int, err error) {
	var existing []model.Satellite
	if err = tx.Where("scenario_id = ?", scenarioID).Find(&existing).Error; err != nil {
		return 0, 0, 0, fmt.Errorf("query existing satellites: %w", err)
	}
	existingByID := make(map[string]model.Satellite, len(existing))
	for _, s := range existing {
		existingByID[s.SatID] = s
	}

	var toCreate []model.Satellite
	var toUpdate []model.Satellite
	desiredSet := make(map[string]bool, len(desired))
	for _, sat := range desired {
		desiredSet[sat.SatID] = true
		sat.ScenarioID = scenarioID
		if old, ok := existingByID[sat.SatID]; ok {
			sat.ID = old.ID
			toUpdate = append(toUpdate, sat)
		} else {
			toCreate = append(toCreate, sat)
		}
	}

	if len(toCreate) > 0 {
		if err = tx.Create(&toCreate).Error; err != nil {
			return 0, 0, 0, fmt.Errorf("batch create satellites: %w", err)
		}
		created = len(toCreate)
	}
	for i := range toUpdate {
		if err = tx.Save(&toUpdate[i]).Error; err != nil {
			return 0, 0, 0, fmt.Errorf("update satellite %s: %w", toUpdate[i].SatID, err)
		}
		updated++
	}

	if prune {
		for _, s := range existing {
			if !desiredSet[s.SatID] {
				if err = tx.Delete(&model.Satellite{}, s.ID).Error; err != nil {
					return 0, 0, 0, fmt.Errorf("prune satellite %s: %w", s.SatID, err)
				}
				pruned++
			}
		}
	}
	return created, updated, pruned, nil
}
