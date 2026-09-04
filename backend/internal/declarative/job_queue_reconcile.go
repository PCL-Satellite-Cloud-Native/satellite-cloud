package declarative

import (
	"context"
	"errors"
	"fmt"
	"time"

	"gorm.io/gorm"

	"satellite-cloud/backend/internal/model"
	"satellite-cloud/backend/internal/queue"
)

// JobQueueReconcileResult 汇报任务队列声明式同步的结果。
type JobQueueReconcileResult struct {
	// CRName 清单 metadata.name。
	CRName string
	// QueueName 实际写入的队列逻辑名（spec.name，缺省 metadata.name）。
	QueueName string
	// Stream Redis Stream 名。
	Stream string
	// ConsumerGroup 消费者组名。
	ConsumerGroup string
	// Mode 队列模式（external / inprocess）。
	Mode string
	// Concurrency 并发消费数。
	Concurrency int
	// Enabled 启用开关。
	Enabled bool
	// Action 取值：created / updated / skipped / deleted / notfound。
	Action string
	// RedisAction 取值：created / existing / failed / skipped（dry-run 或未提供 redisAddr）。
	RedisAction string
	// RedisError Redis 确保失败时的错误信息（不阻塞持久层同步）。
	RedisError string
}

// ReconcileJobQueue 把一份 JobQueue CR 同步到 PostgreSQL 的 job_queues 表（幂等），
// 并在 spec.redisAddr 非空且 Redis 可达时，幂等确保 Redis 中 Stream + 消费者组存在。
//
// 同步语义：
//  1. 带删除注解（cloud.satellite.io/delete=true）→ 删除 job_queues 记录；
//     若 spec.redisAddr 非空则一并尝试删除 Redis Stream（Redis 不可达时仅记录告警）；
//  2. 按队列逻辑名（spec.name，缺省 metadata.name）幂等查找；
//  3. 不存在 → 插入声明（Action=created），并（可选）确保 Redis 队列存在；
//  4. 已存在 → spec 期望字段与库中不一致时收敛更新（Action=updated），
//     一致则跳过（Action=skipped）；Redis 确保仍执行一次（幂等，用于补齐缺失的消费者组）。
//
// 与既有机制的关系：rs-worker / od-worker 启动时的 EnsureRSGroup / EnsureODConsumerGroup
// 保持幂等且与声明兼容（BUSYGROUP 忽略）；RedisAddr 为空时本同步只登记声明，
// 队列仍由 worker 按环境变量隐式创建。
func ReconcileJobQueue(db *gorm.DB, cr *JobQueue, _ ReconcileOptions) (*JobQueueReconcileResult, error) {
	if cr == nil {
		return nil, errors.New("nil manifest")
	}
	res := &JobQueueReconcileResult{
		CRName: cr.Metadata.Name,
	}

	// 1. 删除注解分支
	if DeleteRequestedJobQueue(cr) {
		return deleteJobQueue(db, cr)
	}

	// 2. 队列逻辑名：spec.name 缺省取 metadata.name
	name := cr.Spec.Name
	if name == "" {
		name = cr.Metadata.Name
	}
	res.QueueName = name
	res.Stream = cr.Spec.Stream
	res.ConsumerGroup = cr.Spec.ConsumerGroup
	res.Mode = desiredJobQueueMode(cr)
	res.Concurrency = desiredJobQueueConcurrency(cr)
	res.Enabled = desiredJobQueueEnabled(cr)

	// 3. 幂等查找
	var existing model.JobQueue
	err := db.Where("name = ?", name).First(&existing).Error
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, fmt.Errorf("query job queue %q: %w", name, err)
	}

	// 4. 不存在 → 创建
	if errors.Is(err, gorm.ErrRecordNotFound) {
		created, createErr := createJobQueue(db, cr, name)
		if createErr != nil {
			return nil, createErr
		}
		res.Stream = created.Stream
		res.ConsumerGroup = created.ConsumerGroup
		res.Mode = created.Mode
		res.Concurrency = created.Concurrency
		res.Enabled = created.Enabled
		res.Action = "created"
		ensureJobQueueRedis(db, res, cr, name)
		return res, nil
	}

	// 5. 已存在 → 收敛期望字段
	res.Stream = existing.Stream
	res.ConsumerGroup = existing.ConsumerGroup
	res.Mode = existing.Mode
	res.Concurrency = existing.Concurrency
	res.Enabled = existing.Enabled

	if jobQueueSpecsEqual(existing, cr) {
		res.Action = "skipped"
		ensureJobQueueRedis(db, res, cr, name)
		return res, nil
	}
	if err := db.Model(&model.JobQueue{}).Where("id = ?", existing.ID).Updates(map[string]interface{}{
		"stream":           cr.Spec.Stream,
		"consumer_group":   cr.Spec.ConsumerGroup,
		"consumer_prefix":  desiredJobQueueConsumerPrefix(cr, name),
		"concurrency":      desiredJobQueueConcurrency(cr),
		"mode":             desiredJobQueueMode(cr),
		"redis_addr":       cr.Spec.RedisAddr,
		"max_len":          cr.Spec.MaxLen,
		"enabled":          desiredJobQueueEnabled(cr),
		"updated_at":       time.Now().UTC(),
	}).Error; err != nil {
		return nil, fmt.Errorf("update job queue %q: %w", name, err)
	}
	res.Stream = cr.Spec.Stream
	res.ConsumerGroup = cr.Spec.ConsumerGroup
	res.Mode = desiredJobQueueMode(cr)
	res.Concurrency = desiredJobQueueConcurrency(cr)
	res.Enabled = desiredJobQueueEnabled(cr)
	res.Action = "updated"
	ensureJobQueueRedis(db, res, cr, name)
	return res, nil
}

// createJobQueue 插入队列声明到 job_queues 表（幂等）。
func createJobQueue(db *gorm.DB, cr *JobQueue, name string) (*model.JobQueue, error) {
	now := time.Now().UTC()
	q := model.JobQueue{
		Name:           name,
		Stream:         cr.Spec.Stream,
		ConsumerGroup:  cr.Spec.ConsumerGroup,
		ConsumerPrefix: desiredJobQueueConsumerPrefix(cr, name),
		Concurrency:    desiredJobQueueConcurrency(cr),
		Mode:           desiredJobQueueMode(cr),
		RedisAddr:      cr.Spec.RedisAddr,
		MaxLen:         cr.Spec.MaxLen,
		Enabled:        desiredJobQueueEnabled(cr),
		CreatedAt:      now,
		UpdatedAt:      now,
	}
	if err := db.Create(&q).Error; err != nil {
		return nil, fmt.Errorf("create job queue %q: %w", name, err)
	}
	return &q, nil
}

// deleteJobQueue 按删除注解清理 job_queues 记录；
// redisAddr 非空时尝试删除 Redis Stream（失败仅记录告警，不阻塞删除）。
func deleteJobQueue(db *gorm.DB, cr *JobQueue) (*JobQueueReconcileResult, error) {
	res := &JobQueueReconcileResult{
		CRName:      cr.Metadata.Name,
		QueueName:   cr.Spec.Name,
		RedisAction: "skipped",
	}
	if res.QueueName == "" {
		res.QueueName = cr.Metadata.Name
	}
	res.Stream = cr.Spec.Stream

	var existing model.JobQueue
	if err := db.Where("name = ?", res.QueueName).First(&existing).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			res.Action = "notfound" // 幂等：目标已不存在视为完成
			return res, nil
		}
		return nil, fmt.Errorf("query job queue %q: %w", res.QueueName, err)
	}

	// 尝试删除 Redis Stream（尽力而为）
	if cr.Spec.RedisAddr != "" && cr.Spec.Stream != "" {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := queue.DeleteDeclarationStream(ctx, cr.Spec.RedisAddr, cr.Spec.Stream); err != nil {
			res.RedisAction = "failed"
			res.RedisError = err.Error()
		} else {
			res.RedisAction = "deleted"
		}
	}

	if err := db.Delete(&existing).Error; err != nil {
		return nil, fmt.Errorf("delete job queue %q: %w", res.QueueName, err)
	}
	res.Action = "deleted"
	return res, nil
}

// ensureJobQueueRedis 在 spec.redisAddr 非空且启用时幂等确保 Redis 队列存在；
// 失败不阻塞持久层同步，结果写入 res（RedisAction / RedisError）。
func ensureJobQueueRedis(_ *gorm.DB, res *JobQueueReconcileResult, cr *JobQueue, name string) {
	if cr.Spec.RedisAddr == "" {
		res.RedisAction = "skipped" // 未声明 Redis 地址：队列由 worker 按环境变量创建
		return
	}
	decl := queue.DeclarationFromSpec(
		name, name,
		cr.Spec.Stream, cr.Spec.ConsumerGroup,
		cr.Spec.ConsumerPrefix, cr.Spec.Mode,
		cr.Spec.RedisAddr, cr.Spec.Concurrency, cr.Spec.MaxLen,
		desiredJobQueueEnabled(cr),
	)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	applyRes, err := queue.ApplyDeclaration(ctx, decl)
	if err != nil {
		res.RedisAction = "failed"
		res.RedisError = err.Error()
		return
	}
	res.RedisAction = applyRes.RedisAction
	res.RedisError = applyRes.RedisError
}

// jobQueueSpecsEqual 判断 CR 期望字段与库中记录是否一致（忽略 created_at/updated_at）。
func jobQueueSpecsEqual(q model.JobQueue, cr *JobQueue) bool {
	name := cr.Spec.Name
	if name == "" {
		name = cr.Metadata.Name
	}
	return q.Stream == cr.Spec.Stream &&
		q.ConsumerGroup == cr.Spec.ConsumerGroup &&
		q.ConsumerPrefix == desiredJobQueueConsumerPrefix(cr, name) &&
		q.Concurrency == desiredJobQueueConcurrency(cr) &&
		q.Mode == desiredJobQueueMode(cr) &&
		q.RedisAddr == cr.Spec.RedisAddr &&
		q.MaxLen == cr.Spec.MaxLen &&
		q.Enabled == desiredJobQueueEnabled(cr)
}

// desiredJobQueueConsumerPrefix 返回消费者名前缀（缺省 {name}-worker）。
func desiredJobQueueConsumerPrefix(cr *JobQueue, name string) string {
	if cr.Spec.ConsumerPrefix != "" {
		return cr.Spec.ConsumerPrefix
	}
	return name + "-worker"
}

// desiredJobQueueMode 返回队列模式（缺省 external）。
func desiredJobQueueMode(cr *JobQueue) string {
	if cr.Spec.Mode != "" {
		return cr.Spec.Mode
	}
	return "external"
}

// desiredJobQueueConcurrency 返回并发数（缺省 1）。
func desiredJobQueueConcurrency(cr *JobQueue) int {
	if cr.Spec.Concurrency > 0 {
		return cr.Spec.Concurrency
	}
	return 1
}

// desiredJobQueueEnabled 返回启用开关（缺省 true）。
func desiredJobQueueEnabled(cr *JobQueue) bool {
	if cr.Spec.Enabled != nil {
		return *cr.Spec.Enabled
	}
	return true
}
