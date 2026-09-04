package queue

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/redis/go-redis/v9"
)

// Declaration 声明式任务队列（kind: JobQueue 的运行时映射）。
// 描述一个 Redis Stream 任务队列的期望状态：stream 名、消费者组、并发、模式与 Redis 地址。
// 由 declarative.ReconcileJobQueue 将 CR spec 转译为 Declaration 后调用
// ApplyDeclaration / DeleteDeclarationStream，使队列生命周期与 worker 启动时机解耦。
type Declaration struct {
	// Name 队列逻辑名（唯一，如 rs / od）。
	Name string
	// Stream Redis Stream 名（如 rs.jobs / od.jobs）。
	Stream string
	// ConsumerGroup 消费者组名（如 rs-workers / od-workers）。
	ConsumerGroup string
	// ConsumerPrefix worker 消费者名前缀（如 rs-worker）。
	ConsumerPrefix string
	// Concurrency 并发消费数（>=1）。
	Concurrency int
	// Mode 队列模式：external（独立 worker）/ inprocess（内进程）。
	Mode string
	// RedisAddr Redis 地址（如 redis:6379）。
	RedisAddr string
	// MaxLen Stream 最大长度（0 表示不限，仅应用于 ApplyDeclaration 时的 XTRIM）。
	MaxLen int64
	// Enabled 启用开关；false 时 ApplyDeclaration 不创建/不修改 Redis 队列。
	Enabled bool
}

// DeclarationFromSpec 由 JobQueue CR 的期望字段构造运行时声明（保留零值判断）。
// 供 declarative 包转译；name 为空时回退到 fallbackName。
func DeclarationFromSpec(name, fallbackName, stream, consumerGroup, consumerPrefix, mode, redisAddr string, concurrency int, maxLen int64, enabled bool) Declaration {
	if name == "" {
		name = fallbackName
	}
	if consumerPrefix == "" {
		consumerPrefix = name + "-worker"
	}
	if mode == "" {
		mode = "external"
	}
	if concurrency <= 0 {
		concurrency = 1
	}
	return Declaration{
		Name:           name,
		Stream:         stream,
		ConsumerGroup:  consumerGroup,
		ConsumerPrefix: consumerPrefix,
		Concurrency:    concurrency,
		Mode:           mode,
		RedisAddr:      redisAddr,
		MaxLen:         maxLen,
		Enabled:        enabled,
	}
}

// DefaultDeclarations 返回与既有环境变量默认值一致的内置队列声明（rs / od）。
// 迁移种子（000011_job_queues.up.sql）与 JobQueue 示例清单应与此保持一致。
func DefaultDeclarations() []Declaration {
	return []Declaration{
		{
			Name:           "rs",
			Stream:         "rs.jobs",
			ConsumerGroup:  "rs-workers",
			ConsumerPrefix: "rs-worker",
			Concurrency:    1,
			Mode:           "external",
			Enabled:        true,
		},
		{
			Name:           "od",
			Stream:         "od.jobs",
			ConsumerGroup:  "od-workers",
			ConsumerPrefix: "od-worker",
			Concurrency:    1,
			Mode:           "external",
			Enabled:        true,
		},
	}
}

// ApplyDeclarationResult 汇报 Redis 侧确保结果。
type ApplyDeclarationResult struct {
	// RedisAction 取值：created / existing / failed / skipped。
	RedisAction string
	// RedisError Redis 确保失败时的错误信息（不影响调用方完成 PG 同步）。
	RedisError string
	// PendingBefore / PendingAfter 为 stream 内待处理消息数（诊断用）。
	PendingBefore int64
	PendingAfter  int64
}

// ApplyDeclaration 幂等确保 Redis 中存在 stream + 消费者组（XGroupCreateMkStream）。
// BUSYGROUP 视为已存在（existing）；连接失败返回 RedisAction=failed 但不返回 error，
// 调用方可据此继续完成持久层同步，仅记录告警。
func ApplyDeclaration(ctx context.Context, decl Declaration) (*ApplyDeclarationResult, error) {
	res := &ApplyDeclarationResult{RedisAction: "skipped"}
	if decl.RedisAddr == "" || !decl.Enabled || decl.Stream == "" || decl.ConsumerGroup == "" {
		return res, nil
	}
	rdb := redis.NewClient(&redis.Options{Addr: decl.RedisAddr})
	defer rdb.Close()

	pingCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	if err := rdb.Ping(pingCtx).Err(); err != nil {
		res.RedisAction = "failed"
		res.RedisError = fmt.Sprintf("redis ping %s: %v", decl.RedisAddr, err)
		return res, nil
	}

	// 幂等创建 stream + 消费者组
	err := rdb.XGroupCreateMkStream(ctx, decl.Stream, decl.ConsumerGroup, "0").Err()
	switch {
	case err == nil:
		res.RedisAction = "created"
	case strings.Contains(err.Error(), "BUSYGROUP"):
		res.RedisAction = "existing"
	default:
		res.RedisAction = "failed"
		res.RedisError = fmt.Sprintf("XGroupCreateMkStream %s/%s: %v", decl.Stream, decl.ConsumerGroup, err)
		return res, nil
	}

	// 可选 XTRIM：限制 stream 最大长度，防止无限增长
	if decl.MaxLen > 0 {
		_ = rdb.XTrimMaxLen(ctx, decl.Stream, decl.MaxLen).Err()
	}

	// 诊断：记录待处理消息数（尽量而为）
	info, err := rdb.XPending(ctx, decl.Stream, decl.ConsumerGroup).Result()
	if err == nil {
		res.PendingBefore = info.Count
	}
	return res, nil
}

// DeleteDeclarationStream 删除 Redis stream（连同其消费者组）。
// 用于 JobQueue CR 带删除注解时的清理；stream 不存在视为已完成（不报错）。
// 注意：仅当队列没有正在消费的 worker 时才能彻底删除。
func DeleteDeclarationStream(ctx context.Context, redisAddr, stream string) error {
	if redisAddr == "" || stream == "" {
		return nil
	}
	rdb := redis.NewClient(&redis.Options{Addr: redisAddr})
	defer rdb.Close()

	pingCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	if err := rdb.Ping(pingCtx).Err(); err != nil {
		return fmt.Errorf("redis ping %s: %w", redisAddr, err)
	}
	if err := rdb.Del(ctx, stream).Err(); err != nil {
		return fmt.Errorf("DEL %s: %w", stream, err)
	}
	return nil
}

// PingDeclaration 探测队列所在 Redis 是否可达（供 dry-run 与健康检查使用）。
func PingDeclaration(ctx context.Context, redisAddr string) error {
	if redisAddr == "" {
		return nil
	}
	rdb := redis.NewClient(&redis.Options{Addr: redisAddr})
	defer rdb.Close()
	pingCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	return rdb.Ping(pingCtx).Err()
}
