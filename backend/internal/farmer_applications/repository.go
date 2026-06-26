package farmer_applications

import (
	"encoding/json"

	"github.com/jmoiron/sqlx"
	apperrors "github.com/koydensehire/backend/pkg/errors"
)

type Repository struct {
	db *sqlx.DB
}

func NewRepository(db *sqlx.DB) *Repository {
	return &Repository{db: db}
}

func (r *Repository) Create(req *CreateApplicationRequest, passwordHash string, inviteCodeID, referredByUserID *string, source string) (*FarmerApplication, error) {
	categoriesJSON, _ := json.Marshal(req.ProductCategories)
	docsJSON, _ := json.Marshal(req.DocumentURLs)

	var videoStatus string
	if req.ApplicationVideoKey != nil {
		videoStatus = "uploaded"
	} else {
		videoStatus = "missing"
	}

	var app FarmerApplication
	err := r.db.Get(&app, `
		INSERT INTO farmer_applications (
			full_name, phone, email, password_hash, phone_verified,
			business_name, producer_type, city, district, village, address, bio,
			product_categories, product_examples, production_place_type,
			document_urls, application_note,
			application_video_key, application_video_status,
			invite_code_id, referred_by_user_id, application_source,
			kvkk_accepted, platform_terms_accepted,
			declares_own_production, declares_accurate_location, declares_not_intermediary,
			status
		) VALUES (
			$1,$2,$3,$4,true,
			$5,$6,$7,$8,$9,$10,$11,
			$12,$13,$14,
			$15,$16,
			$17,$18,
			$19,$20,$21,
			$22,$23,
			$24,$25,$26,
			'pending'
		) RETURNING *
	`,
		req.FullName, req.Phone, req.Email, passwordHash,
		req.BusinessName, req.ProducerType, req.City, req.District, req.Village, req.Address, req.Bio,
		categoriesJSON, req.ProductExamples, req.ProductionPlaceType,
		docsJSON, req.ApplicationNote,
		req.ApplicationVideoKey, videoStatus,
		inviteCodeID, referredByUserID, source,
		req.KvkkAccepted, req.PlatformTermsAccepted,
		req.DeclaresOwnProduction, req.DeclaresAccurateLocation, req.DeclaresNotIntermediary,
	)
	return &app, err
}

func (r *Repository) GetByID(id string) (*FarmerApplication, error) {
	var app FarmerApplication
	err := r.db.Get(&app, "SELECT * FROM farmer_applications WHERE id = $1", id)
	if err != nil {
		return nil, apperrors.ErrNotFound
	}
	return &app, nil
}

func (r *Repository) List(page, limit int, status string) ([]FarmerApplication, int, error) {
	args := []interface{}{}
	where := ""
	if status != "" {
		where = "WHERE status = $1"
		args = append(args, status)
	}

	var total int
	countQuery := "SELECT COUNT(*) FROM farmer_applications " + where
	if err := r.db.Get(&total, countQuery, args...); err != nil {
		return nil, 0, err
	}

	offset := (page - 1) * limit
	if status != "" {
		args = append(args, limit, offset)
		var apps []FarmerApplication
		err := r.db.Select(&apps, `
			SELECT * FROM farmer_applications WHERE status = $1
			ORDER BY created_at DESC LIMIT $2 OFFSET $3
		`, args...)
		if apps == nil {
			apps = []FarmerApplication{}
		}
		return apps, total, err
	}

	args = append(args, limit, offset)
	var apps []FarmerApplication
	err := r.db.Select(&apps, `
		SELECT * FROM farmer_applications ORDER BY created_at DESC LIMIT $1 OFFSET $2
	`, limit, offset)
	if apps == nil {
		apps = []FarmerApplication{}
	}
	return apps, total, err
}

func (r *Repository) Approve(id, reviewedBy string) error {
	_, err := r.db.Exec(`
		UPDATE farmer_applications
		SET status = 'approved', reviewed_by = $1, reviewed_at = NOW(), updated_at = NOW()
		WHERE id = $2
	`, reviewedBy, id)
	return err
}

func (r *Repository) Reject(id, reviewedBy, adminNote, rejectionReason string) error {
	_, err := r.db.Exec(`
		UPDATE farmer_applications
		SET status = 'rejected', reviewed_by = $1, reviewed_at = NOW(),
		    admin_note = $2, rejection_reason = $3, updated_at = NOW()
		WHERE id = $4
	`, reviewedBy, adminNote, rejectionReason, id)
	return err
}

func (r *Repository) RequestVideo(id, reviewedBy string) error {
	_, err := r.db.Exec(`
		UPDATE farmer_applications
		SET status = 'needs_video', reviewed_by = $1,
		    application_video_status = 'requested',
		    video_requested_at = NOW(), updated_at = NOW()
		WHERE id = $2
	`, reviewedBy, id)
	return err
}

func (r *Repository) PhoneExistsActive(phone string) (bool, error) {
	var exists bool
	err := r.db.Get(&exists, `
		SELECT EXISTS(
			SELECT 1 FROM farmer_applications
			WHERE phone = $1 AND status IN ('pending', 'needs_video')
		)
	`, phone)
	return exists, err
}

func (r *Repository) PhoneExistsInUsers(phone string) (bool, error) {
	var exists bool
	err := r.db.Get(&exists, "SELECT EXISTS(SELECT 1 FROM users WHERE phone = $1)", phone)
	return exists, err
}
