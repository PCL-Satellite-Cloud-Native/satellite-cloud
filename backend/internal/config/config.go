package config

import (
	"fmt"
	"net/url"
	"os"
	"strconv"

	"github.com/spf13/viper"
	"github.com/subosito/gotenv"
)

type Config struct {
	Server   ServerConfig
	Database DatabaseConfig
	Log      LogConfig
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
