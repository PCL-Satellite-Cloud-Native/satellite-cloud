package declarative

import (
	"strings"
	"testing"
)

const rsTaskYAML = `
apiVersion: cloud.satellite.io/v1
kind: RemoteSensingTask
metadata:
  name: rs-task-demo
  labels:
    app.kubernetes.io/part-of: satellite-cloud
spec:
  scenarioName: Scenario5_full_36x22
  satelliteId: sat-1-1
  filePrefix: "20251215_083000"
  inputDirectory: /nfs/data/raw/20251215_083000
  sensor: MSS
  enableDetection: true
  detectionClasses: airplane,ship
  detectionDrawLabels: false
`

func TestParseRemoteSensingTask(t *testing.T) {
	cr, err := ParseRemoteSensingTask([]byte(rsTaskYAML))
	if err != nil {
		t.Fatalf("ParseRemoteSensingTask 失败: %v", err)
	}
	if cr.Metadata.Name != "rs-task-demo" {
		t.Errorf("metadata.name = %q, want rs-task-demo", cr.Metadata.Name)
	}
	if cr.Spec.ScenarioName != "Scenario5_full_36x22" {
		t.Errorf("spec.scenarioName = %q", cr.Spec.ScenarioName)
	}
	if cr.Spec.SatelliteID != "sat-1-1" {
		t.Errorf("spec.satelliteId = %q", cr.Spec.SatelliteID)
	}
	if cr.Spec.FilePrefix != "20251215_083000" {
		t.Errorf("spec.filePrefix = %q", cr.Spec.FilePrefix)
	}
	if cr.Spec.InputDirectory != "/nfs/data/raw/20251215_083000" {
		t.Errorf("spec.inputDirectory = %q", cr.Spec.InputDirectory)
	}
	if cr.Spec.Sensor != "MSS" {
		t.Errorf("spec.sensor = %q", cr.Spec.Sensor)
	}
	if cr.Spec.EnableDetection == nil || *cr.Spec.EnableDetection != true {
		t.Errorf("spec.enableDetection = %v, want true", cr.Spec.EnableDetection)
	}
	if cr.Spec.DetectionClasses != "airplane,ship" {
		t.Errorf("spec.detectionClasses = %q", cr.Spec.DetectionClasses)
	}
	if cr.Spec.DetectionDrawLabels == nil || *cr.Spec.DetectionDrawLabels != false {
		t.Errorf("spec.detectionDrawLabels = %v, want false", cr.Spec.DetectionDrawLabels)
	}
}

func TestParseRemoteSensingTaskDefaults(t *testing.T) {
	// 缺省 enableDetection / detectionDrawLabels：空 nil，由 reconcile 层取默认值
	cr, err := ParseRemoteSensingTask([]byte(`
apiVersion: cloud.satellite.io/v1
kind: RemoteSensingTask
metadata:
  name: rs-default
spec:
  scenarioName: S1
  filePrefix: "p"
  inputDirectory: /data
`))
	if err != nil {
		t.Fatalf("ParseRemoteSensingTask 失败: %v", err)
	}
	if cr.Spec.EnableDetection != nil {
		t.Errorf("enableDetection 应为缺省 nil, got %v", *cr.Spec.EnableDetection)
	}
	if cr.Spec.DetectionDrawLabels != nil {
		t.Errorf("detectionDrawLabels 应为缺省 nil, got %v", *cr.Spec.DetectionDrawLabels)
	}
	if got := desiredEnableDetection(cr); !got {
		t.Errorf("desiredEnableDetection 默认应 true, got %v", got)
	}
	if got := desiredDrawLabels(cr); got {
		t.Errorf("desiredDrawLabels 默认应 false, got %v", got)
	}
}

func TestParseRemoteSensingTaskValidation(t *testing.T) {
	cases := []struct {
		name    string
		yaml    string
		wantErr string
	}{
		{
			"缺 scenarioName",
			"apiVersion: cloud.satellite.io/v1\nkind: RemoteSensingTask\nmetadata:\n  name: rs-x\nspec:\n  filePrefix: p\n  inputDirectory: /data\n",
			"scenarioName is required",
		},
		{
			"缺 filePrefix",
			"apiVersion: cloud.satellite.io/v1\nkind: RemoteSensingTask\nmetadata:\n  name: rs-x\nspec:\n  scenarioName: S1\n  inputDirectory: /data\n",
			"filePrefix is required",
		},
		{
			"缺 inputDirectory",
			"apiVersion: cloud.satellite.io/v1\nkind: RemoteSensingTask\nmetadata:\n  name: rs-x\nspec:\n  scenarioName: S1\n  filePrefix: p\n",
			"inputDirectory is required",
		},
		{
			"缺 metadata.name",
			"apiVersion: cloud.satellite.io/v1\nkind: RemoteSensingTask\nmetadata: {}\nspec:\n  scenarioName: S1\n  filePrefix: p\n  inputDirectory: /data\n",
			"metadata.name",
		},
		{
			"kind 不匹配",
			"apiVersion: cloud.satellite.io/v1\nkind: Satellite\nmetadata:\n  name: rs-x\nspec:\n  scenarioName: S1\n  filePrefix: p\n  inputDirectory: /data\n",
			"unsupported kind",
		},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			_, err := ParseRemoteSensingTask([]byte(c.yaml))
			if err == nil {
				t.Fatalf("期望校验失败 %q, 但解析成功", c.wantErr)
			}
			if !strings.Contains(err.Error(), c.wantErr) {
				t.Fatalf("错误信息 %q 应包含 %q", err.Error(), c.wantErr)
			}
		})
	}
}

func TestParseManifestRemoteSensingTask(t *testing.T) {
	m, err := ParseManifest([]byte(rsTaskYAML))
	if err != nil {
		t.Fatalf("ParseManifest 失败: %v", err)
	}
	if m.Kind != KindRemoteSensingTask {
		t.Fatalf("kind = %q, want %q", m.Kind, KindRemoteSensingTask)
	}
	if m.RemoteSensingTask == nil {
		t.Fatal("m.RemoteSensingTask 应为 nil")
	}
	if m.RemoteSensingTask.Spec.SatelliteID != "sat-1-1" {
		t.Errorf("satelliteId = %q", m.RemoteSensingTask.Spec.SatelliteID)
	}
}

func TestDeleteRequestedRemoteSensingTask(t *testing.T) {
	cr, err := ParseRemoteSensingTask([]byte(rsTaskYAML))
	if err != nil {
		t.Fatalf("ParseRemoteSensingTask 失败: %v", err)
	}
	if DeleteRequestedRemoteSensingTask(cr) {
		t.Error("无删除注解时应返回 false")
	}
	cr.Metadata.Annotations = map[string]string{DeleteAnnotation: "true"}
	if !DeleteRequestedRemoteSensingTask(cr) {
		t.Error("带 delete=true 注解时应返回 true")
	}
}

func TestRemoteSensingTaskInputsEqual(t *testing.T) {
	cr, err := ParseRemoteSensingTask([]byte(rsTaskYAML))
	if err != nil {
		t.Fatalf("ParseRemoteSensingTask 失败: %v", err)
	}
	// 与 spec 一致 → 相等
	eq := cr.Spec.FilePrefix == "20251215_083000" &&
		cr.Spec.InputDirectory == "/nfs/data/raw/20251215_083000" &&
		cr.Spec.Sensor == "MSS" &&
		desiredEnableDetection(cr) == true &&
		cr.Spec.DetectionClasses == "airplane,ship" &&
		desiredDrawLabels(cr) == false
	if !eq {
		t.Error("spec 字段映射与预期不一致")
	}
}
