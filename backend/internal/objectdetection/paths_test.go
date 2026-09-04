package objectdetection

import (
	"runtime"
	"testing"
)

func TestPathForWSLRunner(t *testing.T) {
	got := pathForWSLRunner(`D:/Code/foo/bar.dat`)
	want := "/mnt/d/Code/foo/bar.dat"
	if got != want {
		t.Fatalf("pathForWSLRunner() = %q, want %q", got, want)
	}
}

func TestPathForOSAccess(t *testing.T) {
	if runtime.GOOS == "windows" {
		got := pathForOSAccess("/mnt/d/Code/foo.dat")
		if got != `D:\Code\foo.dat` {
			t.Fatalf("pathForOSAccess() = %q", got)
		}
		return
	}
	if pathForOSAccess("/mnt/d/Code/foo.dat") != "/mnt/d/Code/foo.dat" {
		t.Fatalf("non-windows should pass through")
	}
}
