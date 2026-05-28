package reports

import (
	"time"

	"github.com/google/uuid"
	apperrors "github.com/koydensehire/backend/pkg/errors"
)

const duplicateWindow = 24 * time.Hour

var validReasons = map[string]bool{
	"inappropriate": true,
	"misleading":    true,
	"spam":          true,
	"other":         true,
}

var validTargetTypes = map[string]bool{
	"product": true,
	"farmer":  true,
}

var validReviewStatuses = map[string]bool{
	"reviewed":  true,
	"dismissed": true,
}

type Service struct {
	repo *Repository
}

func NewService(repo *Repository) *Service {
	return &Service{repo: repo}
}

// SubmitReport validates and persists a new report.
// reporterID is nil for guest users.
func (s *Service) SubmitReport(reporterID *uuid.UUID, req *SubmitReportRequest) (*Report, error) {
	if !validTargetTypes[req.TargetType] {
		return nil, apperrors.New("INVALID_TARGET_TYPE", "Geçersiz hedef türü; 'product' veya 'farmer' olmalı", 400)
	}
	if !validReasons[req.Reason] {
		return nil, apperrors.New("INVALID_REASON", "Geçersiz sebep; 'inappropriate', 'misleading', 'spam' veya 'other' olmalı", 400)
	}

	targetID, err := uuid.Parse(req.TargetID)
	if err != nil {
		return nil, apperrors.New("INVALID_TARGET_ID", "Geçersiz hedef ID formatı", 400)
	}

	// Duplicate check — only for authenticated users (guests have no stable ID)
	exists, err := s.repo.ExistsWithinWindow(reporterID, req.TargetType, targetID, duplicateWindow)
	if err != nil {
		return nil, apperrors.ErrInternal
	}
	if exists {
		return nil, apperrors.New("DUPLICATE_REPORT", "Bu içerik için 24 saat içinde zaten bir bildirim gönderdiniz", 409)
	}

	report := &Report{
		ReporterID: reporterID,
		TargetType: req.TargetType,
		TargetID:   targetID,
		Reason:     req.Reason,
		Note:       req.Note,
	}
	return s.repo.Create(report)
}

// ListReports returns paginated reports for the admin panel.
func (s *Service) ListReports(f ListReportsFilter) ([]Report, int, error) {
	return s.repo.List(f)
}

// ReviewReport transitions a report to reviewed or dismissed.
// Only admin callers should reach this method (enforced by route middleware).
func (s *Service) ReviewReport(reportID string, reviewerID string, req *ReviewReportRequest) (*Report, error) {
	if !validReviewStatuses[req.Status] {
		return nil, apperrors.New("INVALID_STATUS", "Geçersiz durum; 'reviewed' veya 'dismissed' olmalı", 400)
	}

	rid, err := uuid.Parse(reportID)
	if err != nil {
		return nil, apperrors.New("INVALID_REPORT_ID", "Geçersiz rapor ID formatı", 400)
	}
	rvid, err := uuid.Parse(reviewerID)
	if err != nil {
		return nil, apperrors.ErrInternal
	}

	return s.repo.UpdateStatus(rid, req.Status, req.ReviewNote, rvid)
}
