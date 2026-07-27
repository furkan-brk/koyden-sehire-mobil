package sms

import "strings"

// ToE164 Türkiye numaralarını E.164 formatına çevirir: 05xxxxxxxxx -> +905xxxxxxxxx
// Zaten "+" ile başlayan numaralara dokunmaz (yurt dışı numaraları için).
func ToE164(phone string) string {
	phone = strings.TrimSpace(phone)
	for _, ch := range []string{" ", "-", "(", ")", "."} {
		phone = strings.ReplaceAll(phone, ch, "")
	}

	switch {
	case phone == "":
		return ""
	case strings.HasPrefix(phone, "+"):
		return phone
	case strings.HasPrefix(phone, "00"):
		return "+" + phone[2:]
	case strings.HasPrefix(phone, "0"):
		return "+90" + phone[1:]
	case strings.HasPrefix(phone, "90"):
		return "+" + phone
	default:
		return "+90" + phone
	}
}
