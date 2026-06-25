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

	now := time.Now().UTC()
	updates := map[string]interface{}{
		"host_node_name": p.NodeName,
		"updated_at":     now,
	}
	if p.ExecutedSatID != "" {
		updates["executed_sat_id"] = p.ExecutedSatID
		if satPK := s.lookupSatellitePKBySatID(ctx, p.ExecutedSatID); satPK != nil {
			updates["satellite_id"] = *satPK
		}
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

func (s *RemoteSensingService) lookupSatellitePKBySatID(ctx context.Context, satID string) *uint {
	var sat model.Satellite
	if err := s.db.WithContext(ctx).Select("id").Where("sat_id = ?", satID).First(&sat).Error; err != nil {
		return nil
	}
	id := sat.ID
	return &id
}
