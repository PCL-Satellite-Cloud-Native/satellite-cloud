package handlers

import (
	"satellite-cloud/backend/internal/model"
	"satellite-cloud/backend/internal/pilotcluster"
)

func filterPilotSatellites(sats []model.Satellite) []model.Satellite {
	m := pilotcluster.Current()
	if !m.Enabled {
		return sats
	}
	out := make([]model.Satellite, 0, len(m.Entries))
	for _, s := range sats {
		if satelliteMatchesPilot(s, m) {
			out = append(out, s)
		}
	}
	if len(out) == 0 {
		return sats
	}
	return out
}

// satelliteMatchesPilot 匹配 Pilot sat_id，或 legacy 星历名 / STK 显示名（见 ephem 桥接归档）。
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
