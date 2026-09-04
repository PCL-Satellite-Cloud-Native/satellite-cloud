package handlers

import (
	"testing"

	"satellite-cloud/backend/internal/model"
)

func TestFilterPilotSatellites_deduplicatesEphemBridge(t *testing.T) {
	t.Setenv("SATELLITE_PILOT_CLUSTER", "true")

	sats := []model.Satellite{
		{SatID: "sat-1-1", StkName: "Sat_1_1"},
		{SatID: "sat-6-6", StkName: "Sat_6_6"},
		{SatID: "sat-1-2", StkName: "Sat_1_2"},
		{SatID: "sat-6-7", StkName: "Sat_6_7"},
	}

	out := filterPilotSatellites(sats)
	if len(out) != 2 {
		t.Fatalf("len(out) = %d, want 2 (one row per pilot entry)", len(out))
	}
	if out[0].SatID != "sat-1-1" {
		t.Fatalf("first sat_id = %q, want sat-1-1 (prefer business id over ephem duplicate)", out[0].SatID)
	}
	if out[1].SatID != "sat-1-2" {
		t.Fatalf("second sat_id = %q, want sat-1-2", out[1].SatID)
	}
}
