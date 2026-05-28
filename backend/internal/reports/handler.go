package reports

import (
	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
	"github.com/koydensehire/backend/internal/middleware"
	"github.com/koydensehire/backend/pkg/response"
	"github.com/koydensehire/backend/pkg/validator"
	"strconv"
)

type Handler struct {
	svc *Service
}

func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

// Submit handles POST /api/v1/reports
// JWT is optional — guests can also report.
func (h *Handler) Submit(c *fiber.Ctx) error {
	var req SubmitReportRequest
	if err := c.BodyParser(&req); err != nil {
		return response.BadRequest(c, "Geçersiz istek gövdesi")
	}
	if err := validator.Validate(&req); err != nil {
		return response.BadRequest(c, "Zorunlu alanlar eksik")
	}

	// Extract reporter ID if JWT was provided (middleware sets it when token is valid).
	var reporterID *uuid.UUID
	if rawID, ok := c.Locals(middleware.UserIDKey).(string); ok && rawID != "" {
		parsed, err := uuid.Parse(rawID)
		if err == nil {
			reporterID = &parsed
		}
	}

	report, err := h.svc.SubmitReport(reporterID, &req)
	if err != nil {
		return response.Error(c, err)
	}
	return response.Created(c, report, "Bildiriminiz alındı")
}

// AdminList handles GET /api/v1/admin/reports?status=pending&type=product&page=1
func (h *Handler) AdminList(c *fiber.Ctx) error {
	page, _ := strconv.Atoi(c.Query("page", "1"))
	limit, _ := strconv.Atoi(c.Query("limit", "20"))

	filter := ListReportsFilter{
		Status:     c.Query("status"),
		TargetType: c.Query("type"),
		Page:       page,
		Limit:      limit,
	}

	reports, total, err := h.svc.ListReports(filter)
	if err != nil {
		return response.Error(c, err)
	}

	totalPages := (total + filter.Limit - 1) / filter.Limit
	return response.Paginated(c, reports, response.Pagination{
		Page:       filter.Page,
		Limit:      filter.Limit,
		Total:      total,
		TotalPages: totalPages,
	})
}

// AdminReview handles PATCH /api/v1/admin/reports/:id/review
func (h *Handler) AdminReview(c *fiber.Ctx) error {
	reportID := c.Params("id")
	reviewerID, _ := c.Locals(middleware.UserIDKey).(string)

	var req ReviewReportRequest
	if err := c.BodyParser(&req); err != nil {
		return response.BadRequest(c, "Geçersiz istek gövdesi")
	}
	if err := validator.Validate(&req); err != nil {
		return response.BadRequest(c, "Zorunlu alanlar eksik")
	}

	report, err := h.svc.ReviewReport(reportID, reviewerID, &req)
	if err != nil {
		return response.Error(c, err)
	}
	return response.Success(c, report, "Rapor güncellendi")
}
