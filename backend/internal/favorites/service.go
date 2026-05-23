package favorites

import "github.com/koydensehire/backend/internal/products"

type Service struct {
	repo *Repository
}

func NewService(repo *Repository) *Service {
	return &Service{repo: repo}
}

func (s *Service) Add(userID, productID string) error {
	return s.repo.Add(userID, productID)
}

func (s *Service) Remove(userID, productID string) error {
	return s.repo.Remove(userID, productID)
}

func (s *Service) List(userID string) ([]products.PublicProduct, error) {
	return s.repo.ListWithProducts(userID)
}
