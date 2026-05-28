package users

import (
	"context"
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/koydensehire/backend/internal/audit"
	apperrors "github.com/koydensehire/backend/pkg/errors"
	"github.com/redis/go-redis/v9"
	"golang.org/x/crypto/bcrypt"
)

// AuditLogger is the subset of audit.Repository used by users.Service.
type AuditLogger interface {
	Create(ctx context.Context, p audit.CreateParams) error
}

type Service struct {
	repo      *Repository
	auditRepo AuditLogger
	rdb       *redis.Client
}

func NewService(repo *Repository) *Service {
	return &Service{repo: repo}
}

// SetDeps injects optional dependencies for account deletion (audit log + Redis blacklist).
func (s *Service) SetDeps(auditRepo AuditLogger, rdb *redis.Client) {
	s.auditRepo = auditRepo
	s.rdb = rdb
}

func (s *Service) GetProfile(userID string) (*User, *FarmerProfile, error) {
	user, err := s.repo.GetByID(userID)
	if err != nil {
		return nil, nil, err
	}
	profile, err := s.repo.GetFarmerProfile(userID)
	if err != nil {
		return nil, nil, apperrors.ErrNotFound
	}
	return user, profile, nil
}

func (s *Service) UpdateProfile(userID string, req *UpdateProfileRequest) error {
	return s.repo.UpdateFarmerProfile(userID, req)
}

func (s *Service) GetCustomerProfile(userID string) (*CustomerProfileResponse, error) {
	user, err := s.repo.GetByID(userID)
	if err != nil {
		return nil, err
	}
	return &CustomerProfileResponse{
		ID:        user.ID,
		FullName:  user.FullName,
		Phone:     user.Phone,
		Email:     user.Email,
		CreatedAt: user.CreatedAt,
	}, nil
}

func (s *Service) UpdateCustomerProfile(userID string, req *UpdateCustomerProfileRequest) (*CustomerProfileResponse, error) {
	if err := s.repo.UpdateCustomerProfile(userID, req); err != nil {
		if strings.Contains(err.Error(), "unique") || strings.Contains(err.Error(), "duplicate") {
			return nil, apperrors.New("EMAIL_CONFLICT", "Bu e-posta adresi zaten kullanımda", 409)
		}
		return nil, apperrors.ErrInternal
	}
	return s.GetCustomerProfile(userID)
}

// DeleteAccount şifre doğrular, soft-delete uygular, Redis blacklist ekler ve audit log yazar.
// userID: JWT'den gelen kimlik, role: "farmer" veya "customer".
func (s *Service) DeleteAccount(userID, role, password string) error {
	// Şifre doğrulaması
	currentHash, err := s.repo.FindPasswordHashByID(userID)
	if err != nil {
		return apperrors.ErrNotFound
	}
	if err := bcrypt.CompareHashAndPassword([]byte(currentHash), []byte(password)); err != nil {
		return apperrors.New("INVALID_PASSWORD", "Şifre hatalı", 401)
	}

	// Soft-delete
	if err := s.repo.SoftDeleteUser(userID); err != nil {
		return err
	}

	ctx := context.Background()

	// Redis blacklist: JWT access token expiry'sine kadar geçerli — 24 saat yeterli
	if s.rdb != nil {
		blacklistKey := fmt.Sprintf("blacklist:%s", userID)
		if err := s.rdb.Set(ctx, blacklistKey, "1", 24*time.Hour).Err(); err != nil {
			log.Printf("[WARN] blacklist set failed for user=%s: %v", userID, err)
		}
	}

	// Audit log
	if s.auditRepo != nil {
		go func() {
			_ = s.auditRepo.Create(context.Background(), audit.CreateParams{
				AdminID:    userID, // kendi kendini sildi
				Action:     audit.ActionAccountDeleted,
				TargetType: audit.TargetUser,
				TargetID:   userID,
				Metadata:   map[string]any{"role": role, "self_deletion": true},
			})
		}()
	}

	return nil
}
