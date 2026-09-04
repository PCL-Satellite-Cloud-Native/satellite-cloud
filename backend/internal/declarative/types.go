package declarative

// Package declarative 提供"声明式业务配置"的同步引擎（CRD 化）。
//
// 设计目标：把后端场景/星座/拓扑配置从 migration seed + CSV 导入的混合模式，
// 统一为 kubectl 风格的清单：
//   - SatelliteConstellation：场景 + 整星座 + 拓扑数据源（一体化批量基线）；
//   - Satellite：单颗卫星的精确声明（覆盖轨道参数 / 新增自定义卫星 / 显式删除）；
//   - NetworkTopology：网络拓扑数据源（时延矩阵 / T0 星历 / 路由拓扑）的独立声明，
//     使"拓扑变更"与"星座变更"解耦，可独立同步；
//   - RemoteSensingTask：遥感流水线任务的声明式创建（创建规格 CRD 化，
//     执行由 rs-worker / od-worker 沿用既有机制消费）；
//   - ObjectDetectionTask：YOLOv8 目标检测任务的声明式创建（检测规格 CRD 化，
//     执行由后端 ObjectDetectionService 启动时的 bootstrap 机制接管）；
//   - JobQueue：Redis Stream 任务队列的声明式注册（队列 CRD 化），
//     同步时幂等记录队列期望状态，并在 Redis 可达时确保 Stream + 消费者组存在；
//   - StorageBackend：产物存储的声明式注册（存储 CRD 化），
//     同步时幂等记录存储期望状态（nfs/minio、产物根目录、MinIO 连接、上传开关），
//     并在 backend=minio 时幂等确保 MinIO Bucket 存在。
// 阶段 1 不依赖 Kubernetes，本地 PG 即可运行；未来可将同一类型直接注册为
// CustomResourceDefinition（apiVersion: cloud.satellite.io/v1），
// Controller 的 Reconcile 复用本包逻辑即可。
import "strings"

// SatelliteConstellation 是"场景 + 星座 + 拓扑数据源"的声明式清单。
// 对应未来 CRD: cloud.satellite.io/v1, kind: SatelliteConstellation。
type SatelliteConstellation struct {
	APIVersion string                     `json:"apiVersion" yaml:"apiVersion"`
	Kind       string                     `json:"kind" yaml:"kind"`
	Metadata   ObjectMeta                 `json:"metadata" yaml:"metadata"`
	Spec       SatelliteConstellationSpec `json:"spec" yaml:"spec"`
}

// ObjectMeta 兼容 Kubernetes metadata 的子集。
type ObjectMeta struct {
	Name        string            `json:"name" yaml:"name"`
	Namespace   string            `json:"namespace,omitempty" yaml:"namespace,omitempty"`
	Labels      map[string]string `json:"labels,omitempty" yaml:"labels,omitempty"`
	Annotations map[string]string `json:"annotations,omitempty" yaml:"annotations,omitempty"`
}

// SatelliteConstellationSpec 定义场景与星座的期望状态。
type SatelliteConstellationSpec struct {
	// Scenario 场景元信息（对应 scenarios 表一行）。
	Scenario ScenarioSpec `json:"scenario" yaml:"scenario"`

	// Satellites 卫星声明方式。
	Satellites SatellitesSpec `json:"satellites" yaml:"satellites"`

	// Topology 可选：声明拓扑数据源（delay 矩阵 / T0 星历 / 路由拓扑 CSV），
	// 同步时复用现有 topology.Import* 逻辑（幂等 delete+insert）。
	Topology *TopologySpec `json:"topology,omitempty" yaml:"topology,omitempty"`
}

// ScenarioSpec 对应 scenarios 表字段。
type ScenarioSpec struct {
	Name          string                 `json:"name" yaml:"name"`
	Epoch         string                 `json:"epoch,omitempty" yaml:"epoch,omitempty"`
	StartTime     string                 `json:"startTime,omitempty" yaml:"startTime,omitempty"`
	EndTime       string                 `json:"endTime,omitempty" yaml:"endTime,omitempty"`
	AltKm         float64                `json:"altKm" yaml:"altKm"`
	IncDeg        float64                `json:"incDeg" yaml:"incDeg"`
	NPlanes       int                    `json:"nPlanes" yaml:"nPlanes"`
	NSatsPerPlane int                    `json:"nSatsPerPlane" yaml:"nSatsPerPlane"`
	SensorConfig  map[string]interface{} `json:"sensorConfig,omitempty" yaml:"sensorConfig,omitempty"`
}

// SatellitesSpec 声明卫星的两种模式：
//   - mode=generated: 由构型参数（nPlanes × nSatsPerPlane + 轨道参数）确定性生成
//     Walker 星座，规律与 migration seed 000003 完全一致；
//   - mode=inline:    清单内显式列出卫星（适合少量卫星的自定义场景）。
type SatellitesSpec struct {
	Mode string          `json:"mode" yaml:"mode"`
	List []SatelliteSpec `json:"list,omitempty" yaml:"list,omitempty"`
}

// SatelliteSpec 单颗卫星的显式声明（mode=inline 时使用）。
type SatelliteSpec struct {
	SatID      string  `json:"satId" yaml:"satId"`
	StkName    string  `json:"stkName,omitempty" yaml:"stkName,omitempty"`
	PlaneIndex int     `json:"plane" yaml:"plane"`
	SatInPlane int     `json:"satInPlane" yaml:"satInPlane"`
	AltKm      float64 `json:"altKm,omitempty" yaml:"altKm,omitempty"`
	SmaKm      float64 `json:"smaKm,omitempty" yaml:"smaKm,omitempty"`
	Ecc        float64 `json:"ecc,omitempty" yaml:"ecc,omitempty"`
	IncDeg     float64 `json:"incDeg,omitempty" yaml:"incDeg,omitempty"`
	RaanDeg    float64 `json:"raanDeg,omitempty" yaml:"raanDeg,omitempty"`
	ArgpDeg    float64 `json:"argpDeg,omitempty" yaml:"argpDeg,omitempty"`
	TaDeg      float64 `json:"taDeg,omitempty" yaml:"taDeg,omitempty"`
}

// TopologySpec 拓扑数据源声明（路径相对于执行目录，与 import_topology 工具一致）。
// 供两处复用：SatelliteConstellation.spec.topology（一体化声明）与
// NetworkTopology.spec.dataSources（独立声明）。
type TopologySpec struct {
	// DelayMatrixCSV 时延矩阵 CSV（如 ../frontend/public/data/delay_15x15.csv）。
	DelayMatrixCSV string `json:"delayMatrixCsv,omitempty" yaml:"delayMatrixCsv,omitempty"`
	// T0CsvDir Sat_*_ephem_ext.csv 星历目录（如 ../frontend/public/data/ephem_15）。
	T0CsvDir string `json:"t0CsvDir,omitempty" yaml:"t0CsvDir,omitempty"`
	// RouterCsvDir r??????_net_qos.csv 路由目录（如 ../frontend/public/data/router）。
	RouterCsvDir string `json:"routerCsvDir,omitempty" yaml:"routerCsvDir,omitempty"`
}

// NetworkTopologySpec 独立拓扑清单的期望状态：指定所属场景与拓扑数据源。
type NetworkTopologySpec struct {
	// ScenarioName 所属场景名（scenarios.name），必填。
	// 同步前场景必须已存在（由 SatelliteConstellation 清单创建），否则报错。
	ScenarioName string `json:"scenarioName" yaml:"scenarioName"`
	// DataSources 拓扑数据源（结构复用 TopologySpec）。
	DataSources TopologySpec `json:"dataSources" yaml:"dataSources"`
}

// NetworkTopology 是"网络拓扑数据源"的声明式清单（kind: NetworkTopology）。
// 对应未来 CRD: cloud.satellite.io/v1, kind: NetworkTopology。
//
// 与 SatelliteConstellation.spec.topology 的分工：
//   - Constellation 场景化拓扑：随星座清单批量声明（一体化，向后兼容）；
//   - NetworkTopology 独立拓扑：按场景独立声明/独立同步，解耦"拓扑变更"与"星座变更"，
//     推荐新增拓扑使用本 kind。
//
// 同步语义一致：复用 topology.Import*（幂等 delete+insert）。
type NetworkTopology struct {
	APIVersion string              `json:"apiVersion" yaml:"apiVersion"`
	Kind       string              `json:"kind" yaml:"kind"`
	Metadata   ObjectMeta          `json:"metadata" yaml:"metadata"`
	Spec       NetworkTopologySpec `json:"spec" yaml:"spec"`
}

// 支持的清单类型与版本。
const (
	CRDGroup          = "cloud.satellite.io"
	CRDVersion        = "v1"
	KindConstellation = "SatelliteConstellation"
	// KindSatellite 单颗卫星的声明式清单（星座管理 CRD 化）。
	KindSatellite = "Satellite"
	// KindTopology 网络拓扑的声明式清单（拓扑业务 CRD 化）。
	KindTopology = "NetworkTopology"
	// KindRemoteSensingTask 遥感任务的声明式清单（遥感业务 CRD 化）。
	KindRemoteSensingTask = "RemoteSensingTask"
	// KindObjectDetectionTask 目标检测任务的声明式清单（遥感业务 CRD 化）。
	KindObjectDetectionTask = "ObjectDetectionTask"
	// KindJobQueue 任务队列的声明式清单（队列基础设施 CRD 化）。
	KindJobQueue = "JobQueue"
	// KindStorageBackend 产物存储的声明式清单（存储基础设施 CRD 化）。
	KindStorageBackend = "StorageBackend"
)

// DeleteAnnotation 置为 "true" 时，ReconcileSatellite 对该卫星执行软删除。
// 语义上等价于 kubectl annotate --overwrite satellite/<name> cloud.satellite.io/delete=true。
// 删除前会检查 remote_sensing_tasks 的引用，有引用则拒绝。
const DeleteAnnotation = "cloud.satellite.io/delete"

// SatelliteGenerationModes 支持的卫星声明模式。
const (
	ModeGenerated = "generated"
	ModeInline    = "inline"
)

// Manifest 是 apply-config 扫描清单目录后得到的统一包装，按 kind 分发到
// ReconcileConstellation / ReconcileSatellite / ReconcileTopology /
// ReconcileRemoteSensingTask / ReconcileObjectDetectionTask /
// ReconcileJobQueue / ReconcileStorageBackend。
type Manifest struct {
	// Path 清单文件路径（仅用于日志与报错定位）。
	Path string
	// Kind 实际资源类型：KindConstellation / KindSatellite / KindTopology /
	// KindRemoteSensingTask / KindObjectDetectionTask / KindJobQueue /
	// KindStorageBackend。
	Kind string
	// Constellation 非 nil 当且仅当 Kind == KindConstellation。
	Constellation *SatelliteConstellation
	// Satellite 非 nil 当且仅当 Kind == KindSatellite。
	Satellite *Satellite
	// Topology 非 nil 当且仅当 Kind == KindTopology。
	Topology *NetworkTopology
	// RemoteSensingTask 非 nil 当且仅当 Kind == KindRemoteSensingTask。
	RemoteSensingTask *RemoteSensingTask
	// ObjectDetectionTask 非 nil 当且仅当 Kind == KindObjectDetectionTask。
	ObjectDetectionTask *ObjectDetectionTask
	// JobQueue 非 nil 当且仅当 Kind == KindJobQueue。
	JobQueue *JobQueue
	// StorageBackend 非 nil 当且仅当 Kind == KindStorageBackend。
	StorageBackend *StorageBackend
}

// Satellite 是"单颗卫星"的声明式清单（kind: Satellite，星座管理 CRD 化）。
//
// 与 SatelliteConstellation 的分工：
//   - SatelliteConstellation 负责"场景 + 整星座 + 拓扑"的批量期望状态；
//   - Satellite 负责单颗卫星的精确声明：新增自定义卫星、覆盖轨道参数、显式删除。
//
// spec 语义（声明式"未声明则不管理"）：
//   - scenarioName 必填，按 scenarios.name 解析所属场景；
//   - satId 与 (plane + satInPlane) 至少提供一个：给了 satId 则以其为准，
//     satId 为空时按 sat-{plane}-{satInPlane} 推导；
//   - 轨道根数为可空字段：创建时未声明的字段按所属场景构型的 Walker 规律推导，
//     更新时未声明的字段保留数据库现值。
type Satellite struct {
	APIVersion string          `json:"apiVersion" yaml:"apiVersion"`
	Kind       string          `json:"kind" yaml:"kind"`
	Metadata   ObjectMeta      `json:"metadata" yaml:"metadata"`
	Spec       SatelliteCRSpec `json:"spec" yaml:"spec"`
}

// SatelliteCRSpec 单颗卫星的期望状态。
type SatelliteCRSpec struct {
	// ScenarioName 所属场景名（scenarios.name），必填。
	ScenarioName string `json:"scenarioName" yaml:"scenarioName"`
	// SatID 卫星标识（如 sat-1-1）；与 (plane, satInPlane) 至少提供一个。
	SatID string `json:"satId,omitempty" yaml:"satId,omitempty"`
	// StkName STK 名称，缺省为 Sat_{satId}。
	StkName string `json:"stkName,omitempty" yaml:"stkName,omitempty"`
	// PlaneIndex / SatInPlane 星座定位（satId 缺省时用于推导 sat-{p}-{s}）。
	PlaneIndex *int `json:"plane,omitempty" yaml:"plane,omitempty"`
	SatInPlane *int `json:"satInPlane,omitempty" yaml:"satInPlane,omitempty"`
	// 轨道根数（可空：nil 表示未声明，按场景构型推导或保留现值）。
	AltKm   *float64 `json:"altKm,omitempty" yaml:"altKm,omitempty"`
	SmaKm   *float64 `json:"smaKm,omitempty" yaml:"smaKm,omitempty"`
	Ecc     *float64 `json:"ecc,omitempty" yaml:"ecc,omitempty"`
	IncDeg  *float64 `json:"incDeg,omitempty" yaml:"incDeg,omitempty"`
	RaanDeg *float64 `json:"raanDeg,omitempty" yaml:"raanDeg,omitempty"`
	ArgpDeg *float64 `json:"argpDeg,omitempty" yaml:"argpDeg,omitempty"`
	TaDeg   *float64 `json:"taDeg,omitempty" yaml:"taDeg,omitempty"`
}

// DeleteRequested 返回该清单是否带删除注解（cloud.satellite.io/delete=true）。
func DeleteRequested(cr *Satellite) bool {
	if cr == nil || cr.Metadata.Annotations == nil {
		return false
	}
	v, ok := cr.Metadata.Annotations[DeleteAnnotation]
	return ok && strings.EqualFold(v, "true")
}

// RemoteSensingTask 是"遥感流水线任务"的声明式清单（kind: RemoteSensingTask，
// 遥感业务 CRD 化）。
//
// 与既有 REST 入口（POST /api/remote-sensing/tasks）的分工：
//   - REST API 面向运行期的一次性创建（创建即入队执行）；
//   - 本清单面向配置期的声明式创建：spec 表达"期望存在这样一次任务"，
//     同步是幂等的（同名 + 同场景任务已存在则跳过/收敛），
//     任务的执行仍由 rs-worker / od-worker 沿用既有机制消费。
//
// spec 字段与 CreateTaskRequest 一一对应，便于复用既有校验与落库语义：
//   - scenarioName 必填，按 scenarios.name 解析所属场景；
//   - satelliteId 可选，按 (scenario_id, sat_id | stk_name) 解析目标卫星；
//   - filePrefix / inputDirectory 必填；
//   - enableDetection 缺省 true；detectionDrawLabels 缺省 false。
type RemoteSensingTask struct {
	APIVersion string                  `json:"apiVersion" yaml:"apiVersion"`
	Kind       string                  `json:"kind" yaml:"kind"`
	Metadata   ObjectMeta              `json:"metadata" yaml:"metadata"`
	Spec       RemoteSensingTaskCRSpec `json:"spec" yaml:"spec"`
}

// RemoteSensingTaskCRSpec 遥感任务的期望状态（创建规格）。
type RemoteSensingTaskCRSpec struct {
	// ScenarioName 所属场景名（scenarios.name），必填。
	ScenarioName string `json:"scenarioName" yaml:"scenarioName"`
	// SatelliteID 目标卫星（sat_id 或 stk_name，如 sat-1-1 / Sat_sat-1-1），
	// 可选；缺省时不限定卫星。
	SatelliteID string `json:"satelliteId,omitempty" yaml:"satelliteId,omitempty"`
	// FilePrefix 原始影像文件前缀，必填（如 "20251215_083000"）。
	FilePrefix string `json:"filePrefix" yaml:"filePrefix"`
	// InputDirectory 原始影像输入目录，必填。
	InputDirectory string `json:"inputDirectory" yaml:"inputDirectory"`
	// Sensor 传感器（如 MSS / PAN / MSS_PAN），可选。
	Sensor string `json:"sensor,omitempty" yaml:"sensor,omitempty"`
	// EnableDetection 是否启用 YOLOv8 目标识别，缺省 true。
	EnableDetection *bool `json:"enableDetection,omitempty" yaml:"enableDetection,omitempty"`
	// DetectionClasses 目标识别类别（逗号分隔，如 "airplane,ship"），可选。
	DetectionClasses string `json:"detectionClasses,omitempty" yaml:"detectionClasses,omitempty"`
	// DetectionDrawLabels 是否绘制检测标注框，缺省 false。
	DetectionDrawLabels *bool `json:"detectionDrawLabels,omitempty" yaml:"detectionDrawLabels,omitempty"`
}

// DeleteRequestedRemoteSensingTask 返回该清单是否带删除注解
// （cloud.satellite.io/delete=true）。删除前会检查任务是否处于 running：
// 运行中的任务拒绝删除，其余状态级联清理（stages / artifacts / logs）。
func DeleteRequestedRemoteSensingTask(cr *RemoteSensingTask) bool {
	if cr == nil || cr.Metadata.Annotations == nil {
		return false
	}
	v, ok := cr.Metadata.Annotations[DeleteAnnotation]
	return ok && strings.EqualFold(v, "true")
}

// ObjectDetectionTask 是"YOLOv8 目标检测任务"的声明式清单（kind: ObjectDetectionTask，
// 遥感业务 CRD 化）。
//
// 与既有 REST 入口（POST /api/object-detection/tasks）的分工：
//   - REST API 面向运行期的一次性创建（创建即入队执行）；
//   - 本清单面向配置期的声明式创建：spec 表达"期望存在这样一次检测任务"，
//     同步是幂等的（同名任务已存在则跳过/收敛），
//     任务的执行由后端 ObjectDetectionService 启动时的 bootstrap 机制接管
//     （与 RemoteSensingTask 由 rs-worker / od-worker 消费一致）。
//
// spec 字段与 CreateTaskRequest 一一对应，便于复用既有校验与落库语义：
//   - inputPath 必填，待检测影像（融合产物 .dat）的绝对路径；
//   - classes 可选，目标类别（逗号分隔，如 "airplane,ship"），缺省按后端配置；
//   - drawLabels 缺省 false。
type ObjectDetectionTask struct {
	APIVersion string                    `json:"apiVersion" yaml:"apiVersion"`
	Kind       string                    `json:"kind" yaml:"kind"`
	Metadata   ObjectMeta                `json:"metadata" yaml:"metadata"`
	Spec       ObjectDetectionTaskCRSpec `json:"spec" yaml:"spec"`
}

// ObjectDetectionTaskCRSpec 目标检测任务的期望状态（创建规格）。
type ObjectDetectionTaskCRSpec struct {
	// InputPath 待检测影像（融合产物 .dat）的绝对路径，必填。
	InputPath string `json:"inputPath" yaml:"inputPath"`
	// Classes 目标类别（逗号分隔，如 "airplane,ship"），可选；
	// 缺省时按后端 SATELLITE_OBJECT_DETECTION_DEFAULT_CLASSES 配置。
	Classes string `json:"classes,omitempty" yaml:"classes,omitempty"`
	// DrawLabels 是否绘制检测标注框，缺省 false。
	DrawLabels *bool `json:"drawLabels,omitempty" yaml:"drawLabels,omitempty"`
}

// DeleteRequestedObjectDetectionTask 返回该清单是否带删除注解
// （cloud.satellite.io/delete=true）。删除前会检查任务是否处于 running：
// 运行中的任务拒绝删除，其余状态级联清理（stages / artifacts / logs）。
func DeleteRequestedObjectDetectionTask(cr *ObjectDetectionTask) bool {
	if cr == nil || cr.Metadata.Annotations == nil {
		return false
	}
	v, ok := cr.Metadata.Annotations[DeleteAnnotation]
	return ok && strings.EqualFold(v, "true")
}

// JobQueue 是"任务队列"的声明式清单（kind: JobQueue，队列基础设施 CRD 化）。
//
// 与既有的"worker 启动时隐式创建队列"的分工：
//   - 既有机制：rs-worker / od-worker 启动时按环境变量隐式
//     EnsureRSGroup / EnsureODConsumerGroup，队列名与消费者组散落在部署清单；
//   - 本清单：把队列的"期望状态"（stream / 消费者组 / 并发 / 模式 / Redis 地址）
//     收敛为声明式资源，apply-config 幂等同步到 job_queues 表，
//     并在 spec.redisAddr 可达时幂等确保 Redis 中 Stream + 消费者组存在。
//
// 默认声明与迁移种子（000011_job_queues.up.sql）保持一致：
//   - rs：rs.jobs / rs-workers / rs-worker（SATELLITE_REDIS_STREAM_RS 等环境变量默认值）；
//   - od：od.jobs / od-workers / od-worker。
//
// 删除语义：带删除注解时清理 job_queues 记录，并在 redisAddr 可达时删除 Redis Stream；
// 删除前请确认没有待消费任务。
type JobQueue struct {
	APIVersion string       `json:"apiVersion" yaml:"apiVersion"`
	Kind       string       `json:"kind" yaml:"kind"`
	Metadata   ObjectMeta   `json:"metadata" yaml:"metadata"`
	Spec       JobQueueSpec `json:"spec" yaml:"spec"`
}

// JobQueueSpec 任务队列的期望状态。
type JobQueueSpec struct {
	// Name 队列逻辑名（唯一，如 rs / od）。缺省取 metadata.name。
	Name string `json:"name,omitempty" yaml:"name,omitempty"`
	// Stream Redis Stream 名（如 rs.jobs / od.jobs），必填。
	Stream string `json:"stream" yaml:"stream"`
	// ConsumerGroup 消费者组名（如 rs-workers / od-workers），必填。
	ConsumerGroup string `json:"consumerGroup" yaml:"consumerGroup"`
	// ConsumerPrefix worker 消费者名前缀（如 rs-worker）。缺省 {name}-worker。
	ConsumerPrefix string `json:"consumerPrefix,omitempty" yaml:"consumerPrefix,omitempty"`
	// Concurrency 并发消费数（>=1），缺省 1。
	Concurrency int `json:"concurrency,omitempty" yaml:"concurrency,omitempty"`
	// Mode 队列模式：external（独立 worker 消费）/ inprocess（内进程消费）。
	// 缺省 external。
	Mode string `json:"mode,omitempty" yaml:"mode,omitempty"`
	// RedisAddr Redis 地址（如 redis:6379）。非空时 apply-config 会幂等创建
	// Stream + 消费者组；为空则仅同步声明到 job_queues 表，
	// 队列仍由 worker 启动时按环境变量幂等创建。
	RedisAddr string `json:"redisAddr,omitempty" yaml:"redisAddr,omitempty"`
	// MaxLen Stream 最大长度（0 表示不限），仅对 redisAddr 非空的队列生效。
	MaxLen int64 `json:"maxLen,omitempty" yaml:"maxLen,omitempty"`
	// Enabled 启用开关，缺省 true。
	Enabled *bool `json:"enabled,omitempty" yaml:"enabled,omitempty"`
}

// DeleteRequestedJobQueue 返回该清单是否带删除注解
// （cloud.satellite.io/delete=true）。删除前请确认该队列没有待消费任务。
func DeleteRequestedJobQueue(cr *JobQueue) bool {
	if cr == nil || cr.Metadata.Annotations == nil {
		return false
	}
	v, ok := cr.Metadata.Annotations[DeleteAnnotation]
	return ok && strings.EqualFold(v, "true")
}

// StorageBackend 是"产物存储"的声明式清单（kind: StorageBackend，
// 存储基础设施 CRD 化）。
//
// 与既有"后端启动时按环境变量构造存储后端"的分工：
//   - 既有机制：服务启动时读取 SATELLITE_STORAGE_BACKEND / SATELLITE_MINIO_*
//     / SATELLITE_ARTIFACT_UPLOAD_MINIO 等环境变量构造 storage.Backend，
//     存储配置散落在部署清单；
//   - 本清单：把产物存储的"期望状态"（后端类型 nfs/minio、产物根目录、
//     MinIO 连接、产物上传开关）收敛为声明式资源，apply-config 幂等同步到
//     storage_backends 表，并在 backend=minio 且连接信息完整时幂等确保
//     MinIO Bucket 存在。
//
// 默认声明与迁移种子（000012_storage_backends.up.sql）保持一致：
//   - name=default：nfs，遥感产物根目录 /data/satellite/remote-sensing，
//     目标检测产物根目录 /data/satellite/object-detection，不上传 MinIO。
//
// 删除语义：带删除注解时清理 storage_backends 记录；
// 注意：存储声明仅登记"期望状态"，产物读写仍由运行中的后端服务负责，
// 删除声明不会删除已落盘产物。
type StorageBackend struct {
	APIVersion string              `json:"apiVersion" yaml:"apiVersion"`
	Kind       string              `json:"kind" yaml:"kind"`
	Metadata   ObjectMeta          `json:"metadata" yaml:"metadata"`
	Spec       StorageBackendSpec  `json:"spec" yaml:"spec"`
}

// StorageBackendSpec 产物存储的期望状态。
type StorageBackendSpec struct {
	// Name 存储后端逻辑名（唯一，如 default）。缺省取 metadata.name。
	Name string `json:"name,omitempty" yaml:"name,omitempty"`
	// Backend 存储后端类型：nfs | minio（缺省 nfs）。
	Backend string `json:"backend,omitempty" yaml:"backend,omitempty"`
	// RSArtifactRoot 遥感融合产物根目录（nfs 模式）。
	RSArtifactRoot string `json:"rsArtifactRoot,omitempty" yaml:"rsArtifactRoot,omitempty"`
	// ODArtifactRoot 目标检测产物根目录（nfs 模式）。
	ODArtifactRoot string `json:"odArtifactRoot,omitempty" yaml:"odArtifactRoot,omitempty"`
	// ArtifactUploadMinio 任务完成后是否将产物上传 MinIO（D0 试点），缺省 false。
	ArtifactUploadMinio bool `json:"artifactUploadMinio,omitempty" yaml:"artifactUploadMinio,omitempty"`
	// Minio MinIO 对象存储连接（backend=minio 时必填）。
	Minio *MinioSpec `json:"minio,omitempty" yaml:"minio,omitempty"`
}

// MinioSpec MinIO 对象存储连接配置。
type MinioSpec struct {
	// Endpoint MinIO 端点（如 minio:9000），必填。
	Endpoint string `json:"endpoint" yaml:"endpoint"`
	// AccessKey MinIO 访问密钥，必填。
	AccessKey string `json:"accessKey" yaml:"accessKey"`
	// SecretKey MinIO 私有密钥，必填。
	SecretKey string `json:"secretKey" yaml:"secretKey"`
	// Bucket Bucket 名，缺省 satellite-artifacts。
	Bucket string `json:"bucket,omitempty" yaml:"bucket,omitempty"`
	// Prefix 对象键统一前缀，可选。
	Prefix string `json:"prefix,omitempty" yaml:"prefix,omitempty"`
	// UseSSL 是否使用 TLS 访问 MinIO，缺省 false。
	UseSSL bool `json:"useSSL,omitempty" yaml:"useSSL,omitempty"`
}

// DeleteRequestedStorageBackend 返回该清单是否带删除注解
// （cloud.satellite.io/delete=true）。注意：仅删除声明登记，
// 不会删除已落盘的产物文件。
func DeleteRequestedStorageBackend(cr *StorageBackend) bool {
	if cr == nil || cr.Metadata.Annotations == nil {
		return false
	}
	v, ok := cr.Metadata.Annotations[DeleteAnnotation]
	return ok && strings.EqualFold(v, "true")
}
