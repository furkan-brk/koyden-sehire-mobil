package farmers

import (
	"time"

	"github.com/google/uuid"
)

// DashboardResponse is the response body for GET /farmer/dashboard.
type DashboardResponse struct {
	ProductStats   DashboardProductStats `json:"product_stats"`
	InviteStats    DashboardInviteStats  `json:"invite_stats"`
	RecentProducts []RecentProductItem   `json:"recent_products"`
	WeeklyViews    []DailyCount          `json:"weekly_views"`
}

type DashboardProductStats struct {
	Active  int `json:"active"`
	Pending int `json:"pending"`
	Passive int `json:"passive"`
	Total   int `json:"total"`
}

type DashboardInviteStats struct {
	TotalQuota int `json:"total_quota"`
	UsedQuota  int `json:"used_quota"`
	Remaining  int `json:"remaining"`
}

type RecentProductItem struct {
	ID        uuid.UUID `json:"id"`
	Name      string    `json:"name"`
	Title     string    `json:"title"`
	Price     float64   `json:"price"`
	Unit      string    `json:"unit"`
	Status    string    `json:"status"`
	CreatedAt time.Time `json:"created_at"`
	ImageURL  string    `json:"image_url"`
}

type DailyCount struct {
	Date  string `json:"date"`  // "2006-01-02"
	Count int    `json:"count"`
}
