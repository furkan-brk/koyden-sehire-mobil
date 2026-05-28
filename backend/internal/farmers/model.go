package farmers

import "time"

type FarmerDetail struct {
	ID        string    `db:"id" json:"id"`
	FullName  string    `db:"full_name" json:"full_name"`
	Phone     string    `db:"phone" json:"phone"`
	Email     *string   `db:"email" json:"email"`
	Status    string    `db:"status" json:"status"`
	CreatedAt time.Time `db:"created_at" json:"created_at"`

	DisplayName      string  `db:"display_name" json:"display_name"`
	ProducerType     string  `db:"producer_type" json:"producer_type"`
	City             string  `db:"city" json:"city"`
	District         string  `db:"district" json:"district"`
	Village          string  `db:"village" json:"village"`
	Bio              string  `db:"bio" json:"bio"`
	ProfileImageURL  *string `db:"profile_image_url" json:"profile_image_url"`
	PublicPhone      string  `db:"public_phone" json:"public_phone"`
	ShowPhone        bool    `db:"show_phone" json:"show_phone"`
	IsVerified       bool    `db:"is_verified" json:"is_verified"`
	IsFoundingFarmer bool    `db:"is_founding_farmer" json:"is_founding_farmer"`
	InviteQuota      int     `db:"invite_quota" json:"invite_quota"`
	InviteCode       *string `db:"invite_code" json:"invite_code"`
	UsedInvites      int     `db:"used_invites" json:"used_invites"`
}

type PublicFarmerSummary struct {
	ID               string  `db:"id" json:"id"`
	DisplayName      string  `db:"display_name" json:"display_name"`
	ProducerType     string  `db:"producer_type" json:"producer_type"`
	City             string  `db:"city" json:"city"`
	District         string  `db:"district" json:"district"`
	ProfileImageURL  *string `db:"profile_image_url" json:"profile_image_url"`
	IsVerified       bool    `db:"is_verified" json:"is_verified"`
	IsFoundingFarmer bool    `db:"is_founding_farmer" json:"is_founding_farmer"`
}

type PublicFarmerDetail struct {
	ID               string  `db:"id" json:"id"`
	DisplayName      string  `db:"display_name" json:"display_name"`
	ProducerType     string  `db:"producer_type" json:"producer_type"`
	City             string  `db:"city" json:"city"`
	District         string  `db:"district" json:"district"`
	Village          string  `db:"village" json:"village"`
	Bio              string  `db:"bio" json:"bio"`
	ProfileImageURL  *string `db:"profile_image_url" json:"profile_image_url"`
	PublicPhone      *string `db:"public_phone" json:"public_phone,omitempty"`
	IsVerified       bool    `db:"is_verified" json:"is_verified"`
	IsFoundingFarmer bool    `db:"is_founding_farmer" json:"is_founding_farmer"`
}
