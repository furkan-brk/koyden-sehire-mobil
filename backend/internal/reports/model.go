package reports

import (
	"time"

	"github.com/google/uuid"
)

type Report struct {
	ID         uuid.UUID  `db:"id"          json:"id"`
	ReporterID *uuid.UUID `db:"reporter_id" json:"reporter_id"`
	TargetType string     `db:"target_type" json:"target_type"`
	TargetID   uuid.UUID  `db:"target_id"   json:"target_id"`
	Reason     string     `db:"reason"      json:"reason"`
	Note       string     `db:"note"        json:"note"`
	Status     string     `db:"status"      json:"status"`
	CreatedAt  time.Time  `db:"created_at"  json:"created_at"`
	ReviewedAt *time.Time `db:"reviewed_at" json:"reviewed_at"`
	ReviewedBy *uuid.UUID `db:"reviewed_by" json:"reviewed_by"`
	ReviewNote string     `db:"review_note" json:"review_note"`
}
