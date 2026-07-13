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

func TestRootKeyForObject(t *testing.T) {
	t.Parallel()
	rsRoot := "/opt/remote-sensing"
	if got := rootKeyForObject(rsRoot, "persist_output_preprocessing/tasks/1/a.dat"); got != "remote_sensing" {
		t.Fatalf("rs artifact: got %q", got)
	}
	// RS task 挂载的检测产物：path 以 output_detection/ 开头，须 object_detection 前缀
	detPath := "output_detection/rs_task_217/soccer ball field/tile.jpg"
	if got := rootKeyForObject(rsRoot, detPath); got != "object_detection" {
		t.Fatalf("detection via RS handler: got %q want object_detection", got)
	}
	if got := rootKeyForObject("/opt/object-detection", detPath); got != "object_detection" {
		t.Fatalf("detection via OD root: got %q", got)
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
