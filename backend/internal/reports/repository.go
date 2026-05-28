package reports

import (
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
	apperrors "github.com/koydensehire/backend/pkg/errors"
)

type Repository struct {
	db *sqlx.DB
}

func NewRepository(db *sqlx.DB) *Repository {
	return &Repository{db: db}
}

// Create inserts a new report and returns it.
func (r *Repository) Create(report *Report) (*Report, error) {
	var out Report
	err := r.db.Get(&out, `
		INSERT INTO reports (reporter_id, target_type, target_id, reason, note)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING *
	`, report.ReporterID, report.TargetType, report.TargetID, report.Reason, report.Note)
	if err != nil {
		return nil, err
	}
	return &out, nil
}

// ExistsWithinWindow checks whether a reporter already submitted a report
// against the same target within the given duration (duplicate prevention).
// When reporterID is nil (guest), the check is skipped — guests cannot be
// deduplicated because we have no stable identity for them.
func (r *Repository) ExistsWithinWindow(reporterID *uuid.UUID, targetType string, targetID uuid.UUID, window time.Duration) (bool, error) {
	if reporterID == nil {
		return false, nil
	}
	since := time.Now().Add(-window)
	var count int
	err := r.db.Get(&count, `
		SELECT COUNT(*) FROM reports
		WHERE reporter_id = $1
		  AND target_type = $2
		  AND target_id   = $3
		  AND created_at  >= $4
	`, reporterID, targetType, targetID, since)
	if err != nil {
		return false, err
	}
	return count > 0, nil
}

// List returns a paginated, filtered list of reports for the admin panel.
func (r *Repository) List(f ListReportsFilter) ([]Report, int, error) {
	if f.Limit <= 0 {
		f.Limit = 20
	}
	if f.Page <= 0 {
		f.Page = 1
	}
	offset := (f.Page - 1) * f.Limit

	where := "WHERE 1=1"
	args := []interface{}{}
	argIdx := 1

	if f.Status != "" {
		where += fmt.Sprintf(" AND status = $%d", argIdx)
		args = append(args, f.Status)
		argIdx++
	}
	if f.TargetType != "" {
		where += fmt.Sprintf(" AND target_type = $%d", argIdx)
		args = append(args, f.TargetType)
		argIdx++
	}

	countQuery := "SELECT COUNT(*) FROM reports " + where
	var total int
	if err := r.db.Get(&total, countQuery, args...); err != nil {
		return nil, 0, err
	}

	dataQuery := fmt.Sprintf(
		"SELECT * FROM reports %s ORDER BY created_at DESC LIMIT $%d OFFSET $%d",
		where, argIdx, argIdx+1,
	)
	args = append(args, f.Limit, offset)

	var reports []Report
	if err := r.db.Select(&reports, dataQuery, args...); err != nil {
		return nil, 0, err
	}
	return reports, total, nil
}

// UpdateStatus updates a report's status, review note, reviewer, and reviewed_at timestamp.
func (r *Repository) UpdateStatus(id uuid.UUID, status string, reviewNote string, reviewerID uuid.UUID) (*Report, error) {
	var out Report
	err := r.db.Get(&out, `
		UPDATE reports
		SET status      = $1,
		    review_note = $2,
		    reviewed_by = $3,
		    reviewed_at = NOW()
		WHERE id = $4
		RETURNING *
	`, status, reviewNote, reviewerID, id)
	if err != nil {
		return nil, apperrors.ErrNotFound
	}
	return &out, nil
}
