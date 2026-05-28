package auth

import (
	"context"
	"log"

	"github.com/gofiber/fiber/v2"
	"github.com/koydensehire/backend/pkg/response"
	"github.com/koydensehire/backend/pkg/validator"
)

// CustomerPushNotifier is the subset of notifications.PushService used by the auth handler.
type CustomerPushNotifier interface {
	CustomerRegistered(ctx context.Context, userID, name string) error
}

type Handler struct {
	svc  *Service
	push CustomerPushNotifier // nil = push disabled
}

func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

func (h *Handler) SetPushNotifier(n CustomerPushNotifier) {
	h.push = n
}

func (h *Handler) Login(c *fiber.Ctx) error {
	var req LoginRequest
	if err := c.BodyParser(&req); err != nil {
		return response.BadRequest(c, "Geçersiz istek gövdesi")
	}
	if err := validator.Validate(&req); err != nil {
		return response.BadRequest(c, "Telefon ve şifre zorunludur")
	}

	resp, err := h.svc.Login(&req)
	if err != nil {
		return response.Error(c, err)
	}

	return response.Success(c, resp, "Giriş başarılı")
}

func (h *Handler) Refresh(c *fiber.Ctx) error {
	var req RefreshRequest
	if err := c.BodyParser(&req); err != nil {
		return response.BadRequest(c, "Geçersiz istek gövdesi")
	}
	if err := validator.Validate(&req); err != nil {
		return response.BadRequest(c, "refresh_token zorunludur")
	}

	resp, err := h.svc.Refresh(&req)
	if err != nil {
		return response.Error(c, err)
	}

	return response.Success(c, resp, "Token yenilendi")
}

func (h *Handler) RegisterCustomer(c *fiber.Ctx) error {
	var req RegisterCustomerRequest
	if err := c.BodyParser(&req); err != nil {
		return response.BadRequest(c, "Geçersiz istek gövdesi")
	}
	if err := validator.Validate(&req); err != nil {
		return response.BadRequest(c, "Lütfen tüm alanları doğru doldurun")
	}

	resp, err := h.svc.RegisterCustomer(&req)
	if err != nil {
		return response.Error(c, err)
	}

	if h.push != nil {
		userID := resp.User.ID
		name := resp.User.Name
		go func() {
			if err := h.push.CustomerRegistered(context.Background(), userID, name); err != nil {
				log.Printf("[PUSH] CustomerRegistered failed for user=%s: %v", userID, err)
			}
		}()
	}

	return response.Success(c, resp, "Kayıt başarılı")
}

func (h *Handler) ForgotPassword(c *fiber.Ctx) error {
	var req ForgotPasswordRequest
	if err := c.BodyParser(&req); err != nil {
		return response.BadRequest(c, "Geçersiz istek gövdesi")
	}
	if err := validator.Validate(&req); err != nil {
		return response.BadRequest(c, "Telefon numarası zorunludur")
	}

	if err := h.svc.ForgotPassword(req.Phone); err != nil {
		return response.Error(c, err)
	}

	return response.Success(c, nil, "Şifre sıfırlama kodu gönderildi")
}

func (h *Handler) ResetPassword(c *fiber.Ctx) error {
	var req ResetPasswordRequest
	if err := c.BodyParser(&req); err != nil {
		return response.BadRequest(c, "Geçersiz istek gövdesi")
	}
	if err := validator.Validate(&req); err != nil {
		return response.BadRequest(c, "Telefon, OTP ve yeni şifre zorunludur")
	}

	if err := h.svc.ResetPassword(&req); err != nil {
		return response.Error(c, err)
	}

	return response.Success(c, nil, "Şifre başarıyla güncellendi")
}
