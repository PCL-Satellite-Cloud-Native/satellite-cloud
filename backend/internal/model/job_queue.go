package model

import "time"

// JobQueue 声明式任务队列（kind: JobQueue）在 PostgreSQL 中的持久化记录。
// 对应迁移：000011_job_queues.up.sql。
type JobQueue struct {
	ID uint `gorm:"primaryKey" json:"id"`
	// Name 队列逻辑名（唯一，如 rs / od）。
	Name string `gorm:"size:64;uniqueIndex;not null" json:"name"`
	// Stream Redis Stream 名（如 rs.jobs / od.jobs）。
	Stream string `gorm:"size:128;not null" json:"stream"`
	// ConsumerGroup 消费者组名（如 rs-workers / od-workers）。
	ConsumerGroup string `gorm:"size:128;not null" json:"consumer_group"`
	// ConsumerPrefix worker 消费者名前缀（如 rs-worker）。
	ConsumerPrefix string `gorm:"size:64" json:"consumer_prefix"`
	// Concurrency 并发消费数（>=1）。
	Concurrency int `gorm:"not null;default:1" json:"concurrency"`
	// Mode 队列模式：external（独立 worker）/ inprocess（内进程）。
	Mode string `gorm:"size:16;not null;default:external" json:"mode"`
	// RedisAddr Redis 地址；为空表示由 worker 环境变量决定。
	RedisAddr string `gorm:"size:255" json:"redis_addr"`
	// MaxLen Stream 最大长度（0 不限）。
	MaxLen int64 `gorm:"not null;default:0" json:"max_len"`
	// Enabled 启用开关。
	Enabled bool `gorm:"not null;default:true" json:"enabled"`
	// CreatedAt 创建时间。
	CreatedAt time.Time `gorm:"autoCreateTime" json:"created_at"`
	// UpdatedAt 最后同步时间。
	UpdatedAt time.Time `gorm:"autoUpdateTime" json:"updated_at"`
}
