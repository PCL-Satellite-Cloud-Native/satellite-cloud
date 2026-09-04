package declarative

// ApplyAll 按"StorageBackend → JobQueue → Constellation → Topology →
// Satellite → RemoteSensingTask → ObjectDetectionTask"的顺序同步目录下所有清单，
// 返回每份清单的结果。单份失败不影响其余清单。
//
// 执行顺序依据依赖关系：
//   - StorageBackend 最先：产物存储是任务产出的基础（nfs/minio、产物根目录、
//     上传开关），存储声明先于任务同步（minio 且连接完整时幂等确保 Bucket）；
//   - JobQueue 其次：任务队列是任务执行的基础设施（Redis Stream + 消费者组），
//     队列声明先于任务同步（RedisAddr 为空时仅登记声明，不影响 worker）；
//   - Constellation 先建场景与整星座（拓扑依赖场景存在）；
//   - Topology 独立同步拓扑数据源（仅依赖场景，不依赖单星覆盖）；
//   - Satellite 做单星覆盖/删除（不依赖拓扑）；
//   - RemoteSensingTask 创建遥感任务（依赖场景与卫星已存在）；
//   - ObjectDetectionTask 创建目标检测任务（输入影像依赖遥感融合产物，
//     故排在遥感任务之后）。
//
// 供两类入口共用：
//   - CLI：cmd/apply-config；
//   - 后端集成：POST /api/crd/sync（internal/api/handlers/crd.go）与
//     服务启动时的 SATELLITE_CRD_CONFIG_DIR 同步。
import (
	"fmt"

	"gorm.io/gorm"
)

// ApplyResult 单份清单的同步结果。
type ApplyResult struct {
	CRName string `json:"name"`
	Kind   string `json:"kind"`
	Status string `json:"status"` // ok | error
	Detail string `json:"detail,omitempty"`
}

// applyManifest 应用单份清单（按 kind 分发到对应 Reconcile）。
// 供 ApplyAll（目录批量）与 ApplyFile（单文件）共用。
func applyManifest(db *gorm.DB, m *Manifest) ApplyResult {
		switch m.Kind {
		case KindConstellation:
			res, err := ReconcileConstellation(db, m.Constellation, ReconcileOptions{})
			if err != nil {
				return ApplyResult{CRName: m.Constellation.Metadata.Name, Kind: m.Kind, Status: "error", Detail: err.Error()}
			}
			return ApplyResult{
				CRName: res.CRName,
				Kind:   m.Kind,
				Status: "ok",
				Detail: fmt.Sprintf("卫星=期望 %d 新增 %d 更新 %d 裁剪 %d 拓扑=%v",
					res.SatellitesDesired, res.SatellitesCreated, res.SatellitesUpdated, res.SatellitesPruned, res.TopologySynced),
			}
		case KindTopology:
			res, err := ReconcileTopology(db, m.Topology)
			if err != nil {
				return ApplyResult{CRName: m.Topology.Metadata.Name, Kind: m.Kind, Status: "error", Detail: err.Error()}
			}
			return ApplyResult{
				CRName: res.CRName,
				Kind:   m.Kind,
				Status: "ok",
				Detail: fmt.Sprintf("场景=%s 拓扑=%v delay=%d t0=%d router=%d/%d",
					res.Scenario, res.Synced, res.DelayEdges, res.T0States, res.RouterNodes, res.RouterLinks),
			}
		case KindSatellite:
			res, err := ReconcileSatellite(db, m.Satellite, ReconcileOptions{})
			if err != nil {
				return ApplyResult{CRName: m.Satellite.Metadata.Name, Kind: m.Kind, Status: "error", Detail: err.Error()}
			}
			detail := fmt.Sprintf("卫星=%s 动作=%s", res.SatID, res.Action)
			if res.Referenced {
				detail += " 引用拒绝=true"
			}
			return ApplyResult{CRName: res.CRName, Kind: m.Kind, Status: "ok", Detail: detail}
		case KindRemoteSensingTask:
			res, err := ReconcileRemoteSensingTask(db, m.RemoteSensingTask, ReconcileOptions{})
			if err != nil {
				return ApplyResult{CRName: m.RemoteSensingTask.Metadata.Name, Kind: m.Kind, Status: "error", Detail: err.Error()}
			}
			detail := fmt.Sprintf("任务=%s 场景=%s 动作=%s", res.TaskName, res.ScenarioName, res.Action)
			if res.Status != "" {
				detail += fmt.Sprintf(" 状态=%s", res.Status)
			}
			if res.CurrentStage != "" {
				detail += fmt.Sprintf(" 阶段=%s", res.CurrentStage)
			}
			if res.Referenced {
				detail += " 运行中拒绝删除=true"
			}
			return ApplyResult{CRName: res.CRName, Kind: m.Kind, Status: "ok", Detail: detail}
		case KindObjectDetectionTask:
			res, err := ReconcileObjectDetectionTask(db, m.ObjectDetectionTask, ReconcileOptions{})
			if err != nil {
				return ApplyResult{CRName: m.ObjectDetectionTask.Metadata.Name, Kind: m.Kind, Status: "error", Detail: err.Error()}
			}
			detail := fmt.Sprintf("任务=%s 动作=%s", res.TaskName, res.Action)
			if res.Status != "" {
				detail += fmt.Sprintf(" 状态=%s", res.Status)
			}
			if res.CurrentStage != "" {
				detail += fmt.Sprintf(" 阶段=%s", res.CurrentStage)
			}
			if res.Referenced {
				detail += " 运行中拒绝删除=true"
			}
			return ApplyResult{CRName: res.CRName, Kind: m.Kind, Status: "ok", Detail: detail}
		case KindJobQueue:
			res, err := ReconcileJobQueue(db, m.JobQueue, ReconcileOptions{})
			if err != nil {
				return ApplyResult{CRName: m.JobQueue.Metadata.Name, Kind: m.Kind, Status: "error", Detail: err.Error()}
			}
			detail := fmt.Sprintf("队列=%s stream=%s 动作=%s", res.QueueName, res.Stream, res.Action)
			if res.RedisAction != "" {
				detail += fmt.Sprintf(" redis=%s", res.RedisAction)
			}
			if res.RedisError != "" {
				detail += fmt.Sprintf(" redisError=%s", res.RedisError)
			}
			return ApplyResult{CRName: res.CRName, Kind: m.Kind, Status: "ok", Detail: detail}
		case KindStorageBackend:
			res, err := ReconcileStorageBackend(db, m.StorageBackend, ReconcileOptions{})
			if err != nil {
				return ApplyResult{CRName: m.StorageBackend.Metadata.Name, Kind: m.Kind, Status: "error", Detail: err.Error()}
			}
			detail := fmt.Sprintf("存储=%s 后端=%s 动作=%s", res.BackendName, res.Backend, res.Action)
			if res.BucketAction != "" {
				detail += fmt.Sprintf(" bucket=%s", res.BucketAction)
			}
			if res.BucketError != "" {
				detail += fmt.Sprintf(" bucketError=%s", res.BucketError)
			}
			return ApplyResult{CRName: res.CRName, Kind: m.Kind, Status: "ok", Detail: detail}
		default:
			return ApplyResult{Kind: m.Kind, Status: "error", Detail: "unsupported kind"}
	}
}

// ApplyAll 按依赖顺序同步目录下所有清单，返回每份清单的结果。
// 单份失败不影响其余清单。
func ApplyAll(db *gorm.DB, dir string) ([]ApplyResult, error) {
	manifests, err := LoadDirectoryManifests(dir)
	if err != nil {
		return nil, err
	}

	var results []ApplyResult
	// 0) StorageBackend：产物存储声明（最底层基础设施最先；
	//    minio 且连接完整时幂等确保 MinIO Bucket）。
	for _, m := range manifests {
		if m.Kind == KindStorageBackend {
			results = append(results, applyManifest(db, m))
		}
	}
	// 1) JobQueue：任务队列声明（RedisAddr 非空时幂等确保 Redis 队列）。
	for _, m := range manifests {
		if m.Kind == KindJobQueue {
			results = append(results, applyManifest(db, m))
		}
	}
	// 2) Constellation：确保场景与整星座存在（拓扑依赖场景）。
	for _, m := range manifests {
		if m.Kind == KindConstellation {
			results = append(results, applyManifest(db, m))
		}
	}
	// 3) Topology：独立拓扑数据源同步（仅依赖场景）。
	for _, m := range manifests {
		if m.Kind == KindTopology {
			results = append(results, applyManifest(db, m))
		}
	}
	// 4) Satellite：单星覆盖/删除。
	for _, m := range manifests {
		if m.Kind == KindSatellite {
			results = append(results, applyManifest(db, m))
		}
	}
	// 5) RemoteSensingTask：遥感任务声明式创建（依赖场景与卫星已存在）。
	for _, m := range manifests {
		if m.Kind == KindRemoteSensingTask {
			results = append(results, applyManifest(db, m))
		}
	}
	// 6) ObjectDetectionTask：目标检测任务声明式创建（输入影像依赖遥感融合产物）。
	for _, m := range manifests {
		if m.Kind == KindObjectDetectionTask {
			results = append(results, applyManifest(db, m))
		}
	}
	return results, nil
}
