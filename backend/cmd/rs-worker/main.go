package main

import (
	"context"
	"errors"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"

	"satellite-cloud/backend/internal/config"
	"satellite-cloud/backend/internal/metrics"
	"satellite-cloud/backend/internal/queue"
	"satellite-cloud/backend/internal/remotesensing"
	"satellite-cloud/backend/pkg/database"
	"satellite-cloud/backend/pkg/logger"
)

func main() {
	cfg := config.Load()
	zapLogger := logger.New(cfg.Log.Level, cfg.Log.Output)

	zapLogger.Info("rs-worker starting",
		zap.String("redis_addr", cfg.Queue.RedisAddr),
		zap.String("stream_rs", cfg.Queue.StreamRS),
		zap.String("consumer_group", cfg.Queue.ConsumerGroup),
		zap.Int("concurrency", cfg.Queue.RSWorkerConcurrency),
	)

	db, err := database.NewPostgres(cfg.Database)
	if err != nil {
		zapLogger.Fatal("Failed to connect to database", zap.Error(err))
	}

	rsSvc := remotesensing.NewRemoteSensingService(
		db, zapLogger, cfg.RemoteSensing, cfg.ObjectDetection, cfg.Argo,
		remotesensing.WorkerOptions(cfg.Queue),
	)

	consumerName := queue.DefaultConsumerName()
	qClient, err := queue.NewClient(cfg.Queue.RedisAddr, cfg.Queue.StreamRS, cfg.Queue.ConsumerGroup, consumerName)
	if err != nil {
		zapLogger.Fatal("Failed to connect redis", zap.Error(err))
	}
	defer qClient.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	metrics.StartServer(ctx, zapLogger)
	go metrics.RunQueueCollector(ctx, cfg.Queue, zapLogger)

	if err := qClient.EnsureRSConsumerGroup(ctx); err != nil {
		zapLogger.Fatal("Failed to ensure consumer group", zap.Error(err))
	}
	zapLogger.Info("Redis consumer group ready",
		zap.String("stream", cfg.Queue.StreamRS),
		zap.String("group", cfg.Queue.ConsumerGroup),
		zap.String("consumer", consumerName),
	)

	rsSvc.BootstrapStaleRunningTasks(ctx)

	concurrency := cfg.Queue.RSWorkerConcurrency
	if concurrency <= 0 {
		concurrency = 1
	}
	sem := make(chan struct{}, concurrency)
	var wg sync.WaitGroup

	processJob := func(streamID string, job queue.RSJobPayload) {
		sem <- struct{}{}
		wg.Add(1)
		go func() {
			defer func() {
				<-sem
				wg.Done()
			}()
			zapLogger.Info("rs-worker 开始处理任务",
				zap.Uint("task_id", job.TaskID),
				zap.Uint("satellite_id", job.SatelliteID),
				zap.String("node", os.Getenv("NODE_NAME")),
				zap.String("stream_id", streamID),
			)
			rsSvc.RunPipelineFromJob(context.Background(), job)
			if ackErr := qClient.AckRSJob(ctx, streamID); ackErr != nil {
				zapLogger.Error("XAck failed", zap.String("stream_id", streamID), zap.Error(ackErr))
			}
		}()
	}

	go func() {
		ticker := time.NewTicker(30 * time.Second)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				msgs, err := qClient.ReclaimStaleRSJobs(ctx, 2*time.Minute, 10)
				if err != nil {
					zapLogger.Warn("ReclaimStaleRSJobs failed", zap.Error(err))
					continue
				}
				for _, msg := range msgs {
					job, parseErr := queue.ParseRSJobMessage(msg.Values)
					if parseErr != nil {
						zapLogger.Error("invalid reclaimed rs.jobs payload",
							zap.String("stream_id", msg.ID),
							zap.Error(parseErr),
						)
						_ = qClient.AckRSJob(ctx, msg.ID)
						continue
					}
					zapLogger.Info("回收 orphan Redis job",
						zap.Uint("task_id", job.TaskID),
						zap.String("stream_id", msg.ID),
					)
					processJob(msg.ID, job)
				}
			}
		}
	}()

	go func() {
		for {
			select {
			case <-ctx.Done():
				return
			default:
			}
			streams, err := qClient.ReadRSJob(ctx, 5*time.Second)
			if err != nil {
				if ctx.Err() != nil {
					return
				}
				if errors.Is(err, redis.Nil) {
					continue
				}
				zapLogger.Warn("XReadGroup failed", zap.Error(err))
				time.Sleep(2 * time.Second)
				continue
			}
			for _, s := range streams {
				for _, msg := range s.Messages {
					job, parseErr := queue.ParseRSJobMessage(msg.Values)
					if parseErr != nil {
						zapLogger.Error("invalid rs.jobs payload",
							zap.String("stream_id", msg.ID),
							zap.Error(parseErr),
						)
						_ = qClient.AckRSJob(ctx, msg.ID)
						continue
					}
					processJob(msg.ID, job)
				}
			}
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	zapLogger.Info("rs-worker shutting down...")
	cancel()
	wg.Wait()
	zapLogger.Info("rs-worker exited")
}
