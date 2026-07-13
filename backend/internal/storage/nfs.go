package storage

import (
	"context"
	"io"
	"os"
)

type nfsBackend struct{}

func newNFSBackend() Backend {
	return &nfsBackend{}
}

func (b *nfsBackend) Mode() string { return "nfs" }

func (b *nfsBackend) ResolveLocalPath(rootAbs, relPath string) (string, error) {
	return SafeJoinRoot(rootAbs, relPath)
}

func (b *nfsBackend) Open(ctx context.Context, rootAbs, relPath string) (io.ReadCloser, error) {
	path, err := b.ResolveLocalPath(rootAbs, relPath)
	if err != nil {
		return nil, err
	}
	return os.Open(path)
}
