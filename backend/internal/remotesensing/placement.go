package remotesensing

import (
	"context"
	"time"

	"go.uber.org/zap"

	"satellite-cloud/backend/internal/k8snode"
	"satellite-cloud/backend/internal/model"
)

func (s *RemoteSensingService) recordTaskPlacement(ctx context.Context, taskID uint) {
	if s.metricsWorker == "" {
		return
	}
	p := k8snode.CurrentPlacement(ctx)
	if p.NodeName == "" && p.ExecutedSatID == "" {
		s.logger.Warn("无法解析任务执行节点",
			zap.Uint("task_id", taskID),
			zap.String("worker", s.metricsWorker),
		)
		return
	}

	// od-worker 仅跑阶段 10；RS 落点已由 rs-worker 写入，勿覆盖 executed_sat_id / host_node_name。
	if s.metricsWorker == "od-worker" {
		var existing model.RemoteSensingTask
		if err := s.db.WithContext(ctx).Select("host_node_name", "executed_sat_id").
			First(&existing, taskID).Error; err == nil && existing.ExecutedSatID != "" {
			s.logger.Info("保留 rs-worker 执行落点，od-worker 不覆盖",
				zap.Uint("task_id", taskID),
				zap.String("host_node", existing.HostNodeName),
				zap.String("executed_sat_id", existing.ExecutedSatID),
				zap.String("od_node", p.NodeName),
			)
			return
		}
	}

	now := time.Now().UTC()
	updates := map[string]interface{}{
		"host_node_name": p.NodeName,
		"updated_at":     now,
	}
	if p.ExecutedSatID != "" {
		updates["executed_sat_id"] = p.ExecutedSatID
		// satellite_id 保留创建任务时用户指定的绑定，勿用 executed_sat_id 覆盖。
	}

	if err := s.db.WithContext(ctx).Model(&model.RemoteSensingTask{}).
		Where("id = ?", taskID).
		Updates(updates).Error; err != nil {
		s.logger.Error("记录任务执行节点失败", zap.Uint("task_id", taskID), zap.Error(err))
		return
	}

	s.logger.Info("任务执行节点已记录",
		zap.Uint("task_id", taskID),
		zap.String("host_node", p.NodeName),
		zap.String("executed_sat_id", p.ExecutedSatID),
		zap.String("worker", s.metricsWorker),
	)

	event := RemoteSensingStageEvent{
		TaskID:        taskID,
		TaskStatus:    TaskStatusRunning,
		HostNodeName:  p.NodeName,
		ExecutedSatID: p.ExecutedSatID,
		UpdatedAt:     now,
	}
	s.publishStageEvent(taskID, s.eventWithTaskTopology(taskID, event))
}
