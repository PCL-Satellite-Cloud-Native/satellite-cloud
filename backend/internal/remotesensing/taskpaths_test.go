package remotesensing

import (
	"path/filepath"
	"testing"
)

func TestScratchPreprocessingDir(t *testing.T) {
	t.Parallel()
	legacy := filepath.ToSlash(scratchPreprocessingDir(0, false, "pan_warp_quarters", "workers", "group1"))
	if legacy != "output_preprocessing/pan_warp_quarters/workers/group1" {
		t.Fatalf("legacy = %q", legacy)
	}
	isolated := filepath.ToSlash(scratchPreprocessingDir(196, true, "pan_warp_quarters", "workers", "group1"))
	want := "output_preprocessing/tasks/196/pan_warp_quarters/workers/group1"
	if isolated != want {
		t.Fatalf("isolated = %q, want %q", isolated, want)
	}
}

func TestPersistPreprocessingDir(t *testing.T) {
	t.Parallel()
	legacy := filepath.ToSlash(persistPreprocessingDir(0, "persist_output_preprocessing", false, "pan_rad_toa"))
	if legacy != "persist_output_preprocessing/pan_rad_toa" {
		t.Fatalf("legacy = %q", legacy)
	}
	isolated := filepath.ToSlash(persistPreprocessingDir(196, "persist_output_preprocessing", true, "fusion_envi", "a.dat"))
	want := "persist_output_preprocessing/tasks/196/fusion_envi/a.dat"
	if isolated != want {
		t.Fatalf("isolated = %q, want %q", isolated, want)
	}
}

func TestPersistTaskPathPrefix(t *testing.T) {
	t.Parallel()
	if persistTaskPathPrefix(0, true) != "" {
		t.Fatal("task 0 should be empty prefix")
	}
	if persistTaskPathPrefix(196, false) != "" {
		t.Fatal("isolation off should be empty")
	}
	if got := persistTaskPathPrefix(196, true); got != "tasks/196/" {
		t.Fatalf("prefix = %q", got)
	}
}
