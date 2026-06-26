package users

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

func (r *Repository) GetByID(id string) (*User, error) {
	var u User
	err := r.db.Get(&u, "SELECT id, full_name, phone, email, role, status, phone_verified, phone_verified_at, created_at, updated_at FROM users WHERE id = $1", id)
	if err != nil {
		return nil, apperrors.ErrNotFound
	}
	return &u, nil
}

func (r *Repository) GetFarmerProfile(userID string) (*FarmerProfile, error) {
	var p FarmerProfile
	err := r.db.Get(&p, "SELECT * FROM farmer_profiles WHERE user_id = $1", userID)
	if err != nil {
		return nil, apperrors.ErrNotFound
	}
	return &p, nil
}

func (r *Repository) UpdateFarmerProfile(userID string, req *UpdateProfileRequest) error {
	_, err := r.db.Exec(`
		UPDATE farmer_profiles
		SET display_name = $1, producer_type = $2, city = $3, district = $4,
		    village = $5, address = $6, bio = $7, public_phone = $8, show_phone = $9,
		    profile_image_url = $10, updated_at = NOW()
		WHERE user_id = $11
	`, req.DisplayName, req.ProducerType, req.City, req.District,
		req.Village, req.Address, req.Bio, req.PublicPhone, req.ShowPhone,
		req.ProfileImageURL, userID)
	return err
}

func (r *Repository) UpdateCustomerProfile(userID string, req *UpdateCustomerProfileRequest) error {
	_, err := r.db.Exec(`
		UPDATE users
		SET full_name = $1, email = $2, updated_at = NOW()
		WHERE id = $3
	`, req.FullName, req.Email, userID)
	return err
}

// UpdatePasswordByPhone bcrypt hash'lenmiş yeni şifreyi telefon numarasına göre günceller.
// Telefon bulunamazsa PHONE_NOT_FOUND hatası döner.
func (r *Repository) UpdatePasswordByPhone(phone, hashedPw string) error {
	res, err := r.db.Exec(`
		UPDATE users
		SET password_hash = $1, updated_at = NOW()
		WHERE phone = $2 AND deleted_at IS NULL
	`, hashedPw, phone)
	if err != nil {
		return apperrors.ErrInternal
	}
	rows, err := res.RowsAffected()
	if err != nil {
		return apperrors.ErrInternal
	}
	if rows == 0 {
		return apperrors.New("PHONE_NOT_FOUND", "Bu telefon numarasıyla kayıtlı hesap bulunamadı", 404)
	}
	return nil
}

// SoftDeleteUser kullanıcıyı deleted_at alanını doldurarak soft-delete yapar.
func (r *Repository) SoftDeleteUser(userID string) error {
	res, err := r.db.Exec(`
		UPDATE users
		SET deleted_at = NOW(), updated_at = NOW()
		WHERE id = $1 AND deleted_at IS NULL
	`, userID)
	if err != nil {
		return apperrors.ErrInternal
	}
	rows, err := res.RowsAffected()
	if err != nil {
		return apperrors.ErrInternal
	}
	if rows == 0 {
		return apperrors.ErrNotFound
	}
	return nil
}

// FindPasswordHashByID kullanıcının mevcut şifre hash'ini döner (şifre doğrulaması için).
func (r *Repository) FindPasswordHashByID(userID string) (string, error) {
	var hash string
	err := r.db.Get(&hash, "SELECT password_hash FROM users WHERE id = $1 AND deleted_at IS NULL", userID)
	if err != nil {
		return "", apperrors.ErrNotFound
	}
	return hash, nil
}
