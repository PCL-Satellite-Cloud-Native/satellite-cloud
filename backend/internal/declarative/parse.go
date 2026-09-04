package declarative

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"sigs.k8s.io/yaml"
)

// LoadFromFile 读取并解析单个声明式清单文件。
func LoadFromFile(path string) (*SatelliteConstellation, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read %s: %w", path, err)
	}
	return Parse(data)
}

// Parse 解析清单 YAML 并做基础校验（apiVersion / kind）。
func Parse(data []byte) (*SatelliteConstellation, error) {
	var cr SatelliteConstellation
	if err := yaml.Unmarshal(data, &cr); err != nil {
		return nil, fmt.Errorf("parse yaml: %w", err)
	}
	if cr.Kind == "" {
		return nil, fmt.Errorf("missing required field: kind")
	}
	if cr.Kind != KindConstellation {
		return nil, fmt.Errorf("unsupported kind %q, expected %q", cr.Kind, KindConstellation)
	}
	if cr.APIVersion != "" && cr.APIVersion != fmt.Sprintf("%s/%s", CRDGroup, CRDVersion) {
		return nil, fmt.Errorf("unsupported apiVersion %q, expected %q", cr.APIVersion, CRDGroup+"/"+CRDVersion)
	}
	if cr.Metadata.Name == "" {
		return nil, fmt.Errorf("missing required field: metadata.name")
	}
	if err := validateSpec(&cr.Spec); err != nil {
		return nil, fmt.Errorf("%s: %w", cr.Metadata.Name, err)
	}
	return &cr, nil
}

// validateSpec 校验 spec 的必填字段与合法取值范围。
func validateSpec(s *SatelliteConstellationSpec) error {
	if s.Scenario.Name == "" {
		return fmt.Errorf("spec.scenario.name is required")
	}
	if s.Scenario.NPlanes <= 0 {
		return fmt.Errorf("spec.scenario.nPlanes must be > 0")
	}
	if s.Scenario.NSatsPerPlane <= 0 {
		return fmt.Errorf("spec.scenario.nSatsPerPlane must be > 0")
	}
	switch s.Satellites.Mode {
	case "":
		return fmt.Errorf("spec.satellites.mode is required (generated|inline)")
	case ModeGenerated:
		if len(s.Satellites.List) > 0 {
			return fmt.Errorf("spec.satellites.list must be empty in generated mode")
		}
	case ModeInline:
		if len(s.Satellites.List) == 0 {
			return fmt.Errorf("spec.satellites.list is required in inline mode")
		}
	default:
		return fmt.Errorf("unsupported satellites.mode %q (generated|inline)", s.Satellites.Mode)
	}
	return nil
}

// ParseTopology 解析网络拓扑声明式清单（kind: NetworkTopology）。
func ParseTopology(data []byte) (*NetworkTopology, error) {
	var cr NetworkTopology
	if err := yaml.Unmarshal(data, &cr); err != nil {
		return nil, fmt.Errorf("parse yaml: %w", err)
	}
	if cr.Kind == "" {
		return nil, fmt.Errorf("missing required field: kind")
	}
	if cr.Kind != KindTopology {
		return nil, fmt.Errorf("unsupported kind %q, expected %q", cr.Kind, KindTopology)
	}
	if cr.APIVersion != "" && cr.APIVersion != fmt.Sprintf("%s/%s", CRDGroup, CRDVersion) {
		return nil, fmt.Errorf("unsupported apiVersion %q, expected %q", cr.APIVersion, CRDGroup+"/"+CRDVersion)
	}
	if cr.Metadata.Name == "" {
		return nil, fmt.Errorf("missing required field: metadata.name")
	}
	if err := validateTopologySpec(&cr.Spec); err != nil {
		return nil, fmt.Errorf("%s: %w", cr.Metadata.Name, err)
	}
	return &cr, nil
}

// validateTopologySpec 校验拓扑清单必填字段。
func validateTopologySpec(s *NetworkTopologySpec) error {
	if s.ScenarioName == "" {
		return fmt.Errorf("spec.scenarioName is required")
	}
	ds := s.DataSources
	if ds.DelayMatrixCSV == "" && ds.T0CsvDir == "" && ds.RouterCsvDir == "" {
		return fmt.Errorf("spec.dataSources requires at least one of delayMatrixCsv / t0CsvDir / routerCsvDir")
	}
	return nil
}

// LoadDirectory 扫描目录下所有 *.yaml / *.yml 清单，按文件名排序返回
// （仅 SatelliteConstellation；混用多类型清单的目录请用 LoadDirectoryManifests）。
func LoadDirectory(dir string) ([]*SatelliteConstellation, error) {
	manifests, err := LoadDirectoryManifests(dir)
	if err != nil {
		return nil, err
	}
	var crs []*SatelliteConstellation
	for _, m := range manifests {
		if m.Kind == KindConstellation {
			crs = append(crs, m.Constellation)
		}
	}
	return crs, nil
}

// LoadDirectoryManifests 扫描目录下所有 *.yaml / *.yml 清单
// （多类型：SatelliteConstellation / Satellite / NetworkTopology /
// RemoteSensingTask / ObjectDetectionTask / JobQueue / StorageBackend），
// 按文件名排序返回统一 Manifest 包装。未知 kind 的文件直接报错。
func LoadDirectoryManifests(dir string) ([]*Manifest, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, fmt.Errorf("read config dir: %w", err)
	}
	var paths []string
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		name := e.Name()
		if strings.HasSuffix(name, ".yaml") || strings.HasSuffix(name, ".yml") {
			paths = append(paths, filepath.Join(dir, name))
		}
	}
	sort.Strings(paths)
	if len(paths) == 0 {
		return nil, fmt.Errorf("no *.yaml manifests found in %s", dir)
	}
	var ms []*Manifest
	for _, p := range paths {
		data, err := os.ReadFile(p)
		if err != nil {
			return nil, fmt.Errorf("read %s: %w", p, err)
		}
		m, err := ParseManifest(data)
		if err != nil {
			return nil, fmt.Errorf("%s: %w", p, err)
		}
		m.Path = p
		ms = append(ms, m)
	}
	return ms, nil
}

// ParseSatellite 解析单颗卫星的声明式清单（kind: Satellite）。
func ParseSatellite(data []byte) (*Satellite, error) {
	var cr Satellite
	if err := yaml.Unmarshal(data, &cr); err != nil {
		return nil, fmt.Errorf("parse yaml: %w", err)
	}
	if cr.Kind == "" {
		return nil, fmt.Errorf("missing required field: kind")
	}
	if cr.Kind != KindSatellite {
		return nil, fmt.Errorf("unsupported kind %q, expected %q", cr.Kind, KindSatellite)
	}
	if cr.APIVersion != "" && cr.APIVersion != fmt.Sprintf("%s/%s", CRDGroup, CRDVersion) {
		return nil, fmt.Errorf("unsupported apiVersion %q, expected %q", cr.APIVersion, CRDGroup+"/"+CRDVersion)
	}
	if cr.Metadata.Name == "" {
		return nil, fmt.Errorf("missing required field: metadata.name")
	}
	if err := validateSatelliteSpec(&cr.Spec); err != nil {
		return nil, fmt.Errorf("%s: %w", cr.Metadata.Name, err)
	}
	return &cr, nil
}

// validateSatelliteSpec 校验单星清单的必填字段与合法取值范围。
func validateSatelliteSpec(s *SatelliteCRSpec) error {
	if s.ScenarioName == "" {
		return fmt.Errorf("spec.scenarioName is required")
	}
	if s.SatID == "" {
		if s.PlaneIndex == nil || s.SatInPlane == nil {
			return fmt.Errorf("spec.satId is required, or provide spec.plane and spec.satInPlane")
		}
		if *s.PlaneIndex <= 0 || *s.SatInPlane <= 0 {
			return fmt.Errorf("spec.plane and spec.satInPlane must be > 0")
		}
	}
	return nil
}

// ParseRemoteSensingTask 解析遥感任务声明式清单（kind: RemoteSensingTask）。
func ParseRemoteSensingTask(data []byte) (*RemoteSensingTask, error) {
	var cr RemoteSensingTask
	if err := yaml.Unmarshal(data, &cr); err != nil {
		return nil, fmt.Errorf("parse yaml: %w", err)
	}
	if cr.Kind == "" {
		return nil, fmt.Errorf("missing required field: kind")
	}
	if cr.Kind != KindRemoteSensingTask {
		return nil, fmt.Errorf("unsupported kind %q, expected %q", cr.Kind, KindRemoteSensingTask)
	}
	if cr.APIVersion != "" && cr.APIVersion != fmt.Sprintf("%s/%s", CRDGroup, CRDVersion) {
		return nil, fmt.Errorf("unsupported apiVersion %q, expected %q", cr.APIVersion, CRDGroup+"/"+CRDVersion)
	}
	if cr.Metadata.Name == "" {
		return nil, fmt.Errorf("missing required field: metadata.name")
	}
	if err := validateRemoteSensingTaskSpec(&cr.Spec); err != nil {
		return nil, fmt.Errorf("%s: %w", cr.Metadata.Name, err)
	}
	return &cr, nil
}

// validateRemoteSensingTaskSpec 校验遥感任务清单必填字段。
func validateRemoteSensingTaskSpec(s *RemoteSensingTaskCRSpec) error {
	if s.ScenarioName == "" {
		return fmt.Errorf("spec.scenarioName is required")
	}
	if s.FilePrefix == "" {
		return fmt.Errorf("spec.filePrefix is required")
	}
	if s.InputDirectory == "" {
		return fmt.Errorf("spec.inputDirectory is required")
	}
	return nil
}

// ParseObjectDetectionTask 解析目标检测任务声明式清单（kind: ObjectDetectionTask）。
func ParseObjectDetectionTask(data []byte) (*ObjectDetectionTask, error) {
	var cr ObjectDetectionTask
	if err := yaml.Unmarshal(data, &cr); err != nil {
		return nil, fmt.Errorf("parse yaml: %w", err)
	}
	if cr.Kind == "" {
		return nil, fmt.Errorf("missing required field: kind")
	}
	if cr.Kind != KindObjectDetectionTask {
		return nil, fmt.Errorf("unsupported kind %q, expected %q", cr.Kind, KindObjectDetectionTask)
	}
	if cr.APIVersion != "" && cr.APIVersion != fmt.Sprintf("%s/%s", CRDGroup, CRDVersion) {
		return nil, fmt.Errorf("unsupported apiVersion %q, expected %q", cr.APIVersion, CRDGroup+"/"+CRDVersion)
	}
	if cr.Metadata.Name == "" {
		return nil, fmt.Errorf("missing required field: metadata.name")
	}
	if err := validateObjectDetectionTaskSpec(&cr.Spec); err != nil {
		return nil, fmt.Errorf("%s: %w", cr.Metadata.Name, err)
	}
	return &cr, nil
}

// validateObjectDetectionTaskSpec 校验目标检测任务清单必填字段。
func validateObjectDetectionTaskSpec(s *ObjectDetectionTaskCRSpec) error {
	if s.InputPath == "" {
		return fmt.Errorf("spec.inputPath is required")
	}
	return nil
}

// ParseJobQueue 解析任务队列声明式清单（kind: JobQueue）。
func ParseJobQueue(data []byte) (*JobQueue, error) {
	var cr JobQueue
	if err := yaml.Unmarshal(data, &cr); err != nil {
		return nil, fmt.Errorf("parse yaml: %w", err)
	}
	if cr.Kind == "" {
		return nil, fmt.Errorf("missing required field: kind")
	}
	if cr.Kind != KindJobQueue {
		return nil, fmt.Errorf("unsupported kind %q, expected %q", cr.Kind, KindJobQueue)
	}
	if cr.APIVersion != "" && cr.APIVersion != fmt.Sprintf("%s/%s", CRDGroup, CRDVersion) {
		return nil, fmt.Errorf("unsupported apiVersion %q, expected %q", cr.APIVersion, CRDGroup+"/"+CRDVersion)
	}
	if cr.Metadata.Name == "" {
		return nil, fmt.Errorf("missing required field: metadata.name")
	}
	if err := validateJobQueueSpec(&cr.Spec); err != nil {
		return nil, fmt.Errorf("%s: %w", cr.Metadata.Name, err)
	}
	return &cr, nil
}

// validateJobQueueSpec 校验任务队列清单必填字段与合法取值范围。
func validateJobQueueSpec(s *JobQueueSpec) error {
	if s.Stream == "" {
		return fmt.Errorf("spec.stream is required")
	}
	if s.ConsumerGroup == "" {
		return fmt.Errorf("spec.consumerGroup is required")
	}
	if s.Concurrency < 0 {
		return fmt.Errorf("spec.concurrency must be >= 0 (0 means default 1)")
	}
	if s.MaxLen < 0 {
		return fmt.Errorf("spec.maxLen must be >= 0")
	}
	if s.Mode != "" && s.Mode != "external" && s.Mode != "inprocess" {
		return fmt.Errorf("spec.mode must be external|inprocess, got %q", s.Mode)
	}
	return nil
}

// ParseStorageBackend 解析产物存储声明式清单（kind: StorageBackend）。
func ParseStorageBackend(data []byte) (*StorageBackend, error) {
	var cr StorageBackend
	if err := yaml.Unmarshal(data, &cr); err != nil {
		return nil, fmt.Errorf("parse yaml: %w", err)
	}
	if cr.Kind == "" {
		return nil, fmt.Errorf("missing required field: kind")
	}
	if cr.Kind != KindStorageBackend {
		return nil, fmt.Errorf("unsupported kind %q, expected %q", cr.Kind, KindStorageBackend)
	}
	if cr.APIVersion != "" && cr.APIVersion != fmt.Sprintf("%s/%s", CRDGroup, CRDVersion) {
		return nil, fmt.Errorf("unsupported apiVersion %q, expected %q", cr.APIVersion, CRDGroup+"/"+CRDVersion)
	}
	if cr.Metadata.Name == "" {
		return nil, fmt.Errorf("missing required field: metadata.name")
	}
	if err := validateStorageBackendSpec(&cr.Spec); err != nil {
		return nil, fmt.Errorf("%s: %w", cr.Metadata.Name, err)
	}
	return &cr, nil
}

// validateStorageBackendSpec 校验产物存储清单必填字段与合法取值范围。
func validateStorageBackendSpec(s *StorageBackendSpec) error {
	if s.Backend == "" {
		s.Backend = "nfs"
	}
	switch s.Backend {
	case "nfs":
		// nfs 模式无需额外必填字段（产物根目录可留空，由后端环境变量兜底）。
	case "minio":
		if s.Minio == nil {
			return fmt.Errorf("spec.minio is required for minio backend")
		}
		if s.Minio.Endpoint == "" {
			return fmt.Errorf("spec.minio.endpoint is required for minio backend")
		}
		if s.Minio.AccessKey == "" {
			return fmt.Errorf("spec.minio.accessKey is required for minio backend")
		}
		if s.Minio.SecretKey == "" {
			return fmt.Errorf("spec.minio.secretKey is required for minio backend")
		}
	default:
		return fmt.Errorf("spec.backend must be nfs|minio, got %q", s.Backend)
	}
	return nil
}

// ParseManifest 解析任意受支持类型的清单
// （kind 分发到 Constellation / Satellite / Topology / RemoteSensingTask /
// ObjectDetectionTask / JobQueue / StorageBackend）。
func ParseManifest(data []byte) (*Manifest, error) {
	var probe struct {
		APIVersion string `json:"apiVersion" yaml:"apiVersion"`
		Kind       string `json:"kind" yaml:"kind"`
	}
	if err := yaml.Unmarshal(data, &probe); err != nil {
		return nil, fmt.Errorf("parse yaml: %w", err)
	}
	switch probe.Kind {
	case KindConstellation:
		cr, err := Parse(data)
		if err != nil {
			return nil, err
		}
		return &Manifest{Kind: KindConstellation, Constellation: cr}, nil
	case KindSatellite:
		sat, err := ParseSatellite(data)
		if err != nil {
			return nil, err
		}
		return &Manifest{Kind: KindSatellite, Satellite: sat}, nil
	case KindTopology:
		topo, err := ParseTopology(data)
		if err != nil {
			return nil, err
		}
		return &Manifest{Kind: KindTopology, Topology: topo}, nil
	case KindRemoteSensingTask:
		rs, err := ParseRemoteSensingTask(data)
		if err != nil {
			return nil, err
		}
		return &Manifest{Kind: KindRemoteSensingTask, RemoteSensingTask: rs}, nil
	case KindObjectDetectionTask:
		od, err := ParseObjectDetectionTask(data)
		if err != nil {
			return nil, err
		}
		return &Manifest{Kind: KindObjectDetectionTask, ObjectDetectionTask: od}, nil
	case KindJobQueue:
		jq, err := ParseJobQueue(data)
		if err != nil {
			return nil, err
		}
		return &Manifest{Kind: KindJobQueue, JobQueue: jq}, nil
	case KindStorageBackend:
		sb, err := ParseStorageBackend(data)
		if err != nil {
			return nil, err
		}
		return &Manifest{Kind: KindStorageBackend, StorageBackend: sb}, nil
	default:
		return nil, fmt.Errorf("unsupported kind %q (SatelliteConstellation|Satellite|NetworkTopology|RemoteSensingTask|ObjectDetectionTask|JobQueue|StorageBackend)", probe.Kind)
	}
}
