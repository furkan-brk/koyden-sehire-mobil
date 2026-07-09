package invites

import (
	"crypto/rand"
	"fmt"
	"strings"
	"time"

	"github.com/jmoiron/sqlx"
	apperrors "github.com/koydensehire/backend/pkg/errors"
)

type Repository struct {
	db *sqlx.DB
}

func NewRepository(db *sqlx.DB) *Repository {
	return &Repository{db: db}
}

func (r *Repository) FindByCode(code string) (*InviteCode, error) {
	var ic InviteCode
	err := r.db.Get(&ic, "SELECT * FROM invite_codes WHERE code = $1", strings.ToUpper(code))
	if err != nil {
		return nil, apperrors.ErrNotFound
	}
	return &ic, nil
}

func (r *Repository) FindByOwner(ownerUserID string) ([]InviteCode, error) {
	var codes []InviteCode
	err := r.db.Select(&codes, `
		SELECT * FROM invite_codes WHERE owner_user_id = $1 ORDER BY created_at DESC
	`, ownerUserID)
	if err != nil {
		return nil, err
	}
	if codes == nil {
		codes = []InviteCode{}
	}
	return codes, nil
}

// FindInvitationsByOwner returns every invitation made with the owner's codes,
// joined with the applicant's name for display in the farmer's invite list.
func (r *Repository) FindInvitationsByOwner(ownerUserID string) ([]InvitedRow, error) {
	var rows []InvitedRow
	err := r.db.Select(&rows, `
		SELECT i.invite_code_id, fa.full_name, i.status, i.created_at
		FROM invitations i
		JOIN invite_codes ic ON ic.id = i.invite_code_id
		LEFT JOIN farmer_applications fa ON fa.id = i.application_id
		WHERE ic.owner_user_id = $1
		ORDER BY i.created_at DESC
	`, ownerUserID)
	if err != nil {
		return nil, err
	}
	if rows == nil {
		rows = []InvitedRow{}
	}
	return rows, nil
}

func (r *Repository) IncrementUsed(id string) error {
	_, err := r.db.Exec(`
		UPDATE invite_codes SET used_count = used_count + 1, updated_at = NOW()
		WHERE id = $1
	`, id)
	return err
}

func (r *Repository) CreateInvitation(codeID, inviterID string, appID *string) (*Invitation, error) {
	var inv Invitation
	err := r.db.Get(&inv, `
		INSERT INTO invitations (invite_code_id, inviter_user_id, application_id, status)
		VALUES ($1, $2, $3, 'submitted')
		RETURNING *
	`, codeID, inviterID, appID)
	return &inv, err
}

func (r *Repository) UpdateInvitationByCode(inviteCodeID, status string) error {
	_, err := r.db.Exec(`
		UPDATE invitations SET status = $1, updated_at = NOW()
		WHERE invite_code_id = $2
	`, status, inviteCodeID)
	return err
}

func (r *Repository) UpdateInvitationByApp(applicationID, status string) error {
	_, err := r.db.Exec(`
		UPDATE invitations SET status = $1, updated_at = NOW()
		WHERE application_id = $2
	`, status, applicationID)
	return err
}

func (r *Repository) GenerateUniqueCode() (string, error) {
	const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

	for attempt := 0; attempt < 10; attempt++ {
		b := make([]byte, 6)
		if _, err := rand.Read(b); err != nil {
			return "", fmt.Errorf("generating random bytes: %w", err)
		}
		for i := range b {
			b[i] = chars[int(b[i])%len(chars)]
		}
		code := "KYS-" + string(b)

		var exists bool
		r.db.Get(&exists, "SELECT EXISTS(SELECT 1 FROM invite_codes WHERE code = $1)", code)
		if !exists {
			return code, nil
		}
	}
	return "", apperrors.ErrInternal
}

func (r *Repository) CreateCode(ownerUserID, ownerType, code string, maxUses int) (*InviteCode, error) {
	var ic InviteCode
	err := r.db.Get(&ic, `
		INSERT INTO invite_codes (code, owner_user_id, owner_type, max_uses)
		VALUES ($1, $2, $3, $4)
		RETURNING *
	`, code, ownerUserID, ownerType, maxUses)
	return &ic, err
}

func (r *Repository) IsCodeValid(ic *InviteCode) bool {
	if !ic.IsActive {
		return false
	}
	if ic.UsedCount >= ic.MaxUses {
		return false
	}
	if ic.ExpiresAt != nil && ic.ExpiresAt.Before(time.Now()) {
		return false
	}
	return true
}
