package auth

import (
	"testing"
	"time"

	"github.com/alicebob/miniredis/v2"
	apperrors "github.com/koydensehire/backend/pkg/errors"
	"github.com/redis/go-redis/v9"
	"golang.org/x/crypto/bcrypt"
)

// ---------- mock repository ----------

type mockUserFinder struct {
	users map[string]*User // keyed by phone
}

func (m *mockUserFinder) FindByPhone(phone string) (*User, error) {
	u, ok := m.users[phone]
	if !ok {
		return nil, apperrors.ErrNotFound
	}
	return u, nil
}

func (m *mockUserFinder) FindByID(id string) (*User, error) {
	for _, u := range m.users {
		if u.ID == id {
			return u, nil
		}
	}
	return nil, apperrors.ErrNotFound
}

func (m *mockUserFinder) CreateCustomer(fullName, phone, email, passwordHash string) (*User, error) {
	u := &User{
		ID:           "new-" + phone,
		FullName:     fullName,
		Phone:        phone,
		PasswordHash: passwordHash,
		Role:         "customer",
		Status:       "active",
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}
	m.users[phone] = u
	return u, nil
}

// ---------- test helpers ----------

func hashPw(t *testing.T, pw string) string {
	t.Helper()
	h, err := bcrypt.GenerateFromPassword([]byte(pw), bcrypt.MinCost)
	if err != nil {
		t.Fatalf("bcrypt: %v", err)
	}
	return string(h)
}

func newTestService(t *testing.T, users map[string]*User) (*Service, *miniredis.Miniredis) {
	t.Helper()
	mr, err := miniredis.Run()
	if err != nil {
		t.Fatalf("miniredis.Run: %v", err)
	}
	t.Cleanup(func() { mr.Close() })
	rdb := redis.NewClient(&redis.Options{Addr: mr.Addr()})
	svc := newServiceWithFinder(
		&mockUserFinder{users: users},
		rdb,
		"test-secret-key",
		15*time.Minute,
		7*24*time.Hour,
	)
	return svc, mr
}

// ---------- tests ----------

func TestLogin_Success(t *testing.T) {
	phone := "05321234567"
	password := "secure1234"
	users := map[string]*User{
		phone: {
			ID:           "user-001",
			FullName:     "Ali Veli",
			Phone:        phone,
			PasswordHash: hashPw(t, password),
			Role:         "farmer",
			Status:       "active",
			CreatedAt:    time.Now(),
			UpdatedAt:    time.Now(),
		},
	}
	svc, _ := newTestService(t, users)

	resp, err := svc.Login(&LoginRequest{Phone: phone, Password: password})
	if err != nil {
		t.Fatalf("expected success, got error: %v", err)
	}
	if resp.AccessToken == "" {
		t.Error("expected non-empty access token")
	}
	if resp.RefreshToken == "" {
		t.Error("expected non-empty refresh token")
	}
	if resp.User.Phone != phone {
		t.Errorf("user phone mismatch: got %q, want %q", resp.User.Phone, phone)
	}
}

func TestLogin_WrongPassword(t *testing.T) {
	phone := "05321234568"
	users := map[string]*User{
		phone: {
			ID:           "user-002",
			Phone:        phone,
			PasswordHash: hashPw(t, "correct-password"),
			Role:         "customer",
			Status:       "active",
			CreatedAt:    time.Now(),
			UpdatedAt:    time.Now(),
		},
	}
	svc, _ := newTestService(t, users)

	_, err := svc.Login(&LoginRequest{Phone: phone, Password: "wrong-password"})
	if err == nil {
		t.Fatal("expected error for wrong password")
	}
	appErr, ok := err.(*apperrors.AppError)
	if !ok {
		t.Fatalf("expected *AppError, got %T", err)
	}
	if appErr.Code != "INVALID_CREDENTIALS" {
		t.Errorf("expected code INVALID_CREDENTIALS, got %q", appErr.Code)
	}
}

func TestLogin_UserNotFound(t *testing.T) {
	svc, _ := newTestService(t, map[string]*User{})

	_, err := svc.Login(&LoginRequest{Phone: "05399999999", Password: "anything"})
	if err == nil {
		t.Fatal("expected error for unknown phone")
	}
	appErr, ok := err.(*apperrors.AppError)
	if !ok {
		t.Fatalf("expected *AppError, got %T", err)
	}
	if appErr.Code != "INVALID_CREDENTIALS" {
		t.Errorf("expected code INVALID_CREDENTIALS, got %q", appErr.Code)
	}
}
