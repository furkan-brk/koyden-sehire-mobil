package uploads

type UploadImageResponse struct {
	URL string `json:"url"`
}

type PresignedURLRequest struct {
	ProductID   string `json:"product_id" validate:"required,uuid4"`
	FileSize    int64  `json:"file_size" validate:"required,gt=0"`
	ContentType string `json:"content_type" validate:"required"`
}

type PresignedURLResponse struct {
	UploadURL string            `json:"upload_url"`
	Key       string            `json:"key"`
	URL       string            `json:"url"`
	Headers   map[string]string `json:"headers"`
}


