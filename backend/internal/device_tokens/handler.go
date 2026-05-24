package device_tokens

import (
	"github.com/gofiber/fiber/v2"

	"github.com/koydensehire/backend/internal/middleware"
	"github.com/koydensehire/backend/pkg/response"
)

type Handler struct {
	repo *Repository
}

func NewHandler(repo *Repository) *Handler {
	return &Handler{repo: repo}
}

type upsertRequest struct {
	Token    string `json:"token"`
	Platform string `json:"platform"`
}

type deleteRequest struct {
	Token string `json:"token"`
}

func (h *Handler) Upsert(c *fiber.Ctx) error {
	userID, _ := c.Locals(middleware.UserIDKey).(string)
	if userID == "" {
		return response.Unauthorized(c, "Kimlik doğrulama gerekli")
	}

	var req upsertRequest
	if err := c.BodyParser(&req); err != nil || req.Token == "" {
		return response.BadRequest(c, "token ve platform alanları zorunludur")
	}
	platform := req.Platform
	if platform != "android" && platform != "ios" && platform != "web" {
		platform = "android"
	}

	if err := h.repo.Upsert(userID, req.Token, platform); err != nil {
		return response.Error(c, err)
	}
	return response.Success(c, nil, "Token kaydedildi")
}

func (h *Handler) Remove(c *fiber.Ctx) error {
	userID, _ := c.Locals(middleware.UserIDKey).(string)
	if userID == "" {
		return response.Unauthorized(c, "Kimlik doğrulama gerekli")
	}

	var req deleteRequest
	if err := c.BodyParser(&req); err != nil || req.Token == "" {
		return response.BadRequest(c, "token alanı zorunludur")
	}

	if err := h.repo.Delete(userID, req.Token); err != nil {
		return response.Error(c, err)
	}
	return response.Success(c, nil, "Token silindi")
}
