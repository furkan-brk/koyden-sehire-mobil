package farmer_applications

import "time"

type FarmerApplication struct {
	ID            string  `db:"id" json:"id"`
	FullName      string  `db:"full_name" json:"full_name"`
	Phone         string  `db:"phone" json:"phone"`
	Email         *string `db:"email" json:"email"`
	PasswordHash  string  `db:"password_hash" json:"-"`
	PhoneVerified bool    `db:"phone_verified" json:"phone_verified"`

	BusinessName string `db:"business_name" json:"business_name"`
	ProducerType string `db:"producer_type" json:"producer_type"`
	City         string `db:"city" json:"city"`
	District     string `db:"district" json:"district"`
	Village      string `db:"village" json:"village"`
	Address      *string `db:"address" json:"address"`
	Bio          string `db:"bio" json:"bio"`

	ProductCategories   []byte  `db:"product_categories" json:"product_categories"`
	ProductExamples     string  `db:"product_examples" json:"product_examples"`
	ProductionPlaceType *string `db:"production_place_type" json:"production_place_type"`
	DocumentURLs        []byte  `db:"document_urls" json:"document_urls"`
	ApplicationNote     *string `db:"application_note" json:"application_note"`

	ApplicationVideoKey    *string    `db:"application_video_key" json:"application_video_key"`
	ApplicationVideoURL    *string    `db:"application_video_url" json:"application_video_url"`
	ApplicationVideoStatus string     `db:"application_video_status" json:"application_video_status"`
	VideoRequestedAt       *time.Time `db:"video_requested_at" json:"video_requested_at"`
	VideoUploadedAt        *time.Time `db:"video_uploaded_at" json:"video_uploaded_at"`

	InviteCodeID      *string `db:"invite_code_id" json:"invite_code_id"`
	ReferredByUserID  *string `db:"referred_by_user_id" json:"referred_by_user_id"`
	ApplicationSource string  `db:"application_source" json:"application_source"`

	KvkkAccepted             bool `db:"kvkk_accepted" json:"kvkk_accepted"`
	PlatformTermsAccepted    bool `db:"platform_terms_accepted" json:"platform_terms_accepted"`
	DeclaresOwnProduction    bool `db:"declares_own_production" json:"declares_own_production"`
	DeclaresAccurateLocation bool `db:"declares_accurate_location" json:"declares_accurate_location"`
	DeclaresNotIntermediary  bool `db:"declares_not_intermediary" json:"declares_not_intermediary"`

	Status          string     `db:"status" json:"status"`
	RejectionReason *string    `db:"rejection_reason" json:"rejection_reason"`
	AdminNote       *string    `db:"admin_note" json:"admin_note"`
	ReviewedBy      *string    `db:"reviewed_by" json:"reviewed_by"`
	ReviewedAt      *time.Time `db:"reviewed_at" json:"reviewed_at"`

	CreatedAt time.Time `db:"created_at" json:"created_at"`
	UpdatedAt time.Time `db:"updated_at" json:"updated_at"`
}
