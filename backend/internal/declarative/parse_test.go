package declarative

import (
	"path/filepath"
	"testing"
)

const sampleManifest = `apiVersion: cloud.satellite.io/v1
kind: SatelliteConstellation
metadata:
  name: scenario5-full-36x22
spec:
  scenario:
    name: Scenario5_full_36x22
    epoch: "2025-01-01T00:00:00Z"
    altKm: 550
    incDeg: 53
    nPlanes: 36
    nSatsPerPlane: 22
    sensorConfig:
      type: panchromatic
      resolutionM: 0.5
  satellites:
    mode: generated
  topology:
    delayMatrixCsv: ../frontend/public/data/delay_15x15.csv
    t0CsvDir: ../frontend/public/data/ephem_15
    routerCsvDir: ../frontend/public/data/router
`

func TestParse(t *testing.T) {
	cr, err := Parse([]byte(sampleManifest))
	if err != nil {
		t.Fatal(err)
	}
	if cr.Metadata.Name != "scenario5-full-36x22" {
		t.Errorf("metadata.name=%q", cr.Metadata.Name)
	}
	if cr.Spec.Scenario.NPlanes != 36 || cr.Spec.Scenario.NSatsPerPlane != 22 {
		t.Errorf("构型解析错误: %+v", cr.Spec.Scenario)
	}
	if cr.Spec.Satellites.Mode != ModeGenerated {
		t.Errorf("mode=%q", cr.Spec.Satellites.Mode)
	}
	if cr.Spec.Topology == nil || cr.Spec.Topology.DelayMatrixCSV == "" {
		t.Error("topology 未解析")
	}
	if len(cr.Spec.Scenario.SensorConfig) == 0 {
		t.Error("sensorConfig 未解析")
	}
}

func TestParse_RejectsBadKind(t *testing.T) {
	_, err := Parse([]byte(`apiVersion: cloud.satellite.io/v1
kind: Deployment
metadata:
  name: x
spec: {}`))
	if err == nil {
		t.Fatal("错误 kind 应被拒绝")
	}
}

func TestParse_RejectsMissingName(t *testing.T) {
	_, err := Parse([]byte(`apiVersion: cloud.satellite.io/v1
kind: SatelliteConstellation
spec:
  scenario:
    name: s
    nPlanes: 1
    nSatsPerPlane: 1
  satellites:
    mode: generated`))
	if err == nil {
		t.Fatal("缺少 metadata.name 应被拒绝")
	}
}

func TestLoadDirectory_RealManifests(t *testing.T) {
	// 相对包目录定位真实清单：backend/internal/declarative -> ../../config/declarative
	dir := filepath.Join("..", "..", "config", "declarative")
	crs, err := LoadDirectory(dir)
	if err != nil {
		t.Fatalf("加载 %s 失败: %v", dir, err)
	}
	if len(crs) != 2 {
		t.Fatalf("期望 2 份清单，实际 %d", len(crs))
	}
	for _, cr := range crs {
		if _, err := DesiredSatellites(cr.Spec); err != nil {
			t.Errorf("%s: 期望卫星生成失败: %v", cr.Metadata.Name, err)
		}
	}
}
