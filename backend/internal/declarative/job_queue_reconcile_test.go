package declarative

import (
	"strings"
	"testing"

	"satellite-cloud/backend/internal/model"
)

const jobQueueYAML = `
apiVersion: cloud.satellite.io/v1
kind: JobQueue
metadata:
  name: rs
  labels:
    app.kubernetes.io/part-of: satellite-cloud
spec:
  name: rs
  stream: rs.jobs
  consumerGroup: rs-workers
  consumerPrefix: rs-worker
  concurrency: 2
  mode: external
  redisAddr: redis:6379
  maxLen: 100000
  enabled: true
`

func TestParseJobQueue(t *testing.T) {
	cr, err := ParseJobQueue([]byte(jobQueueYAML))
	if err != nil {
		t.Fatalf("ParseJobQueue 失败: %v", err)
	}
	if cr.Metadata.Name != "rs" {
		t.Errorf("metadata.name = %q, want rs", cr.Metadata.Name)
	}
	if cr.Spec.Stream != "rs.jobs" {
		t.Errorf("spec.stream = %q, want rs.jobs", cr.Spec.Stream)
	}
	if cr.Spec.ConsumerGroup != "rs-workers" {
		t.Errorf("spec.consumerGroup = %q, want rs-workers", cr.Spec.ConsumerGroup)
	}
	if cr.Spec.ConsumerPrefix != "rs-worker" {
		t.Errorf("spec.consumerPrefix = %q, want rs-worker", cr.Spec.ConsumerPrefix)
	}
	if cr.Spec.Concurrency != 2 {
		t.Errorf("spec.concurrency = %d, want 2", cr.Spec.Concurrency)
	}
	if cr.Spec.RedisAddr != "redis:6379" {
		t.Errorf("spec.redisAddr = %q, want redis:6379", cr.Spec.RedisAddr)
	}
	if cr.Spec.Enabled == nil || *cr.Spec.Enabled != true {
		t.Errorf("spec.enabled = %v, want true", cr.Spec.Enabled)
	}
}

func TestParseJobQueueDefaults(t *testing.T) {
	// 缺省 name / consumerPrefix / concurrency / mode / enabled
	cr, err := ParseJobQueue([]byte(`
apiVersion: cloud.satellite.io/v1
kind: JobQueue
metadata:
  name: od
spec:
  stream: od.jobs
  consumerGroup: od-workers
`))
	if err != nil {
		t.Fatalf("ParseJobQueue 失败: %v", err)
	}
	if cr.Spec.Name != "" {
		t.Errorf("spec.name 缺省应为空, got %q", cr.Spec.Name)
	}
	if got := desiredJobQueueConsumerPrefix(cr, "od"); got != "od-worker" {
		t.Errorf("consumerPrefix 缺省应推导为 od-worker, got %q", got)
	}
	if got := desiredJobQueueMode(cr); got != "external" {
		t.Errorf("mode 缺省应 external, got %q", got)
	}
	if got := desiredJobQueueConcurrency(cr); got != 1 {
		t.Errorf("concurrency 缺省应 1, got %d", got)
	}
	if got := desiredJobQueueEnabled(cr); !got {
		t.Errorf("enabled 缺省应 true, got %v", got)
	}
}

func TestParseJobQueueValidation(t *testing.T) {
	cases := []struct {
		name    string
		yaml    string
		wantErr string
	}{
		{
			"缺 stream",
			"apiVersion: cloud.satellite.io/v1\nkind: JobQueue\nmetadata:\n  name: rs\nspec:\n  consumerGroup: rs-workers\n",
			"spec.stream is required",
		},
		{
			"缺 consumerGroup",
			"apiVersion: cloud.satellite.io/v1\nkind: JobQueue\nmetadata:\n  name: rs\nspec:\n  stream: rs.jobs\n",
			"spec.consumerGroup is required",
		},
		{
			"缺 metadata.name",
			"apiVersion: cloud.satellite.io/v1\nkind: JobQueue\nmetadata: {}\nspec:\n  stream: rs.jobs\n  consumerGroup: rs-workers\n",
			"metadata.name",
		},
		{
			"mode 非法",
			"apiVersion: cloud.satellite.io/v1\nkind: JobQueue\nmetadata:\n  name: rs\nspec:\n  stream: rs.jobs\n  consumerGroup: rs-workers\n  mode: bogus\n",
			"spec.mode must be external|inprocess",
		},
		{
			"kind 不匹配",
			"apiVersion: cloud.satellite.io/v1\nkind: RemoteSensingTask\nmetadata:\n  name: rs\nspec:\n  stream: rs.jobs\n  consumerGroup: rs-workers\n",
			"unsupported kind",
		},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			_, err := ParseJobQueue([]byte(c.yaml))
			if err == nil {
				t.Fatalf("期望校验失败 %q, 但解析成功", c.wantErr)
			}
			if !strings.Contains(err.Error(), c.wantErr) {
				t.Fatalf("错误信息 %q 应包含 %q", err.Error(), c.wantErr)
			}
		})
	}
}

func TestParseManifestJobQueue(t *testing.T) {
	m, err := ParseManifest([]byte(jobQueueYAML))
	if err != nil {
		t.Fatalf("ParseManifest 失败: %v", err)
	}
	if m.Kind != KindJobQueue {
		t.Fatalf("kind = %q, want %q", m.Kind, KindJobQueue)
	}
	if m.JobQueue == nil {
		t.Fatal("m.JobQueue 应为非 nil")
	}
	if m.JobQueue.Spec.Stream != "rs.jobs" {
		t.Errorf("stream = %q", m.JobQueue.Spec.Stream)
	}
}

func TestDeleteRequestedJobQueue(t *testing.T) {
	cr, err := ParseJobQueue([]byte(jobQueueYAML))
	if err != nil {
		t.Fatalf("ParseJobQueue 失败: %v", err)
	}
	if DeleteRequestedJobQueue(cr) {
		t.Error("无删除注解时应返回 false")
	}
	cr.Metadata.Annotations = map[string]string{DeleteAnnotation: "true"}
	if !DeleteRequestedJobQueue(cr) {
		t.Error("带 delete=true 注解时应返回 true")
	}
}

func TestJobQueueSpecsEqual(t *testing.T) {
	cr, err := ParseJobQueue([]byte(jobQueueYAML))
	if err != nil {
		t.Fatalf("ParseJobQueue 失败: %v", err)
	}
	// 与 spec 一致 → 相等
	eq := jobQueueSpecsEqual(modelJobQueueFixture(), cr)
	if !eq {
		t.Error("期望 jobQueueSpecsEqual 返回 true（spec 与库中记录一致）")
	}
	// stream 不同 → 不相等
	m := modelJobQueueFixture()
	m.Stream = "rs.jobs.v2"
	if jobQueueSpecsEqual(m, cr) {
		t.Error("期望 jobQueueSpecsEqual 返回 false（stream 不一致）")
	}
}

// modelJobQueueFixture 返回与 jobQueueYAML spec 一致的库记录（不含 Redis，避免测试联网）。
func modelJobQueueFixture() model.JobQueue {
	return model.JobQueue{
		Stream:         "rs.jobs",
		ConsumerGroup:  "rs-workers",
		ConsumerPrefix: "rs-worker",
		Concurrency:    2,
		Mode:           "external",
		RedisAddr:      "redis:6379",
		MaxLen:         100000,
		Enabled:        true,
	}
}
