package uploads

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

func (h *Handler) UploadProductImage(c *fiber.Ctx) error {
	farmerID := c.Locals(middleware.UserIDKey).(string)

	file, err := c.FormFile("file")
	if err != nil {
		return response.BadRequest(c, "Dosya bulunamadı")
	}

	f, err := file.Open()
	if err != nil {
		return response.BadRequest(c, "Dosya açılamadı")
	}
	defer f.Close()

	resp, err := h.svc.UploadProductImage(farmerID, f, file.Filename, file.Size)
	if err != nil {
		return response.Error(c, err)
	}

	return response.Success(c, resp, "Resim yüklendi")
}

func (h *Handler) UploadProfileImage(c *fiber.Ctx) error {
	farmerID := c.Locals(middleware.UserIDKey).(string)

	file, err := c.FormFile("file")
	if err != nil {
		return response.BadRequest(c, "Dosya bulunamadı")
	}

	f, err := file.Open()
	if err != nil {
		return response.BadRequest(c, "Dosya açılamadı")
	}
	defer f.Close()

	resp, err := h.svc.UploadProfileImage(farmerID, f, file.Filename, file.Size)
	if err != nil {
		return response.Error(c, err)
	}

	return response.Success(c, resp, "Profil resmi yüklendi")
}

func (h *Handler) GetProductImagePresignedURL(c *fiber.Ctx) error {
	farmerID := c.Locals(middleware.UserIDKey).(string)

	var req PresignedURLRequest
	if err := c.BodyParser(&req); err != nil {
		return response.BadRequest(c, "Geçersiz istek gövdesi")
	}
	if err := validator.Validate(&req); err != nil {
		return response.BadRequest(c, "Zorunlu alanlar eksik veya geçersiz")
	}

	resp, err := h.svc.GenerateProductImagePresignedURL(c.Context(), farmerID, &req)
	if err != nil {
		return response.Error(c, err)
	}

	return response.Success(c, resp, "Presigned URL oluşturuldu")
}

