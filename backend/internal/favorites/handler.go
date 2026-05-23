package favorites

import (
	"github.com/gofiber/fiber/v2"
	"github.com/koydensehire/backend/internal/middleware"
	"github.com/koydensehire/backend/pkg/response"
)

type Handler struct {
	svc *Service
}

func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

func (h *Handler) List(c *fiber.Ctx) error {
	userID, _ := c.Locals(middleware.UserIDKey).(string)
	items, err := h.svc.List(userID)
	if err != nil {
		return response.Error(c, err)
	}
	return response.Success(c, items, "")
}

func (h *Handler) Add(c *fiber.Ctx) error {
	userID, _ := c.Locals(middleware.UserIDKey).(string)
	productID := c.Params("productId")
	if err := h.svc.Add(userID, productID); err != nil {
		return response.Error(c, err)
	}
	return c.Status(201).JSON(fiber.Map{"success": true})
}

func (h *Handler) Remove(c *fiber.Ctx) error {
	userID, _ := c.Locals(middleware.UserIDKey).(string)
	productID := c.Params("productId")
	if err := h.svc.Remove(userID, productID); err != nil {
		return response.Error(c, err)
	}
	return c.JSON(fiber.Map{"success": true})
}
