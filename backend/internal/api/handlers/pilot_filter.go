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
		if m.ContainsSatID(s.SatID) {
			out = append(out, s)
		}
	}
	if len(out) == 0 {
		return sats
	}
	return out
}
