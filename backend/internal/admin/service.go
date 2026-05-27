package admin

import (
	"context"
	"crypto/rand"
	"fmt"
	"time"

	"github.com/jmoiron/sqlx"

	"github.com/koydensehire/backend/internal/audit"
	apperrors "github.com/koydensehire/backend/pkg/errors"
	"github.com/koydensehire/backend/pkg/storage"
)

type Service struct {
	repo      *Repository
	db        *sqlx.DB
	storage   storage.Provider
	appEnv    string
	auditRepo *audit.Repository
}

func NewService(repo *Repository, db *sqlx.DB, stor storage.Provider, appEnv string, auditRepo *audit.Repository) *Service {
	return &Service{repo: repo, db: db, storage: stor, appEnv: appEnv, auditRepo: auditRepo}
}

func (s *Service) GetDashboard() (*DashboardResponse, error) {
	stats, err := s.repo.GetDashboardStats()
	if err != nil {
		return nil, err
	}
	apps, _ := s.repo.GetApplicationsByDay()
	cats, _ := s.repo.GetProductsByCategory()
	cities, _ := s.repo.GetProducersByCity()
	return &DashboardResponse{
		Stats:              *stats,
		ApplicationsByDay:  apps,
		ProductsByCategory: cats,
		ProducersByCity:    cities,
	}, nil
}

func (s *Service) GetCityDensity() ([]CityDensityPoint, error) {
	return s.repo.GetCityDensity()
}

func (s *Service) GetInviteNetwork() (*InviteNetworkNode, error) {
	return s.repo.GetInviteNetwork()
}

type ApproveResult struct {
	UserID     string `json:"user_id"`
	FarmerName string `json:"farmer_name"`
	Phone      string `json:"phone"`
	InviteCode string `json:"invite_code"`
}

func (s *Service) ApproveApplication(appID, adminID string, req *ApproveApplicationRequest) (*ApproveResult, error) {
	if s.appEnv == "development" {
		fmt.Printf("[DEBUG] ApproveApplication: appID=%q adminID=%q\n", appID, adminID)
	}

	var app struct {
		ID           string  `db:"id"`
		FullName     string  `db:"full_name"`
		Phone        string  `db:"phone"`
		Email        *string `db:"email"`
		PasswordHash string  `db:"password_hash"`
		BusinessName string  `db:"business_name"`
		ProducerType string  `db:"producer_type"`
		City         string  `db:"city"`
		District     string  `db:"district"`
		Village      string  `db:"village"`
		Bio          string  `db:"bio"`
		Status       string  `db:"status"`
		InviteCodeID *string `db:"invite_code_id"`
	}

	// Use explicit columns — SELECT * on this 37-column table causes sqlx.Get
	// to fail when the destination struct is missing any returned column.
	lookupErr := s.db.Get(&app, `
		SELECT id, full_name, phone, email, password_hash,
		       business_name, producer_type, city, district, village,
		       bio, status, invite_code_id
		FROM farmer_applications
		WHERE id = $1
	`, appID)

	if s.appEnv == "development" {
		fmt.Printf("[DEBUG] ApproveApplication: db_found=%v db_err=%v status=%q\n",
			lookupErr == nil, lookupErr, app.Status)
	}

	if lookupErr != nil {
		return nil, apperrors.ErrNotFound
	}

	if app.Status != "pending" && app.Status != "needs_video" {
		return nil, apperrors.New("INVALID_STATUS", "Bu başvuru onaylanamaz", 400)
	}

	var userExists bool
	s.db.Get(&userExists, "SELECT EXISTS(SELECT 1 FROM users WHERE phone = $1)", app.Phone)
	if userExists {
		return nil, apperrors.New("USER_EXISTS", "Bu telefon ile kayıtlı kullanıcı var", 409)
	}

	tx, err := s.db.Beginx()
	if err != nil {
		return nil, apperrors.ErrInternal
	}
	defer tx.Rollback()

	var userID string
	err = tx.Get(&userID, `
		INSERT INTO users (full_name, phone, email, password_hash, role, status, phone_verified, phone_verified_at)
		VALUES ($1, $2, $3, $4, 'farmer', 'active', true, NOW())
		RETURNING id
	`, app.FullName, app.Phone, app.Email, app.PasswordHash)
	if err != nil {
		if s.appEnv == "development" {
			fmt.Printf("[DEBUG] ApproveApplication: INSERT users err=%v\n", err)
		}
		return nil, apperrors.ErrInternal
	}

	isFounding := req.IsFoundingFarmer
	quota := 2
	if isFounding {
		quota = 5
	}
	if req.InviteQuota != nil {
		quota = *req.InviteQuota
	}

	_, err = tx.Exec(`
		INSERT INTO farmer_profiles (
			user_id, display_name, producer_type, city, district, village, bio,
			public_phone, is_founding_farmer, invite_quota
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
	`, userID, app.BusinessName, app.ProducerType, app.City, app.District,
		app.Village, app.Bio, app.Phone, isFounding, quota)
	if err != nil {
		if s.appEnv == "development" {
			fmt.Printf("[DEBUG] ApproveApplication: INSERT farmer_profiles err=%v\n", err)
		}
		return nil, apperrors.ErrInternal
	}

	code, err := generateUniqueCode(s.db)
	if err != nil {
		return nil, apperrors.ErrInternal
	}

	_, err = tx.Exec(`
		INSERT INTO invite_codes (code, owner_user_id, owner_type, max_uses)
		VALUES ($1, $2, 'farmer', $3)
	`, code, userID, quota)
	if err != nil {
		if s.appEnv == "development" {
			fmt.Printf("[DEBUG] ApproveApplication: INSERT invite_codes err=%v\n", err)
		}
		return nil, apperrors.ErrInternal
	}

	_, err = tx.Exec(`
		UPDATE farmer_applications
		SET status = 'approved', reviewed_by = $1, reviewed_at = NOW(), updated_at = NOW()
		WHERE id = $2
	`, adminID, appID)
	if err != nil {
		return nil, apperrors.ErrInternal
	}

	if app.InviteCodeID != nil {
		tx.Exec(`
			UPDATE invitations SET status = 'approved', updated_at = NOW()
			WHERE application_id = $1
		`, appID)
	}

	if err := tx.Commit(); err != nil {
		return nil, apperrors.ErrInternal
	}

	go func() {
		reason := "Başvuru onaylandı"
		_ = s.auditRepo.Create(context.Background(), audit.CreateParams{
			AdminID:    adminID,
			Action:     audit.ActionApplicationApproved,
			TargetType: audit.TargetApplication,
			TargetID:   appID,
			TargetSnapshot: map[string]any{
				"full_name": app.FullName,
				"phone":     app.Phone,
			},
			Reason: &reason,
		})
	}()

	return &ApproveResult{
		UserID:     userID,
		FarmerName: app.FullName,
		Phone:      app.Phone,
		InviteCode: code,
	}, nil
}

func (s *Service) GetApplicationWithVideoURL(appID string) (map[string]any, error) {
	var app struct {
		ID                  string  `db:"id"`
		FullName            string  `db:"full_name"`
		Phone               string  `db:"phone"`
		Status              string  `db:"status"`
		ApplicationVideoKey *string `db:"application_video_key"`
	}
	if err := s.db.Get(&app, `
		SELECT id, full_name, phone, status, application_video_key
		FROM farmer_applications WHERE id = $1
	`, appID); err != nil {
		return nil, apperrors.ErrNotFound
	}

	result := map[string]any{
		"id":        app.ID,
		"full_name": app.FullName,
		"phone":     app.Phone,
		"status":    app.Status,
	}

	if app.ApplicationVideoKey != nil {
		url, err := s.storage.GeneratePresignedGetURL(context.Background(), *app.ApplicationVideoKey, time.Hour)
		if err == nil {
			result["application_video_url"] = url
		}
	}

	return result, nil
}

func generateUniqueCode(db *sqlx.DB) (string, error) {
	const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	for range 10 {
		b := make([]byte, 6)
		if _, err := rand.Read(b); err != nil {
			return "", fmt.Errorf("generating random bytes: %w", err)
		}
		for i := range b {
			b[i] = chars[int(b[i])%len(chars)]
		}
		code := "KYS-" + string(b)
		var exists bool
		db.Get(&exists, "SELECT EXISTS(SELECT 1 FROM invite_codes WHERE code = $1)", code)
		if !exists {
			return code, nil
		}
	}
	return "", apperrors.ErrInternal
}
