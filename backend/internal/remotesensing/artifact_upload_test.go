package remotesensing

import (
	"testing"

	"satellite-cloud/backend/internal/model"
)

func TestShouldUploadArtifact(t *testing.T) {
	t.Parallel()
	cases := []struct {
		typ  string
		want bool
	}{
		{"preview", true},
		{"detection_tile", true},
		{"detection_preview", true},
		{"detection_summary", true},
		{"raw", false},
	}
	for _, tc := range cases {
		got := shouldUploadArtifact(model.RemoteSensingTaskArtifact{Type: tc.typ})
		if got != tc.want {
			t.Fatalf("type=%s got=%v want=%v", tc.typ, got, tc.want)
		}
	}
}
