package products

import (
	"math"
	"strconv"

	"github.com/gofiber/fiber/v2"
	"github.com/koydensehire/backend/internal/middleware"
	"github.com/koydensehire/backend/pkg/response"
	"github.com/koydensehire/backend/pkg/validator"
)

// PushNotifier is implemented by notifications.PushService.
// Nil value is safe — all calls are no-ops when push is disabled.
type PushNotifier interface {
	ProductApproved(farmerID, productTitle string)
	ProductRejected(farmerID, productTitle string)
}

type Handler struct {
	svc  *Service
	push PushNotifier
}

func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

func (h *Handler) SetPushNotifier(n PushNotifier) {
	h.push = n
}

func (h *Handler) List(c *fiber.Ctx) error {
	f := parseFilter(c)

	products, total, err := h.svc.ListPublic(f)
	if err != nil {
		return response.Error(c, err)
	}

	totalPages := int(math.Ceil(float64(total) / float64(f.Limit)))
	return response.Paginated(c, products, response.Pagination{
		Page:       f.Page,
		Limit:      f.Limit,
		Total:      total,
		TotalPages: totalPages,
	})
}

func (h *Handler) GetByID(c *fiber.Ctx) error {
	id := c.Params("id")
	p, err := h.svc.GetPublicByID(id)
	if err != nil {
		return response.Error(c, err)
	}
	return response.Success(c, p, "")
}

func (h *Handler) FarmerList(c *fiber.Ctx) error {
	farmerID, _ := c.Locals(middleware.UserIDKey).(string)
	if farmerID == "" {
		return response.Unauthorized(c, "Kimlik doğrulama gerekli")
	}
	products, err := h.svc.ListByFarmer(farmerID)
	if err != nil {
		return response.Error(c, err)
	}
	return response.Success(c, products, "")
}

func (h *Handler) FarmerCreate(c *fiber.Ctx) error {
	farmerID, _ := c.Locals(middleware.UserIDKey).(string)
	if farmerID == "" {
		return response.Unauthorized(c, "Kimlik doğrulama gerekli")
	}

	var req CreateProductRequest
	if err := c.BodyParser(&req); err != nil {
		return response.BadRequest(c, "Geçersiz istek gövdesi")
	}
	if err := validator.Validate(&req); err != nil {
		return response.BadRequest(c, "Zorunlu alanlar eksik")
	}

	p, err := h.svc.Create(farmerID, &req)
	if err != nil {
		return response.Error(c, err)
	}
	return response.Created(c, p, "Ürün oluşturuldu, onay bekliyor")
}

func (h *Handler) FarmerGetByID(c *fiber.Ctx) error {
	farmerID, _ := c.Locals(middleware.UserIDKey).(string)
	if farmerID == "" {
		return response.Unauthorized(c, "Kimlik doğrulama gerekli")
	}
	id := c.Params("id")

	p, err := h.svc.GetByIDAndFarmer(id, farmerID)
	if err != nil {
		return response.Error(c, err)
	}
	return response.Success(c, p, "")
}

func (h *Handler) FarmerUpdate(c *fiber.Ctx) error {
	farmerID, _ := c.Locals(middleware.UserIDKey).(string)
	if farmerID == "" {
		return response.Unauthorized(c, "Kimlik doğrulama gerekli")
	}
	id := c.Params("id")

	var req UpdateProductRequest
	if err := c.BodyParser(&req); err != nil {
		return response.BadRequest(c, "Geçersiz istek gövdesi")
	}
	if err := validator.Validate(&req); err != nil {
		return response.BadRequest(c, "Zorunlu alanlar eksik")
	}

	p, err := h.svc.Update(id, farmerID, &req)
	if err != nil {
		return response.Error(c, err)
	}
	return response.Success(c, p, "Ürün güncellendi")
}

func (h *Handler) FarmerComplete(c *fiber.Ctx) error {
	farmerID, _ := c.Locals(middleware.UserIDKey).(string)
	if farmerID == "" {
		return response.Unauthorized(c, "Kimlik doğrulama gerekli")
	}
	id := c.Params("id")

	var req CompleteProductRequest
	if err := c.BodyParser(&req); err != nil {
		return response.BadRequest(c, "Geçersiz istek gövdesi")
	}
	if err := validator.Validate(&req); err != nil {
		return response.BadRequest(c, "Zorunlu alanlar eksik veya geçersiz")
	}

	p, err := h.svc.Complete(c.Context(), farmerID, id, &req)
	if err != nil {
		return response.Error(c, err)
	}

	return response.Success(c, p, "Ürün başarıyla tamamlandı ve yayına alındı")
}


func (h *Handler) FarmerUpdateStatus(c *fiber.Ctx) error {
	farmerID, _ := c.Locals(middleware.UserIDKey).(string)
	if farmerID == "" {
		return response.Unauthorized(c, "Kimlik doğrulama gerekli")
	}
	id := c.Params("id")

	var req UpdateStatusRequest
	if err := c.BodyParser(&req); err != nil {
		return response.BadRequest(c, "Geçersiz istek gövdesi")
	}

	if err := h.svc.UpdateStatus(id, farmerID, req.Status); err != nil {
		return response.Error(c, err)
	}
	return response.Success(c, nil, "Ürün durumu güncellendi")
}

func (h *Handler) AdminList(c *fiber.Ctx) error {
	page, _ := strconv.Atoi(c.Query("page", "1"))
	limit, _ := strconv.Atoi(c.Query("limit", "20"))
	if limit > 100 {
		limit = 100
	}

	products, total, err := h.svc.ListAdminProducts(page, limit)
	if err != nil {
		return response.Error(c, err)
	}

	totalPages := int(math.Ceil(float64(total) / float64(limit)))
	return response.Paginated(c, products, response.Pagination{
		Page:       page,
		Limit:      limit,
		Total:      total,
		TotalPages: totalPages,
	})
}

func (h *Handler) AdminGetByID(c *fiber.Ctx) error {
	id := c.Params("id")
	p, err := h.svc.GetAdminProductByID(id)
	if err != nil {
		return response.Error(c, err)
	}
	return response.Success(c, p, "")
}

func (h *Handler) AdminApprove(c *fiber.Ctx) error {
	id := c.Params("id")
	p, _ := h.svc.GetByID(id)
	if err := h.svc.AdminApprove(id); err != nil {
		return response.Error(c, err)
	}
	if p != nil && h.push != nil {
		title := ""
		if p.Title != nil {
			title = *p.Title
		}
		go h.push.ProductApproved(p.FarmerID, title)
	}
	return response.Success(c, nil, "Ürün onaylandı")
}

func (h *Handler) AdminReject(c *fiber.Ctx) error {
	id := c.Params("id")
	p, _ := h.svc.GetByID(id)
	var req AdminRejectRequest
	if err := c.BodyParser(&req); err != nil {
		return response.BadRequest(c, "Geçersiz istek gövdesi")
	}
	if err := h.svc.AdminReject(id, req.AdminNote); err != nil {
		return response.Error(c, err)
	}
	if p != nil && h.push != nil {
		title := ""
		if p.Title != nil {
			title = *p.Title
		}
		go h.push.ProductRejected(p.FarmerID, title)
	}
	return response.Success(c, nil, "Ürün reddedildi")
}

func (h *Handler) AdminHide(c *fiber.Ctx) error {
	id := c.Params("id")
	if err := h.svc.AdminHide(id); err != nil {
		return response.Error(c, err)
	}
	return response.Success(c, nil, "Ürün gizlendi")
}

func (h *Handler) AdminDelete(c *fiber.Ctx) error {
	id := c.Params("id")
	if err := h.svc.AdminDelete(id); err != nil {
		return response.Error(c, err)
	}
	return response.Success(c, nil, "Ürün silindi")
}

func parseFilter(c *fiber.Ctx) *ProductFilter {
	page, _ := strconv.Atoi(c.Query("page", "1"))
	limit, _ := strconv.Atoi(c.Query("limit", "20"))
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 100 {
		limit = 20
	}

	sort := c.Query("sort", "newest")
	switch sort {
	case "newest", "price_asc", "price_desc":
	default:
		sort = "newest"
	}

	stockStatus := c.Query("stock_status")
	switch stockStatus {
	case "", "in_stock", "out_of_stock":
	default:
		stockStatus = ""
	}

	f := &ProductFilter{
		Search:      c.Query("search"),
		CategoryID:  c.Query("category_id"),
		City:        c.Query("city"),
		District:    c.Query("district"),
		Village:     c.Query("village"),
		Sort:        sort,
		Page:        page,
		Limit:       limit,
		StockStatus: stockStatus,
	}

	if minP := c.Query("min_price"); minP != "" {
		v, err := strconv.ParseFloat(minP, 64)
		if err == nil {
			f.MinPrice = &v
		}
	}
	if maxP := c.Query("max_price"); maxP != "" {
		v, err := strconv.ParseFloat(maxP, 64)
		if err == nil {
			f.MaxPrice = &v
		}
	}

	return f
}
