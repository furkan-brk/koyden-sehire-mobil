package favorites

import (
	"encoding/json"

	"github.com/jmoiron/sqlx"
	apperrors "github.com/koydensehire/backend/pkg/errors"

	"github.com/koydensehire/backend/internal/products"
)

type Repository struct {
	db        *sqlx.DB
	publicURL string
}

func NewRepository(db *sqlx.DB, publicURL string) *Repository {
	return &Repository{db: db, publicURL: publicURL}
}

func (r *Repository) Add(userID, productID string) error {
	var status string
	err := r.db.Get(&status, "SELECT status FROM products WHERE id = $1", productID)
	if err != nil {
		return apperrors.ErrNotFound
	}
	if status != "active" {
		return apperrors.New("PRODUCT_NOT_AVAILABLE", "Bu ürün favorilere eklenemez", 400)
	}

	_, err = r.db.Exec(
		"INSERT INTO favorites (user_id, product_id) VALUES ($1, $2) ON CONFLICT DO NOTHING",
		userID, productID,
	)
	return err
}

func (r *Repository) Remove(userID, productID string) error {
	_, err := r.db.Exec(
		"DELETE FROM favorites WHERE user_id = $1 AND product_id = $2",
		userID, productID,
	)
	return err
}

func (r *Repository) ListWithProducts(userID string) ([]products.PublicProduct, error) {
	query := `
		SELECT
			p.id, p.farmer_id, p.category_id, p.title, p.description,
			p.price, p.unit, p.city, p.district, p.village,
			p.status, p.stock_status, p.created_at, p.updated_at,
			fp.display_name, fp.is_verified, fp.is_founding_farmer,
			fp.profile_image_url,
			fp.city AS farmer_city, fp.district AS farmer_district,
			CASE WHEN fp.show_phone THEN fp.public_phone ELSE NULL END AS public_phone,
			c.id AS category_id, c.name AS category_name, c.slug AS category_slug,
			pc.id AS parent_category_id,
			pc.name AS parent_category_name,
			pc.slug AS parent_category_slug,
			COALESCE(
				json_agg(
					json_build_object(
						'url', pi.image_key,
						'sort_order', pi.sort_order
					) ORDER BY pi.sort_order
				) FILTER (WHERE pi.id IS NOT NULL),
				'[]'
			) AS images
		FROM favorites f
		JOIN products p ON p.id = f.product_id
		JOIN farmer_profiles fp ON fp.user_id = p.farmer_id
		JOIN categories c ON c.id = p.category_id
		LEFT JOIN categories pc ON pc.id = c.parent_id
		LEFT JOIN product_images pi ON pi.product_id = p.id
		WHERE f.user_id = $1 AND p.status = 'active'
		GROUP BY
			p.id, fp.display_name, fp.is_verified,
			fp.is_founding_farmer, fp.profile_image_url,
			fp.show_phone, fp.public_phone,
			fp.city, fp.district,
			c.id, c.name, c.slug,
			pc.id, pc.name, pc.slug,
			f.created_at
		ORDER BY f.created_at DESC
	`

	rows, err := r.db.Queryx(query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []products.PublicProduct
	for rows.Next() {
		var row products.PublicProductRow
		if err := rows.StructScan(&row); err != nil {
			return nil, err
		}
		result = append(result, r.mapRow(row))
	}

	if result == nil {
		result = []products.PublicProduct{}
	}
	return result, nil
}

func (r *Repository) mapRow(row products.PublicProductRow) products.PublicProduct {
	var images []products.ImageItem
	if len(row.ImagesJSON) > 0 {
		json.Unmarshal(row.ImagesJSON, &images)
	}
	if images == nil {
		images = []products.ImageItem{}
	}
	for i := range images {
		images[i].URL = products.FormatImageURL(images[i].URL, r.publicURL)
	}

	cat := products.CategoryInfo{
		ID:   row.CategoryID,
		Name: row.CategoryName,
		Slug: row.CategorySlug,
	}
	if row.ParentCategoryID != nil {
		cat.Parent = &products.ParentInfo{
			ID:   *row.ParentCategoryID,
			Name: *row.ParentCategoryName,
			Slug: *row.ParentCategorySlug,
		}
	}

	return products.PublicProduct{
		ID:          row.ID,
		Title:       row.Title,
		Description: row.Description,
		Price:       row.Price,
		Unit:        row.Unit,
		City:        row.City,
		District:    row.District,
		Village:     row.Village,
		Status:      row.Status,
		StockStatus: row.StockStatus,
		CreatedAt:   row.CreatedAt,
		Images:      images,
		Category:    cat,
		Farmer: products.FarmerInfo{
			ID:               row.FarmerID,
			DisplayName:      row.DisplayName,
			City:             row.FarmerCity,
			District:         row.FarmerDistrict,
			IsVerified:       row.IsVerified,
			IsFoundingFarmer: row.IsFoundingFarmer,
			ProfileImageURL:  row.FarmerProfileImageURL,
			PublicPhone:      row.PublicPhone,
		},
	}
}
