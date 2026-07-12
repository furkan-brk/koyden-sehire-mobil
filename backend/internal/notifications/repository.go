package notifications

import (
	"github.com/jmoiron/sqlx"
)

type NotifRepository struct {
	db *sqlx.DB
}

func NewNotifRepository(db *sqlx.DB) *NotifRepository {
	return &NotifRepository{db: db}
}

func (r *NotifRepository) Create(n Notification) error {
	data := string(n.Data)
	if data == "" {
		data = "{}"
	}
	_, err := r.db.Exec(
		`INSERT INTO notifications (user_id, type, title, body, data)
		 VALUES ($1, $2, $3, $4, $5::jsonb)`,
		n.UserID, n.Type, n.Title, n.Body, data,
	)
	return err
}

// ListByUser returns paginated notifications for a user, newest first.
func (r *NotifRepository) ListByUser(userID string, page, limit int) ([]Notification, int, error) {
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 50 {
		limit = 20
	}
	offset := (page - 1) * limit

	var total int
	if err := r.db.Get(&total,
		`SELECT COUNT(*) FROM notifications WHERE user_id = $1`, userID,
	); err != nil {
		return nil, 0, err
	}

	var items []Notification
	if err := r.db.Select(&items,
		`SELECT id, user_id, type, title, body, data, is_read, created_at
		 FROM notifications
		 WHERE user_id = $1
		 ORDER BY created_at DESC
		 LIMIT $2 OFFSET $3`,
		userID, limit, offset,
	); err != nil {
		return nil, 0, err
	}
	return items, total, nil
}

// UnreadCount returns the number of unread notifications for a user.
func (r *NotifRepository) UnreadCount(userID string) (int, error) {
	var count int
	err := r.db.Get(&count,
		`SELECT COUNT(*) FROM notifications WHERE user_id = $1 AND is_read = FALSE`,
		userID,
	)
	return count, err
}

// MarkRead marks a single notification as read (only if it belongs to the user).
func (r *NotifRepository) MarkRead(id, userID string) error {
	_, err := r.db.Exec(
		`UPDATE notifications SET is_read = TRUE WHERE id = $1 AND user_id = $2`,
		id, userID,
	)
	return err
}

// MarkAllRead marks all notifications of a user as read.
func (r *NotifRepository) MarkAllRead(userID string) error {
	_, err := r.db.Exec(
		`UPDATE notifications SET is_read = TRUE WHERE user_id = $1 AND is_read = FALSE`,
		userID,
	)
	return err
}
