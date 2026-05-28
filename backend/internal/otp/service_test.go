package otp

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/alicebob/miniredis/v2"
	apperrors "github.com/koydensehire/backend/pkg/errors"
	"github.com/redis/go-redis/v9"
)

// ---------- mocks ----------

type noopAudit struct{}

func (n *noopAudit) InsertAudit(_, _, _, _ string) error { return nil }
func (n *noopAudit) MarkVerified(_ string) error         { return nil }

type noopSMS struct{ sent []string }

func (s *noopSMS) Send(phone, _ string) error {
	s.sent = append(s.sent, phone)
	return nil
}

// ---------- helper ----------

func newTestOTPService(t *testing.T) (*Service, *miniredis.Miniredis) {
	t.Helper()
	mr, err := miniredis.Run()
	if err != nil {
		t.Fatalf("miniredis.Run: %v", err)
	}
	t.Cleanup(func() { mr.Close() })
	rdb := redis.NewClient(&redis.Options{Addr: mr.Addr()})
	svc := newServiceWithAudit(
		&noopAudit{},
		rdb,
		&noopSMS{},
		300,  // expiry seconds
		3,    // maxAttempts
		60,   // cooldown seconds
		"development",
	)
	return svc, mr
}

// seedOTP directly writes an otp:<phone> key into miniredis to simulate
// a previously sent OTP, bypassing the cooldown check.
func seedOTP(t *testing.T, mr *miniredis.Miniredis, phone, code string, attempts int, ttl time.Duration) {
	t.Helper()
	key := fmt.Sprintf("otp:%s", phone)
	val := fmt.Sprintf("%s:%d", code, attempts)
	if err := mr.Set(key, val); err != nil {
		t.Fatalf("miniredis Set: %v", err)
	}
	mr.SetTTL(key, ttl)
}

// ---------- tests ----------

func TestSendOTP_Success(t *testing.T) {
	svc, _ := newTestOTPService(t)

	resp, err := svc.Send("05321112233", "127.0.0.1", "test-agent")
	if err != nil {
		t.Fatalf("expected success, got: %v", err)
	}
	if resp.DevCode == nil {
		t.Error("expected DevCode to be set in development mode")
	}
	if len(*resp.DevCode) != 6 {
		t.Errorf("expected 6-digit code, got %q", *resp.DevCode)
	}
}

func TestVerifyOTP_Success(t *testing.T) {
	svc, mr := newTestOTPService(t)
	phone := "05321112244"
	code := "123456"

	seedOTP(t, mr, phone, code, 0, 300*time.Second)

	resp, err := svc.Verify(phone, code)
	if err != nil {
		t.Fatalf("expected success, got: %v", err)
	}
	if !resp.Verified {
		t.Error("expected Verified=true")
	}

	// The otp_verified marker should now exist in redis.
	rdb := redis.NewClient(&redis.Options{Addr: mr.Addr()})
	exists, _ := rdb.Exists(context.Background(), fmt.Sprintf("otp_verified:%s", phone)).Result()
	if exists == 0 {
		t.Error("expected otp_verified key to be set after successful verification")
	}
}

func TestVerifyOTP_Expired(t *testing.T) {
	svc, _ := newTestOTPService(t)
	phone := "05321112255"

	// No key in redis → expired / not found
	_, err := svc.Verify(phone, "000000")
	if err == nil {
		t.Fatal("expected error for expired OTP")
	}
	appErr, ok := err.(*apperrors.AppError)
	if !ok {
		t.Fatalf("expected *AppError, got %T", err)
	}
	if appErr.Code != "OTP_EXPIRED" {
		t.Errorf("expected OTP_EXPIRED, got %q", appErr.Code)
	}
}

func TestVerifyOTP_MaxAttempts(t *testing.T) {
	svc, mr := newTestOTPService(t)
	phone := "05321112266"
	code := "654321"

	// Seed with attempts already at maxAttempts (3)
	seedOTP(t, mr, phone, code, 3, 300*time.Second)

	_, err := svc.Verify(phone, "wrong-code")
	if err == nil {
		t.Fatal("expected error for max attempts exceeded")
	}
	appErr, ok := err.(*apperrors.AppError)
	if !ok {
		t.Fatalf("expected *AppError, got %T", err)
	}
	if appErr.Code != "MAX_ATTEMPTS" {
		t.Errorf("expected MAX_ATTEMPTS, got %q", appErr.Code)
	}
}
