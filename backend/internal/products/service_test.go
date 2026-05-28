package products

import (
	"testing"
	"time"

	apperrors "github.com/koydensehire/backend/pkg/errors"
)

// ---------- mock repository ----------

type mockProductRepo struct {
	products map[string]*Product
}

func newMockRepo() *mockProductRepo {
	return &mockProductRepo{products: make(map[string]*Product)}
}

func (m *mockProductRepo) ListPublic(f *ProductFilter) ([]PublicProduct, int, error) {
	return []PublicProduct{}, 0, nil
}

func (m *mockProductRepo) GetPublicByID(id string) (*PublicProduct, error) {
	if _, ok := m.products[id]; ok {
		return &PublicProduct{ID: id}, nil
	}
	return nil, apperrors.ErrNotFound
}

func (m *mockProductRepo) GetByID(id string) (*Product, error) {
	p, ok := m.products[id]
	if !ok {
		return nil, apperrors.ErrNotFound
	}
	return p, nil
}

func (m *mockProductRepo) GetByIDAndFarmer(id, farmerID string) (*Product, error) {
	p, ok := m.products[id]
	if !ok || p.FarmerID != farmerID {
		return nil, apperrors.ErrNotFound
	}
	return p, nil
}

func (m *mockProductRepo) ListByFarmer(farmerID string) ([]Product, error) {
	var out []Product
	for _, p := range m.products {
		if p.FarmerID == farmerID {
			out = append(out, *p)
		}
	}
	return out, nil
}

func (m *mockProductRepo) ListByFarmerPublic(farmerID string) ([]PublicProduct, error) {
	return []PublicProduct{}, nil
}

func (m *mockProductRepo) Create(farmerID string, req *CreateProductRequest) (*Product, error) {
	p := &Product{
		ID:          "prod-new-001",
		FarmerID:    farmerID,
		CategoryID:  req.CategoryID,
		Title:       req.Title,
		Description: req.Description,
		Price:       req.Price,
		Unit:        req.Unit,
		City:        req.City,
		District:    req.District,
		Village:     req.Village,
		Status:      "pending",
		StockStatus: "available",
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}
	m.products[p.ID] = p
	return p, nil
}

func (m *mockProductRepo) Update(id, farmerID string, req *UpdateProductRequest) (*Product, error) {
	p, ok := m.products[id]
	if !ok {
		return nil, apperrors.ErrNotFound
	}
	p.Title = req.Title
	return p, nil
}

func (m *mockProductRepo) UpdateStatus(id, farmerID, status string) error {
	p, ok := m.products[id]
	if !ok {
		return apperrors.ErrNotFound
	}
	p.Status = status
	return nil
}

func (m *mockProductRepo) AdminApprove(id string) error {
	p, ok := m.products[id]
	if !ok {
		return apperrors.ErrNotFound
	}
	p.Status = "active"
	return nil
}

func (m *mockProductRepo) AdminReject(id, note string) error {
	p, ok := m.products[id]
	if !ok {
		return apperrors.ErrNotFound
	}
	p.Status = "rejected"
	return nil
}

func (m *mockProductRepo) AdminHide(id string) error {
	p, ok := m.products[id]
	if !ok {
		return apperrors.ErrNotFound
	}
	p.Status = "hidden"
	return nil
}

func (m *mockProductRepo) AdminDelete(id string) error {
	if _, ok := m.products[id]; !ok {
		return apperrors.ErrNotFound
	}
	delete(m.products, id)
	return nil
}

func (m *mockProductRepo) ListAll(page, limit int) ([]Product, int, error) {
	var out []Product
	for _, p := range m.products {
		out = append(out, *p)
	}
	return out, len(out), nil
}

// ---------- mock category getter ----------

type mockCategoryGetter struct {
	categories map[string]*CategoryRow
}

func (c *mockCategoryGetter) GetCategory(id string) (*CategoryRow, error) {
	cat, ok := c.categories[id]
	if !ok {
		return nil, apperrors.ErrNotFound
	}
	return cat, nil
}

func (c *mockCategoryGetter) ExecRaw(_ string, _ ...interface{}) error {
	return nil
}

// ---------- helpers ----------

func newTestProductService(t *testing.T) (*Service, *mockProductRepo) {
	t.Helper()
	repo := newMockRepo()
	parentID := "cat-parent"
	catGetter := &mockCategoryGetter{
		categories: map[string]*CategoryRow{
			"cat-sub-001": {ParentID: &parentID, IsActive: true},
			"cat-parent":  {ParentID: nil, IsActive: true},
		},
	}
	svc := newServiceWithInterfaces(repo, catGetter, "", "development")
	return svc, repo
}

// ---------- tests ----------

func TestCreateProduct_Success(t *testing.T) {
	svc, _ := newTestProductService(t)

	req := &CreateProductRequest{
		CategoryID:  "cat-sub-001",
		Title:       "Taze Domates",
		Description: "Güneş gören tarladan taze domates",
		Price:       25.0,
		Unit:        "kg",
		City:        "İzmir",
		District:    "Ödemiş",
		Village:     "Birgi",
		ImageURLs:   []string{},
	}

	p, err := svc.Create("farmer-001", req)
	if err != nil {
		t.Fatalf("expected success, got: %v", err)
	}
	if p.Title != req.Title {
		t.Errorf("title mismatch: got %q, want %q", p.Title, req.Title)
	}
	if p.Status != "pending" {
		t.Errorf("expected status=pending, got %q", p.Status)
	}
	if p.FarmerID != "farmer-001" {
		t.Errorf("farmer_id mismatch: got %q, want farmer-001", p.FarmerID)
	}
}

func TestGetProduct_NotFound(t *testing.T) {
	svc, _ := newTestProductService(t)

	_, err := svc.GetByID("nonexistent-id")
	if err == nil {
		t.Fatal("expected error for nonexistent product")
	}
	appErr, ok := err.(*apperrors.AppError)
	if !ok {
		t.Fatalf("expected *AppError, got %T", err)
	}
	if appErr.StatusCode != 404 {
		t.Errorf("expected 404, got %d", appErr.StatusCode)
	}
}

func TestCreateProduct_InvalidCategory_ParentNotAllowed(t *testing.T) {
	svc, _ := newTestProductService(t)

	req := &CreateProductRequest{
		CategoryID:  "cat-parent", // parent category — not allowed
		Title:       "Test Ürün",
		Description: "Açıklama",
		Price:       10.0,
		Unit:        "kg",
		City:        "İzmir",
		District:    "Bornova",
		Village:     "Test",
	}

	_, err := svc.Create("farmer-001", req)
	if err == nil {
		t.Fatal("expected error for parent category selection")
	}
	appErr, ok := err.(*apperrors.AppError)
	if !ok {
		t.Fatalf("expected *AppError, got %T", err)
	}
	if appErr.Code != "INVALID_CATEGORY" {
		t.Errorf("expected INVALID_CATEGORY, got %q", appErr.Code)
	}
}
