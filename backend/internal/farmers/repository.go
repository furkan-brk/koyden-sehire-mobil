package farmers

import (
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
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

func (r *Repository) GetPublicByID(id string) (*PublicFarmerDetail, error) {
	var row struct {
		UserID           string  `db:"user_id"`
		DisplayName      string  `db:"display_name"`
		ProducerType     string  `db:"producer_type"`
		City             string  `db:"city"`
		District         string  `db:"district"`
		Village          string  `db:"village"`
		Address          *string `db:"address"`
		Bio              string  `db:"bio"`
		ProfileImageURL  *string `db:"profile_image_url"`
		PublicPhone      string  `db:"public_phone"`
		ShowPhone        bool    `db:"show_phone"`
		IsVerified       bool    `db:"is_verified"`
		IsFoundingFarmer bool    `db:"is_founding_farmer"`
	}
	err := r.db.Get(&row, `
		SELECT fp.user_id, fp.display_name, fp.producer_type, fp.city, fp.district, fp.village, fp.address,
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
		Address:          row.Address,
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
		       fp.display_name, fp.producer_type, fp.city, fp.district, fp.village, fp.address, fp.bio,
		       fp.profile_image_url, fp.public_phone, fp.show_phone,
		       fp.is_verified, fp.is_founding_farmer, fp.invite_quota,
		       ic.code AS invite_code, COALESCE(ic.used_count, 0) AS used_invites
		FROM users u
		JOIN farmer_profiles fp ON fp.user_id = u.id
		LEFT JOIN LATERAL (
			SELECT code, used_count
			FROM invite_codes
			WHERE owner_user_id = u.id AND is_active = true
			ORDER BY created_at DESC
			LIMIT 1
		) ic ON true
		WHERE u.id = $1 AND u.role = 'farmer'
	`, id)
	if err != nil {
		return nil, apperrors.ErrNotFound
	}

	// Referans eden kişi: bu farmerin başvurusundaki referred_by_user_id
	var ref struct {
		ID          string `db:"id"`
		FullName    string `db:"full_name"`
		Phone       string `db:"phone"`
		City        string `db:"city"`
		DisplayName string `db:"display_name"`
	}
	if refErr := r.db.Get(&ref, `
		SELECT u2.id, u2.full_name, u2.phone, fp2.city, fp2.display_name
		FROM farmer_applications fa
		JOIN users u2 ON u2.id = fa.referred_by_user_id
		JOIN farmer_profiles fp2 ON fp2.user_id = u2.id
		WHERE fa.phone = (SELECT phone FROM users WHERE id = $1)
		  AND fa.status = 'approved'
		  AND fa.referred_by_user_id IS NOT NULL
		LIMIT 1
	`, id); refErr == nil {
		d.ReferredBy = &ReferredByInfo{
			ID:          ref.ID,
			FullName:    ref.FullName,
			Phone:       ref.Phone,
			City:        ref.City,
			DisplayName: ref.DisplayName,
		}
	}

	// Bu farmerin davet ettiği üreticiler
	type referralRow struct {
		ID          string    `db:"id"`
		FullName    string    `db:"full_name"`
		DisplayName string    `db:"display_name"`
		City        string    `db:"city"`
		Status      string    `db:"status"`
		CreatedAt   time.Time `db:"created_at"`
		InviteCode  *string   `db:"invite_code"`
	}
	var rows []referralRow
	_ = r.db.Select(&rows, `
		SELECT u2.id, u2.full_name, fp2.display_name, fp2.city, u2.status, u2.created_at,
		       ic.code AS invite_code
		FROM farmer_applications fa
		JOIN users u2 ON u2.phone = fa.phone AND u2.role = 'farmer'
		JOIN farmer_profiles fp2 ON fp2.user_id = u2.id
		LEFT JOIN LATERAL (
			SELECT code FROM invite_codes
			WHERE owner_user_id = u2.id AND is_active = true
			ORDER BY created_at DESC LIMIT 1
		) ic ON true
		WHERE fa.referred_by_user_id = $1
		  AND fa.status = 'approved'
		ORDER BY u2.created_at DESC
	`, id)
	d.Referrals = make([]ReferralItem, len(rows))
	for i, row := range rows {
		d.Referrals[i] = ReferralItem{
			ID:          row.ID,
			FullName:    row.FullName,
			DisplayName: row.DisplayName,
			City:        row.City,
			Status:      row.Status,
			CreatedAt:   row.CreatedAt,
			InviteCode:  row.InviteCode,
		}
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

func (r *Repository) ListAdmin(page, limit int, city string) ([]FarmerDetail, int, error) {
	var total int
	if err := r.db.Get(&total, `
		SELECT COUNT(*) FROM users u
		JOIN farmer_profiles fp ON fp.user_id = u.id
		WHERE u.role = 'farmer'
		  AND ($1 = '' OR LOWER(fp.city) = LOWER($1))
	`, city); err != nil {
		return nil, 0, err
	}

	offset := (page - 1) * limit
	var farmers []FarmerDetail
	err := r.db.Select(&farmers, `
		SELECT u.id, u.full_name, u.phone, u.email, u.status, u.created_at,
		       fp.display_name, fp.producer_type, fp.city, fp.district, fp.village, fp.address, fp.bio,
		       fp.profile_image_url, fp.public_phone, fp.show_phone,
		       fp.is_verified, fp.is_founding_farmer, fp.invite_quota,
		       ic.code AS invite_code, COALESCE(ic.used_count, 0) AS used_invites
		FROM users u
		JOIN farmer_profiles fp ON fp.user_id = u.id
		LEFT JOIN LATERAL (
			SELECT code, used_count
			FROM invite_codes
			WHERE owner_user_id = u.id AND is_active = true
			ORDER BY created_at DESC
			LIMIT 1
		) ic ON true
		WHERE u.role = 'farmer'
		  AND ($1 = '' OR LOWER(fp.city) = LOWER($1))
		ORDER BY u.created_at DESC
		LIMIT $2 OFFSET $3
	`, city, limit, offset)
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

// GetProductStatsByFarmerID returns active/pending/passive counts in a single query.
func (r *Repository) GetProductStatsByFarmerID(farmerID uuid.UUID) (active, pending, passive int, err error) {
	rows, err := r.db.Query(`
		SELECT status, COUNT(*) AS cnt
		FROM products
		WHERE farmer_id = $1 AND status IN ('active', 'pending', 'passive')
		GROUP BY status
	`, farmerID)
	if err != nil {
		return
	}
	defer rows.Close()
	for rows.Next() {
		var status string
		var cnt int
		if err = rows.Scan(&status, &cnt); err != nil {
			return
		}
		switch status {
		case "active":
			active = cnt
		case "pending":
			pending = cnt
		case "passive":
			passive = cnt
		}
	}
	err = rows.Err()
	return
}

// GetInviteStatsByFarmerID returns total quota and used count from the farmer's invite code.
// A farmer has at most one invite code; if none exists the quota values are zero.
func (r *Repository) GetInviteStatsByFarmerID(farmerID uuid.UUID) (totalQuota, usedQuota int, err error) {
	err = r.db.QueryRow(`
		SELECT COALESCE(SUM(max_uses), 0), COALESCE(SUM(used_count), 0)
		FROM invite_codes
		WHERE owner_user_id = $1
	`, farmerID).Scan(&totalQuota, &usedQuota)
	return
}

// GetRecentProductsByFarmerID returns the most recent products for the farmer.
func (r *Repository) GetRecentProductsByFarmerID(farmerID uuid.UUID, limit int) ([]RecentProductItem, error) {
	type row struct {
		ID        uuid.UUID `db:"id"`
		Title     string    `db:"title"`
		Price     float64   `db:"price"`
		Unit      string    `db:"unit"`
		Status    string    `db:"status"`
		CreatedAt time.Time `db:"created_at"`
		ImageKey  *string   `db:"image_key"`
	}
	var rows []row
	err := r.db.Select(&rows, `
		SELECT p.id, COALESCE(p.title, '') AS title,
		       COALESCE(p.price, 0) AS price, COALESCE(p.unit, '') AS unit,
		       COALESCE(p.status, '') AS status, p.created_at,
		       (SELECT pi.image_key FROM product_images pi
		        WHERE pi.product_id = p.id
		        ORDER BY pi.sort_order ASC
		        LIMIT 1) AS image_key
		FROM products p
		WHERE p.farmer_id = $1
		  AND p.status NOT IN ('on-going', 'successful', 'failed')
		ORDER BY p.created_at DESC
		LIMIT $2
	`, farmerID, limit)
	if err != nil {
		return nil, err
	}
	items := make([]RecentProductItem, len(rows))
	for i, row := range rows {
		items[i] = RecentProductItem{
			ID:        row.ID,
			Name:      row.Title,
			Title:     row.Title,
			Price:     row.Price,
			Unit:      row.Unit,
			Status:    row.Status,
			CreatedAt: row.CreatedAt,
		}
		if row.ImageKey != nil {
			items[i].ImageURL = products.FormatImageURL(*row.ImageKey, r.publicURL)
		}
	}
	return items, nil
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
