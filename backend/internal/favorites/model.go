package favorites

import "time"

type Favorite struct {
	UserID    string    `db:"user_id"`
	ProductID string    `db:"product_id"`
	CreatedAt time.Time `db:"created_at"`
}
