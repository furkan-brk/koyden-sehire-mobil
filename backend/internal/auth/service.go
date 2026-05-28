package auth

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"log"
	"time"

	"github.com/golang-jwt/jwt/v5"
	apperrors "github.com/koydensehire/backend/pkg/errors"
	"github.com/koydensehire/backend/pkg/sms"
	"github.com/redis/go-redis/v9"
	"golang.org/x/crypto/bcrypt"
)

// PasswordUpdater is the subset of users.Repository used by auth.Service for password reset.
type PasswordUpdater interface {
	UpdatePasswordByPhone(phone, hashedPw string) error
}

type Service struct {
	repo               UserFinder
	rdb                *redis.Client
	jwtSecret          string
	jwtExpiry          time.Duration
	refreshTokenExpiry time.Duration
	userRepo           PasswordUpdater
	smsProvider        sms.Provider
	appEnv             string
}

func NewService(repo *Repository, rdb *redis.Client, jwtSecret string, jwtExpiry, refreshTokenExpiry time.Duration) *Service {
	return &Service{
		repo:               repo,
		rdb:                rdb,
		jwtSecret:          jwtSecret,
		jwtExpiry:          jwtExpiry,
		refreshTokenExpiry: refreshTokenExpiry,
	}
}

// newServiceWithFinder is used by tests to inject a mock UserFinder.
func newServiceWithFinder(repo UserFinder, rdb *redis.Client, jwtSecret string, jwtExpiry, refreshTokenExpiry time.Duration) *Service {
	return &Service{
		repo:               repo,
		rdb:                rdb,
		jwtSecret:          jwtSecret,
		jwtExpiry:          jwtExpiry,
		refreshTokenExpiry: refreshTokenExpiry,
	}
}

// SetUserRepo injects the users repository dependency for password-reset operations.
// Called after construction so the circular-dependency between packages is avoided.
func (s *Service) SetUserRepo(r PasswordUpdater) {
	s.userRepo = r
}

// SetSMSProvider injects the SMS provider for password-reset OTP delivery.
func (s *Service) SetSMSProvider(p sms.Provider, appEnv string) {
	s.smsProvider = p
	s.appEnv = appEnv
}

func (s *Service) Login(req *LoginRequest) (*LoginResponse, error) {
	user, err := s.repo.FindByPhone(req.Phone)
	if err != nil {
		return nil, apperrors.New("INVALID_CREDENTIALS", "Telefon numarası veya şifre hatalı", 401)
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		return nil, apperrors.New("INVALID_CREDENTIALS", "Telefon numarası veya şifre hatalı", 401)
	}

	if user.Status == "suspended" {
		return nil, apperrors.New("ACCOUNT_SUSPENDED", "Hesabınız askıya alınmıştır", 403)
	}

	token, err := s.generateToken(user)
	if err != nil {
		return nil, apperrors.ErrInternal
	}

	refreshToken, err := s.issueRefreshToken(context.Background(), user.ID)
	if err != nil {
		return nil, apperrors.ErrInternal
	}

	return &LoginResponse{
		AccessToken:  token,
		RefreshToken: refreshToken,
		User: UserInfo{
			ID:     user.ID,
			Name:   user.FullName,
			Phone:  user.Phone,
			Role:   user.Role,
			Status: user.Status,
		},
	}, nil
}

// RegisterCustomer creates a new 'customer' account.
// Preconditions:
//   - The phone must have a fresh otp_verified:{phone} marker in Redis (set by otp.Verify).
//     We consume (delete) it on success so the same OTP cannot be reused.
//   - Phone / email must be unique (enforced at DB level; mapped to 409 by repo).
func (s *Service) RegisterCustomer(req *RegisterCustomerRequest) (*LoginResponse, error) {
	if !validPhone(req.Phone) {
		return nil, apperrors.New("INVALID_PHONE", "Geçersiz telefon numarası formatı", 400)
	}

	ctx := context.Background()
	verifiedKey := fmt.Sprintf("otp_verified:%s", req.Phone)

	exists, err := s.rdb.Exists(ctx, verifiedKey).Result()
	if err != nil {
		return nil, apperrors.ErrInternal
	}
	if exists == 0 {
		// Either OTP was never verified or the 30-min window expired.
		return nil, apperrors.New("OTP_NOT_VERIFIED", "Telefon doğrulaması gerekli", 400)
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), 12)
	if err != nil {
		return nil, apperrors.ErrInternal
	}

	user, err := s.repo.CreateCustomer(req.FullName, req.Phone, req.Email, string(hash))
	if err != nil {
		return nil, err
	}

	// Consume the OTP marker so this same verification can't be reused for
	// another registration attempt.
	s.rdb.Del(ctx, verifiedKey)

	token, err := s.generateToken(user)
	if err != nil {
		return nil, apperrors.ErrInternal
	}

	refreshToken, err := s.issueRefreshToken(ctx, user.ID)
	if err != nil {
		return nil, apperrors.ErrInternal
	}

	return &LoginResponse{
		AccessToken:  token,
		RefreshToken: refreshToken,
		User: UserInfo{
			ID:     user.ID,
			Name:   user.FullName,
			Phone:  user.Phone,
			Role:   user.Role,
			Status: user.Status,
		},
	}, nil
}

// Refresh validates the given refresh token, issues a new access token and a
// rotated refresh token (old token is deleted), and returns a full LoginResponse.
func (s *Service) Refresh(req *RefreshRequest) (*LoginResponse, error) {
	ctx := context.Background()
	key := refreshKey(req.RefreshToken)

	userID, err := s.rdb.Get(ctx, key).Result()
	if err != nil {
		return nil, apperrors.New("INVALID_REFRESH_TOKEN", "Oturum süresi doldu, lütfen tekrar giriş yapın", 401)
	}

	user, err := s.repo.FindByID(userID)
	if err != nil {
		return nil, apperrors.New("INVALID_REFRESH_TOKEN", "Oturum süresi doldu, lütfen tekrar giriş yapın", 401)
	}

	if user.Status == "suspended" {
		return nil, apperrors.New("ACCOUNT_SUSPENDED", "Hesabınız askıya alınmıştır", 403)
	}

	// Token rotation: delete the old refresh token first.
	s.rdb.Del(ctx, key)

	accessToken, err := s.generateToken(user)
	if err != nil {
		return nil, apperrors.ErrInternal
	}

	newRefreshToken, err := s.issueRefreshToken(ctx, user.ID)
	if err != nil {
		return nil, apperrors.ErrInternal
	}

	return &LoginResponse{
		AccessToken:  accessToken,
		RefreshToken: newRefreshToken,
		User: UserInfo{
			ID:     user.ID,
			Name:   user.FullName,
			Phone:  user.Phone,
			Role:   user.Role,
			Status: user.Status,
		},
	}, nil
}

func (s *Service) generateToken(user *User) (string, error) {
	claims := jwt.MapClaims{
		"user_id": user.ID,
		"role":    user.Role,
		"exp":     time.Now().Add(s.jwtExpiry).Unix(),
		"iat":     time.Now().Unix(),
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := token.SignedString([]byte(s.jwtSecret))
	if err != nil {
		return "", fmt.Errorf("signing token: %w", err)
	}
	return signed, nil
}

func refreshKey(token string) string {
	return fmt.Sprintf("refresh_token:%s", token)
}

func (s *Service) issueRefreshToken(ctx context.Context, userID string) (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	token := hex.EncodeToString(b)
	if err := s.rdb.Set(ctx, refreshKey(token), userID, s.refreshTokenExpiry).Err(); err != nil {
		return "", err
	}
	return token, nil
}

// ForgotPassword telefona şifre sıfırlama OTP'si gönderir.
// OTP, login OTP'siyle çakışmaması için "reset:{phone}" key'iyle Redis'e yazılır (5 dk TTL).
// Development modunda kod stdout'a basılır; production'da SMS gönderilir.
func (s *Service) ForgotPassword(phone string) error {
	if !validPhone(phone) {
		return apperrors.New("INVALID_PHONE", "Geçersiz telefon numarası formatı", 400)
	}

	_, err := s.repo.FindByPhone(phone)
	if err != nil {
		return apperrors.New("PHONE_NOT_FOUND", "Bu telefon numarasıyla kayıtlı hesap bulunamadı", 404)
	}

	ctx := context.Background()
	resetKey := fmt.Sprintf("reset:%s", phone)

	code := generateOTPCode()
	value := fmt.Sprintf("%s:0", code)
	if err := s.rdb.Set(ctx, resetKey, value, 300*time.Second).Err(); err != nil {
		return apperrors.ErrInternal
	}

	if s.appEnv == "development" {
		log.Printf("[RESET OTP] %s -> %s", phone, code)
	} else if s.smsProvider != nil {
		msg := fmt.Sprintf("Köyden Şehire şifre sıfırlama kodunuz: %s. Bu kod 5 dakika geçerlidir.", code)
		go func() {
			if err := s.smsProvider.Send(phone, msg); err != nil {
				log.Printf("[SMS] reset OTP send failed: %v", err)
			}
		}()
	}

	return nil
}

// ResetPassword OTP'yi doğrular ve şifreyi günceller.
func (s *Service) ResetPassword(req *ResetPasswordRequest) error {
	if !validPhone(req.Phone) {
		return apperrors.New("INVALID_PHONE", "Geçersiz telefon numarası formatı", 400)
	}
	if len(req.NewPassword) < 8 {
		return apperrors.New("PASSWORD_TOO_SHORT", "Şifre en az 8 karakter olmalıdır", 400)
	}

	ctx := context.Background()
	resetKey := fmt.Sprintf("reset:%s", req.Phone)

	val, err := s.rdb.Get(ctx, resetKey).Result()
	if err != nil {
		return apperrors.New("OTP_EXPIRED", "OTP süresi dolmuş veya bulunamadı", 400)
	}

	storedCode, attempts := splitCode(val)

	if attempts >= 3 {
		s.rdb.Del(ctx, resetKey)
		return apperrors.New("OTP_EXPIRED", "Çok fazla yanlış deneme, lütfen yeniden şifre sıfırlama isteği gönderin", 400)
	}

	if storedCode != req.OTP {
		newAttempts := attempts + 1
		remaining := 3 - newAttempts
		newVal := fmt.Sprintf("%s:%d", storedCode, newAttempts)
		ttl, _ := s.rdb.TTL(ctx, resetKey).Result()
		s.rdb.Set(ctx, resetKey, newVal, ttl)
		return apperrors.New("OTP_INVALID", fmt.Sprintf("OTP hatalı, %d deneme hakkınız kaldı", remaining), 400)
	}

	// OTP doğrulandı — tek kullanım
	s.rdb.Del(ctx, resetKey)

	hash, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), 12)
	if err != nil {
		return apperrors.ErrInternal
	}

	if s.userRepo == nil {
		return apperrors.ErrInternal
	}

	return s.userRepo.UpdatePasswordByPhone(req.Phone, string(hash))
}

func generateOTPCode() string {
	// 6 haneli sayısal sıfırlama kodu
	b := make([]byte, 3)
	rand.Read(b)
	code := (int(b[0])<<16 | int(b[1])<<8 | int(b[2])) % 1000000
	return fmt.Sprintf("%06d", code)
}

func splitCode(val string) (string, int) {
	for i := len(val) - 1; i >= 0; i-- {
		if val[i] == ':' {
			code := val[:i]
			attempts := 0
			fmt.Sscanf(val[i+1:], "%d", &attempts)
			return code, attempts
		}
	}
	return val, 0
}

// validPhone matches the same 05XXXXXXXXX format enforced by the OTP service,
// so we never accept a registration phone that the OTP flow couldn't have verified.
func validPhone(phone string) bool {
	if len(phone) != 11 {
		return false
	}
	if phone[0] != '0' || phone[1] != '5' {
		return false
	}
	for i := 2; i < 11; i++ {
		c := phone[i]
		if c < '0' || c > '9' {
			return false
		}
	}
	return true
}
