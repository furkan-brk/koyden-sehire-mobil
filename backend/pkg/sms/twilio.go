package sms

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

const twilioAPIBase = "https://api.twilio.com/2010-04-01"

type TwilioProvider struct {
	accountSID   string
	authToken    string
	from         string // TWILIO_FROM_NUMBER (+1...) — messagingSID boşsa kullanılır
	messagingSID string // TWILIO_MESSAGING_SERVICE_SID — doluysa from'un yerine geçer
	baseURL      string // testlerde override edilir
	client       *http.Client
}

func NewTwilioProvider(accountSID, authToken, from, messagingSID string) *TwilioProvider {
	return &TwilioProvider{
		accountSID:   accountSID,
		authToken:    authToken,
		from:         from,
		messagingSID: messagingSID,
		baseURL:      twilioAPIBase,
		client:       &http.Client{Timeout: 10 * time.Second},
	}
}

func (t *TwilioProvider) Send(phone, message string) error {
	form := url.Values{}
	form.Set("To", ToE164(phone))
	form.Set("Body", message)
	if t.messagingSID != "" {
		form.Set("MessagingServiceSid", t.messagingSID)
	} else {
		form.Set("From", t.from)
	}

	endpoint := fmt.Sprintf("%s/Accounts/%s/Messages.json", t.baseURL, t.accountSID)
	req, err := http.NewRequest(http.MethodPost, endpoint, strings.NewReader(form.Encode()))
	if err != nil {
		return fmt.Errorf("twilio request build failed: %w", err)
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.SetBasicAuth(t.accountSID, t.authToken)

	resp, err := t.client.Do(req)
	if err != nil {
		return fmt.Errorf("twilio request failed: %w", err)
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<16))

	if resp.StatusCode >= 300 {
		var apiErr struct {
			Code     int    `json:"code"`
			Message  string `json:"message"`
			MoreInfo string `json:"more_info"`
		}
		if err := json.Unmarshal(body, &apiErr); err == nil && apiErr.Message != "" {
			return fmt.Errorf("twilio error (http %d, code %d): %s", resp.StatusCode, apiErr.Code, apiErr.Message)
		}
		return fmt.Errorf("twilio error (http %d)", resp.StatusCode)
	}

	return nil
}
