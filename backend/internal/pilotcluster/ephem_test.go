package pilotcluster

import "testing"

func TestEphemSTKName(t *testing.T) {
	if got := EphemSTKName(1, 1); got != "Sat_6_6" {
		t.Fatalf("EphemSTKName(1,1) = %q, want Sat_6_6", got)
	}
	if got := EphemSTKName(3, 5); got != "Sat_8_10" {
		t.Fatalf("EphemSTKName(3,5) = %q, want Sat_8_10", got)
	}
	if got := EphemSTKFromPilotSatID("sat-2-3"); got != "Sat_7_8" {
		t.Fatalf("EphemSTKFromPilotSatID(sat-2-3) = %q, want Sat_7_8", got)
	}
}

func TestEphemOrbitSlot(t *testing.T) {
	o, s := EphemOrbitSlot(2, 4)
	if o != 7 || s != 9 {
		t.Fatalf("EphemOrbitSlot(2,4) = (%d,%d), want (7,9)", o, s)
	}
}
