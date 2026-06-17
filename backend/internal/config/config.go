package config

import (
	"fmt"
	"net/url"
	"os"
	"path"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"

	"github.com/spf13/viper"
	"github.com/subosito/gotenv"
)

type Config struct {
	Server          ServerConfig
	Database        DatabaseConfig
	Log             LogConfig
	Queue           QueueConfig
	RemoteSensing   RemoteSensingConfig
	ObjectDetection ObjectDetectionConfig
}

type ServerConfig struct {
	Port int
	Mode string // development, production
}

type DatabaseConfig struct {
	Host     string
	Port     int
	User     string
	Password string
	DBName   string
	SSLMode  string
	MaxConns int
}

type LogConfig struct {
	Level  string // debug, info, warn, error
	Output string // stdout, file path
}

// QueueConfig Redis Stream 与 Phase 1 流水线开关
type QueueConfig struct {
	RedisAddr            string
	StreamRS             string
	StreamOD             string
	ConsumerGroup        string
	RSWorkerConcurrency  int
	UseInProcessPipeline bool
}

type RemoteSensingConfig struct {
	RootPath              string
	PythonBin             string
	DemFile               string
	Device                string
	PersistOutputDir      string
	StageTimeoutSec       int
	FusionStageTimeoutSec int
	FusionBlockSize       int
	FusionGDALThreads     string
	StageMaxRetries       int
	CommandHeartbeatSec   int
	WorkerConcurrency     int
	WorkerQueueSize       int
	PanRPCParallel        int
	PansharpenPar         int
	PanRPCCPUThreads      int
	PanRPCWarpMemMB       int
	PanRPCMaxTotalWarpMB  int
	PanRPCResampleAlg     string
	PansharpenMode        string
	PansharpenGDALThread  string
	CoregisterMode        string
	CoregisterGDALThreads string
	FusionDirectEnabled   bool
}

type ObjectDetectionConfig struct {
	RootPath            string
	RunnerPath          string
	Device              string
	DefaultClasses      string
	OutputSubdir        string
	StageTimeoutSec     int
	StageMaxRetries     int
	CommandHeartbeatSec int
	WorkerConcurrency   int
	WorkerQueueSize     int
}

// UseCPU 当 device 不为 gpu 时使用 CPU 推理（本地默认 cpu；服务器 GPU 就绪后设 SATELLITE_OBJECT_DETECTION_DEVICE=gpu）
func (c ObjectDetectionConfig) UseCPU() bool {
	return strings.ToLower(strings.TrimSpace(c.Device)) != "gpu"
}

func Load() *Config {
	// 可选：加载 .env 到环境变量（本地开发用；K8s 下通常无此文件，由 ConfigMap/Secret 注入 env）
	_ = gotenv.Load(".env")

	viper.SetConfigName("config")
	viper.SetConfigType("yaml")
	viper.AddConfigPath(".")
	viper.AddConfigPath("./config")
	viper.AddConfigPath("/etc/satellite")

	// 环境变量（优先级高于配置文件，K8s 部署时用 Secret/ConfigMap 注入）
	viper.SetEnvPrefix("SATELLITE")
	viper.AutomaticEnv()

	// 默认值
	setDefaults()

	// 读取配置文件（可选）
	if err := viper.ReadInConfig(); err != nil {
		fmt.Printf("Warning: Config file not found, using defaults and environment variables: %v\n", err)
	}

	config := &Config{
		Server: ServerConfig{
			Port: viper.GetInt("server.port"),
			Mode: viper.GetString("server.mode"),
		},
		Database: dbConfigFromEnvOrViper(),
		Log: LogConfig{
			Level:  viper.GetString("log.level"),
			Output: viper.GetString("log.output"),
		},
		Queue:           queueConfigFromEnvOrViper(),
		RemoteSensing:   remoteSensingConfigFromEnvOrViper(),
		ObjectDetection: objectDetectionConfigFromEnvOrViper(),
	}

	return config
}

// dbConfigFromEnvOrViper 优先使用 K8s 注入的 SATELLITE_DATABASE_* 环境变量
func dbConfigFromEnvOrViper() DatabaseConfig {
	get := func(envKey, viperKey string, defaultVal string) string {
		if v := os.Getenv(envKey); v != "" {
			return v
		}
		if v := viper.GetString(viperKey); v != "" {
			return v
		}
		return defaultVal
	}
	getInt := func(envKey, viperKey string, defaultVal int) int {
		if v := os.Getenv(envKey); v != "" {
			if i, err := strconv.Atoi(v); err == nil {
				return i
			}
		}
		if v := viper.GetInt(viperKey); v != 0 || viper.IsSet(viperKey) {
			return v
		}
		return defaultVal
	}
	return DatabaseConfig{
		Host:     get("SATELLITE_DATABASE_HOST", "database.host", "localhost"),
		Port:     getInt("SATELLITE_DATABASE_PORT", "database.port", 5432),
		User:     get("SATELLITE_DATABASE_USER", "database.user", "satellite_user"),
		Password: get("SATELLITE_DATABASE_PASSWORD", "database.password", "satellite_pass"),
		DBName:   get("SATELLITE_DATABASE_DBNAME", "database.dbname", "satellite_db"),
		SSLMode:  get("SATELLITE_DATABASE_SSLMODE", "database.sslmode", "disable"),
		MaxConns: getInt("SATELLITE_DATABASE_MAXCONNS", "database.max_conns", 10),
	}
}

func setDefaults() {
	// Server defaults
	viper.SetDefault("server.port", 8080)
	viper.SetDefault("server.mode", "development")

	// Database defaults
	viper.SetDefault("database.host", "localhost")
	viper.SetDefault("database.port", 5432)
	viper.SetDefault("database.user", "satellite_user")
	viper.SetDefault("database.password", "satellite_pass")
	viper.SetDefault("database.dbname", "satellite_db")
	viper.SetDefault("database.sslmode", "disable")
	viper.SetDefault("database.max_conns", 10)

	// Log defaults
	viper.SetDefault("log.level", "info")
	viper.SetDefault("log.output", "stdout")

	// Remote sensing defaults
	viper.SetDefault("remote_sensing.root", "../Satellite-Remote-Sensing")
	viper.SetDefault("remote_sensing.python", "python3")
	viper.SetDefault("remote_sensing.dem_file", "")
	viper.SetDefault("remote_sensing.device", "cpu")
	viper.SetDefault("remote_sensing.persist_output_dir", "persist_output_preprocessing")
	viper.SetDefault("remote_sensing.stage_timeout_seconds", 1800)
	viper.SetDefault("remote_sensing.fusion_stage_timeout_seconds", 1500)
	viper.SetDefault("remote_sensing.fusion_block_size", 2048)
	viper.SetDefault("remote_sensing.fusion_gdal_threads", "2")
	viper.SetDefault("remote_sensing.stage_max_retries", 1)
	viper.SetDefault("remote_sensing.command_heartbeat_seconds", 60)
	viper.SetDefault("remote_sensing.worker_concurrency", 1)
	viper.SetDefault("remote_sensing.worker_queue_size", 64)
	viper.SetDefault("remote_sensing.pan_rpc_parallelism", 2)
	viper.SetDefault("remote_sensing.pansharpen_parallelism", 3)
	viper.SetDefault("remote_sensing.pan_rpc_cpu_threads", 1)
	viper.SetDefault("remote_sensing.pan_rpc_warp_mem_mb", 1024)
	viper.SetDefault("remote_sensing.pan_rpc_max_total_warp_mem_mb", 2048)
	viper.SetDefault("remote_sensing.pan_rpc_resample_alg", "near")
	viper.SetDefault("remote_sensing.pansharpen_mode", "parallel")
	viper.SetDefault("remote_sensing.pansharpen_gdal_threads", "1")
	viper.SetDefault("remote_sensing.coregister_mode", "serial4")
	viper.SetDefault("remote_sensing.coregister_gdal_threads", "2")
	viper.SetDefault("remote_sensing.fusion_direct_enabled", true)

	viper.SetDefault("object_detection.root", "../Object-Detection")
	viper.SetDefault("object_detection.runner", "")
	viper.SetDefault("object_detection.device", "cpu")
	viper.SetDefault("object_detection.default_classes", "")
	viper.SetDefault("object_detection.output_subdir", "output_detection")
	viper.SetDefault("object_detection.stage_timeout_seconds", 14400)
	viper.SetDefault("object_detection.stage_max_retries", 0)
	viper.SetDefault("object_detection.command_heartbeat_seconds", 60)
	viper.SetDefault("object_detection.worker_concurrency", 1)
	viper.SetDefault("object_detection.worker_queue_size", 64)

	viper.SetDefault("queue.redis_addr", "localhost:6379")
	viper.SetDefault("queue.stream_rs", "rs.jobs")
	viper.SetDefault("queue.stream_od", "od.jobs")
	viper.SetDefault("queue.consumer_group", "rs-workers")
	viper.SetDefault("queue.rs_worker_concurrency", 1)
	viper.SetDefault("queue.use_inprocess_pipeline", true)
}

func queueConfigFromEnvOrViper() QueueConfig {
	get := func(envKey, viperKey, defaultVal string) string {
		if v := os.Getenv(envKey); v != "" {
			return v
		}
		if v := viper.GetString(viperKey); v != "" {
			return v
		}
		return defaultVal
	}
	return QueueConfig{
		RedisAddr:            get("SATELLITE_REDIS_ADDR", "queue.redis_addr", "localhost:6379"),
		StreamRS:             get("SATELLITE_REDIS_STREAM_RS", "queue.stream_rs", "rs.jobs"),
		StreamOD:             get("SATELLITE_REDIS_STREAM_OD", "queue.stream_od", "od.jobs"),
		ConsumerGroup:        get("SATELLITE_REDIS_CONSUMER_GROUP", "queue.consumer_group", "rs-workers"),
		RSWorkerConcurrency:  getInt("SATELLITE_RS_WORKER_CONCURRENCY", "queue.rs_worker_concurrency", 1),
		UseInProcessPipeline: getBool("SATELLITE_USE_INPROCESS_PIPELINE", "queue.use_inprocess_pipeline", true),
	}
}

func remoteSensingConfigFromEnvOrViper() RemoteSensingConfig {
	get := func(envKey, viperKey, defaultVal string) string {
		if v := os.Getenv(envKey); v != "" {
			return v
		}
		if v := viper.GetString(viperKey); v != "" {
			return v
		}
		return defaultVal
	}

	rootPath := normalizePath(get("SATELLITE_REMOTE_SENSING_ROOT", "remote_sensing.root", "../Satellite-Remote-Sensing"))
	pythonBin := get("SATELLITE_REMOTE_SENSING_PYTHON", "remote_sensing.python", "")
	demFile := normalizePath(get("SATELLITE_REMOTE_SENSING_DEM_FILE", "remote_sensing.dem_file", ""))
	device := strings.ToLower(strings.TrimSpace(get("SATELLITE_REMOTE_SENSING_DEVICE", "remote_sensing.device", "cpu")))
	if device != "cpu" && device != "gpu" && device != "auto" {
		device = "cpu"
	}
	persistOutputDir := filepath.Clean(get("SATELLITE_REMOTE_SENSING_PERSIST_OUTPUT_DIR", "remote_sensing.persist_output_dir", "persist_output_preprocessing"))
	stageTimeoutSec := getInt("SATELLITE_REMOTE_SENSING_STAGE_TIMEOUT_SECONDS", "remote_sensing.stage_timeout_seconds", 1800)
	fusionStageTimeoutSec := getInt("SATELLITE_REMOTE_SENSING_FUSION_STAGE_TIMEOUT_SECONDS", "remote_sensing.fusion_stage_timeout_seconds", 1500)
	fusionBlockSize := getInt("SATELLITE_REMOTE_SENSING_FUSION_BLOCK_SIZE", "remote_sensing.fusion_block_size", 2048)
	fusionGDALThreads := get("SATELLITE_REMOTE_SENSING_FUSION_GDAL_THREADS", "remote_sensing.fusion_gdal_threads", "2")
	stageMaxRetries := getInt("SATELLITE_REMOTE_SENSING_STAGE_MAX_RETRIES", "remote_sensing.stage_max_retries", 1)
	commandHeartbeatSec := getInt("SATELLITE_REMOTE_SENSING_COMMAND_HEARTBEAT_SECONDS", "remote_sensing.command_heartbeat_seconds", 60)
	workerConcurrency := getInt("SATELLITE_REMOTE_SENSING_WORKER_CONCURRENCY", "remote_sensing.worker_concurrency", 1)
	workerQueueSize := getInt("SATELLITE_REMOTE_SENSING_WORKER_QUEUE_SIZE", "remote_sensing.worker_queue_size", 64)
	panRPCParallel := getInt("SATELLITE_REMOTE_SENSING_PAN_RPC_PARALLELISM", "remote_sensing.pan_rpc_parallelism", 2)
	pansharpenParallel := getInt("SATELLITE_REMOTE_SENSING_PANSHARPEN_PARALLELISM", "remote_sensing.pansharpen_parallelism", 3)
	panRPCCPUThreads := getInt("SATELLITE_REMOTE_SENSING_PAN_RPC_CPU_THREADS", "remote_sensing.pan_rpc_cpu_threads", 1)
	panRPCWarpMemMB := getInt("SATELLITE_REMOTE_SENSING_PAN_RPC_WARP_MEM_MB", "remote_sensing.pan_rpc_warp_mem_mb", 1024)
	panRPCMaxTotalWarpMB := getInt("SATELLITE_REMOTE_SENSING_PAN_RPC_MAX_TOTAL_WARP_MEM_MB", "remote_sensing.pan_rpc_max_total_warp_mem_mb", 2048)
	panRPCResampleAlg := get("SATELLITE_REMOTE_SENSING_PAN_RPC_RESAMPLE_ALG", "remote_sensing.pan_rpc_resample_alg", "near")
	pansharpenMode := strings.ToLower(strings.TrimSpace(get("SATELLITE_REMOTE_SENSING_PANSHARPEN_MODE", "remote_sensing.pansharpen_mode", "parallel")))
	if pansharpenMode != "parallel" && pansharpenMode != "batch" {
		pansharpenMode = "parallel"
	}
	pansharpenGDALThreads := get("SATELLITE_REMOTE_SENSING_PANSHARPEN_GDAL_THREADS", "remote_sensing.pansharpen_gdal_threads", "1")
	coregisterMode := strings.ToLower(strings.TrimSpace(get("SATELLITE_REMOTE_SENSING_COREGISTER_MODE", "remote_sensing.coregister_mode", "serial4")))
	if coregisterMode != "serial4" && coregisterMode != "batch1" {
		coregisterMode = "serial4"
	}
	coregisterGDALThreads := get("SATELLITE_REMOTE_SENSING_COREGISTER_GDAL_THREADS", "remote_sensing.coregister_gdal_threads", "2")
	fusionDirectEnabled := getBool("SATELLITE_REMOTE_SENSING_FUSION_DIRECT_ENABLED", "remote_sensing.fusion_direct_enabled", true)
	if pythonBin == "" {
		// 本地开发优先使用遥感项目虚拟环境，避免依赖装在 .venv 但后端仍调用系统 python3。
		venvPython := filepath.Join(rootPath, ".venv", "bin", "python")
		if stat, err := os.Stat(venvPython); err == nil && !stat.IsDir() {
			pythonBin = venvPython
		} else {
			pythonBin = "python3"
		}
	}
	if demFile == "" {
		// 兼容历史行为：未显式配置 DEM 时仍尝试使用脚本目录下默认文件。
		demFile = filepath.Join(rootPath, "GMTED2010.jp2")
	}

	return RemoteSensingConfig{
		RootPath: rootPath,
		PythonBin:             pythonBin,
		DemFile:               demFile,
		Device:                device,
		PersistOutputDir:      persistOutputDir,
		StageTimeoutSec:       stageTimeoutSec,
		FusionStageTimeoutSec: fusionStageTimeoutSec,
		FusionBlockSize:       fusionBlockSize,
		FusionGDALThreads:     fusionGDALThreads,
		StageMaxRetries:       stageMaxRetries,
		CommandHeartbeatSec:   commandHeartbeatSec,
		WorkerConcurrency:     workerConcurrency,
		WorkerQueueSize:       workerQueueSize,
		PanRPCParallel:        panRPCParallel,
		PansharpenPar:         pansharpenParallel,
		PanRPCCPUThreads:      panRPCCPUThreads,
		PanRPCWarpMemMB:       panRPCWarpMemMB,
		PanRPCMaxTotalWarpMB:  panRPCMaxTotalWarpMB,
		PanRPCResampleAlg:     panRPCResampleAlg,
		PansharpenMode:        pansharpenMode,
		PansharpenGDALThread:  pansharpenGDALThreads,
		CoregisterMode:        coregisterMode,
		CoregisterGDALThreads: coregisterGDALThreads,
		FusionDirectEnabled:   fusionDirectEnabled,
	}
}

func objectDetectionConfigFromEnvOrViper() ObjectDetectionConfig {
	get := func(envKey, viperKey, defaultVal string) string {
		if v := os.Getenv(envKey); v != "" {
			return v
		}
		if v := viper.GetString(viperKey); v != "" {
			return v
		}
		return defaultVal
	}

	rootPath := normalizePath(get("SATELLITE_OBJECT_DETECTION_ROOT", "object_detection.root", "../Object-Detection"))
	runnerPath := get("SATELLITE_OBJECT_DETECTION_RUNNER", "object_detection.runner", "")
	device := strings.ToLower(strings.TrimSpace(get("SATELLITE_OBJECT_DETECTION_DEVICE", "object_detection.device", "cpu")))
	if device != "cpu" && device != "gpu" {
		device = "cpu"
	}
	defaultClasses := get("SATELLITE_OBJECT_DETECTION_DEFAULT_CLASSES", "object_detection.default_classes", "")
	outputSubdir := filepath.Clean(get("SATELLITE_OBJECT_DETECTION_OUTPUT_SUBDIR", "object_detection.output_subdir", "output_detection"))
	stageTimeoutSec := getInt("SATELLITE_OBJECT_DETECTION_STAGE_TIMEOUT_SECONDS", "object_detection.stage_timeout_seconds", 14400)
	stageMaxRetries := getInt("SATELLITE_OBJECT_DETECTION_STAGE_MAX_RETRIES", "object_detection.stage_max_retries", 0)
	commandHeartbeatSec := getInt("SATELLITE_OBJECT_DETECTION_COMMAND_HEARTBEAT_SECONDS", "object_detection.command_heartbeat_seconds", 60)
	workerConcurrency := getInt("SATELLITE_OBJECT_DETECTION_WORKER_CONCURRENCY", "object_detection.worker_concurrency", 1)
	workerQueueSize := getInt("SATELLITE_OBJECT_DETECTION_WORKER_QUEUE_SIZE", "object_detection.worker_queue_size", 64)

	if runnerPath == "" {
		binary := filepath.Join(rootPath, "yolov8s")
		if stat, err := os.Stat(binary); err == nil && !stat.IsDir() {
			runnerPath = binary
		} else {
			runnerPath = "./yolov8s"
		}
	}

	return ObjectDetectionConfig{
		RootPath:            rootPath,
		RunnerPath:          runnerPath,
		Device:              device,
		DefaultClasses:      defaultClasses,
		OutputSubdir:        outputSubdir,
		StageTimeoutSec:     stageTimeoutSec,
		StageMaxRetries:     stageMaxRetries,
		CommandHeartbeatSec: commandHeartbeatSec,
		WorkerConcurrency:   workerConcurrency,
		WorkerQueueSize:     workerQueueSize,
	}
}

func getInt(envKey, viperKey string, defaultVal int) int {
	if v := os.Getenv(envKey); v != "" {
		if i, err := strconv.Atoi(v); err == nil {
			return i
		}
	}
	if v := viper.GetInt(viperKey); v != 0 || viper.IsSet(viperKey) {
		return v
	}
	return defaultVal
}

func normalizePath(pathStr string) string {
	if pathStr == "" {
		return pathStr
	}
	// WSL 挂载路径在 Windows 上不是 filepath.IsAbs；若 Abs 会变成 D:\mnt\d\... 导致 Python/Stat 均失败。
	if runtime.GOOS == "windows" && strings.HasPrefix(pathStr, "/mnt/") {
		return path.Clean(pathStr)
	}
	if filepath.IsAbs(pathStr) {
		return filepath.Clean(pathStr)
	}
	abs, err := filepath.Abs(pathStr)
	if err != nil {
		return pathStr
	}
	return abs
}

func getBool(envKey, viperKey string, defaultVal bool) bool {
	if v := os.Getenv(envKey); v != "" {
		switch strings.ToLower(strings.TrimSpace(v)) {
		case "1", "true", "yes", "y", "on":
			return true
		case "0", "false", "no", "n", "off":
			return false
		}
	}
	if viper.IsSet(viperKey) {
		return viper.GetBool(viperKey)
	}
	return defaultVal
}

// DSN 返回 PostgreSQL 连接字符串（libpq 格式，供 GORM 等使用）
func (d DatabaseConfig) DSN() string {
	return fmt.Sprintf("host=%s port=%d user=%s password=%s dbname=%s sslmode=%s",
		d.Host, d.Port, d.User, d.Password, d.DBName, d.SSLMode)
}

// MigrateURL 返回 golang-migrate 使用的 postgres:// URL
func (d DatabaseConfig) MigrateURL() string {
	password := url.QueryEscape(d.Password)
	return fmt.Sprintf("postgres://%s:%s@%s:%d/%s?sslmode=%s",
		url.QueryEscape(d.User), password, d.Host, d.Port, d.DBName, d.SSLMode)
}
