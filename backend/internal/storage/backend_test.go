package storage

import (
	"testing"

	"satellite-cloud/backend/internal/config"
)

func TestSafeJoinRoot(t *testing.T) {
	root := t.TempDir()
	ok, err := SafeJoinRoot(root, "persist_output_preprocessing/out.tif")
	if err != nil {
		t.Fatal(err)
	}
	if ok == "" {
		t.Fatal("expected path")
	}
	if _, err := SafeJoinRoot(root, "../etc/passwd"); err == nil {
		t.Fatal("expected path escape error")
	}
}

func TestObjectKey(t *testing.T) {
	got := objectKey("artifacts", "remote_sensing", "tasks/1/out.tif")
	want := "artifacts/remote_sensing/tasks/1/out.tif"
	if got != want {
		t.Fatalf("got %q want %q", got, want)
	}
}

func TestNewDefaultNFS(t *testing.T) {
	b, err := New(config.StorageConfig{Backend: "nfs"})
	if err != nil {
		t.Fatal(err)
	}
	if b.Mode() != "nfs" {
		t.Fatalf("mode=%q", b.Mode())
	}
}
