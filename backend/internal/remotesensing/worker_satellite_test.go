package remotesensing

import "testing"

func TestJobMatchesLocalSatellite(t *testing.T) {
	t.Parallel()
	cases := []struct {
		name      string
		enabled   bool
		jobSatID  uint
		required  string
		local     string
		wantMatch bool
	}{
		{"disabled", false, 4, "sat-1-1", "sat-2-1", true},
		{"no binding", true, 0, "", "sat-1-1", true},
		{"missing required", true, 4, "", "sat-1-1", true},
		{"missing local", true, 4, "sat-1-1", "", true},
		{"match", true, 4, "sat-1-1", "sat-1-1", true},
		{"mismatch", true, 26, "sat-2-1", "sat-1-1", false},
	}
	for _, tc := range cases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			got := JobMatchesLocalSatellite(tc.enabled, tc.jobSatID, tc.required, tc.local)
			if got != tc.wantMatch {
				t.Fatalf("JobMatchesLocalSatellite() = %v, want %v", got, tc.wantMatch)
			}
		})
	}
}
