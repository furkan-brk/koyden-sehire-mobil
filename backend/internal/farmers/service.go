package farmers

import (
	"fmt"

	"github.com/google/uuid"
)

type Service struct {
	repo *Repository
}

func NewService(repo *Repository) *Service {
	return &Service{repo: repo}
}

// GetDashboard aggregates product stats, invite stats, engagement stats
// (views + favourites), recent products, and the last-7-days view series.
func (s *Service) GetDashboard(farmerID uuid.UUID) (*DashboardResponse, error) {
	active, pending, passive, err := s.repo.GetProductStatsByFarmerID(farmerID)
	if err != nil {
		return nil, fmt.Errorf("product stats: %w", err)
	}

	totalQuota, usedQuota, err := s.repo.GetInviteStatsByFarmerID(farmerID)
	if err != nil {
		return nil, fmt.Errorf("invite stats: %w", err)
	}

	recent, err := s.repo.GetRecentProductsByFarmerID(farmerID, 5)
	if err != nil {
		return nil, fmt.Errorf("recent products: %w", err)
	}

	totalViews, weeklyViews, err := s.repo.GetViewStatsByFarmerID(farmerID)
	if err != nil {
		return nil, fmt.Errorf("view stats: %w", err)
	}

	totalFavorites, err := s.repo.GetFavoriteTotalByFarmerID(farmerID)
	if err != nil {
		return nil, fmt.Errorf("favorite stats: %w", err)
	}

	return &DashboardResponse{
		ProductStats: DashboardProductStats{
			Active:  active,
			Pending: pending,
			Passive: passive,
			Total:   active + pending + passive,
		},
		InviteStats: DashboardInviteStats{
			TotalQuota: totalQuota,
			UsedQuota:  usedQuota,
			Remaining:  totalQuota - usedQuota,
		},
		EngagementStats: DashboardEngagementStats{
			TotalViews:     totalViews,
			TotalFavorites: totalFavorites,
		},
		RecentProducts: recent,
		WeeklyViews:    weeklyViews,
	}, nil
}

func (s *Service) GetPublic(id string) (*PublicFarmerDetail, error) {
	return s.repo.GetPublicByID(id)
}

func (s *Service) ListPublic(page, limit int, city, search string) ([]PublicFarmerSummary, int, error) {
	return s.repo.ListPublic(page, limit, city, search)
}

func (s *Service) GetAdminDetail(id string) (*FarmerDetail, error) {
	return s.repo.GetAdminDetail(id)
}

func (s *Service) List(page, limit int, city string) ([]FarmerDetail, int, error) {
	return s.repo.ListAdmin(page, limit, city)
}

func (s *Service) Suspend(id string) error {
	return s.repo.Suspend(id)
}

func (s *Service) Reactivate(id string) error {
	return s.repo.Reactivate(id)
}

func (s *Service) SetFounding(id string, isFounding bool) error {
	return s.repo.SetFounding(id, isFounding)
}

func (s *Service) UpdateInviteQuota(id string, quota int) error {
	return s.repo.UpdateInviteQuota(id, quota)
}
