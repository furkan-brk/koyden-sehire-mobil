package auth

import "time"

type User struct {
	ID              string     `db:"id"`
	FullName        string     `db:"full_name"`
	Phone           string     `db:"phone"`
	Email           *string    `db:"email"`
	PasswordHash    string     `db:"password_hash"`
	Role            string     `db:"role"`
	Status          string     `db:"status"`
	PhoneVerified   bool       `db:"phone_verified"`
	PhoneVerifiedAt *time.Time `db:"phone_verified_at"`
	ProfileImageURL *string    `db:"profile_image_url"`
	CreatedAt       time.Time  `db:"created_at"`
	UpdatedAt       time.Time  `db:"updated_at"`
	DeletedAt       *time.Time `db:"deleted_at"`
}
