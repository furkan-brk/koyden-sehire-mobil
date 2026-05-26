package notifications

import (
	"log"

	"github.com/koydensehire/backend/internal/device_tokens"
)

// PushService sends FCM push notifications triggered by product events.
type PushService struct {
	tokenRepo *device_tokens.Repository
	fcm       *FCMClient // nil = disabled
}

func NewPushService(tokenRepo *device_tokens.Repository, fcm *FCMClient) *PushService {
	return &PushService{tokenRepo: tokenRepo, fcm: fcm}
}

// ProductApproved notifies the farmer and all customers who favorited that farmer.
func (s *PushService) ProductApproved(farmerID, productTitle string) {
	s.sendToUser(farmerID,
		"Ürününüz Onaylandı ✓",
		productTitle+" artık alıcılara görünüyor.",
		map[string]string{"type": "product_approved"},
	)
	s.sendToFarmerFans(farmerID,
		"Yeni Ürün",
		"Takip ettiğiniz üretici yeni ürün ekledi: "+productTitle,
		map[string]string{"type": "new_product", "farmer_id": farmerID},
	)
}

// ProductRejected notifies only the farmer.
func (s *PushService) ProductRejected(farmerID, productTitle string) {
	s.sendToUser(farmerID,
		"Ürün İncelemesi",
		productTitle+" onaylanmadı. Detaylar için uygulamayı açın.",
		map[string]string{"type": "product_rejected"},
	)
}

func (s *PushService) sendToUser(userID, title, body string, data map[string]string) {
	if s.fcm == nil {
		log.Printf("[PUSH-DEV] user=%s title=%q body=%q", userID, title, body)
		return
	}
	tokens, err := s.tokenRepo.GetByUser(userID)
	if err != nil || len(tokens) == 0 {
		return
	}
	s.fanOut(tokens, title, body, data)
}

func (s *PushService) sendToFarmerFans(farmerID, title, body string, data map[string]string) {
	if s.fcm == nil {
		log.Printf("[PUSH-DEV] fans-of=%s title=%q body=%q", farmerID, title, body)
		return
	}
	tokens, err := s.tokenRepo.GetFarmerFanTokens(farmerID)
	if err != nil || len(tokens) == 0 {
		return
	}
	s.fanOut(tokens, title, body, data)
}

func (s *PushService) fanOut(tokens []string, title, body string, data map[string]string) {
	for _, tok := range tokens {
		stale, err := s.fcm.Send(tok, title, body, data)
		if err != nil {
			log.Printf("[PUSH] send error token=%s: %v", tok[:min(8, len(tok))], err)
		}
		if stale {
			_ = s.tokenRepo.DeleteStale(tok)
		}
	}
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
