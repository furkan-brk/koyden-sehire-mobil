package device_tokens

import "time"

type DeviceToken struct {
	ID        string    `db:"id"         json:"id"`
	UserID    string    `db:"user_id"    json:"user_id"`
	Token     string    `db:"token"      json:"token"`
	Platform  string    `db:"platform"   json:"platform"`
	CreatedAt time.Time `db:"created_at" json:"created_at"`
	UpdatedAt time.Time `db:"updated_at" json:"updated_at"`
}
