package notifications

import (
	"encoding/json"
	"time"
)

type Notification struct {
	ID        string          `db:"id"         json:"id"`
	UserID    string          `db:"user_id"    json:"user_id"`
	Type      string          `db:"type"       json:"type"`
	Title     string          `db:"title"      json:"title"`
	Body      string          `db:"body"       json:"body"`
	Data      json.RawMessage `db:"data"       json:"data"`
	IsRead    bool            `db:"is_read"    json:"is_read"`
	CreatedAt time.Time       `db:"created_at" json:"created_at"`
}

// Notification type constants
const (
	TypeProductApproved = "product_approved"
	TypeProductRejected = "product_rejected"
	TypeNewProduct      = "new_product"
	TypeAnnouncement    = "announcement"

	TypeApplicationApproved = "application_approved"
	TypeApplicationRejected = "application_rejected"
	TypeAccountSuspended    = "account_suspended"
	TypeAccountReactivated  = "account_reactivated"
	TypeNewCustomer         = "new_customer"
	TypeProductHidden       = "product_hidden"
	TypeInviteUsed          = "invite_used"
)
