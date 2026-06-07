package farmer_applications

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/jmoiron/sqlx"
	"github.com/redis/go-redis/v9"
	"golang.org/x/crypto/bcrypt"

	apperrors "github.com/koydensehire/backend/pkg/errors"
	"github.com/koydensehire/backend/pkg/response"
	"github.com/koydensehire/backend/pkg/storage"
	"github.com/koydensehire/backend/pkg/validator"
)

type Handler struct {
	repo    *Repository
	rdb     *redis.Client
	db      *sqlx.DB
	storage storage.Provider
	appEnv  string
}

func NewHandler(repo *Repository, rdb *redis.Client, db *sqlx.DB, stor storage.Provider, appEnv string) *Handler {
	return &Handler{repo: repo, rdb: rdb, db: db, storage: stor, appEnv: appEnv}
}

func (h *Handler) Create(c *fiber.Ctx) error {
	var req CreateApplicationRequest
	if err := c.BodyParser(&req); err != nil {
		return response.BadRequest(c, "Geçersiz istek gövdesi")
	}
	if err := validator.Validate(&req); err != nil {
		return response.BadRequest(c, "Zorunlu alanlar eksik")
	}

	if !req.KvkkAccepted || !req.PlatformTermsAccepted ||
		!req.DeclaresOwnProduction || !req.DeclaresAccurateLocation || !req.DeclaresNotIntermediary {
		return response.BadRequest(c, "Tüm koşullar kabul edilmelidir")
	}

	ctx := context.Background()

	// --- invite code validation ---
	rawCode := req.InviteCode
	inviteCode := strings.ToUpper(strings.TrimSpace(rawCode))

	if h.appEnv == "development" {
		fmt.Printf("[DEBUG] farmer-applications Create: received=%q normalized=%q\n", rawCode, inviteCode)
	}

	// Use an explicit column list — SELECT * would fail if the inline struct is
	// missing any column returned by the DB (e.g. expires_at, created_at, updated_at).
	var ic struct {
		ID          string     `db:"id"`
		OwnerUserID string     `db:"owner_user_id"`
		OwnerType   string     `db:"owner_type"`
		MaxUses     int        `db:"max_uses"`
		UsedCount   int        `db:"used_count"`
		IsActive    bool       `db:"is_active"`
		ExpiresAt   *time.Time `db:"expires_at"`
	}
	lookupErr := h.db.Get(&ic, `
		SELECT id, owner_user_id, owner_type, max_uses, used_count, is_active, expires_at
		FROM invite_codes
		WHERE code = $1
	`, inviteCode)

	if h.appEnv == "development" {
		fmt.Printf("[DEBUG] farmer-applications Create: db_found=%v db_err=%v used=%d max=%d is_active=%v expires_at=%v\n",
			lookupErr == nil, lookupErr, ic.UsedCount, ic.MaxUses, ic.IsActive, ic.ExpiresAt)
	}

	if lookupErr != nil {
		return response.BadRequest(c, "Geçersiz davet kodu")
	}

	// Validate code state
	if !ic.IsActive {
		return response.BadRequest(c, "Davet kodu aktif değil")
	}
	if ic.UsedCount >= ic.MaxUses {
		return response.BadRequest(c, "Davet kodu dolmuş")
	}
	if ic.ExpiresAt != nil && ic.ExpiresAt.Before(time.Now()) {
		return response.BadRequest(c, "Davet kodu süresi dolmuş")
	}

	verifiedKey := fmt.Sprintf("otp_verified:%s", req.Phone)
	exists, err := h.rdb.Exists(ctx, verifiedKey).Result()
	if err != nil || exists == 0 {
		return response.BadRequest(c, "Telefon numarası doğrulanmamış")
	}

	phoneInUsers, _ := h.repo.PhoneExistsInUsers(req.Phone)
	if phoneInUsers {
		return response.Conflict(c, "Bu telefon numarası ile kayıtlı bir hesap var")
	}

	phoneInApps, _ := h.repo.PhoneExistsActive(req.Phone)
	if phoneInApps {
		return response.Conflict(c, "Bu telefon için aktif bir başvuru bulunuyor")
	}

	if req.ApplicationVideoKey != nil {
		prefix := fmt.Sprintf("application-videos/pending/%s/", req.Phone)
		key := *req.ApplicationVideoKey
		if !strings.HasPrefix(key, prefix) || strings.Contains(key, "..") ||
			strings.Contains(key, "//") || strings.Contains(key, "\\") {
			return response.BadRequest(c, "Geçersiz video anahtarı")
		}
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), 12)
	if err != nil {
		return response.Error(c, apperrors.ErrInternal)
	}

	source := "farmer_invite"
	if ic.OwnerType == "admin" {
		source = "admin_invite"
	}

	inviteCodeID := ic.ID
	referredByID := ic.OwnerUserID

	// Atomically consume one invite slot before creating the application.
	// The WHERE clause guards against TOCTOU: if two requests pass the
	// earlier check simultaneously, only one UPDATE will succeed.
	consumeRes, err := h.db.Exec(`
		UPDATE invite_codes
		SET used_count = used_count + 1, updated_at = NOW()
		WHERE id = $1
		  AND is_active = true
		  AND used_count < max_uses
		  AND (expires_at IS NULL OR expires_at > NOW())
	`, ic.ID)
	if err != nil {
		return response.Error(c, apperrors.ErrInternal)
	}
	if affected, _ := consumeRes.RowsAffected(); affected == 0 {
		return response.BadRequest(c, "Davet kodu dolmuş veya geçersiz")
	}

	app, err := h.repo.Create(&req, string(hash), &inviteCodeID, &referredByID, source)
	if err != nil {
		// Roll back the invite consumption since the application failed.
		h.db.Exec(`UPDATE invite_codes SET used_count = used_count - 1, updated_at = NOW() WHERE id = $1`, ic.ID)
		return response.Error(c, apperrors.ErrInternal)
	}

	h.rdb.Del(ctx, verifiedKey)

	go fireNewApplicationWebhook(app)

	return response.Created(c, fiber.Map{"message": "Başvurunuz alındı", "application_id": app.ID}, "Başvurunuz alındı")
}

func (h *Handler) VideoPresign(c *fiber.Ctx) error {
	var req VideoPresignRequest
	if err := c.BodyParser(&req); err != nil {
		return response.BadRequest(c, "Geçersiz istek gövdesi")
	}
	if err := validator.Validate(&req); err != nil {
		return response.BadRequest(c, "Zorunlu alanlar eksik")
	}

	if !validPhone(req.Phone) {
		return response.BadRequest(c, "Geçersiz telefon numarası formatı")
	}

	ctx := context.Background()
	inviteCode := strings.ToUpper(strings.TrimSpace(req.InviteCode))

	var ic struct {
		IsActive  bool       `db:"is_active"`
		MaxUses   int        `db:"max_uses"`
		UsedCount int        `db:"used_count"`
		ExpiresAt *time.Time `db:"expires_at"`
	}
	if err := h.db.Get(&ic, `
		SELECT is_active, max_uses, used_count, expires_at
		FROM invite_codes WHERE code = $1
	`, inviteCode); err != nil {
		return response.BadRequest(c, "Geçersiz davet kodu")
	}
	if !ic.IsActive || ic.UsedCount >= ic.MaxUses {
		return response.BadRequest(c, "Davet kodu geçersiz veya dolmuş")
	}
	if ic.ExpiresAt != nil && ic.ExpiresAt.Before(time.Now()) {
		return response.BadRequest(c, "Davet kodu süresi dolmuş")
	}

	verifiedKey := fmt.Sprintf("otp_verified:%s", req.Phone)
	exists, err := h.rdb.Exists(ctx, verifiedKey).Result()
	if err != nil || exists == 0 {
		return response.BadRequest(c, "Telefon numarası doğrulanmamış")
	}

	timestamp := time.Now().Unix()
	key := fmt.Sprintf("application-videos/pending/%s/%d.mp4", req.Phone, timestamp)

	url, err := h.storage.GeneratePresignedPutURL(ctx, key, "video/mp4", nil, 15*time.Minute)
	if err != nil {
		return response.Error(c, apperrors.ErrInternal)
	}

	return response.Success(c, VideoPresignResponse{
		UploadURL: url,
		Key:       key,
	}, "")
}

func validPhone(phone string) bool {
	if len(phone) != 11 {
		return false
	}
	if !strings.HasPrefix(phone, "05") {
		return false
	}
	for _, c := range phone[1:] {
		if c < '0' || c > '9' {
			return false
		}
	}
	return true
}

func fireNewApplicationWebhook(_ *FarmerApplication) {
	// n8n webhook fired by caller if notification service is wired in
}
