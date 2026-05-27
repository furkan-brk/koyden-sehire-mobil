package notifications

import (
	"context"
	"log"
	"time"

	"github.com/koydensehire/backend/internal/device_tokens"
	"github.com/koydensehire/backend/pkg/sms"
)

// PushService sends FCM push notifications triggered by product events
// and persists each notification to the DB via NotifRepository.
type PushService struct {
	tokenRepo  *device_tokens.Repository
	notifRepo  *NotifRepository // nil = no persistence
	fcm        *FCMClient       // nil = disabled
	sms        sms.Provider     // nil = no SMS
}

func NewPushService(tokenRepo *device_tokens.Repository, notifRepo *NotifRepository, fcm *FCMClient, smsProvider sms.Provider) *PushService {
	return &PushService{tokenRepo: tokenRepo, notifRepo: notifRepo, fcm: fcm, sms: smsProvider}
}

// isQuietHour returns true between 22:00–08:00 Istanbul time.
// Critical notifications (application results, account changes) bypass this.
// Marketing-type notifications (new_product fan-out) should respect it.
func isQuietHour() bool {
	loc, _ := time.LoadLocation("Europe/Istanbul")
	h := time.Now().In(loc).Hour()
	return h >= 22 || h < 8
}

// ProductApproved notifies the farmer and all customers who favorited that farmer.
func (s *PushService) ProductApproved(farmerID, productTitle string) {
	s.sendToUser(farmerID,
		TypeProductApproved,
		"Ürününüz Onaylandı",
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
	if isQuietHour() {
		log.Printf("[PUSH] quiet hours — skipping fan-out push for farmer=%s", farmerID)
		return
	}
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

// ApplicationApproved notifies the farmer that their application was approved via DB notification and SMS.
func (s *PushService) ApplicationApproved(_ context.Context, userID, name, phone string) error {
	s.sendToUser(userID,
		TypeApplicationApproved,
		"Başvurunuz Onaylandı",
		"Köyden Şehire'ye hoş geldiniz! Başvurunuz onaylandı.",
		map[string]string{"type": TypeApplicationApproved},
	)
	if s.sms != nil && phone != "" {
		if err := s.sms.Send(phone, "Köyden Şehire'ye hoş geldiniz! Başvurunuz onaylandı."); err != nil {
			log.Printf("[PUSH] SMS send failed for ApplicationApproved user=%s: %v", userID, err)
		}
	}
	return nil
}

// ApplicationRejected notifies the applicant that their application was rejected.
// If userID is empty (no account was created), only SMS is sent.
func (s *PushService) ApplicationRejected(_ context.Context, userID, name, phone, reason string) error {
	body := "Başvurunuz değerlendirilemedi. Sebep: " + reason + "."
	if userID != "" {
		s.sendToUser(userID,
			TypeApplicationRejected,
			"Başvuru Sonucu",
			body,
			map[string]string{"type": TypeApplicationRejected},
		)
	}
	if s.sms != nil && phone != "" {
		if err := s.sms.Send(phone, body); err != nil {
			log.Printf("[PUSH] SMS send failed for ApplicationRejected phone=%s: %v", phone, err)
		}
	}
	return nil
}

// AccountSuspended notifies the farmer that their account was suspended via DB notification and SMS.
func (s *PushService) AccountSuspended(_ context.Context, userID, phone string) error {
	s.sendToUser(userID,
		TypeAccountSuspended,
		"Hesabınız Askıya Alındı",
		"Köyden Şehire hesabınız geçici olarak askıya alınmıştır.",
		map[string]string{"type": TypeAccountSuspended},
	)
	if s.sms != nil && phone != "" {
		if err := s.sms.Send(phone, "Köyden Şehire hesabınız geçici olarak askıya alınmıştır."); err != nil {
			log.Printf("[PUSH] SMS send failed for AccountSuspended user=%s: %v", userID, err)
		}
	}
	return nil
}

// AccountReactivated notifies the farmer that their account was reactivated via DB notification and FCM push.
func (s *PushService) AccountReactivated(_ context.Context, userID string) error {
	s.sendToUser(userID,
		TypeAccountReactivated,
		"Hesabınız Aktif Edildi",
		"Köyden Şehire hesabınız tekrar aktif hale getirildi.",
		map[string]string{"type": TypeAccountReactivated},
	)
	return nil
}

// CustomerRegistered persists a welcome in-app notification for a new customer (no SMS, no FCM push).
func (s *PushService) CustomerRegistered(_ context.Context, userID, name string) error {
	s.saveNotif(userID,
		TypeNewCustomer,
		"Hoş Geldiniz!",
		"Merhaba "+name+"! Yerel üreticileri keşfetmeye başlayabilirsiniz.",
	)
	return nil
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

