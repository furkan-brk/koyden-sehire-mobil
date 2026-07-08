package admin

import (
	"github.com/jmoiron/sqlx"
)

type Repository struct {
	db *sqlx.DB
}

func NewRepository(db *sqlx.DB) *Repository {
	return &Repository{db: db}
}

func (r *Repository) GetDashboardStats() (*DashboardStats, error) {
	var stats DashboardStats

	r.db.Get(&stats.TotalFarmers, "SELECT COUNT(*) FROM users WHERE role = 'farmer'")
	r.db.Get(&stats.ActiveFarmers, "SELECT COUNT(*) FROM users WHERE role = 'farmer' AND status = 'active'")
	r.db.Get(&stats.SuspendedFarmers, "SELECT COUNT(*) FROM users WHERE role = 'farmer' AND status = 'suspended'")
	r.db.Get(&stats.PendingApplications, "SELECT COUNT(*) FROM farmer_applications WHERE status IN ('pending', 'needs_video')")
	r.db.Get(&stats.TodayApplications, "SELECT COUNT(*) FROM farmer_applications WHERE created_at::date = CURRENT_DATE")
	r.db.Get(&stats.PendingProducts, "SELECT COUNT(*) FROM products WHERE status = 'pending'")
	r.db.Get(&stats.ActiveProducts, "SELECT COUNT(*) FROM products WHERE status = 'active'")
	r.db.Get(&stats.TotalProducts, "SELECT COUNT(*) FROM products")

	return &stats, nil
}

func (r *Repository) GetApplicationsByDay() ([]ChartPoint, error) {
	rows, err := r.db.Queryx(`
		SELECT to_char(created_at::date, 'YYYY-MM-DD') AS name, COUNT(*)::float8 AS value
		FROM farmer_applications
		WHERE created_at >= NOW() - INTERVAL '14 days'
		GROUP BY created_at::date
		ORDER BY created_at::date
	`)
	if err != nil {
		return []ChartPoint{}, err
	}
	defer rows.Close()
	out := []ChartPoint{}
	for rows.Next() {
		var p ChartPoint
		if err := rows.StructScan(&p); err != nil {
			return out, err
		}
		out = append(out, p)
	}
	return out, nil
}

func (r *Repository) GetProductsByCategory() ([]ChartPoint, error) {
	rows, err := r.db.Queryx(`
		WITH RECURSIVE cat_tree AS (
			SELECT id, id AS root_id, name AS root_name
			FROM categories
			WHERE parent_id IS NULL
			UNION ALL
			SELECT c.id, t.root_id, t.root_name
			FROM categories c
			JOIN cat_tree t ON c.parent_id = t.id
		)
		SELECT t.root_name AS name, COUNT(p.id)::float8 AS value
		FROM cat_tree t
		LEFT JOIN products p ON p.category_id = t.id AND p.status = 'active'
		GROUP BY t.root_id, t.root_name
		ORDER BY value DESC
		LIMIT 10
	`)
	if err != nil {
		return []ChartPoint{}, err
	}
	defer rows.Close()
	out := []ChartPoint{}
	for rows.Next() {
		var p ChartPoint
		if err := rows.StructScan(&p); err != nil {
			return out, err
		}
		out = append(out, p)
	}
	return out, nil
}

func (r *Repository) GetProducersByCity() ([]ChartPoint, error) {
	rows, err := r.db.Queryx(`
		SELECT fp.city AS name, COUNT(*)::float8 AS value
		FROM farmer_profiles fp
		JOIN users u ON u.id = fp.user_id
		WHERE u.status = 'active'
		GROUP BY fp.city
		ORDER BY value DESC
		LIMIT 10
	`)
	if err != nil {
		return []ChartPoint{}, err
	}
	defer rows.Close()
	out := []ChartPoint{}
	for rows.Next() {
		var p ChartPoint
		if err := rows.StructScan(&p); err != nil {
			return out, err
		}
		out = append(out, p)
	}
	return out, nil
}

func (r *Repository) GetCityDensity() ([]CityDensityPoint, error) {
	rows, err := r.db.Queryx(`
		SELECT fp.city AS city, COUNT(*) AS farmer_count
		FROM farmer_profiles fp
		JOIN users u ON u.id = fp.user_id
		WHERE u.status = 'active'
		GROUP BY fp.city
		ORDER BY farmer_count DESC
	`)
	if err != nil {
		return []CityDensityPoint{}, err
	}
	defer rows.Close()
	out := []CityDensityPoint{}
	for rows.Next() {
		var p CityDensityPoint
		if err := rows.StructScan(&p); err != nil {
			return out, err
		}
		out = append(out, p)
	}
	return out, nil
}

// GetInviteNetwork returns the invite tree rooted at admin invite codes.
// Each node represents an invite code and links to the farmers it produced.
func (r *Repository) GetInviteNetwork() (*InviteNetworkNode, error) {
	type row struct {
		ID         string  `db:"id"`
		Code       string  `db:"code"`
		OwnerType  string  `db:"owner_type"`
		OwnerID    *string `db:"owner_user_id"`
		OwnerName  *string `db:"owner_name"`
		UsedCount  int     `db:"used_count"`
		MaxUses    int     `db:"max_uses"`
	}
	rows, err := r.db.Queryx(`
		SELECT ic.id, ic.code, ic.owner_type, ic.owner_user_id,
		       COALESCE(fp.display_name, u.full_name) AS owner_name,
		       ic.used_count, ic.max_uses
		FROM invite_codes ic
		LEFT JOIN users u ON u.id = ic.owner_user_id
		LEFT JOIN farmer_profiles fp ON fp.user_id = ic.owner_user_id
		WHERE ic.is_active = true
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	codes := []row{}
	for rows.Next() {
		var r row
		if err := rows.StructScan(&r); err != nil {
			return nil, err
		}
		codes = append(codes, r)
	}

	byOwner := map[string][]InviteNetworkNode{}
	roots := []InviteNetworkNode{}
	for _, c := range codes {
		name := ""
		if c.OwnerName != nil {
			name = *c.OwnerName
		}
		node := InviteNetworkNode{
			ID:         c.ID,
			Name:       name,
			InviteCode: c.Code,
			UsedCount:  c.UsedCount,
			MaxUses:    c.MaxUses,
			Children:   []InviteNetworkNode{},
		}
		if c.OwnerType == "admin" || c.OwnerID == nil {
			roots = append(roots, node)
		} else {
			byOwner[*c.OwnerID] = append(byOwner[*c.OwnerID], node)
		}
	}

	return &InviteNetworkNode{
		ID:       "root",
		Name:     "Köyden Şehre",
		Children: roots,
	}, nil
}
