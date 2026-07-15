package products

import "time"

// ProductRepository is the data-access interface used by Service.
// The concrete *Repository satisfies this interface.
type ProductRepository interface {
	ListPublic(f *ProductFilter) ([]PublicProduct, int, error)
	GetPublicByID(id string) (*PublicProduct, error)
	GetByID(id string) (*Product, error)
	GetByIDAndFarmer(id, farmerID string) (*Product, error)
	ListByFarmer(farmerID string) ([]FarmerProductDetail, error)
	ListByFarmerPublic(farmerID string, page, limit int) ([]PublicProduct, int, error)
	RecordView(productID, viewerKey string) error
	Create(farmerID string, req *CreateProductRequest) (*Product, error)
	Update(id, farmerID string, req *UpdateProductRequest) (*Product, error)
	UpdateStatus(id, farmerID, status string) error
	UpdateStockStatus(id, farmerID, stockStatus string) error
	Delete(id, farmerID string) error
	AdminApprove(id string) error
	AdminReject(id, note string) error
	AdminHide(id string) error
	AdminDelete(id string) error
	ListAll(page, limit int) ([]Product, int, error)
	GetAdminProductByID(id string) (*AdminProductDetail, error)
	ListAdminProducts(page, limit int) ([]AdminProductDetail, int, error)
	CreateDraft(id, farmerID string) error
	Complete(id, farmerID string, req *CompleteProductRequest) (*Product, error)
	GetExpiredDrafts(olderThan time.Duration) ([]Product, error)
}
