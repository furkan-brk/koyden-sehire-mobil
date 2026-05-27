package categories

import (
	"github.com/jmoiron/sqlx"
	apperrors "github.com/koydensehire/backend/pkg/errors"
)

type Repository struct {
	db *sqlx.DB
}

func NewRepository(db *sqlx.DB) *Repository {
	return &Repository{db: db}
}

func (r *Repository) ListActive() ([]Category, error) {
	var cats []Category
	err := r.db.Select(&cats, `
		SELECT * FROM categories
		WHERE is_active = true
		ORDER BY sort_order, name
	`)
	return cats, err
}

func (r *Repository) ListAll() ([]Category, error) {
	var cats []Category
	err := r.db.Select(&cats, "SELECT * FROM categories ORDER BY sort_order, name")
	return cats, err
}

func (r *Repository) GetByID(id string) (*Category, error) {
	var c Category
	err := r.db.Get(&c, "SELECT * FROM categories WHERE id = $1", id)
	if err != nil {
		return nil, apperrors.ErrNotFound
	}
	return &c, nil
}

func (r *Repository) GetSubcategoryIDs(parentID string) ([]string, error) {
	var ids []string
	err := r.db.Select(&ids, "SELECT id FROM categories WHERE parent_id = $1 AND is_active = true", parentID)
	return ids, err
}

func (r *Repository) Create(req *CreateCategoryRequest) (*Category, error) {
	var cat Category
	err := r.db.Get(&cat, `
		INSERT INTO categories (name, slug, parent_id, icon, icon_name, color_hex, sort_order)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING *
	`, req.Name, req.Slug, req.ParentID, req.Icon, req.IconName, req.ColorHex, req.SortOrder)
	return &cat, err
}

func (r *Repository) Update(id string, req *UpdateCategoryRequest) (*Category, error) {
	var cat Category
	err := r.db.Get(&cat, `
		UPDATE categories
		SET name = $1, slug = $2, parent_id = $3, icon = $4, icon_name = $5, color_hex = $6, sort_order = $7, updated_at = NOW()
		WHERE id = $8
		RETURNING *
	`, req.Name, req.Slug, req.ParentID, req.Icon, req.IconName, req.ColorHex, req.SortOrder, id)
	if err != nil {
		return nil, apperrors.ErrNotFound
	}
	return &cat, nil
}

func (r *Repository) SoftDelete(id string) error {
	tx, err := r.db.Beginx()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	var cat Category
	if err := tx.Get(&cat, "SELECT * FROM categories WHERE id = $1", id); err != nil {
		return apperrors.ErrNotFound
	}

	_, err = tx.Exec("UPDATE categories SET is_active = false, updated_at = NOW() WHERE id = $1", id)
	if err != nil {
		return err
	}

	if cat.ParentID == nil {
		_, err = tx.Exec("UPDATE categories SET is_active = false, updated_at = NOW() WHERE parent_id = $1", id)
		if err != nil {
			return err
		}
	}

	return tx.Commit()
}
