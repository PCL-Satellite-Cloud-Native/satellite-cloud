package metrics

import (
	"context"
	"time"

	"go.uber.org/zap"

	"satellite-cloud/backend/internal/config"
	"satellite-cloud/backend/internal/queue"
)

// RunQueueCollector 周期性刷新 rs.jobs / od.jobs 队列深度
func RunQueueCollector(ctx context.Context, cfg config.QueueConfig, logger *zap.Logger) {
	if cfg.RedisAddr == "" {
		return
	}
	client, err := queue.NewClient(cfg.RedisAddr, cfg.StreamRS, cfg.ConsumerGroup, "metrics-collector")
	if err != nil {
		logger.Warn("queue metrics collector: redis unavailable", zap.Error(err))
		return
	}
	defer client.Close()

	ticker := time.NewTicker(15 * time.Second)
	defer ticker.Stop()

	refresh := func() {
		if n, err := client.StreamGroupPending(ctx, cfg.StreamRS, cfg.ConsumerGroup); err == nil {
			SetQueueDepth(cfg.StreamRS, float64(n))
		}
		if n, err := client.StreamGroupPending(ctx, cfg.StreamOD, cfg.ODConsumerGroup); err == nil {
			SetQueueDepth(cfg.StreamOD, float64(n))
		}
	}
	refresh()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			refresh()
		}
	}
}
