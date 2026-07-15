package products

import (
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/jmoiron/sqlx"
	apperrors "github.com/koydensehire/backend/pkg/errors"
)

type Repository struct {
	db        *sqlx.DB
	publicURL string
}

func NewRepository(db *sqlx.DB, publicURL string) *Repository {
	return &Repository{db: db, publicURL: publicURL}
}

func (r *Repository) ListPublic(f *ProductFilter) ([]PublicProduct, int, error) {
	args := []interface{}{}
	argIdx := 1
	conditions := []string{"p.status = 'active'"}

	if f.Search != "" {
		conditions = append(conditions, fmt.Sprintf(
			"(p.title ILIKE $%d OR fp.display_name ILIKE $%d OR c.name ILIKE $%d OR pc.name ILIKE $%d)",
			argIdx, argIdx, argIdx, argIdx,
		))
		args = append(args, "%"+f.Search+"%")
		argIdx++
	}

	if f.CategoryID != "" {
		var parentID *string
		r.db.Get(&parentID, "SELECT parent_id FROM categories WHERE id = $1", f.CategoryID)
		if parentID == nil {
			var subIDs []string
			r.db.Select(&subIDs, "SELECT id FROM categories WHERE parent_id = $1 AND is_active = true", f.CategoryID)
			if len(subIDs) > 0 {
				placeholders := make([]string, len(subIDs))
				for i, id := range subIDs {
					placeholders[i] = fmt.Sprintf("$%d", argIdx)
					args = append(args, id)
					argIdx++
				}
				conditions = append(conditions, fmt.Sprintf("p.category_id IN (%s)", strings.Join(placeholders, ",")))
			}
		} else {
			conditions = append(conditions, fmt.Sprintf("p.category_id = $%d", argIdx))
			args = append(args, f.CategoryID)
			argIdx++
		}
	}

	if f.City != "" {
		conditions = append(conditions, fmt.Sprintf("p.city = $%d", argIdx))
		args = append(args, f.City)
		argIdx++
	}
	if f.District != "" {
		conditions = append(conditions, fmt.Sprintf("p.district = $%d", argIdx))
		args = append(args, f.District)
		argIdx++
	}
	if f.Village != "" {
		conditions = append(conditions, fmt.Sprintf("p.village = $%d", argIdx))
		args = append(args, f.Village)
		argIdx++
	}
	if f.MinPrice != nil {
		conditions = append(conditions, fmt.Sprintf("p.price >= $%d", argIdx))
		args = append(args, *f.MinPrice)
		argIdx++
	}
	if f.MaxPrice != nil {
		conditions = append(conditions, fmt.Sprintf("p.price <= $%d", argIdx))
		args = append(args, *f.MaxPrice)
		argIdx++
	}
	if f.StockStatus != "" {
		conditions = append(conditions, fmt.Sprintf("p.stock_status = $%d", argIdx))
		args = append(args, f.StockStatus)
		argIdx++
	}

	where := strings.Join(conditions, " AND ")

	countQuery := fmt.Sprintf(`
		SELECT COUNT(DISTINCT p.id)
		FROM products p
		JOIN farmer_profiles fp ON fp.user_id = p.farmer_id
		JOIN categories c ON c.id = p.category_id
		LEFT JOIN categories pc ON pc.id = c.parent_id
		WHERE %s
	`, where)

	var total int
	if err := r.db.Get(&total, countQuery, args...); err != nil {
		return nil, 0, err
	}

	// Default order: most recently published first. published_at is set on
	// admin approval; created_at is a stable tiebreaker for equal/NULL values.
	orderBy := "p.published_at DESC NULLS LAST, p.created_at DESC"
	switch f.Sort {
	case "price_asc":
		orderBy = "p.price ASC"
	case "price_desc":
		orderBy = "p.price DESC"
	case "most_viewed":
		orderBy = "(SELECT COUNT(*) FROM product_views pv WHERE pv.product_id = p.id) DESC, p.published_at DESC NULLS LAST"
	}

	offset := (f.Page - 1) * f.Limit
	args = append(args, f.Limit, offset)

	query := fmt.Sprintf(`
		SELECT
			p.id, p.farmer_id, p.category_id, p.title, p.description,
			p.price, p.unit, p.city, p.district, p.village,
			p.status, p.stock_status, p.created_at, p.updated_at, p.published_at,
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
		FROM products p
		JOIN farmer_profiles fp ON fp.user_id = p.farmer_id
		JOIN categories c ON c.id = p.category_id
		LEFT JOIN categories pc ON pc.id = c.parent_id
		LEFT JOIN product_images pi ON pi.product_id = p.id
		WHERE %s
		GROUP BY
			p.id, fp.display_name, fp.is_verified,
			fp.is_founding_farmer, fp.profile_image_url,
			fp.show_phone, fp.public_phone,
			fp.city, fp.district,
			c.id, c.name, c.slug,
			pc.id, pc.name, pc.slug
		ORDER BY %s
		LIMIT $%d OFFSET $%d
	`, where, orderBy, argIdx, argIdx+1)

	rows, err := r.db.Queryx(query, args...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var products []PublicProduct
	for rows.Next() {
		var row PublicProductRow
		if err := rows.StructScan(&row); err != nil {
			return nil, 0, err
		}
		products = append(products, mapRowToPublicProduct(row, r.publicURL))
	}

	if products == nil {
		products = []PublicProduct{}
	}
	return products, total, nil
}

func (r *Repository) GetPublicByID(id string) (*PublicProduct, error) {
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
		FROM products p
		JOIN farmer_profiles fp ON fp.user_id = p.farmer_id
		JOIN categories c ON c.id = p.category_id
		LEFT JOIN categories pc ON pc.id = c.parent_id
		LEFT JOIN product_images pi ON pi.product_id = p.id
		WHERE p.id = $1 AND p.status = 'active'
		GROUP BY
			p.id, fp.display_name, fp.is_verified,
			fp.is_founding_farmer, fp.profile_image_url,
			fp.show_phone, fp.public_phone,
			fp.city, fp.district,
			c.id, c.name, c.slug,
			pc.id, pc.name, pc.slug
	`

	var row PublicProductRow
	if err := r.db.QueryRowx(query, id).StructScan(&row); err != nil {
		return nil, apperrors.ErrNotFound
	}
	p := mapRowToPublicProduct(row, r.publicURL)
	return &p, nil
}

func (r *Repository) GetByID(id string) (*Product, error) {
	var p Product
	err := r.db.Get(&p, "SELECT * FROM products WHERE id = $1", id)
	if err != nil {
		return nil, apperrors.ErrNotFound
	}
	return &p, nil
}

func (r *Repository) GetByIDAndFarmer(id, farmerID string) (*Product, error) {
	var p Product
	err := r.db.Get(&p, "SELECT * FROM products WHERE id = $1 AND farmer_id = $2", id, farmerID)
	if err != nil {
		return nil, apperrors.ErrNotFound
	}
	return &p, nil
}

func (r *Repository) ListByFarmer(farmerID string) ([]FarmerProductDetail, error) {
	query := `
		SELECT
			p.id, p.farmer_id, p.title, p.description,
			p.price, p.unit, p.city, p.district, p.village,
			p.status, p.stock_status, p.admin_note, p.created_at,
			(SELECT COUNT(*) FROM favorites f WHERE f.product_id = p.id) AS favorite_count,
			(SELECT COUNT(*) FROM product_views pv WHERE pv.product_id = p.id) AS view_count,
			c.id   AS category_id,
			c.name AS category_name,
			c.slug AS category_slug,
			pc.id   AS parent_category_id,
			pc.name AS parent_category_name,
			pc.slug AS parent_category_slug,
			COALESCE(
				json_agg(
					json_build_object('url', pi.image_key, 'sort_order', pi.sort_order)
					ORDER BY pi.sort_order
				) FILTER (WHERE pi.id IS NOT NULL),
				'[]'
			) AS images
		FROM products p
		LEFT JOIN categories      c  ON c.id          = p.category_id
		LEFT JOIN categories      pc ON pc.id         = c.parent_id
		LEFT JOIN product_images  pi ON pi.product_id = p.id
		WHERE p.farmer_id = $1 AND p.status != 'on-going'
		GROUP BY
			p.id, p.farmer_id, p.title, p.description,
			p.price, p.unit, p.city, p.district, p.village,
			p.status, p.stock_status, p.admin_note, p.created_at,
			c.id, c.name, c.slug,
			pc.id, pc.name, pc.slug
		ORDER BY p.created_at DESC
	`

	rows, err := r.db.Queryx(query, farmerID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var products []FarmerProductDetail
	for rows.Next() {
		var row AdminProductRow
		if err := rows.StructScan(&row); err != nil {
			return nil, err
		}
		products = append(products, mapRowToFarmerDetail(row, r.publicURL))
	}

	if products == nil {
		products = []FarmerProductDetail{}
	}
	return products, nil
}

// RecordView inserts a single product view event. Deduplication is handled
// by the caller (Redis SETNX debounce in the handler).
func (r *Repository) RecordView(productID, viewerKey string) error {
	_, err := r.db.Exec(`
		INSERT INTO product_views (product_id, viewer_key)
		VALUES ($1, $2)
	`, productID, viewerKey)
	return err
}

func (r *Repository) ListByFarmerPublic(farmerID string, page, limit int) ([]PublicProduct, int, error) {
	var total int
	if err := r.db.Get(&total, `
		SELECT COUNT(*) FROM products WHERE farmer_id = $1 AND status = 'active'
	`, farmerID); err != nil {
		return nil, 0, err
	}

	offset := (page - 1) * limit
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
		FROM products p
		JOIN farmer_profiles fp ON fp.user_id = p.farmer_id
		JOIN categories c ON c.id = p.category_id
		LEFT JOIN categories pc ON pc.id = c.parent_id
		LEFT JOIN product_images pi ON pi.product_id = p.id
		WHERE p.farmer_id = $1 AND p.status = 'active'
		GROUP BY
			p.id, fp.display_name, fp.is_verified,
			fp.is_founding_farmer, fp.profile_image_url,
			fp.show_phone, fp.public_phone,
			fp.city, fp.district,
			c.id, c.name, c.slug,
			pc.id, pc.name, pc.slug
		ORDER BY p.created_at DESC
		LIMIT $2 OFFSET $3
	`

	rows, err := r.db.Queryx(query, farmerID, limit, offset)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var products []PublicProduct
	for rows.Next() {
		var row PublicProductRow
		if err := rows.StructScan(&row); err != nil {
			return nil, 0, err
		}
		products = append(products, mapRowToPublicProduct(row, r.publicURL))
	}
	if products == nil {
		products = []PublicProduct{}
	}
	return products, total, nil
}

func (r *Repository) Create(farmerID string, req *CreateProductRequest) (*Product, error) {
	tx, err := r.db.Beginx()
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	var p Product
	err = tx.Get(&p, `
		INSERT INTO products (farmer_id, category_id, title, description, price, unit, city, district, village, status)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'pending')
		RETURNING *
	`, farmerID, req.CategoryID, req.Title, req.Description, req.Price, req.Unit,
		req.City, req.District, req.Village)
	if err != nil {
		return nil, err
	}

	for i, url := range req.ImageURLs {
		key := extractImageKey(url, r.publicURL)
		_, err = tx.Exec(`
			INSERT INTO product_images (product_id, image_key, sort_order)
			VALUES ($1, $2, $3)
		`, p.ID, key, i)
		if err != nil {
			return nil, err
		}
	}

	return &p, tx.Commit()
}

func (r *Repository) Update(id, farmerID string, req *UpdateProductRequest) (*Product, error) {
	tx, err := r.db.Beginx()
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	var p Product
	stockStatus := req.StockStatus
	if stockStatus == "" {
		stockStatus = "available"
	}
	err = tx.Get(&p, `
		UPDATE products
		SET category_id = $1, title = $2, description = $3, price = $4,
		    unit = $5, city = $6, district = $7, village = $8,
		    stock_status = $9, updated_at = NOW()
		WHERE id = $10 AND farmer_id = $11
		RETURNING *
	`, req.CategoryID, req.Title, req.Description, req.Price, req.Unit,
		req.City, req.District, req.Village, stockStatus, id, farmerID)
	if err != nil {
		return nil, apperrors.ErrNotFound
	}

	if _, err := tx.Exec("DELETE FROM product_images WHERE product_id = $1", id); err != nil {
		return nil, err
	}

	for i, url := range req.ImageURLs {
		key := extractImageKey(url, r.publicURL)
		if _, err := tx.Exec(`
			INSERT INTO product_images (product_id, image_key, sort_order)
			VALUES ($1, $2, $3)
		`, id, key, i); err != nil {
			return nil, err
		}
	}

	return &p, tx.Commit()
}

func (r *Repository) UpdateStatus(id, farmerID, status string) error {
	result, err := r.db.Exec(`
		UPDATE products SET status = $1, updated_at = NOW()
		WHERE id = $2 AND farmer_id = $3
	`, status, id, farmerID)
	if err != nil {
		return err
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		return apperrors.ErrNotFound
	}
	return nil
}

func (r *Repository) UpdateStockStatus(id, farmerID, stockStatus string) error {
	result, err := r.db.Exec(`
		UPDATE products SET stock_status = $1, updated_at = NOW()
		WHERE id = $2 AND farmer_id = $3
	`, stockStatus, id, farmerID)
	if err != nil {
		return err
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		return apperrors.ErrNotFound
	}
	return nil
}

func (r *Repository) Delete(id, farmerID string) error {
	result, err := r.db.Exec(`
		DELETE FROM products WHERE id = $1 AND farmer_id = $2
	`, id, farmerID)
	if err != nil {
		return err
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		return apperrors.ErrNotFound
	}
	return nil
}

func (r *Repository) AdminApprove(id string) error {
	_, err := r.db.Exec(`
		UPDATE products
		SET status = 'active', published_at = NOW(), updated_at = NOW()
		WHERE id = $1
	`, id)
	return err
}

func (r *Repository) AdminReject(id, note string) error {
	_, err := r.db.Exec(`
		UPDATE products SET status = 'rejected', admin_note = $1, updated_at = NOW() WHERE id = $2
	`, note, id)
	return err
}

func (r *Repository) AdminHide(id string) error {
	_, err := r.db.Exec(`
		UPDATE products SET status = 'hidden', updated_at = NOW() WHERE id = $1
	`, id)
	return err
}

func (r *Repository) AdminDelete(id string) error {
	_, err := r.db.Exec("DELETE FROM products WHERE id = $1", id)
	return err
}

func (r *Repository) CreateDraft(id, farmerID string) error {
	_, err := r.db.Exec(`
		INSERT INTO products (id, farmer_id, status)
		VALUES ($1, $2, 'on-going')
		ON CONFLICT (id) DO NOTHING
	`, id, farmerID)
	return err
}

func (r *Repository) Complete(id, farmerID string, req *CompleteProductRequest) (*Product, error) {
	tx, err := r.db.Beginx()
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	var p Product
	err = tx.Get(&p, `
		UPDATE products
		SET category_id = $1, title = $2, description = $3, price = $4,
		    unit = $5, city = $6, district = $7, village = $8, status = 'pending', updated_at = NOW()
		WHERE id = $9 AND farmer_id = $10
		RETURNING *
	`, req.CategoryID, req.Title, req.Description, req.Price, req.Unit,
		req.City, req.District, req.Village, id, farmerID)
	if err != nil {
		return nil, apperrors.ErrNotFound
	}

	if _, err := tx.Exec("DELETE FROM product_images WHERE product_id = $1", id); err != nil {
		return nil, err
	}

	for i, key := range req.ImageKeys {
		if _, err := tx.Exec(`
			INSERT INTO product_images (product_id, image_key, sort_order)
			VALUES ($1, $2, $3)
		`, id, key, i); err != nil {
			return nil, err
		}
	}

	return &p, tx.Commit()
}

func (r *Repository) GetExpiredDrafts(olderThan time.Duration) ([]Product, error) {
	var products []Product
	query := `
		SELECT * FROM products
		WHERE status = 'on-going' AND created_at < NOW() - $1::interval
	`
	intervalStr := fmt.Sprintf("%d seconds", int(olderThan.Seconds()))
	err := r.db.Select(&products, query, intervalStr)
	if err != nil {
		return nil, err
	}
	if products == nil {
		products = []Product{}
	}
	return products, nil
}

func (r *Repository) ListAll(page, limit int) ([]Product, int, error) {
	var total int
	if err := r.db.Get(&total, "SELECT COUNT(*) FROM products WHERE status != 'on-going'"); err != nil {
		return nil, 0, err
	}

	var products []Product
	offset := (page - 1) * limit
	err := r.db.Select(&products, `
		SELECT * FROM products WHERE status != 'on-going' ORDER BY created_at DESC LIMIT $1 OFFSET $2
	`, limit, offset)
	if err != nil {
		return nil, 0, err
	}
	if products == nil {
		products = []Product{}
	}
	return products, total, nil
}

func (r *Repository) GetImages(productID string) ([]ProductImage, error) {
	var images []ProductImage
	err := r.db.Select(&images, `
		SELECT * FROM product_images WHERE product_id = $1 ORDER BY sort_order
	`, productID)
	if err != nil {
		return nil, err
	}
	if images == nil {
		images = []ProductImage{}
	}
	return images, nil
}

func (r *Repository) GetAdminProductByID(id string) (*AdminProductDetail, error) {
	query := `
		SELECT
			p.id, p.farmer_id, p.title, p.description,
			p.price, p.unit, p.city, p.district, p.village,
			p.status, p.stock_status, p.admin_note, p.created_at, p.published_at,
			(SELECT COUNT(*) FROM favorites f WHERE f.product_id = p.id) AS favorite_count,
			(SELECT COUNT(*) FROM product_views pv WHERE pv.product_id = p.id) AS view_count,
			u.full_name AS farmer_full_name,
			u.phone    AS farmer_phone,
			u.status   AS farmer_status,
			fp.display_name      AS farmer_display_name,
			fp.city              AS farmer_city,
			fp.district          AS farmer_district,
			COALESCE(fp.is_verified,        false) AS farmer_is_verified,
			COALESCE(fp.is_founding_farmer, false) AS farmer_is_founding_farmer,
			fp.profile_image_url AS farmer_profile_image_url,
			c.id   AS category_id,
			c.name AS category_name,
			c.slug AS category_slug,
			pc.id   AS parent_category_id,
			pc.name AS parent_category_name,
			pc.slug AS parent_category_slug,
			COALESCE(
				json_agg(
					json_build_object('url', pi.image_key, 'sort_order', pi.sort_order)
					ORDER BY pi.sort_order
				) FILTER (WHERE pi.id IS NOT NULL),
				'[]'
			) AS images
		FROM products p
		LEFT JOIN users           u  ON u.id          = p.farmer_id
		LEFT JOIN farmer_profiles fp ON fp.user_id    = p.farmer_id
		LEFT JOIN categories      c  ON c.id          = p.category_id
		LEFT JOIN categories      pc ON pc.id         = c.parent_id
		LEFT JOIN product_images  pi ON pi.product_id = p.id
		WHERE p.id = $1
		GROUP BY
			p.id, p.farmer_id, p.title, p.description,
			p.price, p.unit, p.city, p.district, p.village,
			p.status, p.stock_status, p.admin_note, p.created_at, p.published_at,
			u.full_name, u.phone, u.status,
			fp.display_name, fp.city, fp.district,
			fp.is_verified, fp.is_founding_farmer, fp.profile_image_url,
			c.id, c.name, c.slug,
			pc.id, pc.name, pc.slug
	`
	var row AdminProductRow
	if err := r.db.QueryRowx(query, id).StructScan(&row); err != nil {
		return nil, apperrors.ErrNotFound
	}
	d := mapAdminRowToDetail(row, r.publicURL)
	return &d, nil
}

func (r *Repository) ListAdminProducts(page, limit int) ([]AdminProductDetail, int, error) {
	var total int
	if err := r.db.Get(&total, "SELECT COUNT(*) FROM products WHERE status != 'on-going'"); err != nil {
		return nil, 0, err
	}

	offset := (page - 1) * limit
	query := `
		SELECT
			p.id, p.farmer_id, p.title, p.description,
			p.price, p.unit, p.city, p.district, p.village,
			p.status, p.stock_status, p.admin_note, p.created_at, p.published_at,
			(SELECT COUNT(*) FROM favorites f WHERE f.product_id = p.id) AS favorite_count,
			(SELECT COUNT(*) FROM product_views pv WHERE pv.product_id = p.id) AS view_count,
			u.full_name AS farmer_full_name,
			u.phone    AS farmer_phone,
			u.status   AS farmer_status,
			fp.display_name      AS farmer_display_name,
			fp.city              AS farmer_city,
			fp.district          AS farmer_district,
			COALESCE(fp.is_verified,        false) AS farmer_is_verified,
			COALESCE(fp.is_founding_farmer, false) AS farmer_is_founding_farmer,
			fp.profile_image_url AS farmer_profile_image_url,
			c.id   AS category_id,
			c.name AS category_name,
			c.slug AS category_slug,
			pc.id   AS parent_category_id,
			pc.name AS parent_category_name,
			pc.slug AS parent_category_slug,
			COALESCE(
				json_agg(
					json_build_object('url', pi.image_key, 'sort_order', pi.sort_order)
					ORDER BY pi.sort_order
				) FILTER (WHERE pi.id IS NOT NULL),
				'[]'
			) AS images
		FROM products p
		LEFT JOIN users           u  ON u.id          = p.farmer_id
		LEFT JOIN farmer_profiles fp ON fp.user_id    = p.farmer_id
		LEFT JOIN categories      c  ON c.id          = p.category_id
		LEFT JOIN categories      pc ON pc.id         = c.parent_id
		LEFT JOIN product_images  pi ON pi.product_id = p.id
		WHERE p.status != 'on-going'
		GROUP BY
			p.id, p.farmer_id, p.title, p.description,
			p.price, p.unit, p.city, p.district, p.village,
			p.status, p.stock_status, p.admin_note, p.created_at, p.published_at,
			u.full_name, u.phone, u.status,
			fp.display_name, fp.city, fp.district,
			fp.is_verified, fp.is_founding_farmer, fp.profile_image_url,
			c.id, c.name, c.slug,
			pc.id, pc.name, pc.slug
		ORDER BY p.created_at DESC
		LIMIT $1 OFFSET $2
	`

	rows, err := r.db.Queryx(query, limit, offset)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var products []AdminProductDetail
	for rows.Next() {
		var row AdminProductRow
		if err := rows.StructScan(&row); err != nil {
			return nil, 0, err
		}
		products = append(products, mapAdminRowToDetail(row, r.publicURL))
	}
	if products == nil {
		products = []AdminProductDetail{}
	}
	return products, total, nil
}

func mapAdminRowToDetail(row AdminProductRow, publicURL string) AdminProductDetail {
	var images []ImageItem
	if len(row.ImagesJSON) > 0 {
		json.Unmarshal(row.ImagesJSON, &images)
	}
	if images == nil {
		images = []ImageItem{}
	}
	for i := range images {
		images[i].URL = FormatImageURL(images[i].URL, publicURL)
	}

	var cat *CategoryInfo
	if row.CategoryID != nil {
		c := CategoryInfo{
			ID:   *row.CategoryID,
			Name: derefStr(row.CategoryName),
			Slug: derefStr(row.CategorySlug),
		}
		if row.ParentCategoryID != nil {
			c.Parent = &ParentInfo{
				ID:   *row.ParentCategoryID,
				Name: derefStr(row.ParentCategoryName),
				Slug: derefStr(row.ParentCategorySlug),
			}
		}
		cat = &c
	}

	var farmer *AdminProductFarmerInfo
	if row.FarmerFullName != nil {
		farmer = &AdminProductFarmerInfo{
			ID:               row.FarmerID,
			FullName:         derefStr(row.FarmerFullName),
			DisplayName:      derefStr(row.FarmerDisplayName),
			Phone:            derefStr(row.FarmerPhone),
			City:             derefStr(row.FarmerCity),
			District:         derefStr(row.FarmerDistrict),
			Status:           derefStr(row.FarmerStatus),
			IsVerified:       row.FarmerIsVerified,
			IsFoundingFarmer: row.FarmerIsFoundingFarmer,
			ProfileImageURL:  row.FarmerProfileImageURL,
		}
	}

	return AdminProductDetail{
		ID:          row.ID,
		FarmerID:    row.FarmerID,
		Title:       derefStr(row.Title),
		Description: derefStr(row.Description),
		Price:       derefFloat(row.Price),
		Unit:        derefStr(row.Unit),
		City:        derefStr(row.City),
		District:    derefStr(row.District),
		Village:     derefStr(row.Village),
		Status:      row.Status,
		StockStatus: row.StockStatus,
		AdminNote:     row.AdminNote,
		CreatedAt:     row.CreatedAt,
		PublishedAt:   row.PublishedAt,
		FavoriteCount: row.FavoriteCount,
		ViewCount:     row.ViewCount,
		Images:        images,
		Category:      cat,
		Farmer:        farmer,
	}
}

func derefStr(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

func derefFloat(f *float64) float64 {
	if f == nil {
		return 0.0
	}
	return *f
}

func FormatImageURL(keyOrURL, publicURL string) string {
	if keyOrURL == "" {
		return ""
	}
	if strings.HasPrefix(keyOrURL, "http://") || strings.HasPrefix(keyOrURL, "https://") {
		return keyOrURL
	}
	return strings.TrimRight(publicURL, "/") + "/" + strings.TrimLeft(keyOrURL, "/")
}

func mapRowToPublicProduct(row PublicProductRow, publicURL string) PublicProduct {
	var images []ImageItem
	if len(row.ImagesJSON) > 0 {
		json.Unmarshal(row.ImagesJSON, &images)
	}
	if images == nil {
		images = []ImageItem{}
	}
	for i := range images {
		images[i].URL = FormatImageURL(images[i].URL, publicURL)
	}

	cat := CategoryInfo{
		ID:   row.CategoryID,
		Name: row.CategoryName,
		Slug: row.CategorySlug,
	}
	if row.ParentCategoryID != nil {
		cat.Parent = &ParentInfo{
			ID:   *row.ParentCategoryID,
			Name: *row.ParentCategoryName,
			Slug: *row.ParentCategorySlug,
		}
	}

	return PublicProduct{
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
		PublishedAt: row.PublishedAt,
		Images:      images,
		Category:    cat,
		Farmer: FarmerInfo{
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

func extractImageKey(rawURL, publicURL string) string {
	if publicURL == "" || rawURL == "" {
		return rawURL
	}
	baseURL := strings.TrimRight(publicURL, "/")
	if strings.HasPrefix(rawURL, baseURL) {
		key := strings.TrimPrefix(rawURL, baseURL)
		return strings.TrimLeft(key, "/")
	}
	return rawURL
}

func mapRowToFarmerDetail(row AdminProductRow, publicURL string) FarmerProductDetail {
	var images []ImageItem
	if len(row.ImagesJSON) > 0 {
		json.Unmarshal(row.ImagesJSON, &images)
	}
	if images == nil {
		images = []ImageItem{}
	}
	for i := range images {
		images[i].URL = FormatImageURL(images[i].URL, publicURL)
	}

	var cat *CategoryInfo
	if row.CategoryID != nil {
		cat = &CategoryInfo{
			ID:   *row.CategoryID,
			Name: derefStr(row.CategoryName),
			Slug: derefStr(row.CategorySlug),
		}
		if row.ParentCategoryID != nil {
			cat.Parent = &ParentInfo{
				ID:   *row.ParentCategoryID,
				Name: derefStr(row.ParentCategoryName),
				Slug: derefStr(row.ParentCategorySlug),
			}
		}
	}

	return FarmerProductDetail{
		ID:          row.ID,
		Title:       derefStr(row.Title),
		Description: derefStr(row.Description),
		Price:       derefFloat(row.Price),
		Unit:        derefStr(row.Unit),
		City:        derefStr(row.City),
		District:    derefStr(row.District),
		Village:     derefStr(row.Village),
		CategoryID:  row.CategoryID,
		Status:      row.Status,
		StockStatus: row.StockStatus,
		AdminNote:     row.AdminNote,
		CreatedAt:     row.CreatedAt,
		FavoriteCount: row.FavoriteCount,
		ViewCount:     row.ViewCount,
		Images:        images,
		Category:      cat,
	}
}

