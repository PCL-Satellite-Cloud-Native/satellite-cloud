package declarative

import (
	"strings"
	"testing"

	"satellite-cloud/backend/internal/objectdetection"
)

const odTaskYAML = `
apiVersion: cloud.satellite.io/v1
kind: ObjectDetectionTask
metadata:
  name: od-task-demo
  labels:
    app.kubernetes.io/part-of: satellite-cloud
spec:
  inputPath: /nfs/data/fusion/20251215_083000-MSS1-fusion.dat
  classes: airplane,ship
  drawLabels: false
`

func TestParseObjectDetectionTask(t *testing.T) {
	cr, err := ParseObjectDetectionTask([]byte(odTaskYAML))
	if err != nil {
		t.Fatalf("ParseObjectDetectionTask 失败: %v", err)
	}
	if cr.Metadata.Name != "od-task-demo" {
		t.Errorf("metadata.name = %q, want od-task-demo", cr.Metadata.Name)
	}
	if cr.Spec.InputPath != "/nfs/data/fusion/20251215_083000-MSS1-fusion.dat" {
		t.Errorf("spec.inputPath = %q", cr.Spec.InputPath)
	}
	if cr.Spec.Classes != "airplane,ship" {
		t.Errorf("spec.classes = %q", cr.Spec.Classes)
	}
	if cr.Spec.DrawLabels == nil || *cr.Spec.DrawLabels != false {
		t.Errorf("spec.drawLabels = %v, want false", cr.Spec.DrawLabels)
	}
}

func TestParseObjectDetectionTaskDefaults(t *testing.T) {
	// 缺省 drawLabels：空 nil，由 reconcile 层取默认值 false
	cr, err := ParseObjectDetectionTask([]byte(`
apiVersion: cloud.satellite.io/v1
kind: ObjectDetectionTask
metadata:
  name: od-default
spec:
  inputPath: /nfs/data/fusion/x-MSS1-fusion.dat
`))
	if err != nil {
		t.Fatalf("ParseObjectDetectionTask 失败: %v", err)
	}
	if cr.Spec.DrawLabels != nil {
		t.Errorf("drawLabels 应为缺省 nil, got %v", *cr.Spec.DrawLabels)
	}
	if got := desiredObjectDetectionDrawLabels(cr); got {
		t.Errorf("desiredObjectDetectionDrawLabels 默认应 false, got %v", got)
	}
}

func TestParseObjectDetectionTaskValidation(t *testing.T) {
	cases := []struct {
		name    string
		yaml    string
		wantErr string
	}{
		{
			"缺 inputPath",
			"apiVersion: cloud.satellite.io/v1\nkind: ObjectDetectionTask\nmetadata:\n  name: od-x\nspec: {}\n",
			"inputPath is required",
		},
		{
			"缺 metadata.name",
			"apiVersion: cloud.satellite.io/v1\nkind: ObjectDetectionTask\nmetadata: {}\nspec:\n  inputPath: /data/x.dat\n",
			"metadata.name",
		},
		{
			"kind 不匹配",
			"apiVersion: cloud.satellite.io/v1\nkind: RemoteSensingTask\nmetadata:\n  name: od-x\nspec:\n  inputPath: /data/x.dat\n",
			"unsupported kind",
		},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			_, err := ParseObjectDetectionTask([]byte(c.yaml))
			if err == nil {
				t.Fatalf("期望校验失败 %q, 但解析成功", c.wantErr)
			}
			if !strings.Contains(err.Error(), c.wantErr) {
				t.Fatalf("错误信息 %q 应包含 %q", err.Error(), c.wantErr)
			}
		})
	}
}

func TestParseManifestObjectDetectionTask(t *testing.T) {
	m, err := ParseManifest([]byte(odTaskYAML))
	if err != nil {
		t.Fatalf("ParseManifest 失败: %v", err)
	}
	if m.Kind != KindObjectDetectionTask {
		t.Fatalf("kind = %q, want %q", m.Kind, KindObjectDetectionTask)
	}
	if m.ObjectDetectionTask == nil {
		t.Fatal("m.ObjectDetectionTask 应为 nil")
	}
	if m.ObjectDetectionTask.Spec.InputPath != "/nfs/data/fusion/20251215_083000-MSS1-fusion.dat" {
		t.Errorf("inputPath = %q", m.ObjectDetectionTask.Spec.InputPath)
	}
}

func TestDeleteRequestedObjectDetectionTask(t *testing.T) {
	cr, err := ParseObjectDetectionTask([]byte(odTaskYAML))
	if err != nil {
		t.Fatalf("ParseObjectDetectionTask 失败: %v", err)
	}
	if DeleteRequestedObjectDetectionTask(cr) {
		t.Error("无删除注解时应返回 false")
	}
	cr.Metadata.Annotations = map[string]string{DeleteAnnotation: "true"}
	if !DeleteRequestedObjectDetectionTask(cr) {
		t.Error("带 delete=true 注解时应返回 true")
	}
}

func TestObjectDetectionStageDefinitions(t *testing.T) {
	defs := objectdetection.StageDefinitions()
	if len(defs) != 1 {
		t.Fatalf("阶段定义数量 = %d, want 1", len(defs))
	}
	if defs[0].Name != "detect" {
		t.Errorf("阶段名称 = %q, want detect", defs[0].Name)
	}
	if defs[0].Order != 1 {
		t.Errorf("阶段顺序 = %d, want 1", defs[0].Order)
	}
}

func TestObjectDetectionTaskInputsEqual(t *testing.T) {
	cr, err := ParseObjectDetectionTask([]byte(odTaskYAML))
	if err != nil {
		t.Fatalf("ParseObjectDetectionTask 失败: %v", err)
	}
	// 与 spec 一致 → 相等
	eq := cr.Spec.InputPath == "/nfs/data/fusion/20251215_083000-MSS1-fusion.dat" &&
		cr.Spec.Classes == "airplane,ship" &&
		desiredObjectDetectionDrawLabels(cr) == false
	if !eq {
		t.Error("spec 字段映射与预期不一致")
	}
}
