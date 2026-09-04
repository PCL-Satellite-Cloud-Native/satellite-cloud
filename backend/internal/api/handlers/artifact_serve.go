package handlers

import (
	"io"
	"mime"
	"net/http"
	"path/filepath"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

func serveArtifactFile(c *gin.Context, logger *zap.Logger, absPath, relPath, artifactType string) {
	contentType := http.DetectContentType([]byte{})
	if ext := filepath.Ext(absPath); ext != "" {
		if mt := mime.TypeByExtension(ext); mt != "" {
			contentType = mt
		}
	}
	filename := filepath.Base(absPath)
	if filename == "" || filename == "." {
		filename = filepath.Base(relPath)
	}
	c.Header("Content-Disposition", artifactDisposition(artifactType)+"; filename=\""+filename+"\"")
	c.Header("Content-Type", contentType)
	c.File(absPath)
}

func serveArtifactStream(c *gin.Context, logger *zap.Logger, rc io.ReadCloser, relPath, artifactType string) {
	defer rc.Close()
	contentType := http.DetectContentType([]byte{})
	if ext := filepath.Ext(relPath); ext != "" {
		if mt := mime.TypeByExtension(ext); mt != "" {
			contentType = mt
		}
	}
	filename := filepath.Base(relPath)
	c.Header("Content-Disposition", artifactDisposition(artifactType)+"; filename=\""+filename+"\"")
	c.Header("Content-Type", contentType)
	c.Status(http.StatusOK)
	if _, err := io.Copy(c.Writer, rc); err != nil {
		logger.Error("流式传输产物失败", zap.Error(err))
	}
}

func artifactDisposition(artifactType string) string {
	switch artifactType {
	case "preview", "detection_preview", "detection_tile", "tile":
		return "inline"
	default:
		return "attachment"
	}
}
