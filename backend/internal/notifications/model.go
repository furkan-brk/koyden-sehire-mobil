package notifications

import "time"

type Notification struct {
	ID        string    `db:"id"         json:"id"`
	UserID    string    `db:"user_id"    json:"user_id"`
	Type      string    `db:"type"       json:"type"`
	Title     string    `db:"title"      json:"title"`
	Body      string    `db:"body"       json:"body"`
	IsRead    bool      `db:"is_read"    json:"is_read"`
	CreatedAt time.Time `db:"created_at" json:"created_at"`
}

// Notification type constants
const (
	TypeProductApproved = "product_approved"
	TypeProductRejected = "product_rejected"
	TypeNewProduct      = "new_product"
	TypeAnnouncement    = "announcement"
)
