package remotesensing

import (
	"context"
	"os"

	"go.uber.org/zap"

	"satellite-cloud/backend/internal/model"
	"satellite-cloud/backend/internal/storage"
)

// shouldUploadArtifact D0：仅上传前端需要的预览/检测图，跳过数 GB 的 fusion .dat。
func shouldUploadArtifact(art model.RemoteSensingTaskArtifact) bool {
	switch art.Type {
	case "preview", "detection_preview", "detection_tile", "detection_summary":
		return true
	default:
		return false
	}
}

func (s *RemoteSensingService) uploadArtifactBestEffort(art model.RemoteSensingTaskArtifact) {
	if s.artifactUploader == nil || !shouldUploadArtifact(art) {
		return
	}
	rootKey := ""
	if art.Metadata != nil {
		if v, ok := art.Metadata["artifact_root"].(string); ok {
			rootKey = v
		}
	}
	rootAbs := s.artifactRootAbs(rootKey)
	localAbs, err := storage.SafeJoinRoot(rootAbs, art.Path)
	if err != nil {
		s.logger.Warn("artifact 上传跳过：路径无效", zap.Uint("task_id", art.TaskID), zap.String("path", art.Path), zap.Error(err))
		return
	}
	if _, err := os.Stat(localAbs); err != nil {
		s.logger.Warn("artifact 上传跳过：本地文件不存在", zap.Uint("task_id", art.TaskID), zap.String("path", localAbs), zap.Error(err))
		return
	}
	ctx := context.Background()
	if err := storage.PutFile(ctx, s.artifactUploader, rootAbs, art.Path, localAbs); err != nil {
		s.logger.Warn("artifact 上传 MinIO 失败",
			zap.Uint("task_id", art.TaskID),
			zap.Uint("artifact_id", art.ID),
			zap.String("path", art.Path),
			zap.Error(err),
		)
		return
	}
	s.logger.Info("artifact 已上传 MinIO",
		zap.Uint("task_id", art.TaskID),
		zap.String("type", art.Type),
		zap.String("path", art.Path),
		zap.String("uploader", s.artifactUploader.Mode()),
	)
}

func (s *RemoteSensingService) maybeUploadArtifactAsync(art model.RemoteSensingTaskArtifact) {
	if s.artifactUploader == nil || !shouldUploadArtifact(art) {
		return
	}
	go s.uploadArtifactBestEffort(art)
}
