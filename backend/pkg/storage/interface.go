package storage

import (
	"context"
	"io"
	"time"
)

type Provider interface {
	Upload(ctx context.Context, key string, file io.Reader, contentType string, size int64) (string, error)
	GeneratePresignedPutURL(ctx context.Context, key string, contentType string, metadata map[string]string, ttl time.Duration) (string, error)
	GeneratePresignedGetURL(ctx context.Context, key string, ttl time.Duration) (string, error)
	Delete(ctx context.Context, key string) error
	Exists(ctx context.Context, key string) (bool, error)
	DeletePrefix(ctx context.Context, prefix string) error
	GetPublicURL(key string) string
}
