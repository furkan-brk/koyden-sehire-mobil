package uploads

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"log"
	"net/http"
	"path/filepath"
	"strings"
	"time"

	"github.com/google/uuid"
	apperrors "github.com/koydensehire/backend/pkg/errors"
	"github.com/koydensehire/backend/pkg/storage"
)

type ProductRepository interface {
	CreateDraft(id, farmerID string) error
}

type Service struct {
	storage     storage.Provider
	productRepo ProductRepository
}

func NewService(stor storage.Provider, productRepo ProductRepository) *Service {
	return &Service{storage: stor, productRepo: productRepo}
}

var allowedImageTypes = map[string]bool{
	"image/jpeg": true,
	"image/png":  true,
	"image/webp": true,
}

var allowedImageExts = map[string]string{
	"image/jpeg": ".jpg",
	"image/png":  ".png",
	"image/webp": ".webp",
}


func (s *Service) UploadProductImage(farmerID string, file io.Reader, filename string, size int64) (*UploadImageResponse, error) {
	if size > 5*1024*1024 {
		return nil, apperrors.New("FILE_TOO_LARGE", "Resim 5MB'dan büyük olamaz", 400)
	}

	buf := make([]byte, 512)
	n, err := io.ReadFull(file, buf)
	if err != nil && err != io.ErrUnexpectedEOF && err != io.EOF {
		return nil, apperrors.ErrInternal
	}
	buf = buf[:n]

	contentType := http.DetectContentType(buf)
	log.Printf("[upload] product-image farmerID=%s filename=%s size=%d contentType=%s", farmerID, filename, size, contentType)
	if !allowedImageTypes[contentType] {
		return nil, apperrors.New("INVALID_FILE_TYPE", "Sadece JPEG, PNG veya WebP yükleyebilirsiniz", 400)
	}

	combined := io.MultiReader(bytes.NewReader(buf), file)
	key := fmt.Sprintf("product-images/%s/%d_%s", farmerID, time.Now().Unix(), sanitizeFilename(filename))

	url, err := s.storage.Upload(context.Background(), key, combined, contentType, size)
	if err != nil {
		return nil, apperrors.ErrInternal
	}

	return &UploadImageResponse{URL: url}, nil
}

func (s *Service) UploadProfileImage(farmerID string, file io.Reader, filename string, size int64) (*UploadImageResponse, error) {
	if size > 2*1024*1024 {
		return nil, apperrors.New("FILE_TOO_LARGE", "Profil resmi 2MB'dan büyük olamaz", 400)
	}

	buf := make([]byte, 512)
	n, err := io.ReadFull(file, buf)
	if err != nil && err != io.ErrUnexpectedEOF && err != io.EOF {
		return nil, apperrors.ErrInternal
	}
	buf = buf[:n]

	contentType := http.DetectContentType(buf)
	log.Printf("[upload] profile-image farmerID=%s filename=%s size=%d contentType=%s", farmerID, filename, size, contentType)
	if !allowedImageTypes[contentType] {
		return nil, apperrors.New("INVALID_FILE_TYPE", "Sadece JPEG, PNG veya WebP yükleyebilirsiniz", 400)
	}

	combined := io.MultiReader(bytes.NewReader(buf), file)
	key := fmt.Sprintf("profile-images/%s/%d_%s", farmerID, time.Now().Unix(), sanitizeFilename(filename))

	url, err := s.storage.Upload(context.Background(), key, combined, contentType, size)
	if err != nil {
		return nil, apperrors.ErrInternal
	}

	return &UploadImageResponse{URL: url}, nil
}

func sanitizeFilename(name string) string {
	ext := filepath.Ext(name)
	base := strings.TrimSuffix(name, ext)
	safe := strings.Map(func(r rune) rune {
		if (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') || r == '-' || r == '_' {
			return r
		}
		return '_'
	}, base)
	return safe + ext
}

func (s *Service) GenerateProductImagePresignedURL(ctx context.Context, farmerID string, req *PresignedURLRequest) (*PresignedURLResponse, error) {
	if req.FileSize > 5*1024*1024 {
		return nil, apperrors.New("FILE_TOO_LARGE", "Resim 5MB'dan büyük olamaz", 400)
	}

	ext, ok := allowedImageExts[req.ContentType]
	if !ok {
		return nil, apperrors.New("INVALID_FILE_TYPE", "Sadece JPEG, PNG veya WebP yükleyebilirsiniz", 400)
	}

	// 1. Create/ensure the product is registered as draft ('on-going') in the database
	if err := s.productRepo.CreateDraft(req.ProductID, farmerID); err != nil {
		log.Printf("[upload] failed to create draft product: %v", err)
		return nil, apperrors.ErrInternal
	}

	// 2. Generate the key: products/images/{farmer_id}/{product_id}/{image_uuid}.{ext}
	imageUUID := uuid.NewString()
	key := fmt.Sprintf("products/images/%s/%s/%s%s", farmerID, req.ProductID, imageUUID, ext)

	// 3. Generate presigned PUT URL — no S3 metadata so x-amz-meta-* headers are not
	// added to X-Amz-SignedHeaders; this avoids CORS preflight failures in web browsers.
	// farmer_id and product_id are already encoded in the key path.
	url, err := s.storage.GeneratePresignedPutURL(ctx, key, req.ContentType, nil, 15*time.Minute)
	if err != nil {
		log.Printf("[upload] failed to generate presigned URL: %v", err)
		return nil, apperrors.ErrInternal
	}

	headers := map[string]string{
		"Content-Type": req.ContentType,
	}

	return &PresignedURLResponse{
		UploadURL: url,
		Key:       key,
		URL:       s.storage.GetPublicURL(key),
		Headers:   headers,
	}, nil
}
