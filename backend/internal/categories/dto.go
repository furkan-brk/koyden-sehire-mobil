package categories

type CreateCategoryRequest struct {
	Name      string  `json:"name" validate:"required"`
	Slug      string  `json:"slug" validate:"required"`
	ParentID  *string `json:"parent_id"`
	Icon      *string `json:"icon"`
	IconName  string  `json:"icon_name"`
	ColorHex  string  `json:"color_hex"`
	SortOrder int     `json:"sort_order"`
}

type UpdateCategoryRequest struct {
	Name      string  `json:"name" validate:"required"`
	Slug      string  `json:"slug" validate:"required"`
	ParentID  *string `json:"parent_id"`
	Icon      *string `json:"icon"`
	IconName  string  `json:"icon_name"`
	ColorHex  string  `json:"color_hex"`
	SortOrder int     `json:"sort_order"`
}
