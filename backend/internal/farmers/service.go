package farmers

type Service struct {
	repo *Repository
}

func NewService(repo *Repository) *Service {
	return &Service{repo: repo}
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

func (s *Service) List(page, limit int) ([]FarmerDetail, int, error) {
	return s.repo.ListAdmin(page, limit)
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
