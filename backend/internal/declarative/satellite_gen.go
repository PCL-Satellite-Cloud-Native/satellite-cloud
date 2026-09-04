package declarative

import (
	"fmt"
	"math"

	"satellite-cloud/backend/internal/model"
)

// 地球赤道半径（km），与 migration seed 000003 的 sma = 6378.137 + alt 约定一致。
const earthRadiusKm = 6378.137

// GenerateConstellation 根据场景构型参数确定性生成 Walker 星座卫星列表。
//
// 生成规律与 backend/migrations/000003_seed_starlink_36x22.up.sql 完全一致：
//   - sat_id:   sat-{plane}-{slot}，如 sat-1-1、sat-36-22
//   - stk_name: Sat_{plane}_{slot}
//   - sma_km:   6378.137 + alt_km（近圆轨道）
//   - ecc: 0, inc: spec.incDeg, argp: 0
//   - raan:     (plane-1) * 360/nPlanes
//   - ta:       (slot-1) * 360/nSatsPerPlane，偶数面额外偏移半颗（Walker 相位因子）
//   - 浮点统一保留 6 位小数，与 seed 的数值精度一致
//
// 同一输入恒产出同一输出（确定性），适合作为"期望状态"反复 reconcile。
func GenerateConstellation(sc ScenarioSpec) ([]model.Satellite, error) {
	nPlanes := sc.NPlanes
	nSlots := sc.NSatsPerPlane
	if nPlanes <= 0 || nSlots <= 0 {
		return nil, fmt.Errorf("invalid constellation: nPlanes=%d nSatsPerPlane=%d", nPlanes, nSlots)
	}
	alt := sc.AltKm
	if alt <= 0 {
		return nil, fmt.Errorf("invalid altKm=%v", alt)
	}

	sats := make([]model.Satellite, 0, nPlanes*nSlots)
	for p := 1; p <= nPlanes; p++ {
		for s := 1; s <= nSlots; s++ {
			raan, ta := WalkerSlot(p, s, nPlanes, nSlots)
			sats = append(sats, model.Satellite{
				SatID:           fmt.Sprintf("sat-%d-%d", p, s),
				StkName:         fmt.Sprintf("Sat_%d_%d", p, s),
				PlaneIndex:      p,
				SatIndexInPlane: s,
				AltKm:           round6(alt),
				SmaKm:           round6(earthRadiusKm + alt),
				Ecc:             0,
				IncDeg:          round6(sc.IncDeg),
				RaanDeg:         raan,
				ArgpDeg:         0,
				TaDeg:           ta,
			})
		}
	}
	return sats, nil
}

// WalkerSlot 计算 Walker 星座某槽位 (plane, slot) 的 RAAN 与 TA。
// 与 GenerateConstellation 同一规律：单星清单（kind: Satellite）未显式声明
// 轨道根数时也复用此函数推导默认值，保证生成结果与整星座完全一致。
func WalkerSlot(plane, slot, nPlanes, nSlots int) (raan, ta float64) {
	if plane <= 0 || slot <= 0 || nPlanes <= 0 || nSlots <= 0 {
		return 0, 0
	}
	raan = round6((float64(plane) - 1) * 360.0 / float64(nPlanes))
	offset := 0.0
	if plane%2 == 0 {
		offset = 360.0 / float64(nSlots) / 2 // 偶面半颗偏移
	}
	ta = round6(mod360((float64(slot)-1)*360.0/float64(nSlots) + offset))
	return raan, ta
}

// InlineSatellites 把 inline 模式的显式卫星声明转换为模型，未提供的轨道参数从场景构型取默认值。
func InlineSatellites(sc ScenarioSpec, list []SatelliteSpec) ([]model.Satellite, error) {
	sats := make([]model.Satellite, 0, len(list))
	for _, spec := range list {
		if spec.SatID == "" {
			return nil, fmt.Errorf("inline satellite missing satId")
		}
		stk := spec.StkName
		if stk == "" {
			stk = "Sat_" + spec.SatID
		}
		sma := spec.SmaKm
		alt := spec.AltKm
		if sma <= 0 && alt > 0 {
			sma = round6(earthRadiusKm + alt)
		}
		if sma <= 0 {
			sma = round6(earthRadiusKm + sc.AltKm)
		}
		inc := spec.IncDeg
		if inc == 0 {
			inc = sc.IncDeg
		}
		sats = append(sats, model.Satellite{
			SatID:           spec.SatID,
			StkName:         stk,
			PlaneIndex:      spec.PlaneIndex,
			SatIndexInPlane: spec.SatInPlane,
			AltKm:           round6(alt),
			SmaKm:           sma,
			Ecc:             spec.Ecc,
			IncDeg:          round6(inc),
			RaanDeg:         round6(spec.RaanDeg),
			ArgpDeg:         round6(spec.ArgpDeg),
			TaDeg:           round6(spec.TaDeg),
		})
	}
	return sats, nil
}

// DesiredSatellites 根据 spec.satellites.mode 生成期望的卫星集合。
func DesiredSatellites(spec SatelliteConstellationSpec) ([]model.Satellite, error) {
	switch spec.Satellites.Mode {
	case ModeGenerated:
		return GenerateConstellation(spec.Scenario)
	case ModeInline:
		if len(spec.Satellites.List) == 0 {
			return nil, fmt.Errorf("inline mode requires non-empty satellites.list")
		}
		return InlineSatellites(spec.Scenario, spec.Satellites.List)
	default:
		return nil, fmt.Errorf("unsupported satellites.mode %q", spec.Satellites.Mode)
	}
}

// round6 保留 6 位小数，与 migration seed 的数值精度一致。
func round6(v float64) float64 {
	return math.Round(v*1e6) / 1e6
}

func mod360(v float64) float64 {
	v = math.Mod(v, 360)
	if v < 0 {
		v += 360
	}
	return v
}
