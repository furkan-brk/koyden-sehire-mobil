package sms

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestTwilioSendUsesE164AndBasicAuth(t *testing.T) {
	var gotPath, gotTo, gotBody, gotFrom, gotMessagingSID, gotUser, gotPass string
	var basicAuthOK bool

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotPath = r.URL.Path
		gotUser, gotPass, basicAuthOK = r.BasicAuth()
		_ = r.ParseForm()
		gotTo = r.PostForm.Get("To")
		gotBody = r.PostForm.Get("Body")
		gotFrom = r.PostForm.Get("From")
		gotMessagingSID = r.PostForm.Get("MessagingServiceSid")
		w.WriteHeader(http.StatusCreated)
		_, _ = w.Write([]byte(`{"sid":"SM123","status":"queued"}`))
	}))
	defer srv.Close()

	p := NewTwilioProvider("AC123", "token123", "+15551234567", "")
	p.baseURL = srv.URL

	if err := p.Send("05327300325", "Köyden Şehire doğrulama kodunuz: 123456"); err != nil {
		t.Fatalf("Send() returned error: %v", err)
	}

	if want := "/Accounts/AC123/Messages.json"; gotPath != want {
		t.Errorf("path = %q, want %q", gotPath, want)
	}
	if !basicAuthOK || gotUser != "AC123" || gotPass != "token123" {
		t.Errorf("basic auth = (%q, %q, ok=%v), want (AC123, token123, true)", gotUser, gotPass, basicAuthOK)
	}
	if want := "+905327300325"; gotTo != want {
		t.Errorf("To = %q, want %q", gotTo, want)
	}
	if !strings.Contains(gotBody, "123456") {
		t.Errorf("Body = %q, want it to contain the code", gotBody)
	}
	if gotFrom != "+15551234567" {
		t.Errorf("From = %q, want +15551234567", gotFrom)
	}
	if gotMessagingSID != "" {
		t.Errorf("MessagingServiceSid = %q, want empty when from-number is used", gotMessagingSID)
	}
}

func TestTwilioSendPrefersMessagingService(t *testing.T) {
	var gotFrom, gotMessagingSID string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_ = r.ParseForm()
		gotFrom = r.PostForm.Get("From")
		gotMessagingSID = r.PostForm.Get("MessagingServiceSid")
		w.WriteHeader(http.StatusCreated)
	}))
	defer srv.Close()

	p := NewTwilioProvider("AC123", "token123", "+15551234567", "MG999")
	p.baseURL = srv.URL

	if err := p.Send("05327300325", "test"); err != nil {
		t.Fatalf("Send() returned error: %v", err)
	}
	if gotMessagingSID != "MG999" {
		t.Errorf("MessagingServiceSid = %q, want MG999", gotMessagingSID)
	}
	if gotFrom != "" {
		t.Errorf("From = %q, want empty when messaging service SID is set", gotFrom)
	}
}

func TestTwilioSendParsesAPIError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusUnauthorized)
		_, _ = w.Write([]byte(`{"code":20003,"message":"Authenticate","more_info":"https://www.twilio.com/docs/errors/20003"}`))
	}))
	defer srv.Close()

	p := NewTwilioProvider("AC123", "wrong", "+15551234567", "")
	p.baseURL = srv.URL

	err := p.Send("05327300325", "test")
	if err == nil {
		t.Fatal("Send() = nil, want error on HTTP 401")
	}
	if !strings.Contains(err.Error(), "20003") || !strings.Contains(err.Error(), "Authenticate") {
		t.Errorf("error = %q, want it to include the Twilio code and message", err)
	}
	if strings.Contains(err.Error(), "wrong") {
		t.Errorf("error = %q, must not leak the auth token", err)
	}
}
