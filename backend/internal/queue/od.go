package queue

import (
	"context"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/redis/go-redis/v9"
)

// ODJobPayload 与 MICROSERVICES_IMPLEMENTATION_PLAN §6.2 一致
type ODJobPayload struct {
	TaskID              uint   `json:"task_id"`
	SatelliteID         uint   `json:"satellite_id"`
	FilePrefix          string `json:"file_prefix"`
	FusionDatRel        string `json:"fusion_dat_rel"`
	DetectionClasses    string `json:"detection_classes"`
	DetectionDrawLabels bool   `json:"detection_draw_labels"`
	EnqueuedAt          string `json:"enqueued_at"`
}

// DefaultODConsumerName 基于 hostname 生成 od-worker 消费者名
func DefaultODConsumerName() string {
	host, err := os.Hostname()
	if err != nil || host == "" {
		return "od-worker"
	}
	return "od-worker-" + host
}

// IsRedisNoGroup Redis Stream 消费者组不存在（常见于 Redis 重启后 od.jobs 仍在但 group 元数据丢失）
func IsRedisNoGroup(err error) bool {
	return err != nil && strings.Contains(err.Error(), "NOGROUP")
}

// EnsureODConsumerGroup 创建 od.jobs Stream 与消费者组
func (c *Client) EnsureODConsumerGroup(ctx context.Context, streamOD, consumerGroup string) error {
	err := c.rdb.XGroupCreateMkStream(ctx, streamOD, consumerGroup, "0").Err()
	if err != nil && !strings.Contains(err.Error(), "BUSYGROUP") {
		return fmt.Errorf("XGroupCreateMkStream od: %w", err)
	}
	return nil
}

// EnqueueODJob 向 od.jobs 写入一条检测任务
func (c *Client) EnqueueODJob(ctx context.Context, streamOD string, p ODJobPayload) (string, error) {
	if p.EnqueuedAt == "" {
		p.EnqueuedAt = time.Now().UTC().Format(time.RFC3339)
	}
	values := map[string]interface{}{
		"task_id":               strconv.FormatUint(uint64(p.TaskID), 10),
		"satellite_id":          strconv.FormatUint(uint64(p.SatelliteID), 10),
		"file_prefix":           p.FilePrefix,
		"fusion_dat_rel":        p.FusionDatRel,
		"detection_classes":     p.DetectionClasses,
		"detection_draw_labels": strconv.FormatBool(p.DetectionDrawLabels),
		"enqueued_at":           p.EnqueuedAt,
	}
	id, err := c.rdb.XAdd(ctx, &redis.XAddArgs{
		Stream: streamOD,
		Values: values,
	}).Result()
	if err != nil {
		return "", fmt.Errorf("XAdd %s: %w", streamOD, err)
	}
	return id, nil
}

// ReadODJob 阻塞读取 od.jobs
func (c *Client) ReadODJob(ctx context.Context, streamOD, consumerGroup, consumerName string, block time.Duration) ([]redis.XStream, error) {
	return c.rdb.XReadGroup(ctx, &redis.XReadGroupArgs{
		Group:    consumerGroup,
		Consumer: consumerName,
		Streams:  []string{streamOD, ">"},
		Count:    1,
		Block:    block,
	}).Result()
}

// AckODJob 确认 od.jobs 消息
func (c *Client) AckODJob(ctx context.Context, streamOD, consumerGroup, streamID string) error {
	return c.rdb.XAck(ctx, streamOD, consumerGroup, streamID).Err()
}

// ParseODJobMessage 解析 od.jobs payload
func ParseODJobMessage(values map[string]interface{}) (ODJobPayload, error) {
	var p ODJobPayload
	var err error
	if p.TaskID, err = parseUintField(values, "task_id"); err != nil {
		return p, err
	}
	if p.SatelliteID, err = parseUintField(values, "satellite_id"); err != nil {
		return p, err
	}
	p.FilePrefix = stringField(values, "file_prefix")
	p.FusionDatRel = stringField(values, "fusion_dat_rel")
	p.DetectionClasses = stringField(values, "detection_classes")
	if p.DetectionDrawLabels, err = parseBoolField(values, "detection_draw_labels"); err != nil {
		return p, err
	}
	p.EnqueuedAt = stringField(values, "enqueued_at")
	if p.TaskID == 0 {
		return p, fmt.Errorf("missing task_id")
	}
	if strings.TrimSpace(p.FusionDatRel) == "" {
		return p, fmt.Errorf("missing fusion_dat_rel")
	}
	return p, nil
}
