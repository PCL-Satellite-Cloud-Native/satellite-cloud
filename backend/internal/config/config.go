package config

import (
	"fmt"
	"net/url"
	"os"
	"path/filepath"
	"strconv"

	"github.com/spf13/viper"
	"github.com/subosito/gotenv"
)

type Config struct {
	Server        ServerConfig
	Database      DatabaseConfig
	Log           LogConfig
	RemoteSensing RemoteSensingConfig
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

type RemoteSensingConfig struct {
	RootPath              string
	PythonBin             string
	DemFile               string
	PersistOutputDir      string
	StageTimeoutSec       int
	FusionStageTimeoutSec int
	StageMaxRetries       int
	CommandHeartbeatSec   int
	PanRPCParallel        int
	PansharpenPar         int
	PanRPCCPUThreads      int
	PanRPCWarpMemMB       int
	PanRPCMaxTotalWarpMB  int
	PanRPCResampleAlg     string
	PansharpenGDALThread  string
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
		RemoteSensing: remoteSensingConfigFromEnvOrViper(),
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
	viper.SetDefault("remote_sensing.persist_output_dir", "persist_output_preprocessing")
	viper.SetDefault("remote_sensing.stage_timeout_seconds", 1800)
	viper.SetDefault("remote_sensing.fusion_stage_timeout_seconds", 1500)
	viper.SetDefault("remote_sensing.stage_max_retries", 1)
	viper.SetDefault("remote_sensing.command_heartbeat_seconds", 60)
	viper.SetDefault("remote_sensing.pan_rpc_parallelism", 2)
	viper.SetDefault("remote_sensing.pansharpen_parallelism", 3)
	viper.SetDefault("remote_sensing.pan_rpc_cpu_threads", 1)
	viper.SetDefault("remote_sensing.pan_rpc_warp_mem_mb", 1024)
	viper.SetDefault("remote_sensing.pan_rpc_max_total_warp_mem_mb", 2048)
	viper.SetDefault("remote_sensing.pan_rpc_resample_alg", "near")
	viper.SetDefault("remote_sensing.pansharpen_gdal_threads", "1")
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
	persistOutputDir := filepath.Clean(get("SATELLITE_REMOTE_SENSING_PERSIST_OUTPUT_DIR", "remote_sensing.persist_output_dir", "persist_output_preprocessing"))
	stageTimeoutSec := getInt("SATELLITE_REMOTE_SENSING_STAGE_TIMEOUT_SECONDS", "remote_sensing.stage_timeout_seconds", 1800)
	fusionStageTimeoutSec := getInt("SATELLITE_REMOTE_SENSING_FUSION_STAGE_TIMEOUT_SECONDS", "remote_sensing.fusion_stage_timeout_seconds", 1500)
	stageMaxRetries := getInt("SATELLITE_REMOTE_SENSING_STAGE_MAX_RETRIES", "remote_sensing.stage_max_retries", 1)
	commandHeartbeatSec := getInt("SATELLITE_REMOTE_SENSING_COMMAND_HEARTBEAT_SECONDS", "remote_sensing.command_heartbeat_seconds", 60)
	panRPCParallel := getInt("SATELLITE_REMOTE_SENSING_PAN_RPC_PARALLELISM", "remote_sensing.pan_rpc_parallelism", 2)
	pansharpenParallel := getInt("SATELLITE_REMOTE_SENSING_PANSHARPEN_PARALLELISM", "remote_sensing.pansharpen_parallelism", 3)
	panRPCCPUThreads := getInt("SATELLITE_REMOTE_SENSING_PAN_RPC_CPU_THREADS", "remote_sensing.pan_rpc_cpu_threads", 1)
	panRPCWarpMemMB := getInt("SATELLITE_REMOTE_SENSING_PAN_RPC_WARP_MEM_MB", "remote_sensing.pan_rpc_warp_mem_mb", 1024)
	panRPCMaxTotalWarpMB := getInt("SATELLITE_REMOTE_SENSING_PAN_RPC_MAX_TOTAL_WARP_MEM_MB", "remote_sensing.pan_rpc_max_total_warp_mem_mb", 2048)
	panRPCResampleAlg := get("SATELLITE_REMOTE_SENSING_PAN_RPC_RESAMPLE_ALG", "remote_sensing.pan_rpc_resample_alg", "near")
	pansharpenGDALThreads := get("SATELLITE_REMOTE_SENSING_PANSHARPEN_GDAL_THREADS", "remote_sensing.pansharpen_gdal_threads", "1")
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
		RootPath:              rootPath,
		PythonBin:             pythonBin,
		DemFile:               demFile,
		PersistOutputDir:      persistOutputDir,
		StageTimeoutSec:       stageTimeoutSec,
		FusionStageTimeoutSec: fusionStageTimeoutSec,
		StageMaxRetries:       stageMaxRetries,
		CommandHeartbeatSec:   commandHeartbeatSec,
		PanRPCParallel:        panRPCParallel,
		PansharpenPar:         pansharpenParallel,
		PanRPCCPUThreads:      panRPCCPUThreads,
		PanRPCWarpMemMB:       panRPCWarpMemMB,
		PanRPCMaxTotalWarpMB:  panRPCMaxTotalWarpMB,
		PanRPCResampleAlg:     panRPCResampleAlg,
		PansharpenGDALThread:  pansharpenGDALThreads,
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
	if filepath.IsAbs(pathStr) {
		return filepath.Clean(pathStr)
	}
	abs, err := filepath.Abs(pathStr)
	if err != nil {
		return pathStr
	}
	return abs
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
