package remotesensing

import (
	"context"

	"go.uber.org/zap"

	"satellite-cloud/backend/internal/model"
	"satellite-cloud/backend/internal/queue"
)

// JobMatchesLocalSatellite 判断 job 是否应由本 rs-worker 处理（P5-06b）。
// requiredSatID 为 satellites.sat_id（如 sat-1-1）；localSatID 为本节点 satellite.io/id。
// 已绑定卫星（jobSatelliteID>0）时 fail-closed：查不到 required 或本地无标签则不处理，避免落到无数据节点。
func JobMatchesLocalSatellite(enabled bool, jobSatelliteID uint, requiredSatID, localSatID string) bool {
	if !enabled {
		return true
	}
	if jobSatelliteID == 0 {
		return true
	}
	if requiredSatID == "" || localSatID == "" {
		return false
	}
	return requiredSatID == localSatID
}

// MatchRSJob 判断本节点是否应处理该 job（不打日志，供 PEL 扫描使用）。
func (s *RemoteSensingService) MatchRSJob(ctx context.Context, job queue.RSJobPayload, localSatID string) (process bool, requiredSatID string) {
	if !s.queueCfg.SatelliteAwareQueue {
		return true, ""
	}
	satPK := job.SatelliteID
	// Redis 偶发缺 satellite_id 时回落 DB，避免「DB 已绑锚点却被任意节点执行」
	if satPK == 0 && job.TaskID > 0 {
		var t model.RemoteSensingTask
		if err := s.db.WithContext(ctx).Select("satellite_id").First(&t, job.TaskID).Error; err == nil && t.SatelliteID != nil {
			satPK = *t.SatelliteID
			job.SatelliteID = satPK
		}
	}
	var satID *uint
	if satPK > 0 {
		v := satPK
		satID = &v
	}
	requiredSatID = s.satelliteSatID(ctx, satID)
	process = JobMatchesLocalSatellite(true, satPK, requiredSatID, localSatID)
	return process, requiredSatID
}

// ShouldProcessRSJob rs-worker 消费前过滤：不匹配则留 PEL 待本星 XCLAIM。
func (s *RemoteSensingService) ShouldProcessRSJob(ctx context.Context, job queue.RSJobPayload, localSatID string) (process bool, requiredSatID string) {
	process, requiredSatID = s.MatchRSJob(ctx, job, localSatID)
	if !process {
		s.logger.Info("跳过非本星 RS job，留 pending 待本星 XCLAIM",
			zap.Uint("task_id", job.TaskID),
			zap.Uint("job_satellite_id", job.SatelliteID),
			zap.String("required_sat_id", requiredSatID),
			zap.String("local_sat_id", localSatID),
		)
	}
	return process, requiredSatID
}
