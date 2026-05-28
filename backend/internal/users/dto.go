package users

import "time"

type UpdateProfileRequest struct {
	DisplayName     string  `json:"display_name" validate:"required"`
	ProducerType    string  `json:"producer_type" validate:"required"`
	City            string  `json:"city" validate:"required"`
	District        string  `json:"district" validate:"required"`
	Village         string  `json:"village" validate:"required"`
	Bio             string  `json:"bio" validate:"required"`
	PublicPhone     string  `json:"public_phone" validate:"required"`
	ShowPhone       bool    `json:"show_phone"`
	ProfileImageURL *string `json:"profile_image_url"`
}

type CustomerProfileResponse struct {
	ID        string    `json:"id"`
	FullName  string    `json:"full_name"`
	Phone     string    `json:"phone"`
	Email     *string   `json:"email"`
	CreatedAt time.Time `json:"created_at"`
}

type UpdateCustomerProfileRequest struct {
	FullName string  `json:"full_name" validate:"required,min=2,max=100"`
	Email    *string `json:"email" validate:"omitempty,email,max=255"`
}

// DeleteAccountRequest KVKK gereği hesap silme isteği — şifre doğrulaması zorunlu.
type DeleteAccountRequest struct {
	Password string `json:"password" validate:"required"`
}
