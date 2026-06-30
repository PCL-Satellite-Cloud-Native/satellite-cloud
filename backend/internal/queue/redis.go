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

// RSJobPayload 与 MICROSERVICES_IMPLEMENTATION_PLAN §6.1 一致
type RSJobPayload struct {
	TaskID              uint   `json:"task_id"`
	SatelliteID         uint   `json:"satellite_id"`
	Name                string `json:"name"`
	FilePrefix          string `json:"file_prefix"`
	InputDirectory      string `json:"input_directory"`
	Sensor              string `json:"sensor"`
	EnableDetection     bool   `json:"enable_detection"`
	DetectionClasses    string `json:"detection_classes"`
	DetectionDrawLabels bool   `json:"detection_draw_labels"`
	EnqueuedAt          string `json:"enqueued_at"`
}

// Client Redis Stream 客户端封装
type Client struct {
	rdb           *redis.Client
	streamRS      string
	consumerGroup string
	consumerName  string
}

// NewClient 连接 Redis 并返回客户端
func NewClient(addr, streamRS, consumerGroup, consumerName string) (*Client, error) {
	rdb := redis.NewClient(&redis.Options{Addr: addr})
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := rdb.Ping(ctx).Err(); err != nil {
		return nil, fmt.Errorf("redis ping %s: %w", addr, err)
	}
	return &Client{
		rdb:           rdb,
		streamRS:      streamRS,
		consumerGroup: consumerGroup,
		consumerName:  consumerName,
	}, nil
}

// Close 关闭连接
func (c *Client) Close() error {
	return c.rdb.Close()
}

// EnsureRSConsumerGroup 创建 Stream 与消费者组（不存在时）
func (c *Client) EnsureRSConsumerGroup(ctx context.Context) error {
	err := c.rdb.XGroupCreateMkStream(ctx, c.streamRS, c.consumerGroup, "0").Err()
	if err != nil && !strings.Contains(err.Error(), "BUSYGROUP") {
		return fmt.Errorf("XGroupCreateMkStream: %w", err)
	}
	return nil
}

// DefaultConsumerName 基于 hostname 生成消费者名
func DefaultConsumerName() string {
	host, err := os.Hostname()
	if err != nil || host == "" {
		return "rs-worker"
	}
	return "rs-worker-" + host
}

// EnqueueRSJob 向 rs.jobs 写入一条任务
func (c *Client) EnqueueRSJob(ctx context.Context, p RSJobPayload) (string, error) {
	if p.EnqueuedAt == "" {
		p.EnqueuedAt = time.Now().UTC().Format(time.RFC3339)
	}
	values := map[string]interface{}{
		"task_id":               strconv.FormatUint(uint64(p.TaskID), 10),
		"satellite_id":          strconv.FormatUint(uint64(p.SatelliteID), 10),
		"name":                  p.Name,
		"file_prefix":           p.FilePrefix,
		"input_directory":       p.InputDirectory,
		"sensor":                p.Sensor,
		"enable_detection":      strconv.FormatBool(p.EnableDetection),
		"detection_classes":     p.DetectionClasses,
		"detection_draw_labels": strconv.FormatBool(p.DetectionDrawLabels),
		"enqueued_at":           p.EnqueuedAt,
	}
	id, err := c.rdb.XAdd(ctx, &redis.XAddArgs{
		Stream: c.streamRS,
		Values: values,
	}).Result()
	if err != nil {
		return "", fmt.Errorf("XAdd %s: %w", c.streamRS, err)
	}
	return id, nil
}

// ReadRSJob 阻塞读取一条 rs.jobs 消息
func (c *Client) ReadRSJob(ctx context.Context, block time.Duration) ([]redis.XStream, error) {
	return c.rdb.XReadGroup(ctx, &redis.XReadGroupArgs{
		Group:    c.consumerGroup,
		Consumer: c.consumerName,
		Streams:  []string{c.streamRS, ">"},
		Count:    1,
		Block:    block,
	}).Result()
}

// ReclaimStaleRSJobs 回收 idle 超过 minIdle 的 pending 消息（Pod 重启后 orphan job）
func (c *Client) ReclaimStaleRSJobs(ctx context.Context, minIdle time.Duration, count int64) ([]redis.XMessage, error) {
	if count <= 0 {
		count = 10
	}
	msgs, _, err := c.rdb.XAutoClaim(ctx, &redis.XAutoClaimArgs{
		Stream:   c.streamRS,
		Group:    c.consumerGroup,
		Consumer: c.consumerName,
		MinIdle:  minIdle,
		Start:    "0-0",
		Count:    count,
	}).Result()
	if err != nil {
		return nil, fmt.Errorf("XAutoClaim: %w", err)
	}
	return msgs, nil
}

// AckRSJob 确认消息
func (c *Client) AckRSJob(ctx context.Context, streamID string) error {
	return c.rdb.XAck(ctx, c.streamRS, c.consumerGroup, streamID).Err()
}

// StreamGroupPending 消费者组待处理消息数（XPENDING count）
func (c *Client) StreamGroupPending(ctx context.Context, stream, group string) (int64, error) {
	info, err := c.rdb.XPending(ctx, stream, group).Result()
	if err != nil {
		return 0, err
	}
	return info.Count, nil
}

// ParseRSJobMessage 从 Stream 消息 values 解析 payload
func ParseRSJobMessage(values map[string]interface{}) (RSJobPayload, error) {
	var p RSJobPayload
	var err error
	if p.TaskID, err = parseUintField(values, "task_id"); err != nil {
		return p, err
	}
	if p.SatelliteID, err = parseUintField(values, "satellite_id"); err != nil {
		return p, err
	}
	p.Name = stringField(values, "name")
	p.FilePrefix = stringField(values, "file_prefix")
	p.InputDirectory = stringField(values, "input_directory")
	p.Sensor = stringField(values, "sensor")
	if p.EnableDetection, err = parseBoolField(values, "enable_detection"); err != nil {
		return p, err
	}
	p.DetectionClasses = stringField(values, "detection_classes")
	if p.DetectionDrawLabels, err = parseBoolField(values, "detection_draw_labels"); err != nil {
		return p, err
	}
	p.EnqueuedAt = stringField(values, "enqueued_at")
	if p.TaskID == 0 {
		return p, fmt.Errorf("missing task_id")
	}
	if strings.TrimSpace(p.FilePrefix) == "" || strings.TrimSpace(p.InputDirectory) == "" {
		return p, fmt.Errorf("missing file_prefix or input_directory")
	}
	return p, nil
}

func stringField(values map[string]interface{}, key string) string {
	v, ok := values[key]
	if !ok || v == nil {
		return ""
	}
	switch t := v.(type) {
	case string:
		return t
	case []byte:
		return string(t)
	default:
		return fmt.Sprint(t)
	}
}

func parseUintField(values map[string]interface{}, key string) (uint, error) {
	s := strings.TrimSpace(stringField(values, key))
	if s == "" {
		return 0, nil
	}
	n, err := strconv.ParseUint(s, 10, 64)
	if err != nil {
		return 0, fmt.Errorf("invalid %s: %w", key, err)
	}
	return uint(n), nil
}

func parseBoolField(values map[string]interface{}, key string) (bool, error) {
	s := strings.TrimSpace(strings.ToLower(stringField(values, key)))
	if s == "" {
		return false, nil
	}
	switch s {
	case "1", "true", "yes", "y", "on":
		return true, nil
	case "0", "false", "no", "n", "off":
		return false, nil
	default:
		return false, fmt.Errorf("invalid %s: %q", key, s)
	}
}
