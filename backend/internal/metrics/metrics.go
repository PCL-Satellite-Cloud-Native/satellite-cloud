package metrics

import (
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

const namespace = "satellite"

var (
	QueueDepth = promauto.NewGaugeVec(prometheus.GaugeOpts{
		Namespace: namespace,
		Name:      "queue_depth",
		Help:      "Redis stream pending messages in consumer group.",
	}, []string{"stream"})

	WorkerJobsActive = promauto.NewGaugeVec(prometheus.GaugeOpts{
		Namespace: namespace,
		Name:      "worker_jobs_active",
		Help:      "Jobs currently executing in worker process.",
	}, []string{"worker"})

	TaskDurationSeconds = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Namespace: namespace,
		Name:      "task_duration_seconds",
		Help:      "Wall-clock seconds for worker-handled task slice.",
		Buckets:   []float64{30, 60, 120, 180, 300, 600, 900, 1200, 1800, 2400, 3600},
	}, []string{"worker", "outcome"})

	TasksTotal = promauto.NewCounterVec(prometheus.CounterOpts{
		Namespace: namespace,
		Name:      "tasks_total",
		Help:      "Tasks processed by worker with outcome label.",
	}, []string{"worker", "outcome"})
)

func ObserveWorkerTask(worker, outcome string, elapsed time.Duration) {
	if worker == "" {
		return
	}
	TaskDurationSeconds.WithLabelValues(worker, outcome).Observe(elapsed.Seconds())
	TasksTotal.WithLabelValues(worker, outcome).Inc()
}

func SetQueueDepth(stream string, depth float64) {
	QueueDepth.WithLabelValues(stream).Set(depth)
}
