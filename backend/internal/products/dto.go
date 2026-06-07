package products

type CreateProductRequest struct {
	CategoryID  string   `json:"category_id" validate:"required"`
	Title       string   `json:"title" validate:"required"`
	Description string   `json:"description" validate:"required"`
	Price       float64  `json:"price" validate:"required,gt=0"`
	Unit        string   `json:"unit" validate:"required"`
	City        string   `json:"city" validate:"required"`
	District    string   `json:"district" validate:"required"`
	Village     string   `json:"village" validate:"required"`
	ImageURLs   []string `json:"image_urls"`
}

type CompleteProductRequest struct {
	CategoryID  string   `json:"category_id" validate:"required"`
	Title       string   `json:"title" validate:"required"`
	Description string   `json:"description" validate:"required"`
	Price       float64  `json:"price" validate:"required,gt=0"`
	Unit        string   `json:"unit" validate:"required"`
	City        string   `json:"city" validate:"required"`
	District    string   `json:"district" validate:"required"`
	Village     string   `json:"village" validate:"required"`
	ImageKeys   []string `json:"image_keys" validate:"required,min=1"`
}


type UpdateProductRequest struct {
	CategoryID  string   `json:"category_id" validate:"required"`
	Title       string   `json:"title" validate:"required"`
	Description string   `json:"description" validate:"required"`
	Price       float64  `json:"price" validate:"required,gt=0"`
	Unit        string   `json:"unit" validate:"required"`
	City        string   `json:"city" validate:"required"`
	District    string   `json:"district" validate:"required"`
	Village     string   `json:"village" validate:"required"`
	ImageURLs   []string `json:"image_urls"`
}

type UpdateStatusRequest struct {
	Status string `json:"status" validate:"required"`
}

type ProductFilter struct {
	Search      string
	CategoryID  string
	City        string
	District    string
	Village     string
	MinPrice    *float64
	MaxPrice    *float64
	Sort        string
	Page        int
	Limit       int
	StockStatus string
}

type AdminRejectRequest struct {
	AdminNote string `json:"admin_note"`
}
