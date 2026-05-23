package farmers

import (
	"fmt"
	"strings"

	"github.com/jmoiron/sqlx"
	apperrors "github.com/koydensehire/backend/pkg/errors"
)

type Repository struct {
	db *sqlx.DB
}

func NewRepository(db *sqlx.DB) *Repository {
	return &Repository{db: db}
}

func (r *Repository) GetPublicByID(id string) (*PublicFarmerDetail, error) {
	var row struct {
		UserID           string  `db:"user_id"`
		DisplayName      string  `db:"display_name"`
		ProducerType     string  `db:"producer_type"`
		City             string  `db:"city"`
		District         string  `db:"district"`
		Village          string  `db:"village"`
		Bio              string  `db:"bio"`
		ProfileImageURL  *string `db:"profile_image_url"`
		PublicPhone      string  `db:"public_phone"`
		ShowPhone        bool    `db:"show_phone"`
		IsVerified       bool    `db:"is_verified"`
		IsFoundingFarmer bool    `db:"is_founding_farmer"`
	}
	err := r.db.Get(&row, `
		SELECT fp.user_id, fp.display_name, fp.producer_type, fp.city, fp.district, fp.village,
		       fp.bio, fp.profile_image_url, fp.public_phone, fp.show_phone,
		       fp.is_verified, fp.is_founding_farmer
		FROM farmer_profiles fp
		JOIN users u ON u.id = fp.user_id
		WHERE fp.user_id = $1 AND u.status = 'active'
	`, id)
	if err != nil {
		return nil, apperrors.ErrNotFound
	}

	f := &PublicFarmerDetail{
		ID:               row.UserID,
		DisplayName:      row.DisplayName,
		ProducerType:     row.ProducerType,
		City:             row.City,
		District:         row.District,
		Village:          row.Village,
		Bio:              row.Bio,
		ProfileImageURL:  row.ProfileImageURL,
		IsVerified:       row.IsVerified,
		IsFoundingFarmer: row.IsFoundingFarmer,
	}
	if row.ShowPhone {
		f.PublicPhone = &row.PublicPhone
	}
	return f, nil
}

func (r *Repository) GetAdminDetail(id string) (*FarmerDetail, error) {
	var d FarmerDetail
	err := r.db.Get(&d, `
		SELECT u.id, u.full_name, u.phone, u.email, u.status, u.created_at,
		       fp.display_name, fp.producer_type, fp.city, fp.district, fp.village, fp.bio,
		       fp.profile_image_url, fp.public_phone, fp.show_phone,
		       fp.is_verified, fp.is_founding_farmer, fp.invite_quota
		FROM users u
		JOIN farmer_profiles fp ON fp.user_id = u.id
		WHERE u.id = $1 AND u.role = 'farmer'
	`, id)
	if err != nil {
		return nil, apperrors.ErrNotFound
	}
	return &d, nil
}

func (r *Repository) ListPublic(page, limit int, city, search string) ([]PublicFarmerSummary, int, error) {
	args := []interface{}{}
	conditions := []string{"u.status = 'active'", "u.role = 'farmer'"}

	if city != "" {
		args = append(args, city)
		conditions = append(conditions, fmt.Sprintf("LOWER(fp.city) = LOWER($%d)", len(args)))
	}
	if search != "" {
		args = append(args, "%"+strings.ToLower(search)+"%")
		conditions = append(conditions, fmt.Sprintf(
			"(LOWER(fp.display_name) LIKE $%d OR LOWER(fp.city) LIKE $%d OR LOWER(fp.producer_type) LIKE $%d)",
			len(args), len(args), len(args),
		))
	}

	where := "WHERE " + strings.Join(conditions, " AND ")

	var total int
	if err := r.db.Get(&total, fmt.Sprintf(`
		SELECT COUNT(*) FROM users u
		JOIN farmer_profiles fp ON fp.user_id = u.id
		%s
	`, where), args...); err != nil {
		return nil, 0, err
	}

	offset := (page - 1) * limit
	args = append(args, limit, offset)
	var farmers []PublicFarmerSummary
	err := r.db.Select(&farmers, fmt.Sprintf(`
		SELECT fp.user_id AS id, fp.display_name, fp.producer_type, fp.city, fp.district,
		       fp.profile_image_url, fp.is_verified, fp.is_founding_farmer
		FROM users u
		JOIN farmer_profiles fp ON fp.user_id = u.id
		%s
		ORDER BY fp.is_founding_farmer DESC, fp.is_verified DESC, u.created_at DESC
		LIMIT $%d OFFSET $%d
	`, where, len(args)-1, len(args)), args...)
	if farmers == nil {
		farmers = []PublicFarmerSummary{}
	}
	return farmers, total, err
}

func (r *Repository) ListAdmin(page, limit int) ([]FarmerDetail, int, error) {
	var total int
	if err := r.db.Get(&total, "SELECT COUNT(*) FROM users WHERE role = 'farmer'"); err != nil {
		return nil, 0, err
	}

	offset := (page - 1) * limit
	var farmers []FarmerDetail
	err := r.db.Select(&farmers, `
		SELECT u.id, u.full_name, u.phone, u.email, u.status, u.created_at,
		       fp.display_name, fp.producer_type, fp.city, fp.district, fp.village, fp.bio,
		       fp.profile_image_url, fp.public_phone, fp.show_phone,
		       fp.is_verified, fp.is_founding_farmer, fp.invite_quota
		FROM users u
		JOIN farmer_profiles fp ON fp.user_id = u.id
		WHERE u.role = 'farmer'
		ORDER BY u.created_at DESC
		LIMIT $1 OFFSET $2
	`, limit, offset)
	if farmers == nil {
		farmers = []FarmerDetail{}
	}
	return farmers, total, err
}

func (r *Repository) Suspend(id string) error {
	tx, err := r.db.Beginx()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	if _, err := tx.Exec("UPDATE users SET status = 'suspended', updated_at = NOW() WHERE id = $1", id); err != nil {
		return err
	}

	if _, err := tx.Exec(`
		UPDATE products
		SET previous_status = status, status = 'hidden', updated_at = NOW()
		WHERE farmer_id = $1 AND status != 'hidden'
	`, id); err != nil {
		return err
	}

	if _, err := tx.Exec(`
		UPDATE invite_codes SET is_active = false, updated_at = NOW()
		WHERE owner_user_id = $1
	`, id); err != nil {
		return err
	}

	return tx.Commit()
}

func (r *Repository) Reactivate(id string) error {
	tx, err := r.db.Beginx()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	if _, err := tx.Exec("UPDATE users SET status = 'active', updated_at = NOW() WHERE id = $1", id); err != nil {
		return err
	}

	if _, err := tx.Exec(`
		UPDATE products
		SET status = COALESCE(previous_status, 'pending'),
		    previous_status = NULL,
		    updated_at = NOW()
		WHERE farmer_id = $1 AND status = 'hidden' AND previous_status IS NOT NULL
	`, id); err != nil {
		return err
	}

	if _, err := tx.Exec(`
		UPDATE invite_codes SET is_active = true, updated_at = NOW()
		WHERE owner_user_id = $1
	`, id); err != nil {
		return err
	}

	return tx.Commit()
}

func (r *Repository) SetFounding(id string, isFounding bool) error {
	_, err := r.db.Exec(`
		UPDATE farmer_profiles SET is_founding_farmer = $1, updated_at = NOW()
		WHERE user_id = $2
	`, isFounding, id)
	return err
}

func (r *Repository) UpdateInviteQuota(id string, quota int) error {
	tx, err := r.db.Beginx()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	if _, err := tx.Exec(`
		UPDATE farmer_profiles SET invite_quota = $1, updated_at = NOW() WHERE user_id = $2
	`, quota, id); err != nil {
		return err
	}

	if _, err := tx.Exec(`
		UPDATE invite_codes SET max_uses = $1, updated_at = NOW()
		WHERE owner_user_id = $2 AND is_active = true
	`, quota, id); err != nil {
		return err
	}

	return tx.Commit()
}
