package products

import (
	"fmt"
	"net/url"
	"path"
	"strings"

	"github.com/jmoiron/sqlx"
	apperrors "github.com/koydensehire/backend/pkg/errors"
)

// CategoryRow is the minimal DB record returned when validating a category.
type CategoryRow struct {
	ParentID *string `db:"parent_id"`
	IsActive bool    `db:"is_active"`
}

// CategoryGetter is the data-access interface for category validation.
type CategoryGetter interface {
	GetCategory(id string) (*CategoryRow, error)
	ExecRaw(query string, args ...interface{}) error
}

// sqlxCategoryGetter wraps *sqlx.DB to satisfy CategoryGetter.
type sqlxCategoryGetter struct{ db *sqlx.DB }

func (s *sqlxCategoryGetter) GetCategory(id string) (*CategoryRow, error) {
	var cat CategoryRow
	if err := s.db.Get(&cat, "SELECT parent_id, is_active FROM categories WHERE id = $1", id); err != nil {
		return nil, err
	}
	return &cat, nil
}

func (s *sqlxCategoryGetter) ExecRaw(query string, args ...interface{}) error {
	_, err := s.db.Exec(query, args...)
	return err
}

type Service struct {
	repo      ProductRepository
	db        CategoryGetter
	publicURL string
	appEnv    string
}

func NewService(repo *Repository, db *sqlx.DB, publicURL, appEnv string) *Service {
	return &Service{repo: repo, db: &sqlxCategoryGetter{db: db}, publicURL: publicURL, appEnv: appEnv}
}

// newServiceWithInterfaces is used by tests to inject mocks.
func newServiceWithInterfaces(repo ProductRepository, db CategoryGetter, publicURL, appEnv string) *Service {
	return &Service{repo: repo, db: db, publicURL: publicURL, appEnv: appEnv}
}

func (s *Service) ListPublic(f *ProductFilter) ([]PublicProduct, int, error) {
	return s.repo.ListPublic(f)
}

func (s *Service) GetPublicByID(id string) (*PublicProduct, error) {
	return s.repo.GetPublicByID(id)
}

func (s *Service) GetByID(id string) (*Product, error) {
	return s.repo.GetByID(id)
}

func (s *Service) GetByIDAndFarmer(id, farmerID string) (*Product, error) {
	return s.repo.GetByIDAndFarmer(id, farmerID)
}

func (s *Service) ListByFarmer(farmerID string) ([]Product, error) {
	return s.repo.ListByFarmer(farmerID)
}

func (s *Service) ListByFarmerPublic(farmerID string) ([]PublicProduct, error) {
	return s.repo.ListByFarmerPublic(farmerID)
}

func (s *Service) Create(farmerID string, req *CreateProductRequest) (*Product, error) {
	if err := s.validateImageURLs(req.ImageURLs); err != nil {
		return nil, err
	}

	cat, err := s.db.GetCategory(req.CategoryID)
	if err != nil {
		return nil, apperrors.New("INVALID_CATEGORY", "Kategori bulunamadı", 400)
	}
	if !cat.IsActive {
		return nil, apperrors.New("INVALID_CATEGORY", "Bu kategori aktif değil", 400)
	}
	if cat.ParentID == nil {
		return nil, apperrors.New("INVALID_CATEGORY", "Ana kategori seçilemez, alt kategori seçin", 400)
	}

	return s.repo.Create(farmerID, req)
}

func (s *Service) Update(id, farmerID string, req *UpdateProductRequest) (*Product, error) {
	if err := s.validateImageURLs(req.ImageURLs); err != nil {
		return nil, err
	}

	existing, err := s.repo.GetByIDAndFarmer(id, farmerID)
	if err != nil {
		return nil, apperrors.ErrNotFound
	}
	_ = existing

	return s.repo.Update(id, farmerID, req)
}

func (s *Service) UpdateStatus(id, farmerID, status string) error {
	allowed := map[string]bool{"passive": true, "pending": true}
	if !allowed[status] {
		return apperrors.New("INVALID_STATUS", "Geçersiz durum değeri", 400)
	}

	existing, err := s.repo.GetByIDAndFarmer(id, farmerID)
	if err != nil {
		return apperrors.ErrNotFound
	}

	if status == "pending" && existing.Status != "passive" {
		return apperrors.New("INVALID_STATUS_TRANSITION", "Sadece pasif ürünler yeniden aktif edilebilir", 400)
	}
	if status == "passive" && existing.Status != "active" {
		return apperrors.New("INVALID_STATUS_TRANSITION", "Sadece aktif ürünler pasif yapılabilir", 400)
	}

	return s.repo.UpdateStatus(id, farmerID, status)
}

func (s *Service) AdminApprove(id string) error {
	p, err := s.repo.GetByID(id)
	if err != nil {
		return err
	}
	if p.Status != "pending" {
		return apperrors.New("INVALID_STATUS", "Sadece bekleyen ürünler onaylanabilir", 400)
	}
	return s.repo.AdminApprove(id)
}

func (s *Service) AdminReject(id, note string) error {
	_, err := s.repo.GetByID(id)
	if err != nil {
		return err
	}
	return s.db.ExecRaw(
		`UPDATE products SET status = 'rejected', admin_note = $1, updated_at = NOW() WHERE id = $2`,
		note, id,
	)
}

func (s *Service) AdminHide(id string) error {
	_, err := s.repo.GetByID(id)
	if err != nil {
		return err
	}
	return s.repo.AdminHide(id)
}

func (s *Service) AdminDelete(id string) error {
	_, err := s.repo.GetByID(id)
	if err != nil {
		return err
	}
	return s.repo.AdminDelete(id)
}

func (s *Service) ListAll(page, limit int) ([]Product, int, error) {
	return s.repo.ListAll(page, limit)
}

func (s *Service) GetAdminProductByID(id string) (*AdminProductDetail, error) {
	return s.repo.GetAdminProductByID(id)
}

func (s *Service) ListAdminProducts(page, limit int) ([]AdminProductDetail, int, error) {
	return s.repo.ListAdminProducts(page, limit)
}

var allowedImageExts = map[string]bool{
	".jpg":  true,
	".jpeg": true,
	".png":  true,
	".webp": true,
}

func (s *Service) validateImageURLs(imageURLs []string) error {
	for _, raw := range imageURLs {
		parsed, err := url.Parse(raw)
		if err != nil {
			return apperrors.New("INVALID_IMAGE_URL", fmt.Sprintf("Geçersiz resim URL'i: %s", raw), 400)
		}

		// Always check that the path has an allowed image extension.
		ext := strings.ToLower(path.Ext(parsed.Path))
		if !allowedImageExts[ext] {
			return apperrors.New("INVALID_IMAGE_URL", fmt.Sprintf("Geçersiz resim URL'i: %s", raw), 400)
		}

		// In production, additionally enforce that the URL comes from the
		// configured storage domain. Skip this check in development so that
		// placeholder URLs (e.g. placehold.co) are accepted.
		if s.appEnv != "development" && s.publicURL != "" {
			baseURL := strings.TrimRight(s.publicURL, "/")
			if !strings.HasPrefix(raw, baseURL) {
				return apperrors.New("INVALID_IMAGE_URL", fmt.Sprintf("Geçersiz resim URL'i: %s", raw), 400)
			}
		}
	}
	return nil
}
