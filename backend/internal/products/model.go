package products

import (
	"encoding/json"
	"time"
)

type Product struct {
	ID             string    `db:"id" json:"id"`
	FarmerID       string    `db:"farmer_id" json:"farmer_id"`
	CategoryID     *string   `db:"category_id" json:"category_id"`
	Title          *string   `db:"title" json:"title"`
	Description    *string   `db:"description" json:"description"`
	Price          *float64  `db:"price" json:"price"`
	Unit           *string   `db:"unit" json:"unit"`
	City           *string   `db:"city" json:"city"`
	District       *string   `db:"district" json:"district"`
	Village        *string   `db:"village" json:"village"`
	Status         string    `db:"status" json:"status"`
	PreviousStatus *string   `db:"previous_status" json:"previous_status,omitempty"`
	StockStatus    string    `db:"stock_status" json:"stock_status"`
	AdminNote      *string   `db:"admin_note" json:"admin_note,omitempty"`
	CreatedAt      time.Time `db:"created_at" json:"created_at"`
	UpdatedAt      time.Time `db:"updated_at" json:"updated_at"`
}

type ProductImage struct {
	ID        string    `db:"id" json:"id"`
	ProductID string    `db:"product_id" json:"product_id"`
	ImageKey  string    `db:"image_key" json:"key"`
	SortOrder int       `db:"sort_order" json:"sort_order"`
	CreatedAt time.Time `db:"created_at" json:"created_at"`
}


type PublicProductRow struct {
	ID                    string          `db:"id"`
	FarmerID              string          `db:"farmer_id"`
	CategoryID            string          `db:"category_id"`
	Title                 string          `db:"title"`
	Description           string          `db:"description"`
	Price                 float64         `db:"price"`
	Unit                  string          `db:"unit"`
	City                  string          `db:"city"`
	District              string          `db:"district"`
	Village               string          `db:"village"`
	Status                string          `db:"status"`
	StockStatus           string          `db:"stock_status"`
	CreatedAt             time.Time       `db:"created_at"`
	UpdatedAt             time.Time       `db:"updated_at"`
	ImagesJSON            json.RawMessage `db:"images"`
	DisplayName           string          `db:"display_name"`
	IsVerified            bool            `db:"is_verified"`
	IsFoundingFarmer      bool            `db:"is_founding_farmer"`
	FarmerProfileImageURL *string         `db:"profile_image_url"`
	FarmerCity            string          `db:"farmer_city"`
	FarmerDistrict        string          `db:"farmer_district"`
	PublicPhone           *string         `db:"public_phone"`
	CategoryName          string          `db:"category_name"`
	CategorySlug          string          `db:"category_slug"`
	ParentCategoryID      *string         `db:"parent_category_id"`
	ParentCategoryName    *string         `db:"parent_category_name"`
	ParentCategorySlug    *string         `db:"parent_category_slug"`
}

type PublicProduct struct {
	ID          string       `json:"id"`
	Title       string       `json:"title"`
	Description string       `json:"description"`
	Price       float64      `json:"price"`
	Unit        string       `json:"unit"`
	City        string       `json:"city"`
	District    string       `json:"district"`
	Village     string       `json:"village"`
	Status      string       `json:"status"`
	StockStatus string       `json:"stock_status"`
	CreatedAt   time.Time    `json:"created_at"`
	Images      []ImageItem  `json:"images"`
	Category    CategoryInfo `json:"category"`
	Farmer      FarmerInfo   `json:"farmer"`
}

type ImageItem struct {
	URL       string `json:"url"`
	SortOrder int    `json:"sort_order"`
}

type CategoryInfo struct {
	ID     string      `json:"id"`
	Name   string      `json:"name"`
	Slug   string      `json:"slug"`
	Parent *ParentInfo `json:"parent,omitempty"`
}

type ParentInfo struct {
	ID   string `json:"id"`
	Name string `json:"name"`
	Slug string `json:"slug"`
}

type FarmerInfo struct {
	ID               string  `json:"id"`
	DisplayName      string  `json:"display_name"`
	City             string  `json:"city"`
	District         string  `json:"district"`
	IsVerified       bool    `json:"is_verified"`
	IsFoundingFarmer bool    `json:"is_founding_farmer"`
	ProfileImageURL  *string `json:"profile_image_url"`
	PublicPhone      *string `json:"public_phone,omitempty"`
}

// AdminProductFarmerInfo is the farmer object included in admin product responses.
type AdminProductFarmerInfo struct {
	ID               string  `json:"id"`
	FullName         string  `json:"full_name"`
	DisplayName      string  `json:"display_name"`
	Phone            string  `json:"phone"`
	City             string  `json:"city"`
	District         string  `json:"district"`
	Status           string  `json:"status"`
	IsVerified       bool    `json:"is_verified"`
	IsFoundingFarmer bool    `json:"is_founding_farmer"`
	ProfileImageURL  *string `json:"profile_image_url,omitempty"`
}

// AdminProductRow is the raw DB row for admin product queries with JOINs.
type AdminProductRow struct {
	ID          string          `db:"id"`
	FarmerID    string          `db:"farmer_id"`
	Title       *string         `db:"title"`
	Description *string         `db:"description"`
	Price       *float64        `db:"price"`
	Unit        *string         `db:"unit"`
	City        *string         `db:"city"`
	District    *string         `db:"district"`
	Village     *string         `db:"village"`
	Status      string          `db:"status"`
	StockStatus string          `db:"stock_status"`
	AdminNote   *string         `db:"admin_note"`
	CreatedAt   time.Time       `db:"created_at"`
	ImagesJSON  json.RawMessage `db:"images"`
	// Farmer (LEFT JOIN — all nullable)
	FarmerFullName         *string `db:"farmer_full_name"`
	FarmerPhone            *string `db:"farmer_phone"`
	FarmerStatus           *string `db:"farmer_status"`
	FarmerDisplayName      *string `db:"farmer_display_name"`
	FarmerCity             *string `db:"farmer_city"`
	FarmerDistrict         *string `db:"farmer_district"`
	FarmerIsVerified       bool    `db:"farmer_is_verified"`
	FarmerIsFoundingFarmer bool    `db:"farmer_is_founding_farmer"`
	FarmerProfileImageURL  *string `db:"farmer_profile_image_url"`
	// Category (LEFT JOIN — all nullable)
	CategoryID         *string `db:"category_id"`
	CategoryName       *string `db:"category_name"`
	CategorySlug       *string `db:"category_slug"`
	ParentCategoryID   *string `db:"parent_category_id"`
	ParentCategoryName *string `db:"parent_category_name"`
	ParentCategorySlug *string `db:"parent_category_slug"`
}

// AdminProductDetail is returned by both admin list and admin detail endpoints.
type AdminProductDetail struct {
	ID          string                  `json:"id"`
	FarmerID    string                  `json:"farmer_id"`
	Title       string                  `json:"title"`
	Description string                  `json:"description"`
	Price       float64                 `json:"price"`
	Unit        string                  `json:"unit"`
	City        string                  `json:"city"`
	District    string                  `json:"district"`
	Village     string                  `json:"village"`
	Status      string                  `json:"status"`
	StockStatus string                  `json:"stock_status"`
	AdminNote   *string                 `json:"admin_note,omitempty"`
	CreatedAt   time.Time               `json:"created_at"`
	Images      []ImageItem             `json:"images"`
	Category    *CategoryInfo           `json:"category,omitempty"`
	Farmer      *AdminProductFarmerInfo `json:"farmer,omitempty"`
}

type FarmerProductDetail struct {
	ID          string        `json:"id"`
	Title       string        `json:"title"`
	Description string        `json:"description"`
	Price       float64       `json:"price"`
	Unit        string        `json:"unit"`
	City        string        `json:"city"`
	District    string        `json:"district"`
	Village     string        `json:"village"`
	CategoryID  *string       `json:"category_id,omitempty"`
	Status      string        `json:"status"`
	StockStatus string        `json:"stock_status"`
	AdminNote   *string       `json:"admin_note,omitempty"`
	CreatedAt   time.Time     `json:"created_at"`
	Images      []ImageItem   `json:"images"`
	Category    *CategoryInfo `json:"category,omitempty"`
}
