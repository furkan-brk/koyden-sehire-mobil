package audit

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/jmoiron/sqlx"
)

// Action loglanacak admin aksiyonunu temsil eder.
type Action string

const (
	ActionApplicationApproved       Action = "APPLICATION_APPROVED"
	ActionApplicationRejected       Action = "APPLICATION_REJECTED"
	ActionApplicationVideoRequested Action = "APPLICATION_VIDEO_REQUESTED"

	ActionProductApproved Action = "PRODUCT_APPROVED"
	ActionProductRejected Action = "PRODUCT_REJECTED"
	ActionProductHidden   Action = "PRODUCT_HIDDEN"
	ActionProductDeleted  Action = "PRODUCT_DELETED"

	ActionFarmerSuspended          Action = "FARMER_SUSPENDED"
	ActionFarmerReactivated        Action = "FARMER_REACTIVATED"
	ActionFarmerFoundingSet        Action = "FARMER_FOUNDING_SET"
	ActionFarmerInviteQuotaUpdated Action = "FARMER_INVITE_QUOTA_UPDATED"

	ActionCategoryCreated Action = "CATEGORY_CREATED"
	ActionCategoryUpdated Action = "CATEGORY_UPDATED"
	ActionCategoryDeleted Action = "CATEGORY_DELETED"
)

// TargetType etkilenen kaynak tipini belirtir.
type TargetType string

const (
	TargetApplication TargetType = "application"
	TargetProduct     TargetType = "product"
	TargetFarmer      TargetType = "farmer"
	TargetCategory    TargetType = "category"
)

// Entry tek bir audit log kaydını temsil eder.
type Entry struct {
	ID             string     `db:"id"              json:"id"`
	AdminID        string     `db:"admin_id"        json:"admin_id"`
	Action         Action     `db:"action"          json:"action"`
	TargetType     TargetType `db:"target_type"     json:"target_type"`
	TargetID       string     `db:"target_id"       json:"target_id"`
	TargetSnapshot *string    `db:"target_snapshot" json:"target_snapshot,omitempty"`
	Reason         *string    `db:"reason"          json:"reason,omitempty"`
	Metadata       *string    `db:"metadata"        json:"metadata,omitempty"`
	CreatedAt      time.Time  `db:"created_at"      json:"created_at"`
	AdminFullName  *string    `db:"admin_full_name" json:"admin_full_name,omitempty"`
}

// CreateParams yeni log kaydı oluştururken kullanılır.
type CreateParams struct {
	AdminID        string
	Action         Action
	TargetType     TargetType
	TargetID       string
	TargetSnapshot any // JSON'a serileştirilir; nil geçilebilir
	Reason         *string
	Metadata       map[string]any
}

// ListFilter listeleme sorgusunda kullanılır.
type ListFilter struct {
	AdminID    string
	Action     Action
	TargetType TargetType
	TargetID   string
	DateFrom   *time.Time
	DateTo     *time.Time
	Page       int
	Limit      int
}

// Repository audit log veri erişim katmanı.
// Audit loglar immutable'dır — Update/Delete metodları kasıtlı olarak yok.
type Repository struct {
	db *sqlx.DB
}

func NewRepository(db *sqlx.DB) *Repository {
	return &Repository{db: db}
}

// Create yeni bir audit log satırı ekler.
// Hata iş akışını kesmemesi için goroutine içinde çağrılması önerilir.
func (r *Repository) Create(ctx context.Context, p CreateParams) error {
	snapshotJSON, err := marshalNullable(p.TargetSnapshot)
	if err != nil {
		return err
	}
	metaJSON, err := marshalNullable(p.Metadata)
	if err != nil {
		return err
	}

	_, err = r.db.ExecContext(ctx, `
		INSERT INTO admin_audit_logs
			(admin_id, action, target_type, target_id,
			 target_snapshot, reason, metadata)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`, p.AdminID, p.Action, p.TargetType, p.TargetID,
		snapshotJSON, p.Reason, metaJSON)
	return err
}

// List filtrelenebilir sayfalı log listesi döner.
func (r *Repository) List(ctx context.Context, f ListFilter) ([]Entry, int, error) {
	where := []string{"1=1"}
	args := []any{}
	idx := 1

	add := func(cond string, val any) {
		where = append(where, fmt.Sprintf(cond, idx))
		args = append(args, val)
		idx++
	}

	if f.AdminID != "" {
		add("aal.admin_id = $%d", f.AdminID)
	}
	if f.Action != "" {
		add("aal.action = $%d", string(f.Action))
	}
	if f.TargetType != "" {
		add("aal.target_type = $%d", string(f.TargetType))
	}
	if f.TargetID != "" {
		add("aal.target_id = $%d", f.TargetID)
	}
	if f.DateFrom != nil {
		add("aal.created_at >= $%d", *f.DateFrom)
	}
	if f.DateTo != nil {
		add("aal.created_at <= $%d", *f.DateTo)
	}

	wc := strings.Join(where, " AND ")

	var total int
	if err := r.db.GetContext(ctx, &total,
		fmt.Sprintf(`SELECT COUNT(*) FROM admin_audit_logs aal WHERE %s`, wc),
		args...); err != nil {
		return nil, 0, err
	}

	if f.Limit < 1 || f.Limit > 100 {
		f.Limit = 20
	}
	if f.Page < 1 {
		f.Page = 1
	}

	args = append(args, f.Limit, (f.Page-1)*f.Limit)
	rows, err := r.db.QueryxContext(ctx, fmt.Sprintf(`
		SELECT aal.id, aal.admin_id, aal.action, aal.target_type, aal.target_id,
		       aal.target_snapshot, aal.reason, aal.metadata, aal.created_at,
		       u.full_name AS admin_full_name
		FROM admin_audit_logs aal
		JOIN users u ON u.id = aal.admin_id
		WHERE %s
		ORDER BY aal.created_at DESC
		LIMIT $%d OFFSET $%d
	`, wc, idx, idx+1), args...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var entries []Entry
	for rows.Next() {
		var e Entry
		if err := rows.StructScan(&e); err != nil {
			return nil, 0, err
		}
		entries = append(entries, e)
	}
	return entries, total, nil
}

func marshalNullable(v any) (*string, error) {
	if v == nil {
		return nil, nil
	}
	b, err := json.Marshal(v)
	if err != nil {
		return nil, err
	}
	s := string(b)
	return &s, nil
}
