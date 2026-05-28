package users

import (
	"github.com/gofiber/fiber/v2"
	"github.com/koydensehire/backend/internal/middleware"
	"github.com/koydensehire/backend/pkg/response"
	"github.com/koydensehire/backend/pkg/validator"
)

type Handler struct {
	svc *Service
}

func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

func (h *Handler) GetProfile(c *fiber.Ctx) error {
	userID, _ := c.Locals(middleware.UserIDKey).(string)
	if userID == "" {
		return response.Unauthorized(c, "Kimlik doğrulama gerekli")
	}

	user, profile, err := h.svc.GetProfile(userID)
	if err != nil {
		return response.Error(c, err)
	}

	return response.Success(c, fiber.Map{"user": user, "profile": profile}, "")
}

func (h *Handler) UpdateProfile(c *fiber.Ctx) error {
	userID, _ := c.Locals(middleware.UserIDKey).(string)
	if userID == "" {
		return response.Unauthorized(c, "Kimlik doğrulama gerekli")
	}

	var req UpdateProfileRequest
	if err := c.BodyParser(&req); err != nil {
		return response.BadRequest(c, "Geçersiz istek gövdesi")
	}
	if err := validator.Validate(&req); err != nil {
		return response.BadRequest(c, "Zorunlu alanlar eksik")
	}

	if err := h.svc.UpdateProfile(userID, &req); err != nil {
		return response.Error(c, err)
	}

	return response.Success(c, nil, "Profil güncellendi")
}

func (h *Handler) GetCustomerProfile(c *fiber.Ctx) error {
	userID, _ := c.Locals(middleware.UserIDKey).(string)
	if userID == "" {
		return response.Unauthorized(c, "Kimlik doğrulama gerekli")
	}

	profile, err := h.svc.GetCustomerProfile(userID)
	if err != nil {
		return response.Error(c, err)
	}

	return response.Success(c, profile, "")
}

func (h *Handler) UpdateCustomerProfile(c *fiber.Ctx) error {
	userID, _ := c.Locals(middleware.UserIDKey).(string)
	if userID == "" {
		return response.Unauthorized(c, "Kimlik doğrulama gerekli")
	}

	var req UpdateCustomerProfileRequest
	if err := c.BodyParser(&req); err != nil {
		return response.BadRequest(c, "Geçersiz istek gövdesi")
	}
	if err := validator.Validate(&req); err != nil {
		return response.BadRequest(c, "Zorunlu alanlar eksik veya geçersiz")
	}

	profile, err := h.svc.UpdateCustomerProfile(userID, &req)
	if err != nil {
		return response.Error(c, err)
	}

	return response.Success(c, profile, "Profil güncellendi")
}

// DeleteFarmerAccount farmer hesabını siler (KVKK).
func (h *Handler) DeleteFarmerAccount(c *fiber.Ctx) error {
	userID, _ := c.Locals(middleware.UserIDKey).(string)
	if userID == "" {
		return response.Unauthorized(c, "Kimlik doğrulama gerekli")
	}

	var req DeleteAccountRequest
	if err := c.BodyParser(&req); err != nil {
		return response.BadRequest(c, "Geçersiz istek gövdesi")
	}
	if err := validator.Validate(&req); err != nil {
		return response.BadRequest(c, "Şifre zorunludur")
	}

	if err := h.svc.DeleteAccount(userID, "farmer", req.Password); err != nil {
		return response.Error(c, err)
	}

	return response.Success(c, nil, "Hesabınız başarıyla silindi")
}

// DeleteCustomerAccount customer hesabını siler (KVKK).
func (h *Handler) DeleteCustomerAccount(c *fiber.Ctx) error {
	userID, _ := c.Locals(middleware.UserIDKey).(string)
	if userID == "" {
		return response.Unauthorized(c, "Kimlik doğrulama gerekli")
	}

	var req DeleteAccountRequest
	if err := c.BodyParser(&req); err != nil {
		return response.BadRequest(c, "Geçersiz istek gövdesi")
	}
	if err := validator.Validate(&req); err != nil {
		return response.BadRequest(c, "Şifre zorunludur")
	}

	if err := h.svc.DeleteAccount(userID, "customer", req.Password); err != nil {
		return response.Error(c, err)
	}

	return response.Success(c, nil, "Hesabınız başarıyla silindi")
}
