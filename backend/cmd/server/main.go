package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/golang-migrate/migrate/v4"
	_ "github.com/golang-migrate/migrate/v4/database/postgres"
	"github.com/golang-migrate/migrate/v4/source/iofs"
	"go.uber.org/zap"

	"satellite-cloud/backend/internal/api/handlers"
	"satellite-cloud/backend/internal/config"
	"satellite-cloud/backend/internal/remotesensing"
	"satellite-cloud/backend/internal/topology"
	"satellite-cloud/backend/migrations"
	"satellite-cloud/backend/pkg/database"
	"satellite-cloud/backend/pkg/logger"
)

func main() {
	// 初始化配置
	cfg := config.Load()

	// 初始化日志
	zapLogger := logger.New(cfg.Log.Level, cfg.Log.Output)

	// 初始化数据库
	db, err := database.NewPostgres(cfg.Database)
	if err != nil {
		zapLogger.Fatal("Failed to connect to database", zap.Error(err))
	}
	zapLogger.Info("Remote sensing runtime configured",
		zap.String("root_path", cfg.RemoteSensing.RootPath),
		zap.String("python_bin", cfg.RemoteSensing.PythonBin),
		zap.String("dem_file", cfg.RemoteSensing.DemFile),
		zap.String("persist_output_dir", cfg.RemoteSensing.PersistOutputDir),
		zap.Int("stage_timeout_seconds", cfg.RemoteSensing.StageTimeoutSec),
		zap.Int("fusion_stage_timeout_seconds", cfg.RemoteSensing.FusionStageTimeoutSec),
		zap.Int("fusion_block_size", cfg.RemoteSensing.FusionBlockSize),
		zap.String("fusion_gdal_threads", cfg.RemoteSensing.FusionGDALThreads),
		zap.Int("stage_max_retries", cfg.RemoteSensing.StageMaxRetries),
		zap.Int("command_heartbeat_seconds", cfg.RemoteSensing.CommandHeartbeatSec),
		zap.Int("pan_rpc_parallelism", cfg.RemoteSensing.PanRPCParallel),
		zap.Int("pan_rpc_cpu_threads", cfg.RemoteSensing.PanRPCCPUThreads),
		zap.Int("pan_rpc_warp_mem_mb", cfg.RemoteSensing.PanRPCWarpMemMB),
		zap.Int("pan_rpc_max_total_warp_mem_mb", cfg.RemoteSensing.PanRPCMaxTotalWarpMB),
		zap.String("pan_rpc_resample_alg", cfg.RemoteSensing.PanRPCResampleAlg),
		zap.Int("pansharpen_parallelism", cfg.RemoteSensing.PansharpenPar),
		zap.String("pansharpen_mode", cfg.RemoteSensing.PansharpenMode),
		zap.String("pansharpen_gdal_threads", cfg.RemoteSensing.PansharpenGDALThread),
	)

	// 启动时自动执行未应用的迁移（与 K8s/本地环境保持一致）
	sourceDriver, err := iofs.New(migrations.FS, ".")
	if err != nil {
		zapLogger.Fatal("Failed to create migration source", zap.Error(err))
	}
	m, err := migrate.NewWithSourceInstance("iofs", sourceDriver, cfg.Database.MigrateURL())
	if err != nil {
		zapLogger.Fatal("Failed to create migrator", zap.Error(err))
	}
	defer m.Close()
	if err := m.Up(); err != nil && err != migrate.ErrNoChange {
		zapLogger.Fatal("Failed to run migrations", zap.Error(err))
	}
	if err == nil {
		zapLogger.Info("Migrations applied or already up to date")
	}

	// 可选：启动时自动从 CSV 导入拓扑相关数据（当前仅支持 delay 矩阵）
	if os.Getenv("SATELLITE_TOPOLOGY_AUTO_IMPORT") == "true" {
		scenarioName := os.Getenv("SATELLITE_TOPOLOGY_SCENARIO")
		if scenarioName == "" {
			scenarioName = "Scenario5_full_36x22"
		}

		if delayCSV := os.Getenv("SATELLITE_DELAY_CSV"); delayCSV != "" {
			zapLogger.Info("Auto-importing delay edges from CSV",
				zap.String("scenario", scenarioName),
				zap.String("file", delayCSV),
			)
			if err := topology.ImportDelayFromCSV(db, scenarioName, delayCSV); err != nil {
				zapLogger.Error("Failed to auto-import delay edges from CSV", zap.Error(err))
			} else {
				zapLogger.Info("Auto-import delay edges succeeded")
			}
		}
		if t0Dir := os.Getenv("SATELLITE_T0_CSV_DIR"); t0Dir != "" {
			zapLogger.Info("Auto-importing T0 satellite states from CSV dir",
				zap.String("scenario", scenarioName),
				zap.String("dir", t0Dir),
			)
			if err := topology.ImportSatStatesFromCSV(db, scenarioName, t0Dir); err != nil {
				zapLogger.Error("Failed to auto-import T0 states from CSV", zap.Error(err))
			} else {
				zapLogger.Info("Auto-import T0 states succeeded")
			}
		}
		if routerDir := os.Getenv("SATELLITE_ROUTER_CSV_DIR"); routerDir != "" {
			zapLogger.Info("Auto-importing router topology from CSV dir",
				zap.String("scenario", scenarioName),
				zap.String("dir", routerDir),
			)
			if err := topology.ImportRouterFromCSV(db, scenarioName, routerDir); err != nil {
				zapLogger.Error("Failed to auto-import router from CSV", zap.Error(err))
			} else {
				zapLogger.Info("Auto-import router topology succeeded")
			}
		}
	}

	// 设置 Gin 模式
	if cfg.Server.Mode == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	// 创建 Gin 路由
	router := gin.New()

	// 中间件
	router.Use(gin.Recovery())
	router.Use(logger.Middleware(zapLogger))

	// CORS 配置（开发环境：放开所有来源，方便前后端联调）
	router.Use(cors.New(cors.Config{
		AllowAllOrigins:  true,
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Accept", "Authorization"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: true,
		MaxAge:           12 * time.Hour,
	}))

	// 健康检查
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	router.GET("/ready", func(c *gin.Context) {
		sqlDB, err := db.DB()
		if err != nil {
			c.JSON(http.StatusServiceUnavailable, gin.H{"status": "not ready"})
			return
		}
		if err := sqlDB.Ping(); err != nil {
			c.JSON(http.StatusServiceUnavailable, gin.H{"status": "not ready"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"status": "ready"})
	})

	remoteSensingService := remotesensing.NewRemoteSensingService(db, zapLogger, cfg.RemoteSensing)

	// API 路由
	api := router.Group("/api")
	{
		handlers.RegisterRoutes(api, db, zapLogger, remoteSensingService)
	}

	// 创建 HTTP 服务器
	srv := &http.Server{
		Addr:         fmt.Sprintf(":%d", cfg.Server.Port),
		Handler:      router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// 启动服务器（goroutine）
	go func() {
		zapLogger.Info("Starting server", zap.Int("port", cfg.Server.Port))
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			zapLogger.Fatal("Failed to start server", zap.Error(err))
		}
	}()

	// 优雅关闭
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	zapLogger.Info("Shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		zapLogger.Error("Graceful shutdown timeout, forcing close", zap.Error(err))
		if closeErr := srv.Close(); closeErr != nil {
			zapLogger.Error("Force close failed", zap.Error(closeErr))
		}
	}

	zapLogger.Info("Server exited")
}
