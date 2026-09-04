package storage

import (
	"context"
	"io"
	"os"
	"path/filepath"
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

func (b *nfsBackend) Put(ctx context.Context, rootAbs, relPath string, r io.Reader, size int64) error {
	_ = ctx
	_ = size
	path, err := b.ResolveLocalPath(rootAbs, relPath)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	out, err := os.Create(path)
	if err != nil {
		return err
	}
	defer out.Close()
	_, err = io.Copy(out, r)
	return err
}
