// apply-config 是"声明式业务配置"同步 CLI（CRD 化）。
//
// 读取目录下的声明式清单（kubectl 风格 YAML），按 kind 分发并幂等同步到 PostgreSQL：
//   - SatelliteConstellation：场景 + 整星座 + 拓扑数据源（一体化批量基线）；
//   - NetworkTopology：网络拓扑数据源（时延矩阵 / T0 星历 / 路由拓扑）的独立声明；
//   - Satellite：单颗卫星的精确管理（覆盖轨道参数 / 新增自定义卫星 / 显式删除）；
//   - RemoteSensingTask：遥感流水线任务的声明式创建（同名同场景幂等，删除用注解）；
//   - ObjectDetectionTask：YOLOv8 目标检测任务的声明式创建（同名幂等，删除用注解，
//     执行由后端 ObjectDetectionService 启动时的 bootstrap 机制接管）；
//   - JobQueue：任务队列的声明式注册（幂等同步到 job_queues 表，
//     spec.redisAddr 非空时同时确保 Redis 中 Stream + 消费者组存在）；
//   - StorageBackend：产物存储的声明式注册（幂等同步到 storage_backends 表，
//     backend=minio 且连接信息完整时同时确保 MinIO Bucket 存在）。
//
// 用法（在 backend 目录下执行）：
//
//	export SATELLITE_DATABASE_URL="postgres://user:pass@localhost:5432/postgres?sslmode=disable"
//
//	# 预览计划（不写库）
//	go run ./cmd/apply-config -config-dir config/declarative -dry-run
//
//	# 正式同步（幂等，可重复执行）
//	go run ./cmd/apply-config -config-dir config/declarative
//
//	# 收敛：删除 Constellation 清单未声明的卫星（默认不删，保护任务引用）
//	go run ./cmd/apply-config -prune-satellites
//
//	# 单星删除：在 Satellite 清单的 metadata.annotations 中标注
//	#   cloud.satellite.io/delete: "true" 后执行本命令
package main

import (
	"flag"
	"fmt"
	"log"
	"net/url"
	"os"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"

	"satellite-cloud/backend/internal/declarative"
)

// dsnFromEnv 从 SATELLITE_DATABASE_* 环境变量组装 DSN，便于与 backend 使用相同的 Secret。
func dsnFromEnv() string {
	host := os.Getenv("SATELLITE_DATABASE_HOST")
	port := os.Getenv("SATELLITE_DATABASE_PORT")
	user := os.Getenv("SATELLITE_DATABASE_USER")
	pass := os.Getenv("SATELLITE_DATABASE_PASSWORD")
	dbname := os.Getenv("SATELLITE_DATABASE_DBNAME")
	sslmode := os.Getenv("SATELLITE_DATABASE_SSLMODE")
	if host == "" || user == "" || dbname == "" {
		return ""
	}
	if port == "" {
		port = "5432"
	}
	if sslmode == "" {
		sslmode = "disable"
	}
	u := url.URL{
		Scheme:   "postgres",
		User:     url.UserPassword(user, pass),
		Host:     host + ":" + port,
		Path:     "/" + dbname,
		RawQuery: "sslmode=" + url.QueryEscape(sslmode),
	}
	return u.String()
}

func main() {
	var (
		configDir string
		dsn       string
		prune     bool
		dryRun    bool
	)
	flag.StringVar(&configDir, "config-dir", "config/declarative", "声明式清单目录（*.yaml）")
	flag.StringVar(&dsn, "dsn", "", "PostgreSQL DSN（未填时用 SATELLITE_DATABASE_URL 或 SATELLITE_DATABASE_* 组装）")
	flag.BoolVar(&prune, "prune-satellites", false, "删除 Constellation 清单未声明的卫星（软删除，保护任务引用）")
	flag.BoolVar(&dryRun, "dry-run", false, "只打印将执行的同步计划，不写库")
	flag.Parse()

	if dsn == "" {
		dsn = os.Getenv("SATELLITE_DATABASE_URL")
	}
	if dsn == "" {
		dsn = dsnFromEnv()
	}
	if dsn == "" {
		log.Fatalf("必须通过 -dsn、SATELLITE_DATABASE_URL 或 SATELLITE_DATABASE_HOST/USER/PASSWORD/DBNAME 提供数据库连接")
	}

	manifests, err := declarative.LoadDirectoryManifests(configDir)
	if err != nil {
		log.Fatalf("加载清单失败: %v", err)
	}

	// dry-run 模式不连库；正式同步前建立连接（process 闭包内使用）。
	var db *gorm.DB
	if !dryRun {
		db, err = gorm.Open(postgres.Open(dsn), &gorm.Config{})
		if err != nil {
			log.Fatalf("连接数据库失败: %v", err)
		}
	}

	// 执行顺序固定为"StorageBackend → JobQueue → Constellation → Topology →
	// Satellite → RemoteSensingTask → ObjectDetectionTask"，使"细节覆盖批量"的语义与清单文件顺序无关：
	//   - StorageBackend 最先：产物存储是任务产出的基础设施（nfs/minio、
	//     产物根目录、上传开关；minio 且连接完整时幂等确保 Bucket）；
	//   - JobQueue 其次：任务队列是任务执行的基础设施（Redis Stream + 消费者组）；
	//   - Constellation 先建场景（拓扑依赖场景存在）；
	//   - Topology 随后独立同步拓扑数据源；
	//   - Satellite 再做单星覆盖（避免被整星座 upsert 还原）；
	//   - RemoteSensingTask 创建遥感任务（依赖场景与卫星已存在）；
	//   - ObjectDetectionTask 最后创建目标检测任务（输入影像依赖遥感融合产物）。
	process := func(m *declarative.Manifest) bool {
		switch m.Kind {
		case declarative.KindConstellation:
			cr := m.Constellation
			if dryRun {
				n, err := declarative.DesiredSatellites(cr.Spec)
				if err != nil {
					log.Printf("  [dry-run] %s -> 错误: %v", cr.Metadata.Name, err)
					return false
				}
				topo := ""
				if cr.Spec.Topology != nil {
					topo = "(delay/t0/router 按 spec.topology 同步)"
				}
				log.Printf("  [dry-run] %s -> scenario=%s 期望卫星=%d %s",
					cr.Metadata.Name, cr.Spec.Scenario.Name, len(n), topo)
				return true
			}
			res, err := declarative.ReconcileConstellation(db, cr, declarative.ReconcileOptions{
				PruneSatellites: prune,
			})
			if err != nil {
				log.Printf("[%s] 同步失败: %v", cr.Metadata.Name, err)
				return false
			}
			log.Printf("[%s] scenario=%s(id=%d) 卫星 新增=%d 更新=%d 裁剪=%d 拓扑=%v",
				res.CRName, res.Scenario, res.ScenarioID,
				res.SatellitesCreated, res.SatellitesUpdated, res.SatellitesPruned, res.TopologySynced)
			return true
		case declarative.KindTopology:
			t := m.Topology
			if dryRun {
				log.Printf("  [dry-run] %s -> 场景=%s 拓扑数据源(delay=%s t0=%s router=%s)",
					t.Metadata.Name, t.Spec.ScenarioName,
					t.Spec.DataSources.DelayMatrixCSV, t.Spec.DataSources.T0CsvDir, t.Spec.DataSources.RouterCsvDir)
				return true
			}
			res, err := declarative.ReconcileTopology(db, t)
			if err != nil {
				log.Printf("[%s] 同步失败: %v", t.Metadata.Name, err)
				return false
			}
			log.Printf("[%s] 场景=%s(id=%d) 拓扑=%v delay=%d t0=%d router=%d/%d",
				res.CRName, res.Scenario, res.ScenarioID, res.Synced,
				res.DelayEdges, res.T0States, res.RouterNodes, res.RouterLinks)
			return true
		case declarative.KindSatellite:
			s := m.Satellite
			if dryRun {
				if declarative.DeleteRequested(s) {
					log.Printf("  [dry-run] %s -> 删除卫星 %s@%s (delete 注解)",
						s.Metadata.Name, s.Spec.SatID, s.Spec.ScenarioName)
				} else {
					log.Printf("  [dry-run] %s -> 卫星 %s@%s upsert",
						s.Metadata.Name, s.Spec.SatID, s.Spec.ScenarioName)
				}
				return true
			}
			res, err := declarative.ReconcileSatellite(db, s, declarative.ReconcileOptions{})
			if err != nil {
				log.Printf("[%s] 同步失败: %v", s.Metadata.Name, err)
				return false
			}
			log.Printf("[%s] scenario=%s(id=%d) 卫星=%s 动作=%s 引用拒绝=%v",
				res.CRName, res.ScenarioName, res.ScenarioID, res.SatID, res.Action, res.Referenced)
			return true
		case declarative.KindRemoteSensingTask:
			rs := m.RemoteSensingTask
			if dryRun {
				if declarative.DeleteRequestedRemoteSensingTask(rs) {
					log.Printf("  [dry-run] %s -> 删除任务 %s@%s (delete 注解)",
						rs.Metadata.Name, rs.Metadata.Name, rs.Spec.ScenarioName)
				} else {
					log.Printf("  [dry-run] %s -> 任务 %s@%s 创建(scenario=%s satellite=%s filePrefix=%s)",
						rs.Metadata.Name, rs.Metadata.Name, rs.Spec.ScenarioName,
						rs.Spec.ScenarioName, rs.Spec.SatelliteID, rs.Spec.FilePrefix)
				}
				return true
			}
			res, err := declarative.ReconcileRemoteSensingTask(db, rs, declarative.ReconcileOptions{})
			if err != nil {
				log.Printf("[%s] 同步失败: %v", rs.Metadata.Name, err)
				return false
			}
			log.Printf("[%s] 场景=%s(id=%d) 任务=%s 动作=%s 状态=%s 阶段=%s",
				res.CRName, res.ScenarioName, res.ScenarioID, res.TaskName,
				res.Action, res.Status, res.CurrentStage)
			return true
		case declarative.KindObjectDetectionTask:
			od := m.ObjectDetectionTask
			if dryRun {
				if declarative.DeleteRequestedObjectDetectionTask(od) {
					log.Printf("  [dry-run] %s -> 删除检测任务 %s (delete 注解)",
						od.Metadata.Name, od.Metadata.Name)
				} else {
					log.Printf("  [dry-run] %s -> 检测任务 %s 创建(inputPath=%s classes=%s)",
						od.Metadata.Name, od.Metadata.Name, od.Spec.InputPath, od.Spec.Classes)
				}
				return true
			}
			res, err := declarative.ReconcileObjectDetectionTask(db, od, declarative.ReconcileOptions{})
			if err != nil {
				log.Printf("[%s] 同步失败: %v", od.Metadata.Name, err)
				return false
			}
			log.Printf("[%s] 任务=%s 动作=%s 状态=%s 阶段=%s",
				res.CRName, res.TaskName, res.Action, res.Status, res.CurrentStage)
			return true
		case declarative.KindJobQueue:
			jq := m.JobQueue
			if dryRun {
				name := jq.Spec.Name
				if name == "" {
					name = jq.Metadata.Name
				}
				if declarative.DeleteRequestedJobQueue(jq) {
					log.Printf("  [dry-run] %s -> 删除队列 %s stream=%s (delete 注解)",
						jq.Metadata.Name, name, jq.Spec.Stream)
				} else {
					log.Printf("  [dry-run] %s -> 队列 %s stream=%s group=%s 并发=%d 模式=%s redis=%s",
						jq.Metadata.Name, name, jq.Spec.Stream, jq.Spec.ConsumerGroup,
						jq.Spec.Concurrency, jq.Spec.Mode, jq.Spec.RedisAddr)
				}
				return true
			}
			res, err := declarative.ReconcileJobQueue(db, jq, declarative.ReconcileOptions{})
			if err != nil {
				log.Printf("[%s] 同步失败: %v", jq.Metadata.Name, err)
				return false
			}
			log.Printf("[%s] 队列=%s stream=%s 动作=%s redis=%s%s",
				res.CRName, res.QueueName, res.Stream, res.Action, res.RedisAction,
				redisErrSuffix(res.RedisError))
			return true
		case declarative.KindStorageBackend:
			sb := m.StorageBackend
			if dryRun {
				name := sb.Spec.Name
				if name == "" {
					name = sb.Metadata.Name
				}
				if declarative.DeleteRequestedStorageBackend(sb) {
					log.Printf("  [dry-run] %s -> 删除存储声明 %s (delete 注解)",
						sb.Metadata.Name, name)
				} else {
					bucket := ""
					if sb.Spec.Minio != nil {
						bucket = sb.Spec.Minio.Bucket
					}
					log.Printf("  [dry-run] %s -> 存储 %s 后端=%s root(rs/od)=%s/%s 上传MinIO=%v bucket=%s",
						sb.Metadata.Name, name, sb.Spec.Backend,
						sb.Spec.RSArtifactRoot, sb.Spec.ODArtifactRoot,
						sb.Spec.ArtifactUploadMinio, bucket)
				}
				return true
			}
			res, err := declarative.ReconcileStorageBackend(db, sb, declarative.ReconcileOptions{})
			if err != nil {
				log.Printf("[%s] 同步失败: %v", sb.Metadata.Name, err)
				return false
			}
			log.Printf("[%s] 存储=%s 后端=%s 动作=%s bucket=%s%s",
				res.CRName, res.BackendName, res.Backend, res.Action, res.BucketAction,
				bucketErrSuffix(res.BucketError))
			return true
		}
		return false
	}

	ok := 0
	// 第零遍：StorageBackend（产物存储基础设施）
	for _, m := range manifests {
		if m.Kind == declarative.KindStorageBackend && process(m) {
			ok++
		}
	}
	// 第一遍：JobQueue（任务队列基础设施）
	for _, m := range manifests {
		if m.Kind == declarative.KindJobQueue && process(m) {
			ok++
		}
	}
	// 第二遍：Constellation（批量基线）
	for _, m := range manifests {
		if m.Kind == declarative.KindConstellation && process(m) {
			ok++
		}
	}
	// 第三遍：Topology（独立拓扑，依赖场景存在）
	for _, m := range manifests {
		if m.Kind == declarative.KindTopology && process(m) {
			ok++
		}
	}
	// 第四遍：Satellite（细粒度覆盖）
	for _, m := range manifests {
		if m.Kind == declarative.KindSatellite && process(m) {
			ok++
		}
	}
	// 第五遍：RemoteSensingTask（遥感任务声明式创建，依赖场景与卫星已存在）
	for _, m := range manifests {
		if m.Kind == declarative.KindRemoteSensingTask && process(m) {
			ok++
		}
	}
	// 第六遍：ObjectDetectionTask（目标检测任务声明式创建，输入影像依赖遥感融合产物）
	for _, m := range manifests {
		if m.Kind == declarative.KindObjectDetectionTask && process(m) {
			ok++
		}
	}
	if dryRun {
		log.Printf("dry-run: 共 %d 份清单，仅预览不写库", len(manifests))
		return
	}
	if ok < len(manifests) {
		log.Fatalf("部分清单同步失败: %d/%d", ok, len(manifests))
	}
	log.Printf("完成: %d 份清单已同步", ok)
}

// redisErrSuffix 拼接 Redis 告警信息（为空时返回空串）。
func redisErrSuffix(redisErr string) string {
	if redisErr == "" {
		return ""
	}
	return fmt.Sprintf(" redisError=%s", redisErr)
}

// bucketErrSuffix 拼接 MinIO Bucket 确保失败信息（为空时返回空串）。
func bucketErrSuffix(bucketErr string) string {
	if bucketErr == "" {
		return ""
	}
	return fmt.Sprintf(" bucketError=%s", bucketErr)
}
