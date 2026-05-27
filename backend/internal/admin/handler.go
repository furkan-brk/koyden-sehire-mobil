package admin

import (
	"context"
	"log"
	"math"
	"strconv"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/jmoiron/sqlx"

	"github.com/koydensehire/backend/internal/audit"
	"github.com/koydensehire/backend/internal/middleware"
	"github.com/koydensehire/backend/internal/notifications"
	apperrors "github.com/koydensehire/backend/pkg/errors"
	"github.com/koydensehire/backend/pkg/response"
	"github.com/koydensehire/backend/pkg/validator"
)

// ApplicationListItem is the DB-facing + JSON-facing struct for the list endpoint.
// db tags must match the explicit column names in the SELECT query.
type ApplicationListItem struct {
	ID              string    `db:"id"               json:"id"`
	FullName        string    `db:"full_name"         json:"full_name"`
	Phone           string    `db:"phone"             json:"phone"`
	BusinessName    string    `db:"business_name"     json:"business_name"`
	ProducerType    string    `db:"producer_type"     json:"producer_type"`
	City            string    `db:"city"              json:"city"`
	District        string    `db:"district"          json:"district"`
	Village         string    `db:"village"           json:"village"`
	ProductExamples string    `db:"product_examples"  json:"product_examples"`
	Status          string    `db:"status"            json:"status"`
	CreatedAt       time.Time `db:"created_at"        json:"created_at"`
}

// AppPushNotifier is the subset of notifications.PushService used by the admin handler.
type AppPushNotifier interface {
	ApplicationApproved(ctx context.Context, userID, name, phone string) error
	ApplicationRejected(ctx context.Context, userID, name, phone, reason string) error
}

type Handler struct {
	svc       *Service
	db        *sqlx.DB
	notifSvc  *notifications.Service
	auditRepo *audit.Repository
	push      AppPushNotifier // nil = push disabled
}

func NewHandler(svc *Service, db *sqlx.DB, notifSvc *notifications.Service, auditRepo *audit.Repository) *Handler {
	return &Handler{svc: svc, db: db, notifSvc: notifSvc, auditRepo: auditRepo}
}

func (h *Handler) SetPushNotifier(n AppPushNotifier) {
	h.push = n
}

func (h *Handler) Dashboard(c *fiber.Ctx) error {
	stats, err := h.svc.GetDashboard()
	if err != nil {
		return response.Error(c, err)
	}
	return response.Success(c, stats, "")
}

func (h *Handler) CityDensity(c *fiber.Ctx) error {
	data, err := h.svc.GetCityDensity()
	if err != nil {
		return response.Error(c, apperrors.ErrInternal)
	}
	return response.Success(c, data, "")
}

func (h *Handler) InviteNetwork(c *fiber.Ctx) error {
	data, err := h.svc.GetInviteNetwork()
	if err != nil {
		return response.Error(c, apperrors.ErrInternal)
	}
	return response.Success(c, data, "")
}

func (h *Handler) ListApplications(c *fiber.Ctx) error {
	page, _ := strconv.Atoi(c.Query("page", "1"))
	limit, _ := strconv.Atoi(c.Query("limit", "20"))
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 100 {
		limit = 20
	}
	status := c.Query("status")

	// Build WHERE clause based on optional status filter
	var (
		rows     *sqlx.Rows
		total    int
		queryErr error
	)
	if status != "" {
		rows, queryErr = h.db.Queryx(`
			SELECT id, full_name, phone, business_name, producer_type,
			       city, district, village, product_examples, status, created_at
			FROM farmer_applications
			WHERE status = $1
			ORDER BY created_at DESC
			LIMIT $2 OFFSET $3
		`, status, limit, (page-1)*limit)
		if err := h.db.Get(&total, "SELECT COUNT(*) FROM farmer_applications WHERE status = $1", status); err != nil {
			return response.Error(c, apperrors.ErrInternal)
		}
	} else {
		rows, queryErr = h.db.Queryx(`
			SELECT id, full_name, phone, business_name, producer_type,
			       city, district, village, product_examples, status, created_at
			FROM farmer_applications
			ORDER BY created_at DESC
			LIMIT $1 OFFSET $2
		`, limit, (page-1)*limit)
		if err := h.db.Get(&total, "SELECT COUNT(*) FROM farmer_applications"); err != nil {
			return response.Error(c, apperrors.ErrInternal)
		}
	}
	if queryErr != nil {
		return response.Error(c, apperrors.ErrInternal)
	}
	defer rows.Close()

	// Use ApplicationListItem — db tags match the explicit SELECT column list above.
	appList := make([]ApplicationListItem, 0)
	for rows.Next() {
		var a ApplicationListItem
		if err := rows.StructScan(&a); err != nil {
			return response.Error(c, apperrors.ErrInternal)
		}
		appList = append(appList, a)
	}

	totalPages := int(math.Ceil(float64(total) / float64(limit)))

	return response.Paginated(c, appList, response.Pagination{
		Page:       page,
		Limit:      limit,
		Total:      total,
		TotalPages: totalPages,
	})
}

func (h *Handler) GetApplication(c *fiber.Ctx) error {
	id := c.Params("id")
	app, err := h.svc.GetApplicationWithVideoURL(id)
	if err != nil {
		return response.Error(c, err)
	}
	return response.Success(c, app, "")
}

func (h *Handler) ApproveApplication(c *fiber.Ctx) error {
	id := c.Params("id")
	adminID, _ := c.Locals(middleware.UserIDKey).(string)
	if adminID == "" {
		return response.Unauthorized(c, "Kimlik doğrulama gerekli")
	}

	var req ApproveApplicationRequest
	if err := c.BodyParser(&req); err != nil {
		return response.BadRequest(c, "Geçersiz istek gövdesi")
	}

	result, err := h.svc.ApproveApplication(id, adminID, &req)
	if err != nil {
		return response.Error(c, err)
	}

	go h.notifSvc.ApplicationApproved(id, result.FarmerName, "")
	if h.push != nil {
		go func() {
			if err := h.push.ApplicationApproved(context.Background(), result.UserID, result.FarmerName, result.Phone); err != nil {
				log.Printf("[PUSH] ApplicationApproved failed for user=%s: %v", result.UserID, err)
			}
		}()
	}

	return response.Success(c, result, "Başvuru onaylandı")
}

func (h *Handler) RejectApplication(c *fiber.Ctx) error {
	id := c.Params("id")
	adminID, _ := c.Locals(middleware.UserIDKey).(string)
	if adminID == "" {
		return response.Unauthorized(c, "Kimlik doğrulama gerekli")
	}

	var req RejectApplicationRequest
	if err := c.BodyParser(&req); err != nil {
		return response.BadRequest(c, "Geçersiz istek gövdesi")
	}
	if err := validator.Validate(&req); err != nil {
		return response.BadRequest(c, "Red sebebi zorunludur")
	}

	var app struct {
		FullName     string  `db:"full_name"`
		Phone        string  `db:"phone"`
		Status       string  `db:"status"`
		InviteCodeID *string `db:"invite_code_id"`
	}
	if err := h.db.Get(&app, "SELECT full_name, phone, status, invite_code_id FROM farmer_applications WHERE id = $1", id); err != nil {
		return response.NotFound(c, "Başvuru bulunamadı")
	}

	tx, err := h.db.Beginx()
	if err != nil {
		return response.Error(c, apperrors.ErrInternal)
	}
	defer tx.Rollback()

	if _, err := tx.Exec(`
		UPDATE farmer_applications
		SET status = 'rejected', reviewed_by = $1, reviewed_at = NOW(),
		    admin_note = $2, rejection_reason = $3, updated_at = NOW()
		WHERE id = $4
	`, adminID, req.AdminNote, req.RejectionReason, id); err != nil {
		return response.Error(c, apperrors.ErrInternal)
	}

	if _, err := tx.Exec(`
		UPDATE invitations SET status = 'rejected', updated_at = NOW()
		WHERE application_id = $1
	`, id); err != nil {
		return response.Error(c, apperrors.ErrInternal)
	}

	if err := tx.Commit(); err != nil {
		return response.Error(c, apperrors.ErrInternal)
	}

	go h.notifSvc.ApplicationRejected(id, app.FullName, app.Phone, req.RejectionReason)
	if h.push != nil {
		rejPhone := app.Phone
		rejName := app.FullName
		rejReason := req.RejectionReason
		go func() {
			if err := h.push.ApplicationRejected(context.Background(), "", rejName, rejPhone, rejReason); err != nil {
				log.Printf("[PUSH] ApplicationRejected failed for phone=%s: %v", rejPhone, err)
			}
		}()
	}

	go func() {
		reason := req.RejectionReason
		_ = h.auditRepo.Create(context.Background(), audit.CreateParams{
			AdminID:    adminID,
			Action:     audit.ActionApplicationRejected,
			TargetType: audit.TargetApplication,
			TargetID:   id,
			TargetSnapshot: map[string]any{
				"full_name": app.FullName,
				"phone":     app.Phone,
			},
			Reason: &reason,
		})
	}()

	return response.Success(c, nil, "Başvuru reddedildi")
}

func (h *Handler) RequestVideo(c *fiber.Ctx) error {
	id := c.Params("id")
	adminID, _ := c.Locals(middleware.UserIDKey).(string)
	if adminID == "" {
		return response.Unauthorized(c, "Kimlik doğrulama gerekli")
	}

	res, err := h.db.Exec(`
		UPDATE farmer_applications
		SET status = 'needs_video', reviewed_by = $1,
		    application_video_status = 'requested',
		    video_requested_at = NOW(), updated_at = NOW()
		WHERE id = $2 AND status IN ('pending')
	`, adminID, id)
	if err != nil {
		return response.Error(c, apperrors.ErrInternal)
	}
	rows, _ := res.RowsAffected()
	if rows == 0 {
		return response.Conflict(c, "Sadece bekleyen başvurular için video talep edilebilir")
	}

	go func() {
		reason := "Video talep edildi"
		_ = h.auditRepo.Create(context.Background(), audit.CreateParams{
			AdminID:    adminID,
			Action:     audit.ActionApplicationVideoRequested,
			TargetType: audit.TargetApplication,
			TargetID:   id,
			Reason:     &reason,
		})
	}()

	return response.Success(c, nil, "Video talep edildi")
}

func (h *Handler) ListAuditLogs(c *fiber.Ctx) error {
	page, _ := strconv.Atoi(c.Query("page", "1"))
	limit, _ := strconv.Atoi(c.Query("limit", "20"))

	f := audit.ListFilter{
		AdminID:    c.Query("admin_id"),
		Action:     audit.Action(c.Query("action")),
		TargetType: audit.TargetType(c.Query("target_type")),
		TargetID:   c.Query("target_id"),
		Page:       page,
		Limit:      limit,
	}

	if s := c.Query("date_from"); s != "" {
		if t, err := time.Parse(time.RFC3339, s); err == nil {
			f.DateFrom = &t
		}
	}
	if s := c.Query("date_to"); s != "" {
		if t, err := time.Parse(time.RFC3339, s); err == nil {
			f.DateTo = &t
		}
	}

	entries, total, err := h.auditRepo.List(c.Context(), f)
	if err != nil {
		return response.Error(c, apperrors.ErrInternal)
	}

	totalPages := int(math.Ceil(float64(total) / float64(f.Limit)))
	return c.JSON(fiber.Map{
		"success": true,
		"data":    entries,
		"pagination": fiber.Map{
			"page":        f.Page,
			"limit":       f.Limit,
			"total":       total,
			"total_pages": totalPages,
		},
	})
}
