package products

import (
	"context"
	"fmt"
	"log"
	"net/url"
	"path"
	"strings"
	"time"

	"github.com/jmoiron/sqlx"
	apperrors "github.com/koydensehire/backend/pkg/errors"
	pkgstorage "github.com/koydensehire/backend/pkg/storage"
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
	storage   pkgstorage.Provider
	publicURL string
	appEnv    string
}

func NewService(repo *Repository, db *sqlx.DB, stor pkgstorage.Provider, publicURL, appEnv string) *Service {
	return &Service{repo: repo, db: &sqlxCategoryGetter{db: db}, storage: stor, publicURL: publicURL, appEnv: appEnv}
}

// newServiceWithInterfaces is used by tests to inject mocks.
func newServiceWithInterfaces(repo ProductRepository, db CategoryGetter, stor pkgstorage.Provider, publicURL, appEnv string) *Service {
	return &Service{repo: repo, db: db, storage: stor, publicURL: publicURL, appEnv: appEnv}
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

func (s *Service) ListByFarmer(farmerID string) ([]FarmerProductDetail, error) {
	return s.repo.ListByFarmer(farmerID)
}

func (s *Service) ListByFarmerPublic(farmerID string, page, limit int) ([]PublicProduct, int, error) {
	return s.repo.ListByFarmerPublic(farmerID, page, limit)
}

// RecordView persists a product view event. Dedup is done by the handler.
func (s *Service) RecordView(productID, viewerKey string) error {
	return s.repo.RecordView(productID, viewerKey)
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
	if p.Status != "pending" && p.Status != "hidden" {
		return apperrors.New("INVALID_STATUS", "Sadece bekleyen veya gizli ürünler onaylanabilir", 400)
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

func (s *Service) Complete(ctx context.Context, farmerID string, id string, req *CompleteProductRequest) (*Product, error) {
	// 1. Verify category exists and is valid Alt kategori (sub-category)
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

	// 2. Verify each image key actually exists in MinIO/R2
	expectedPrefix := fmt.Sprintf("products/images/%s/%s/", farmerID, id)
	for _, key := range req.ImageKeys {
		if !strings.HasPrefix(key, expectedPrefix) {
			return nil, apperrors.New("INVALID_IMAGE_KEY", fmt.Sprintf("Geçersiz resim yolu: %s", key), 400)
		}

		if s.storage != nil {
			exists, err := s.storage.Exists(ctx, key)
			if err != nil {
				log.Printf("[product:service] failed to verify S3 object existance for key %s: %v", key, err)
				return nil, apperrors.ErrInternal
			}
			if !exists {
				return nil, apperrors.New("IMAGE_NOT_FOUND", fmt.Sprintf("Resim yüklenmemiş veya bulunamadı: %s", key), 400)
			}
		}
	}

	// 3. Call repo to complete and save product
	return s.repo.Complete(id, farmerID, req)
}

func (s *Service) CleanupDrafts(ctx context.Context) error {
	// Get draft products older than 24 hours
	drafts, err := s.repo.GetExpiredDrafts(24 * time.Hour)
	if err != nil {
		return fmt.Errorf("getting expired drafts: %w", err)
	}

	if len(drafts) == 0 {
		return nil
	}

	log.Printf("[products:cleaner] found %d expired draft products to clean up", len(drafts))

	for _, p := range drafts {
		// Delete S3/MinIO files under products/images/{farmer_id}/{product_id}/
		if s.storage != nil {
			prefix := fmt.Sprintf("products/images/%s/%s/", p.FarmerID, p.ID)
			if err := s.storage.DeletePrefix(ctx, prefix); err != nil {
				log.Printf("[products:cleaner] failed to delete S3 folder prefix %s: %v", prefix, err)
			}
		}

		// Delete the product from database (cascade deletes product_images)
		if err := s.repo.AdminDelete(p.ID); err != nil {
			log.Printf("[products:cleaner] failed to delete expired draft product %s from DB: %v", p.ID, err)
		}
	}

	return nil
}

func (s *Service) StartDraftCleanupWorker(ctx context.Context, interval time.Duration) {
	ticker := time.NewTicker(interval)
	go func() {
		log.Printf("[products:cleaner] starting draft product cleanup worker with interval %v", interval)
		for {
			select {
			case <-ctx.Done():
				ticker.Stop()
				return
			case <-ticker.C:
				if err := s.CleanupDrafts(ctx); err != nil {
					log.Printf("[products:cleaner] failed to cleanup draft products: %v", err)
				}
			}
		}
	}()
}


