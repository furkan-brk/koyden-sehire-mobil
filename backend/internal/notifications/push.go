package notifications

import (
	"log"

	"github.com/koydensehire/backend/internal/device_tokens"
)

// PushService sends FCM push notifications triggered by product events
// and persists each notification to the DB via NotifRepository.
type PushService struct {
	tokenRepo  *device_tokens.Repository
	notifRepo  *NotifRepository // nil = no persistence
	fcm        *FCMClient       // nil = disabled
}

func NewPushService(tokenRepo *device_tokens.Repository, notifRepo *NotifRepository, fcm *FCMClient) *PushService {
	return &PushService{tokenRepo: tokenRepo, notifRepo: notifRepo, fcm: fcm}
}

// ProductApproved notifies the farmer and all customers who favorited that farmer.
func (s *PushService) ProductApproved(farmerID, productTitle string) {
	s.sendToUser(farmerID,
		TypeProductApproved,
		"Ürününüz Onaylandı ✓",
		productTitle+" artık alıcılara görünüyor.",
		map[string]string{"type": TypeProductApproved},
	)
	s.sendToFarmerFans(farmerID,
		"Yeni Ürün",
		"Takip ettiğiniz üretici yeni ürün ekledi: "+productTitle,
		map[string]string{"type": TypeNewProduct, "farmer_id": farmerID},
	)
}

// ProductRejected notifies only the farmer.
func (s *PushService) ProductRejected(farmerID, productTitle string) {
	s.sendToUser(farmerID,
		TypeProductRejected,
		"Ürün İncelemesi",
		productTitle+" onaylanmadı. Detaylar için uygulamayı açın.",
		map[string]string{"type": TypeProductRejected},
	)
}

func (s *PushService) sendToUser(userID, notifType, title, body string, data map[string]string) {
	// Persist notification regardless of FCM state
	s.saveNotif(userID, notifType, title, body)

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
	// Persist for each fan user — GetFarmerFanTokens returns tokens, we need user IDs
	// For now fan notifications are FCM-only (no per-user persistence without user IDs)
	s.fanOut(tokens, title, body, data)
}

func (s *PushService) saveNotif(userID, notifType, title, body string) {
	if s.notifRepo == nil {
		return
	}
	if err := s.notifRepo.Create(Notification{
		UserID: userID,
		Type:   notifType,
		Title:  title,
		Body:   body,
	}); err != nil {
		log.Printf("[PUSH] failed to persist notification for user=%s: %v", userID, err)
	}
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

