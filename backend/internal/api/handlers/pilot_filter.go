package handlers

import (
	"satellite-cloud/backend/internal/model"
	"satellite-cloud/backend/internal/pilotcluster"
)

// filterPilotSatellites 在 Pilot 模式下每颗业务卫星只返回一条记录（优先 sat-{p}-{s}，避免与 legacy 星历名重复）。
func filterPilotSatellites(sats []model.Satellite) []model.Satellite {
	m := pilotcluster.Current()
	if !m.Enabled {
		return sats
	}

	bySatID := make(map[string]model.Satellite, len(sats))
	byStk := make(map[string]model.Satellite, len(sats))
	for _, s := range sats {
		bySatID[s.SatID] = s
		if s.StkName != "" {
			byStk[s.StkName] = s
		}
	}

	out := make([]model.Satellite, 0, len(m.Entries))
	for _, e := range m.Entries {
		if s, ok := bySatID[e.SatID]; ok {
			out = append(out, s)
			continue
		}
		if s, ok := bySatID[e.SatName]; ok {
			out = append(out, s)
			continue
		}
		if s, ok := byStk[e.SatName]; ok {
			out = append(out, s)
			continue
		}
		ephem := pilotcluster.EphemSTKName(e.Orbit, e.Slot)
		if s, ok := byStk[ephem]; ok {
			out = append(out, s)
			continue
		}
		if s, ok := bySatID[ephem]; ok {
			out = append(out, s)
		}
	}

	if len(out) == 0 {
		return sats
	}
	return out
}

// satelliteMatchesPilot 匹配 Pilot sat_id，或 legacy 星历名 / STK 显示名（见 ephem 桥接归档）。
// 供 List 等宽表过滤使用；场景卫星列表请用 filterPilotSatellites（按 Pilot 条目去重）。
func satelliteMatchesPilot(s model.Satellite, m *pilotcluster.Map) bool {
	if m.ContainsSatID(s.SatID) {
		return true
	}
	for _, e := range m.Entries {
		if s.SatID == e.SatName || s.StkName == e.SatName {
			return true
		}
		if s.SatID == pilotcluster.EphemSTKName(e.Orbit, e.Slot) || s.StkName == pilotcluster.EphemSTKName(e.Orbit, e.Slot) {
			return true
		}
	}
	return false
}
