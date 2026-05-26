package notifications

import (
	"strconv"

	"github.com/gofiber/fiber/v2"
)

type Handler struct {
	repo *NotifRepository
}

func NewHandler(repo *NotifRepository) *Handler {
	return &Handler{repo: repo}
}

// List returns paginated notifications for the authenticated user.
// GET /farmer/notifications?page=1&limit=20
// GET /customer/notifications?page=1&limit=20
func (h *Handler) List(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"success": false,
			"error":   fiber.Map{"code": "UNAUTHORIZED", "message": "Oturum açmanız gerekiyor"},
		})
	}

	page, _ := strconv.Atoi(c.Query("page", "1"))
	limit, _ := strconv.Atoi(c.Query("limit", "20"))

	items, total, err := h.repo.ListByUser(userID, page, limit)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"error":   fiber.Map{"code": "INTERNAL_ERROR", "message": "Bildirimler alınamadı"},
		})
	}
	if items == nil {
		items = []Notification{}
	}

	unread, _ := h.repo.UnreadCount(userID)

	return c.JSON(fiber.Map{
		"success": true,
		"data": fiber.Map{
			"items":        items,
			"total":        total,
			"unread_count": unread,
		},
	})
}

// MarkRead marks a single notification as read.
// PATCH /farmer/notifications/:id/read
func (h *Handler) MarkRead(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"success": false,
			"error":   fiber.Map{"code": "UNAUTHORIZED", "message": "Oturum açmanız gerekiyor"},
		})
	}
	id := c.Params("id")
	if err := h.repo.MarkRead(id, userID); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"error":   fiber.Map{"code": "INTERNAL_ERROR", "message": "Güncelleme başarısız"},
		})
	}
	return c.JSON(fiber.Map{"success": true})
}

// MarkAllRead marks all notifications of the user as read.
// PATCH /farmer/notifications/read-all
func (h *Handler) MarkAllRead(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"success": false,
			"error":   fiber.Map{"code": "UNAUTHORIZED", "message": "Oturum açmanız gerekiyor"},
		})
	}
	if err := h.repo.MarkAllRead(userID); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"error":   fiber.Map{"code": "INTERNAL_ERROR", "message": "Güncelleme başarısız"},
		})
	}
	return c.JSON(fiber.Map{"success": true})
}
