package invites

import "time"

type ValidateRequest struct {
	Code string `query:"code" json:"code"`
}

// InvitedRow is one invitation made with a code, joined with the applicant's name.
type InvitedRow struct {
	InviteCodeID string    `db:"invite_code_id" json:"-"`
	FullName     *string   `db:"full_name" json:"full_name"`
	Status       string    `db:"status" json:"status"`
	CreatedAt    time.Time `db:"created_at" json:"created_at"`
}

// FarmerInviteItem is an invite code plus the invitations made with it,
// matching the shape the mobile app's "Davetlerim" screen parses.
type FarmerInviteItem struct {
	InviteCode
	Invitations []InvitedRow `json:"invitations"`
}

type ValidateResponse struct {
	Valid     bool   `json:"valid"`
	Code      string `json:"code"`
	MaxUses   int    `json:"max_uses"`
	UsedCount int    `json:"used_count"`
	Remaining int    `json:"remaining"`
}
