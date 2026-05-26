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
		    village = $5, bio = $6, public_phone = $7, show_phone = $8,
		    profile_image_url = $9, updated_at = NOW()
		WHERE user_id = $10
	`, req.DisplayName, req.ProducerType, req.City, req.District,
		req.Village, req.Bio, req.PublicPhone, req.ShowPhone,
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
