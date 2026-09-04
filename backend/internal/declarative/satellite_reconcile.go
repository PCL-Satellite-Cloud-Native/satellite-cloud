package declarative

// 单颗卫星的声明式同步（星座管理 CRD 化的核心）。
//
// Satellite CR（kind: Satellite）提供整星座之外的细粒度管理：
//   - 新增/覆盖单颗卫星（upsert，幂等）；
//   - 删除单颗卫星（delete 注解，删除前检查 remote_sensing_tasks 引用）；
//   - 未显式声明的轨道根数：创建时按所属场景构型的 Walker 规律推导
//     （与 GenerateConstellation 完全一致），更新时保留数据库现值。
//
// 删除语义：清单不存在不删除（保护任务引用），只有显式带删除注解才删除。

import (
	"errors"
	"fmt"

	"gorm.io/gorm"

	"satellite-cloud/backend/internal/model"
)

// SatelliteReconcileResult 汇报单颗卫星同步结果。
type SatelliteReconcileResult struct {
	CRName       string
	ScenarioName string
	ScenarioID   uint
	SatID        string
	// Action 取值：created / updated / deleted / notfound / refused。
	Action string
	// Referenced 为 true 表示删除被 remote_sensing_tasks 引用拒绝。
	Referenced bool
}

// ReconcileSatellite 把一份 Satellite CR 同步到 PostgreSQL（幂等）。
//
// 语义：
//  1. 带删除注解（cloud.satellite.io/delete=true）→ 软删除，删除前检查任务引用；
//  2. 按 scenarioName 解析场景（不存在则报错，提示先 apply SatelliteConstellation）；
//  3. 确定 sat_id：spec.satId 优先，否则由 (plane, satInPlane) 推导 sat-{p}-{s}；
//  4. 该场景下无同名卫星 → 创建：未声明字段按场景构型 Walker 规律推导；
//  5. 已有同名卫星 → 更新：显式声明字段覆盖，未声明字段保留现值。
func ReconcileSatellite(db *gorm.DB, cr *Satellite, _ ReconcileOptions) (*SatelliteReconcileResult, error) {
	if cr == nil {
		return nil, fmt.Errorf("nil manifest")
	}
	res := &SatelliteReconcileResult{CRName: cr.Metadata.Name, ScenarioName: cr.Spec.ScenarioName}

	// 1. 删除注解分支
	if DeleteRequested(cr) {
		return deleteSatellite(db, cr)
	}

	// 2. 解析所属场景
	var sc model.Scenario
	if err := db.Where("name = ?", cr.Spec.ScenarioName).First(&sc).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, fmt.Errorf("scenario %q not found: apply SatelliteConstellation first", cr.Spec.ScenarioName)
		}
		return nil, fmt.Errorf("query scenario %q: %w", cr.Spec.ScenarioName, err)
	}
	res.ScenarioID = sc.ID

	// 3. 确定 sat_id
	satID := cr.Spec.SatID
	if satID == "" {
		satID = fmt.Sprintf("sat-%d-%d", *cr.Spec.PlaneIndex, *cr.Spec.SatInPlane)
	}
	res.SatID = satID

	// 4. 查该场景下同名卫星
	var existing *model.Satellite
	var cur model.Satellite
	err := db.Where("scenario_id = ? AND sat_id = ?", sc.ID, satID).First(&cur).Error
	switch {
	case err == nil:
		existing = &cur
	case errors.Is(err, gorm.ErrRecordNotFound):
		// 新建
	default:
		return nil, fmt.Errorf("query satellite %s: %w", satID, err)
	}

	desired, err := buildSatelliteModel(sc, cr.Spec, existing)
	if err != nil {
		return nil, err
	}
	desired.ScenarioID = sc.ID
	if existing != nil {
		desired.ID = existing.ID
		if err := db.Save(&desired).Error; err != nil {
			return nil, fmt.Errorf("update satellite %s: %w", satID, err)
		}
		res.Action = "updated"
		return res, nil
	}
	if err := db.Create(&desired).Error; err != nil {
		return nil, fmt.Errorf("create satellite %s: %w", satID, err)
	}
	res.Action = "created"
	return res, nil
}

// deleteSatellite 软删除单颗卫星。删除前检查 remote_sensing_tasks 引用，
// 有引用则拒绝（返回 Action=refused，不报错，便于日志与幂等重试）。
func deleteSatellite(db *gorm.DB, cr *Satellite) (*SatelliteReconcileResult, error) {
	res := &SatelliteReconcileResult{CRName: cr.Metadata.Name, ScenarioName: cr.Spec.ScenarioName}

	var sc model.Scenario
	if err := db.Where("name = ?", cr.Spec.ScenarioName).First(&sc).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, fmt.Errorf("scenario %q not found: apply SatelliteConstellation first", cr.Spec.ScenarioName)
		}
		return nil, fmt.Errorf("query scenario %q: %w", cr.Spec.ScenarioName, err)
	}
	res.ScenarioID = sc.ID

	satID := cr.Spec.SatID
	if satID == "" {
		satID = fmt.Sprintf("sat-%d-%d", *cr.Spec.PlaneIndex, *cr.Spec.SatInPlane)
	}
	res.SatID = satID

	var sat model.Satellite
	if err := db.Where("scenario_id = ? AND sat_id = ?", sc.ID, satID).First(&sat).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			res.Action = "notfound" // 幂等：目标已不存在视为完成
			return res, nil
		}
		return nil, fmt.Errorf("query satellite %s: %w", satID, err)
	}

	var ref int64
	if err := db.Model(&model.RemoteSensingTask{}).Where("satellite_id = ?", sat.ID).Count(&ref).Error; err != nil {
		return nil, fmt.Errorf("check task references for %s: %w", satID, err)
	}
	if ref > 0 {
		res.Action = "refused"
		res.Referenced = true
		return res, nil
	}

	if err := db.Delete(&sat).Error; err != nil {
		return nil, fmt.Errorf("delete satellite %s: %w", satID, err)
	}
	res.Action = "deleted"
	return res, nil
}

// buildSatelliteModel 由清单 spec + 场景构型 + 现有行（可能为 nil）合并出期望卫星。
//
// 字段优先级：清单显式声明 > 数据库现值（更新时）> 场景构型推导（创建时）。
func buildSatelliteModel(sc model.Scenario, spec SatelliteCRSpec, existing *model.Satellite) (model.Satellite, error) {
	satID := spec.SatID
	if satID == "" {
		satID = fmt.Sprintf("sat-%d-%d", *spec.PlaneIndex, *spec.SatInPlane)
	}

	m := model.Satellite{SatID: satID}

	// stk_name
	m.StkName = spec.StkName
	if m.StkName == "" {
		if existing != nil && existing.StkName != "" {
			m.StkName = existing.StkName
		} else {
			m.StkName = "Sat_" + satID
		}
	}

	// plane / satInPlane
	if spec.PlaneIndex != nil {
		m.PlaneIndex = *spec.PlaneIndex
	} else if existing != nil {
		m.PlaneIndex = existing.PlaneIndex
	}
	if spec.SatInPlane != nil {
		m.SatIndexInPlane = *spec.SatInPlane
	} else if existing != nil {
		m.SatIndexInPlane = existing.SatIndexInPlane
	}

	// 场景构型推导默认值（Walker 规律）
	plane, slot := satIDToSlot(satID)
	var dRaan, dTa float64
	if plane > 0 && slot > 0 && sc.NPlanes > 0 && sc.NSatsPerPlane > 0 &&
		plane <= sc.NPlanes && slot <= sc.NSatsPerPlane {
		dRaan, dTa = WalkerSlot(plane, slot, sc.NPlanes, sc.NSatsPerPlane)
	}
	dSma := round6(earthRadiusKm + sc.AltKm)
	dAlt := round6(sc.AltKm)
	dInc := round6(sc.IncDeg)

	// sma / alt（两者联动：只给一个时另一个按 6378.137 换算）
	switch {
	case spec.AltKm != nil && spec.SmaKm != nil:
		m.AltKm = round6(*spec.AltKm)
		m.SmaKm = round6(*spec.SmaKm)
	case spec.AltKm != nil:
		m.AltKm = round6(*spec.AltKm)
		m.SmaKm = round6(earthRadiusKm + *spec.AltKm)
	case spec.SmaKm != nil:
		m.SmaKm = round6(*spec.SmaKm)
		m.AltKm = round6(*spec.SmaKm - earthRadiusKm)
	default:
		if existing != nil && existing.SmaKm > 0 {
			m.AltKm = existing.AltKm
			m.SmaKm = existing.SmaKm
		} else {
			m.AltKm = dAlt
			m.SmaKm = dSma
		}
	}

	// ecc
	if spec.Ecc != nil {
		m.Ecc = round6(*spec.Ecc)
	} else if existing != nil {
		m.Ecc = existing.Ecc
	}

	// inc
	if spec.IncDeg != nil {
		m.IncDeg = round6(*spec.IncDeg)
	} else if existing != nil && existing.IncDeg != 0 {
		m.IncDeg = existing.IncDeg
	} else {
		m.IncDeg = dInc
	}

	// raan
	if spec.RaanDeg != nil {
		m.RaanDeg = round6(*spec.RaanDeg)
	} else if existing != nil {
		m.RaanDeg = existing.RaanDeg
	} else {
		m.RaanDeg = dRaan
	}

	// argp
	if spec.ArgpDeg != nil {
		m.ArgpDeg = round6(*spec.ArgpDeg)
	} else if existing != nil {
		m.ArgpDeg = existing.ArgpDeg
	}

	// ta
	if spec.TaDeg != nil {
		m.TaDeg = round6(*spec.TaDeg)
	} else if existing != nil {
		m.TaDeg = existing.TaDeg
	} else {
		m.TaDeg = dTa
	}

	return m, nil
}

// satIDToSlot 从 sat-{plane}-{slot} 解析星座定位；格式不符返回 (0,0)。
func satIDToSlot(satID string) (plane, slot int) {
	var p, s int
	if _, err := fmt.Sscanf(satID, "sat-%d-%d", &p, &s); err != nil {
		return 0, 0
	}
	return p, s
}
