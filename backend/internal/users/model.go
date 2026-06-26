package users

import "time"

type User struct {
	ID              string     `db:"id" json:"id"`
	FullName        string     `db:"full_name" json:"full_name"`
	Phone           string     `db:"phone" json:"phone"`
	Email           *string    `db:"email" json:"email"`
	Role            string     `db:"role" json:"role"`
	Status          string     `db:"status" json:"status"`
	PhoneVerified   bool       `db:"phone_verified" json:"phone_verified"`
	PhoneVerifiedAt *time.Time `db:"phone_verified_at" json:"phone_verified_at"`
	CreatedAt       time.Time  `db:"created_at" json:"created_at"`
	UpdatedAt       time.Time  `db:"updated_at" json:"updated_at"`
	DeletedAt       *time.Time `db:"deleted_at" json:"deleted_at,omitempty"`
}

type FarmerProfile struct {
	ID               string    `db:"id" json:"id"`
	UserID           string    `db:"user_id" json:"user_id"`
	DisplayName      string    `db:"display_name" json:"display_name"`
	ProducerType     string    `db:"producer_type" json:"producer_type"`
	City             string    `db:"city" json:"city"`
	District         string    `db:"district" json:"district"`
	Village          string    `db:"village" json:"village"`
	Address          *string   `db:"address" json:"address"`
	Bio              string    `db:"bio" json:"bio"`
	ProfileImageURL  *string   `db:"profile_image_url" json:"profile_image_url"`
	PublicPhone      string    `db:"public_phone" json:"public_phone"`
	ShowPhone        bool      `db:"show_phone" json:"show_phone"`
	IsVerified       bool      `db:"is_verified" json:"is_verified"`
	IsFoundingFarmer bool      `db:"is_founding_farmer" json:"is_founding_farmer"`
	InviteQuota      int       `db:"invite_quota" json:"invite_quota"`
	CreatedAt        time.Time `db:"created_at" json:"created_at"`
	UpdatedAt        time.Time `db:"updated_at" json:"updated_at"`
}
