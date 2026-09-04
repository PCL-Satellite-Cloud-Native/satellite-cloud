package declarative

import (
	"strings"
	"testing"

	"satellite-cloud/backend/internal/model"
)

const storageBackendYAML = `
apiVersion: cloud.satellite.io/v1
kind: StorageBackend
metadata:
  name: default
  labels:
    app.kubernetes.io/part-of: satellite-cloud
spec:
  name: default
  backend: nfs
  rsArtifactRoot: /data/satellite/remote-sensing
  odArtifactRoot: /data/satellite/object-detection
  artifactUploadMinio: true
`

const storageBackendMinioYAML = `
apiVersion: cloud.satellite.io/v1
kind: StorageBackend
metadata:
  name: minio-main
spec:
  backend: minio
  rsArtifactRoot: /data/satellite/remote-sensing
  odArtifactRoot: /data/satellite/object-detection
  minio:
    endpoint: minio:9000
    accessKey: minioadmin
    secretKey: minioadmin
    bucket: satellite-artifacts
    prefix: sat/
    useSSL: false
`

func TestParseStorageBackend(t *testing.T) {
	cr, err := ParseStorageBackend([]byte(storageBackendYAML))
	if err != nil {
		t.Fatalf("ParseStorageBackend 失败: %v", err)
	}
	if cr.Metadata.Name != "default" {
		t.Errorf("metadata.name = %q, want default", cr.Metadata.Name)
	}
	if cr.Spec.Backend != "nfs" {
		t.Errorf("spec.backend = %q, want nfs", cr.Spec.Backend)
	}
	if cr.Spec.RSArtifactRoot != "/data/satellite/remote-sensing" {
		t.Errorf("spec.rsArtifactRoot = %q", cr.Spec.RSArtifactRoot)
	}
	if !cr.Spec.ArtifactUploadMinio {
		t.Error("spec.artifactUploadMinio = false, want true")
	}
}

func TestParseStorageBackendMinio(t *testing.T) {
	cr, err := ParseStorageBackend([]byte(storageBackendMinioYAML))
	if err != nil {
		t.Fatalf("ParseStorageBackend 失败: %v", err)
	}
	if cr.Spec.Backend != "minio" {
		t.Errorf("spec.backend = %q, want minio", cr.Spec.Backend)
	}
	if cr.Spec.Minio == nil {
		t.Fatal("spec.minio 应为非 nil")
	}
	if cr.Spec.Minio.Endpoint != "minio:9000" {
		t.Errorf("spec.minio.endpoint = %q", cr.Spec.Minio.Endpoint)
	}
	if cr.Spec.Minio.Bucket != "satellite-artifacts" {
		t.Errorf("spec.minio.bucket = %q", cr.Spec.Minio.Bucket)
	}
	if cr.Spec.Minio.Prefix != "sat/" {
		t.Errorf("spec.minio.prefix = %q", cr.Spec.Minio.Prefix)
	}
}

func TestParseStorageBackendDefaults(t *testing.T) {
	// 缺省 backend=nfs / bucket=satellite-artifacts / useSSL=false
	cr, err := ParseStorageBackend([]byte(`
apiVersion: cloud.satellite.io/v1
kind: StorageBackend
metadata:
  name: default
spec:
  backend: minio
  minio:
    endpoint: minio:9000
    accessKey: minioadmin
    secretKey: minioadmin
`))
	if err != nil {
		t.Fatalf("ParseStorageBackend 失败: %v", err)
	}
	if got := desiredStorageBackendType(cr); got != "minio" {
		t.Errorf("backend 应为 minio, got %q", got)
	}
	if got := desiredStorageBucket(cr); got != "satellite-artifacts" {
		t.Errorf("bucket 缺省应 satellite-artifacts, got %q", got)
	}
	if got := desiredStorageMinioUseSSL(cr); got {
		t.Error("useSSL 缺省应 false")
	}
}

func TestParseStorageBackendValidation(t *testing.T) {
	cases := []struct {
		name    string
		yaml    string
		wantErr string
	}{
		{
			"backend 非法",
			"apiVersion: cloud.satellite.io/v1\nkind: StorageBackend\nmetadata:\n  name: default\nspec:\n  backend: bogus\n",
			"spec.backend must be nfs|minio",
		},
		{
			"minio 缺 endpoint",
			"apiVersion: cloud.satellite.io/v1\nkind: StorageBackend\nmetadata:\n  name: default\nspec:\n  backend: minio\n  minio:\n    accessKey: a\n    secretKey: b\n",
			"spec.minio.endpoint is required",
		},
		{
			"minio 缺 accessKey",
			"apiVersion: cloud.satellite.io/v1\nkind: StorageBackend\nmetadata:\n  name: default\nspec:\n  backend: minio\n  minio:\n    endpoint: minio:9000\n    secretKey: b\n",
			"spec.minio.accessKey is required",
		},
		{
			"minio 缺 secretKey",
			"apiVersion: cloud.satellite.io/v1\nkind: StorageBackend\nmetadata:\n  name: default\nspec:\n  backend: minio\n  minio:\n    endpoint: minio:9000\n    accessKey: a\n",
			"spec.minio.secretKey is required",
		},
		{
			"minio 缺 spec.minio",
			"apiVersion: cloud.satellite.io/v1\nkind: StorageBackend\nmetadata:\n  name: default\nspec:\n  backend: minio\n",
			"spec.minio is required",
		},
		{
			"缺 metadata.name",
			"apiVersion: cloud.satellite.io/v1\nkind: StorageBackend\nmetadata: {}\nspec:\n  backend: nfs\n",
			"metadata.name",
		},
		{
			"kind 不匹配",
			"apiVersion: cloud.satellite.io/v1\nkind: JobQueue\nmetadata:\n  name: default\nspec:\n  stream: rs.jobs\n  consumerGroup: rs-workers\n",
			"unsupported kind",
		},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			_, err := ParseStorageBackend([]byte(c.yaml))
			if err == nil {
				t.Fatalf("期望校验失败 %q, 但解析成功", c.wantErr)
			}
			if !strings.Contains(err.Error(), c.wantErr) {
				t.Fatalf("错误信息 %q 应包含 %q", err.Error(), c.wantErr)
			}
		})
	}
}

func TestParseManifestStorageBackend(t *testing.T) {
	m, err := ParseManifest([]byte(storageBackendMinioYAML))
	if err != nil {
		t.Fatalf("ParseManifest 失败: %v", err)
	}
	if m.Kind != KindStorageBackend {
		t.Fatalf("kind = %q, want %q", m.Kind, KindStorageBackend)
	}
	if m.StorageBackend == nil {
		t.Fatal("m.StorageBackend 应为非 nil")
	}
	if m.StorageBackend.Spec.Backend != "minio" {
		t.Errorf("backend = %q", m.StorageBackend.Spec.Backend)
	}
}

func TestDeleteRequestedStorageBackend(t *testing.T) {
	cr, err := ParseStorageBackend([]byte(storageBackendYAML))
	if err != nil {
		t.Fatalf("ParseStorageBackend 失败: %v", err)
	}
	if DeleteRequestedStorageBackend(cr) {
		t.Error("无删除注解时应返回 false")
	}
	cr.Metadata.Annotations = map[string]string{DeleteAnnotation: "true"}
	if !DeleteRequestedStorageBackend(cr) {
		t.Error("带 delete=true 注解时应返回 true")
	}
}

func TestStorageBackendSpecsEqual(t *testing.T) {
	cr, err := ParseStorageBackend([]byte(storageBackendYAML))
	if err != nil {
		t.Fatalf("ParseStorageBackend 失败: %v", err)
	}
	// 与 spec 一致 → 相等
	if !storageBackendSpecsEqual(modelStorageBackendFixture(), cr) {
		t.Error("期望 storageBackendSpecsEqual 返回 true（spec 与库中记录一致）")
	}
	// backend 不同 → 不相等
	m := modelStorageBackendFixture()
	m.Backend = "minio"
	if storageBackendSpecsEqual(m, cr) {
		t.Error("期望 storageBackendSpecsEqual 返回 false（backend 不一致）")
	}
}

// modelStorageBackendFixture 返回与 storageBackendYAML spec 一致的库记录
// （MinioBucket 为缺省值 satellite-artifacts，与 createStorageBackend 写入一致）。
func modelStorageBackendFixture() model.StorageBackend {
	return model.StorageBackend{
		Backend:             "nfs",
		RSArtifactRoot:      "/data/satellite/remote-sensing",
		ODArtifactRoot:      "/data/satellite/object-detection",
		ArtifactUploadMinio: true,
		MinioBucket:         "satellite-artifacts",
	}
}
