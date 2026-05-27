package farmers

import (
	"context"
	"log"
	"math"
	"strconv"
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/koydensehire/backend/pkg/response"
)

// FarmerPushNotifier is the subset of notifications.PushService used by the farmers handler.
type FarmerPushNotifier interface {
	AccountSuspended(ctx context.Context, userID, phone string) error
	AccountReactivated(ctx context.Context, userID string) error
}

type Handler struct {
	svc  *Service
	push FarmerPushNotifier // nil = push disabled
}

func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

func (h *Handler) SetPushNotifier(n FarmerPushNotifier) {
	h.push = n
}

func (h *Handler) ListPublic(c *fiber.Ctx) error {
	page, _ := strconv.Atoi(c.Query("page", "1"))
	limit, _ := strconv.Atoi(c.Query("limit", "20"))
	if limit > 100 {
		limit = 100
	}
	city := strings.TrimSpace(c.Query("city", ""))
	search := strings.TrimSpace(c.Query("search", ""))

	farmers, total, err := h.svc.ListPublic(page, limit, city, search)
	if err != nil {
		return response.Error(c, err)
	}

	totalPages := int(math.Ceil(float64(total) / float64(limit)))
	return response.Paginated(c, farmers, response.Pagination{
		Page:       page,
		Limit:      limit,
		Total:      total,
		TotalPages: totalPages,
	})
}

func (h *Handler) GetPublic(c *fiber.Ctx) error {
	id := c.Params("id")
	f, err := h.svc.GetPublic(id)
	if err != nil {
		return response.Error(c, err)
	}
	return response.Success(c, f, "")
}

func (h *Handler) AdminList(c *fiber.Ctx) error {
	page, _ := strconv.Atoi(c.Query("page", "1"))
	limit, _ := strconv.Atoi(c.Query("limit", "20"))
	if limit > 100 {
		limit = 100
	}

	farmers, total, err := h.svc.List(page, limit)
	if err != nil {
		return response.Error(c, err)
	}

	totalPages := int(math.Ceil(float64(total) / float64(limit)))
	return response.Paginated(c, farmers, response.Pagination{
		Page:       page,
		Limit:      limit,
		Total:      total,
		TotalPages: totalPages,
	})
}

func (h *Handler) AdminGetByID(c *fiber.Ctx) error {
	id := c.Params("id")
	f, err := h.svc.GetAdminDetail(id)
	if err != nil {
		return response.Error(c, err)
	}
	return response.Success(c, f, "")
}

func (h *Handler) AdminSuspend(c *fiber.Ctx) error {
	id := c.Params("id")
	// Fetch farmer detail before suspending to obtain phone for SMS.
	detail, _ := h.svc.GetAdminDetail(id)
	if err := h.svc.Suspend(id); err != nil {
		return response.Error(c, err)
	}
	if h.push != nil {
		phone := ""
		if detail != nil {
			phone = detail.Phone
		}
		farmerID := id
		go func() {
			if err := h.push.AccountSuspended(context.Background(), farmerID, phone); err != nil {
				log.Printf("[PUSH] AccountSuspended failed for user=%s: %v", farmerID, err)
			}
		}()
	}
	return response.Success(c, nil, "Çiftçi askıya alındı")
}

func (h *Handler) AdminReactivate(c *fiber.Ctx) error {
	id := c.Params("id")
	if err := h.svc.Reactivate(id); err != nil {
		return response.Error(c, err)
	}
	if h.push != nil {
		farmerID := id
		go func() {
			if err := h.push.AccountReactivated(context.Background(), farmerID); err != nil {
				log.Printf("[PUSH] AccountReactivated failed for user=%s: %v", farmerID, err)
			}
		}()
	}
	return response.Success(c, nil, "Çiftçi aktif edildi")
}

func (h *Handler) AdminSetFounding(c *fiber.Ctx) error {
	id := c.Params("id")
	var body struct {
		IsFounding bool `json:"is_founding_farmer"`
	}
	if err := c.BodyParser(&body); err != nil {
		return response.BadRequest(c, "Geçersiz istek gövdesi")
	}
	if err := h.svc.SetFounding(id, body.IsFounding); err != nil {
		return response.Error(c, err)
	}
	return response.Success(c, nil, "Kurucu çiftçi durumu güncellendi")
}

func (h *Handler) AdminUpdateInviteQuota(c *fiber.Ctx) error {
	id := c.Params("id")
	var body struct {
		InviteQuota int `json:"invite_quota"`
	}
	if err := c.BodyParser(&body); err != nil {
		return response.BadRequest(c, "Geçersiz istek gövdesi")
	}
	if body.InviteQuota < 0 {
		return response.BadRequest(c, "Davet kotası 0'dan küçük olamaz")
	}
	if err := h.svc.UpdateInviteQuota(id, body.InviteQuota); err != nil {
		return response.Error(c, err)
	}
	return response.Success(c, nil, "Davet kotası güncellendi")
}
