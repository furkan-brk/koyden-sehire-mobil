package storage

import (
	"context"
	"io"
	"log"
	"strings"
	"time"
)

// DevProvider is used in development when real storage (R2/MinIO) is not configured.
// It validates nothing about storage, returns static placeholder URLs, and logs every call.
type DevProvider struct{}

func (d *DevProvider) Upload(ctx context.Context, key string, file io.Reader, contentType string, size int64) (string, error) {
	url := placeholderURL(key)
	log.Printf("[storage:dev] Upload key=%s contentType=%s size=%d → %s", key, contentType, size, url)
	return url, nil
}

func (d *DevProvider) GeneratePresignedPutURL(ctx context.Context, key string, contentType string, metadata map[string]string, ttl time.Duration) (string, error) {
	url := "http://localhost:8080/dev-noop-presign"
	log.Printf("[storage:dev] GeneratePresignedPutURL key=%s contentType=%s metadata=%v → %s", key, contentType, metadata, url)
	return url, nil
}

func (d *DevProvider) GeneratePresignedGetURL(ctx context.Context, key string, ttl time.Duration) (string, error) {
	url := "http://localhost:8080/dev-noop-presign"
	log.Printf("[storage:dev] GeneratePresignedGetURL key=%s → %s", key, url)
	return url, nil
}

func (d *DevProvider) Delete(ctx context.Context, key string) error {
	log.Printf("[storage:dev] Delete key=%s (no-op)", key)
	return nil
}

func (d *DevProvider) Exists(ctx context.Context, key string) (bool, error) {
	log.Printf("[storage:dev] Exists key=%s (no-op -> true)", key)
	return true, nil
}

func (d *DevProvider) DeletePrefix(ctx context.Context, prefix string) error {
	log.Printf("[storage:dev] DeletePrefix prefix=%s (no-op)", prefix)
	return nil
}

func (d *DevProvider) GetPublicURL(key string) string {
	return placeholderURL(key)
}




func placeholderURL(key string) string {
	if strings.HasPrefix(key, "profile-images/") {
		return "https://placehold.co/300x300.jpg?text=Profile"
	}
	return "https://placehold.co/600x400.jpg?text=Product"
}
