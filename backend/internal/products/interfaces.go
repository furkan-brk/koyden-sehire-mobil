package products

// ProductRepository is the data-access interface used by Service.
// The concrete *Repository satisfies this interface.
type ProductRepository interface {
	ListPublic(f *ProductFilter) ([]PublicProduct, int, error)
	GetPublicByID(id string) (*PublicProduct, error)
	GetByID(id string) (*Product, error)
	GetByIDAndFarmer(id, farmerID string) (*Product, error)
	ListByFarmer(farmerID string) ([]Product, error)
	ListByFarmerPublic(farmerID string) ([]PublicProduct, error)
	Create(farmerID string, req *CreateProductRequest) (*Product, error)
	Update(id, farmerID string, req *UpdateProductRequest) (*Product, error)
	UpdateStatus(id, farmerID, status string) error
	AdminApprove(id string) error
	AdminReject(id, note string) error
	AdminHide(id string) error
	AdminDelete(id string) error
	ListAll(page, limit int) ([]Product, int, error)
}
