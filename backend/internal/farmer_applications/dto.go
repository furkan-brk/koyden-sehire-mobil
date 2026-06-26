package farmer_applications

type CreateApplicationRequest struct {
	FullName   string  `json:"full_name" validate:"required"`
	Phone      string  `json:"phone" validate:"required"`
	Email      *string `json:"email"`
	Password   string  `json:"password" validate:"required,min=6"`
	InviteCode string  `json:"invite_code" validate:"required"`

	BusinessName        string   `json:"business_name" validate:"required"`
	ProducerType        string   `json:"producer_type" validate:"required"`
	City                string   `json:"city" validate:"required"`
	District            string   `json:"district" validate:"required"`
	Village             string   `json:"village"`
	Address             *string  `json:"address"`
	Bio                 string   `json:"bio" validate:"required"`
	ProductCategories   []string `json:"product_categories" validate:"required"`
	ProductExamples     string   `json:"product_examples" validate:"required"`
	ProductionPlaceType *string  `json:"production_place_type"`
	DocumentURLs        []string `json:"document_urls"`
	ApplicationNote     *string  `json:"application_note"`

	ApplicationVideoKey *string `json:"application_video_key"`

	KvkkAccepted             bool `json:"kvkk_accepted" validate:"required"`
	PlatformTermsAccepted    bool `json:"platform_terms_accepted" validate:"required"`
	DeclaresOwnProduction    bool `json:"declares_own_production" validate:"required"`
	DeclaresAccurateLocation bool `json:"declares_accurate_location" validate:"required"`
	DeclaresNotIntermediary  bool `json:"declares_not_intermediary" validate:"required"`
}

type VideoPresignRequest struct {
	Phone       string `json:"phone" validate:"required"`
	InviteCode  string `json:"invite_code" validate:"required"`
	ContentType string `json:"content_type" validate:"required"`
}

type VideoPresignResponse struct {
	UploadURL string `json:"upload_url"`
	Key       string `json:"key"`
}
