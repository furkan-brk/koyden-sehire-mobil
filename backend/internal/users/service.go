package users

import (
	"strings"

	apperrors "github.com/koydensehire/backend/pkg/errors"
)

type Service struct {
	repo *Repository
}

func NewService(repo *Repository) *Service {
	return &Service{repo: repo}
}

func (s *Service) GetProfile(userID string) (*User, *FarmerProfile, error) {
	user, err := s.repo.GetByID(userID)
	if err != nil {
		return nil, nil, err
	}
	profile, err := s.repo.GetFarmerProfile(userID)
	if err != nil {
		return nil, nil, apperrors.ErrNotFound
	}
	return user, profile, nil
}

func (s *Service) UpdateProfile(userID string, req *UpdateProfileRequest) error {
	return s.repo.UpdateFarmerProfile(userID, req)
}

func (s *Service) GetCustomerProfile(userID string) (*CustomerProfileResponse, error) {
	user, err := s.repo.GetByID(userID)
	if err != nil {
		return nil, err
	}
	return &CustomerProfileResponse{
		ID:        user.ID,
		FullName:  user.FullName,
		Phone:     user.Phone,
		Email:     user.Email,
		CreatedAt: user.CreatedAt,
	}, nil
}

func (s *Service) UpdateCustomerProfile(userID string, req *UpdateCustomerProfileRequest) (*CustomerProfileResponse, error) {
	if err := s.repo.UpdateCustomerProfile(userID, req); err != nil {
		if strings.Contains(err.Error(), "unique") || strings.Contains(err.Error(), "duplicate") {
			return nil, apperrors.New("EMAIL_CONFLICT", "Bu e-posta adresi zaten kullanımda", 409)
		}
		return nil, apperrors.ErrInternal
	}
	return s.GetCustomerProfile(userID)
}
