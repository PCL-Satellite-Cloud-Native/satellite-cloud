package remotesensing

import (
	"context"

	"go.uber.org/zap"

	"satellite-cloud/backend/internal/queue"
)

// JobMatchesLocalSatellite 判断 job 是否应由本 rs-worker 处理（P5-06b）。
// requiredSatID 为 satellites.sat_id（如 sat-1-1）；localSatID 为本节点 satellite.io/id。
func JobMatchesLocalSatellite(enabled bool, jobSatelliteID uint, requiredSatID, localSatID string) bool {
	if !enabled {
		return true
	}
	if jobSatelliteID == 0 || requiredSatID == "" {
		return true
	}
	if localSatID == "" {
		return true
	}
	return requiredSatID == localSatID
}

// ShouldProcessRSJob rs-worker 消费前过滤：不匹配则交还 stream 供其他节点消费。
func (s *RemoteSensingService) ShouldProcessRSJob(ctx context.Context, job queue.RSJobPayload, localSatID string) (process bool, requiredSatID string) {
	if !s.queueCfg.SatelliteAwareQueue {
		return true, ""
	}
	var satID *uint
	if job.SatelliteID > 0 {
		v := job.SatelliteID
		satID = &v
	}
	requiredSatID = s.satelliteSatID(ctx, satID)
	process = JobMatchesLocalSatellite(true, job.SatelliteID, requiredSatID, localSatID)
	if !process {
		s.logger.Info("跳过非本星 RS job，留 pending 待 XAUTOCLAIM",
			zap.Uint("task_id", job.TaskID),
			zap.Uint("job_satellite_id", job.SatelliteID),
			zap.String("required_sat_id", requiredSatID),
			zap.String("local_sat_id", localSatID),
		)
	}
	return process, requiredSatID
}
