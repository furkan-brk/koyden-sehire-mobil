package device_tokens

import "github.com/jmoiron/sqlx"

type Repository struct {
	db *sqlx.DB
}

func NewRepository(db *sqlx.DB) *Repository {
	return &Repository{db: db}
}

// Upsert stores the token for userID, first removing it from any other user
// so a device can only belong to one account at a time.
func (r *Repository) Upsert(userID, token, platform string) error {
	_, err := r.db.Exec(
		"DELETE FROM device_tokens WHERE token = $1 AND user_id != $2",
		token, userID,
	)
	if err != nil {
		return err
	}
	_, err = r.db.Exec(`
		INSERT INTO device_tokens (user_id, token, platform)
		VALUES ($1, $2, $3)
		ON CONFLICT (user_id, token)
		DO UPDATE SET platform = EXCLUDED.platform, updated_at = NOW()
	`, userID, token, platform)
	return err
}

func (r *Repository) Delete(userID, token string) error {
	_, err := r.db.Exec(
		"DELETE FROM device_tokens WHERE user_id = $1 AND token = $2",
		userID, token,
	)
	return err
}

// DeleteStale removes a specific token regardless of user (called when FCM
// reports the token is no longer registered).
func (r *Repository) DeleteStale(token string) error {
	_, err := r.db.Exec("DELETE FROM device_tokens WHERE token = $1", token)
	return err
}

// GetByUser returns all FCM tokens for a user.
func (r *Repository) GetByUser(userID string) ([]string, error) {
	var tokens []string
	err := r.db.Select(&tokens, "SELECT token FROM device_tokens WHERE user_id = $1", userID)
	return tokens, err
}

// GetFarmerFanTokens returns FCM tokens of all customers who have favorited
// at least one product from the given farmer.
func (r *Repository) GetFarmerFanTokens(farmerID string) ([]string, error) {
	var tokens []string
	err := r.db.Select(&tokens, `
		SELECT DISTINCT dt.token
		FROM device_tokens dt
		JOIN favorites f ON f.user_id = dt.user_id
		JOIN products p ON p.id = f.product_id
		WHERE p.farmer_id = $1
	`, farmerID)
	return tokens, err
}
