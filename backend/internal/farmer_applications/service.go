package farmer_applications

import (
	"context"
	"fmt"
	"time"

	apperrors "github.com/koydensehire/backend/pkg/errors"
	"github.com/koydensehire/backend/pkg/storage"
	"github.com/redis/go-redis/v9"
)

type FullService struct {
	repo    *Repository
	rdb     *redis.Client
	storage storage.Provider
}

func NewService(repo *Repository, rdb *redis.Client, stor storage.Provider) *FullService {
	return &FullService{repo: repo, rdb: rdb, storage: stor}
}

func (s *FullService) GenerateVideoPresignURL(phone, inviteCode, contentType string) (*VideoPresignResponse, error) {
	ctx := context.Background()

	verifiedKey := fmt.Sprintf("otp_verified:%s", phone)
	exists, err := s.rdb.Exists(ctx, verifiedKey).Result()
	if err != nil || exists == 0 {
		return nil, apperrors.New("PHONE_NOT_VERIFIED", "Telefon numarası doğrulanmamış", 400)
	}

	_ = inviteCode

	timestamp := time.Now().Unix()
	key := fmt.Sprintf("application-videos/pending/%s/%d.mp4", phone, timestamp)

	url, err := s.storage.GeneratePresignedPutURL(ctx, key, "video/mp4", nil, 15*time.Minute)
	if err != nil {
		return nil, apperrors.ErrInternal
	}

	return &VideoPresignResponse{
		UploadURL: url,
		Key:       key,
	}, nil
}
