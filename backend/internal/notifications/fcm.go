package notifications

import (
	"bytes"
	"crypto/rsa"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

type serviceAccount struct {
	ClientEmail string `json:"client_email"`
	PrivateKey  string `json:"private_key"`
	TokenURI    string `json:"token_uri"`
}

type FCMClient struct {
	projectID   string
	sa          serviceAccount
	privateKey  *rsa.PrivateKey
	mu          sync.Mutex
	cachedToken string
	tokenExpiry time.Time
}

// NewFCMClient parses serviceAccountJSON and returns a ready client.
// Returns nil (with a log warning) if the JSON is empty or malformed so the
// rest of the application can still run without push notifications.
func NewFCMClient(projectID, serviceAccountJSON string) *FCMClient {
	if projectID == "" || serviceAccountJSON == "" {
		log.Println("[FCM] credentials not configured — push notifications disabled")
		return nil
	}

	var sa serviceAccount
	if err := json.Unmarshal([]byte(serviceAccountJSON), &sa); err != nil {
		log.Printf("[FCM] failed to parse service account JSON: %v — push notifications disabled", err)
		return nil
	}

	block, _ := pem.Decode([]byte(sa.PrivateKey))
	if block == nil {
		log.Println("[FCM] failed to decode private key PEM — push notifications disabled")
		return nil
	}
	raw, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		log.Printf("[FCM] failed to parse private key: %v — push notifications disabled", err)
		return nil
	}
	rsaKey, ok := raw.(*rsa.PrivateKey)
	if !ok {
		log.Println("[FCM] private key is not RSA — push notifications disabled")
		return nil
	}
	if sa.TokenURI == "" {
		sa.TokenURI = "https://oauth2.googleapis.com/token"
	}

	return &FCMClient{projectID: projectID, sa: sa, privateKey: rsaKey}
}

type googleClaims struct {
	jwt.RegisteredClaims
	Scope string `json:"scope"`
}

func (c *FCMClient) accessToken() (string, error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.cachedToken != "" && time.Now().Before(c.tokenExpiry.Add(-5*time.Minute)) {
		return c.cachedToken, nil
	}

	now := time.Now()
	tok := jwt.NewWithClaims(jwt.SigningMethodRS256, googleClaims{
		Scope: "https://www.googleapis.com/auth/firebase.messaging",
		RegisteredClaims: jwt.RegisteredClaims{
			Issuer:    c.sa.ClientEmail,
			Subject:   c.sa.ClientEmail,
			Audience:  jwt.ClaimStrings{c.sa.TokenURI},
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(time.Hour)),
		},
	})
	signed, err := tok.SignedString(c.privateKey)
	if err != nil {
		return "", fmt.Errorf("signing JWT: %w", err)
	}

	resp, err := http.PostForm(c.sa.TokenURI, url.Values{
		"grant_type": {"urn:ietf:params:oauth:grant-type:jwt-bearer"},
		"assertion":  {signed},
	})
	if err != nil {
		return "", fmt.Errorf("token exchange: %w", err)
	}
	defer resp.Body.Close()

	var result struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int    `json:"expires_in"`
		Error       string `json:"error"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return "", fmt.Errorf("decoding token response: %w", err)
	}
	if result.Error != "" {
		return "", fmt.Errorf("token error: %s", result.Error)
	}

	c.cachedToken = result.AccessToken
	c.tokenExpiry = now.Add(time.Duration(result.ExpiresIn) * time.Second)
	return c.cachedToken, nil
}

type fcmMessage struct {
	Message fcmPayload `json:"message"`
}

type fcmPayload struct {
	Token        string            `json:"token"`
	Notification fcmNotification   `json:"notification"`
	Data         map[string]string `json:"data,omitempty"`
	Android      *fcmAndroid       `json:"android,omitempty"`
	APNS         *fcmAPNS          `json:"apns,omitempty"`
}

type fcmNotification struct {
	Title string `json:"title"`
	Body  string `json:"body"`
}

type fcmAndroid struct {
	Priority string `json:"priority"`
}

type fcmAPNS struct {
	Payload map[string]interface{} `json:"payload"`
}

// Send delivers a push notification to a single device token.
// Returns a boolean indicating whether the token should be removed (stale).
func (c *FCMClient) Send(deviceToken, title, body string, data map[string]string) (stale bool, err error) {
	accessToken, err := c.accessToken()
	if err != nil {
		return false, fmt.Errorf("getting access token: %w", err)
	}

	msg := fcmMessage{
		Message: fcmPayload{
			Token:        deviceToken,
			Notification: fcmNotification{Title: title, Body: body},
			Data:         data,
			Android:      &fcmAndroid{Priority: "high"},
			APNS: &fcmAPNS{
				Payload: map[string]interface{}{
					"aps": map[string]interface{}{"sound": "default"},
				},
			},
		},
	}

	body2, _ := json.Marshal(msg)
	endpoint := fmt.Sprintf("https://fcm.googleapis.com/v1/projects/%s/messages:send", c.projectID)
	req, err := http.NewRequest("POST", endpoint, bytes.NewReader(body2))
	if err != nil {
		return false, err
	}
	req.Header.Set("Authorization", "Bearer "+accessToken)
	req.Header.Set("Content-Type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return false, err
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusOK {
		return false, nil
	}

	raw, _ := io.ReadAll(resp.Body)
	// 404 means the token is no longer registered — caller should delete it.
	if resp.StatusCode == http.StatusNotFound {
		return true, fmt.Errorf("FCM token not found: %s", raw)
	}
	// 401 invalidates cached token so next call re-fetches.
	if resp.StatusCode == http.StatusUnauthorized {
		c.mu.Lock()
		c.cachedToken = ""
		c.mu.Unlock()
	}
	return false, fmt.Errorf("FCM %d: %s", resp.StatusCode, raw)
}
