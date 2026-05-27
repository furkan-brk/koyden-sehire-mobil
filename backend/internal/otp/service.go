package otp

import (
	"context"
	"crypto/rand"
	"fmt"
	"log"
	"math/big"
	"strconv"
	"strings"
	"time"

	"github.com/koydensehire/backend/pkg/errors"
	"github.com/koydensehire/backend/pkg/sms"
	"github.com/redis/go-redis/v9"
)

var phoneRegex = `^05[0-9]{9}$`

var otpWhitelist = map[string]struct{}{
	"05327300325": {},
}

func isOtpWhitelisted(phone string) bool {
	_, ok := otpWhitelist[phone]
	return ok
}

type Service struct {
	repo            *Repository
	rdb             *redis.Client
	smsProvider     sms.Provider
	expirySeconds   int
	maxAttempts     int
	cooldownSeconds int
	appEnv          string
}

func NewService(repo *Repository, rdb *redis.Client, smsProv sms.Provider, expiry, maxAttempts, cooldown int, appEnv string) *Service {
	return &Service{
		repo:            repo,
		rdb:             rdb,
		smsProvider:     smsProv,
		expirySeconds:   expiry,
		maxAttempts:     maxAttempts,
		cooldownSeconds: cooldown,
		appEnv:          appEnv,
	}
}

func (s *Service) Send(phone, ip, userAgent string) (*SendResponse, error) {
	if !validPhone(phone) {
		return nil, errors.New("INVALID_PHONE", "Geçersiz telefon numarası formatı", 400)
	}

	ctx := context.Background()
	cooldownKey := fmt.Sprintf("otp_cooldown:%s", phone)

	if !isOtpWhitelisted(phone) && s.appEnv != "development" {
		exists, err := s.rdb.Exists(ctx, cooldownKey).Result()
		if err != nil {
			return nil, errors.ErrInternal
		}
		if exists > 0 {
			return nil, errors.New("COOLDOWN_ACTIVE", "Lütfen biraz bekleyin ve tekrar deneyin", 429)
		}
	}

	code := generateCode()

	otpKey := fmt.Sprintf("otp:%s", phone)
	value := fmt.Sprintf("%s:0", code)

	if err := s.rdb.Set(ctx, otpKey, value, time.Duration(s.expirySeconds)*time.Second).Err(); err != nil {
		return nil, errors.ErrInternal
	}

	if !isOtpWhitelisted(phone) && s.appEnv != "development" {
		if err := s.rdb.Set(ctx, cooldownKey, "1", time.Duration(s.cooldownSeconds)*time.Second).Err(); err != nil {
			log.Printf("failed to set OTP cooldown: %v", err)
		}
	}

	var devCode *string
	if s.appEnv == "development" {
		masked := maskPhone(phone)
		log.Printf("OTP for %s: %s", masked, code)
		devCode = &code
	} else {
		msg := fmt.Sprintf("Köyden Şehre doğrulama kodunuz: %s. Bu kod 5 dakika geçerlidir.", code)
		go func() {
			if err := s.smsProvider.Send(phone, msg); err != nil {
				log.Printf("SMS send failed for masked phone: %v", err)
			}
		}()
	}

	s.repo.InsertAudit(phone, "phone_verification", ip, userAgent)

	return &SendResponse{
		Message:   "OTP gönderildi",
		ExpiresIn: s.expirySeconds,
		DevCode:   devCode,
	}, nil
}

func (s *Service) Verify(phone, code string) (*VerifyResponse, error) {
	if !validPhone(phone) {
		return nil, errors.New("INVALID_PHONE", "Geçersiz telefon numarası formatı", 400)
	}

	ctx := context.Background()
	otpKey := fmt.Sprintf("otp:%s", phone)

	val, err := s.rdb.Get(ctx, otpKey).Result()
	if err == redis.Nil {
		return nil, errors.New("OTP_EXPIRED", "OTP süresi dolmuş veya bulunamadı", 400)
	}
	if err != nil {
		return nil, errors.ErrInternal
	}

	parts := strings.SplitN(val, ":", 2)
	if len(parts) != 2 {
		return nil, errors.ErrInternal
	}

	storedCode := parts[0]
	attempts, _ := strconv.Atoi(parts[1])

	if attempts >= s.maxAttempts {
		s.rdb.Del(ctx, otpKey)
		return nil, errors.New("MAX_ATTEMPTS", "Çok fazla yanlış deneme", 400)
	}

	if storedCode != code {
		attempts++
		remaining := s.maxAttempts - attempts
		newVal := fmt.Sprintf("%s:%d", storedCode, attempts)
		ttl, _ := s.rdb.TTL(ctx, otpKey).Result()
		s.rdb.Set(ctx, otpKey, newVal, ttl)
		return nil, errors.New("INVALID_CODE", fmt.Sprintf("Kod hatalı, %d deneme hakkınız kaldı", remaining), 400)
	}

	s.rdb.Del(ctx, otpKey)

	verifiedKey := fmt.Sprintf("otp_verified:%s", phone)
	s.rdb.Set(ctx, verifiedKey, "1", 1800*time.Second)

	s.repo.MarkVerified(phone)

	return &VerifyResponse{Verified: true}, nil
}

func generateCode() string {
	n, _ := rand.Int(rand.Reader, big.NewInt(1000000))
	return fmt.Sprintf("%06d", n.Int64())
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

func maskPhone(phone string) string {
	if len(phone) < 7 {
		return "***"
	}
	return phone[:3] + "***" + phone[7:]
}
