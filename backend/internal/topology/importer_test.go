package topology

import (
	"os"
	"path/filepath"
	"testing"
)

func TestListT0EphemFiles_scan60(t *testing.T) {
	dir := t.TempDir()
	for _, name := range []string{"Sat_3_20_ephem_ext.csv", "Sat_1_1_ephem_ext.csv", "Sat_2_10_ephem_ext.csv", "readme.txt"} {
		if err := os.WriteFile(filepath.Join(dir, name), []byte("x"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	got, err := listT0EphemFiles(dir)
	if err != nil {
		t.Fatal(err)
	}
	want := []string{"Sat_1_1_ephem_ext.csv", "Sat_2_10_ephem_ext.csv", "Sat_3_20_ephem_ext.csv"}
	if len(got) != len(want) {
		t.Fatalf("len=%d want %d: %v", len(got), len(want), got)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("got[%d]=%q want %q (full=%v)", i, got[i], want[i], got)
		}
	}
}

func TestListT0EphemFiles_legacyFallback(t *testing.T) {
	dir := t.TempDir()
	got, err := listT0EphemFiles(dir)
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != len(t0EphemFilesLegacy) {
		t.Fatalf("legacy fallback len=%d want %d", len(got), len(t0EphemFilesLegacy))
	}
	if got[0] != t0EphemFilesLegacy[0] {
		t.Fatalf("first=%q want %q", got[0], t0EphemFilesLegacy[0])
	}
}
