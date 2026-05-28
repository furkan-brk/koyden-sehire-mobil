package reports

type SubmitReportRequest struct {
	TargetType string `json:"target_type" validate:"required"`
	TargetID   string `json:"target_id"   validate:"required"`
	Reason     string `json:"reason"      validate:"required"`
	Note       string `json:"note"`
}

type ReviewReportRequest struct {
	Status     string `json:"status"      validate:"required"`
	ReviewNote string `json:"review_note"`
}

type ListReportsFilter struct {
	Status     string
	TargetType string
	Page       int
	Limit      int
}
