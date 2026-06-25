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

	zapLogger.Info("od-worker starting",
		zap.String("redis_addr", cfg.Queue.RedisAddr),
		zap.String("stream_od", cfg.Queue.StreamOD),
		zap.String("consumer_group", cfg.Queue.ODConsumerGroup),
		zap.Int("concurrency", cfg.Queue.ODWorkerConcurrency),
	)

	db, err := database.NewPostgres(cfg.Database)
	if err != nil {
		zapLogger.Fatal("Failed to connect to database", zap.Error(err))
	}

	rsSvc := remotesensing.NewRemoteSensingService(
		db, zapLogger, cfg.RemoteSensing, cfg.ObjectDetection, cfg.Argo,
		remotesensing.ODWorkerOptions(cfg.Queue),
	)

	consumerName := queue.DefaultODConsumerName()
	qClient, err := queue.NewClient(cfg.Queue.RedisAddr, cfg.Queue.StreamRS, cfg.Queue.ConsumerGroup, consumerName)
	if err != nil {
		zapLogger.Fatal("Failed to connect redis", zap.Error(err))
	}
	defer qClient.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	metrics.StartServer(ctx, zapLogger)
	go metrics.RunQueueCollector(ctx, cfg.Queue, zapLogger)

	if err := qClient.EnsureODConsumerGroup(ctx, cfg.Queue.StreamOD, cfg.Queue.ODConsumerGroup); err != nil {
		zapLogger.Fatal("Failed to ensure od consumer group", zap.Error(err))
	}
	zapLogger.Info("Redis od consumer group ready",
		zap.String("stream", cfg.Queue.StreamOD),
		zap.String("group", cfg.Queue.ODConsumerGroup),
		zap.String("consumer", consumerName),
	)

	concurrency := cfg.Queue.ODWorkerConcurrency
	if concurrency <= 0 {
		concurrency = 1
	}
	sem := make(chan struct{}, concurrency)
	var wg sync.WaitGroup

	go func() {
		for {
			select {
			case <-ctx.Done():
				return
			default:
			}
			streams, err := qClient.ReadODJob(ctx, cfg.Queue.StreamOD, cfg.Queue.ODConsumerGroup, consumerName, 5*time.Second)
			if err != nil {
				if ctx.Err() != nil {
					return
				}
				if errors.Is(err, redis.Nil) {
					continue
				}
				zapLogger.Warn("XReadGroup od failed", zap.Error(err))
				time.Sleep(2 * time.Second)
				continue
			}
			for _, s := range streams {
				for _, msg := range s.Messages {
					job, parseErr := queue.ParseODJobMessage(msg.Values)
					if parseErr != nil {
						zapLogger.Error("invalid od.jobs payload",
							zap.String("stream_id", msg.ID),
							zap.Error(parseErr),
						)
						_ = qClient.AckODJob(ctx, cfg.Queue.StreamOD, cfg.Queue.ODConsumerGroup, msg.ID)
						continue
					}
					sem <- struct{}{}
					wg.Add(1)
					go func(streamID string, payload queue.ODJobPayload) {
						defer func() {
							<-sem
							wg.Done()
						}()
						zapLogger.Info("od-worker 开始处理检测任务",
							zap.Uint("task_id", payload.TaskID),
							zap.Uint("satellite_id", payload.SatelliteID),
							zap.String("node", os.Getenv("NODE_NAME")),
							zap.String("stream_id", streamID),
						)
						rsSvc.RunDetectionFromJob(context.Background(), payload)
						if ackErr := qClient.AckODJob(ctx, cfg.Queue.StreamOD, cfg.Queue.ODConsumerGroup, streamID); ackErr != nil {
							zapLogger.Error("XAck od failed", zap.String("stream_id", streamID), zap.Error(ackErr))
						}
					}(msg.ID, job)
				}
			}
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	zapLogger.Info("od-worker shutting down...")
	cancel()
	wg.Wait()
	zapLogger.Info("od-worker exited")
}
