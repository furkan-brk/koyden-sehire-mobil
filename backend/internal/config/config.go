package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	App      AppConfig
	Database DatabaseConfig
	Redis    RedisConfig
	JWT      JWTConfig
	OTP      OTPConfig
	Storage  StorageConfig
	SMS      SMSConfig
	N8N      N8NConfig
	FCM      FCMConfig
	DeepLink DeepLinkConfig
}

type AppConfig struct {
	Port        string
	Env         string
	BaseURL     string
	AutoMigrate bool
	CORSOrigins []string
}

type DatabaseConfig struct {
	URL            string
	MaxConnections int
	MaxIdle        int
}

type RedisConfig struct {
	URL      string
	Password string
}

type JWTConfig struct {
	Secret               string
	AccessTokenExpiry    time.Duration
	RefreshTokenExpiry   time.Duration
}

type OTPConfig struct {
	ExpirySeconds         int
	MaxAttempts           int
	ResendCooldownSeconds int
}

type StorageConfig struct {
	Provider        string
	Endpoint        string
	PresignEndpoint string // S3_PRESIGN_ENDPOINT — client-accessible URL for presigned PUT URLs
	Bucket          string
	AccessKey       string
	SecretKey       string
	PublicURL       string
}

type SMSConfig struct {
	Username string
	Password string
	Header   string
}

type N8NConfig struct {
	WebhookURL    string
	WebhookSecret string
}

type FCMConfig struct {
	ProjectID          string
	ServiceAccountJSON string
}

type DeepLinkConfig struct {
	AndroidPackage     string
	AndroidSHA256Certs []string
	AppleAppID         string // "<TeamID>.<BundleID>" — boşken AASA endpoint'i 404 döner
}

func Load() (*Config, error) {
	jwtExpiry, err := time.ParseDuration(getEnv("JWT_ACCESS_TOKEN_EXPIRY", "24h"))
	if err != nil {
		return nil, fmt.Errorf("invalid JWT_ACCESS_TOKEN_EXPIRY: %w", err)
	}

	jwtRefreshExpiry, err := time.ParseDuration(getEnv("JWT_REFRESH_TOKEN_EXPIRY", "168h"))
	if err != nil {
		return nil, fmt.Errorf("invalid JWT_REFRESH_TOKEN_EXPIRY: %w", err)
	}

	otpExpiry, _ := strconv.Atoi(getEnv("OTP_EXPIRY_SECONDS", "300"))
	otpMaxAttempts, _ := strconv.Atoi(getEnv("OTP_MAX_ATTEMPTS", "3"))
	otpCooldown, _ := strconv.Atoi(getEnv("OTP_RESEND_COOLDOWN_SECONDS", "60"))
	dbMaxConn, _ := strconv.Atoi(getEnv("DATABASE_MAX_CONNECTIONS", "25"))
	dbMaxIdle, _ := strconv.Atoi(getEnv("DATABASE_MAX_IDLE", "5"))
	autoMigrate, _ := strconv.ParseBool(getEnv("AUTO_MIGRATE", "true"))

	originsRaw := getEnv("CORS_ALLOWED_ORIGINS", "http://localhost:3000,http://localhost:8080")
	origins := strings.Split(originsRaw, ",")
	for i, o := range origins {
		origins[i] = strings.TrimSpace(o)
	}

	certsRaw := getEnv("ANDROID_SHA256_CERT_FINGERPRINTS", "")
	var sha256Certs []string
	for _, c := range strings.Split(certsRaw, ",") {
		if c = strings.TrimSpace(c); c != "" {
			sha256Certs = append(sha256Certs, c)
		}
	}

	cfg := &Config{
		App: AppConfig{
			Port:        getEnv("APP_PORT", "8080"),
			Env:         getEnv("APP_ENV", "development"),
			BaseURL:     getEnv("APP_BASE_URL", "http://localhost:8080"),
			AutoMigrate: autoMigrate,
			CORSOrigins: origins,
		},
		Database: DatabaseConfig{
			URL:            mustEnv("DATABASE_URL"),
			MaxConnections: dbMaxConn,
			MaxIdle:        dbMaxIdle,
		},
		Redis: RedisConfig{
			URL:      getEnv("REDIS_URL", "redis://redis:6379"),
			Password: getEnv("REDIS_PASSWORD", ""),
		},
		JWT: JWTConfig{
			Secret:             mustEnv("JWT_SECRET"),
			AccessTokenExpiry:  jwtExpiry,
			RefreshTokenExpiry: jwtRefreshExpiry,
		},
		OTP: OTPConfig{
			ExpirySeconds:         otpExpiry,
			MaxAttempts:           otpMaxAttempts,
			ResendCooldownSeconds: otpCooldown,
		},
		Storage: StorageConfig{
			Provider:        getEnv("STORAGE_PROVIDER", "r2"),
			Endpoint:        getEnv("S3_ENDPOINT", ""),
			PresignEndpoint: getEnv("S3_PRESIGN_ENDPOINT", getEnv("S3_ENDPOINT", "")),
			Bucket:          getEnv("S3_BUCKET", "koydensehre"),
			AccessKey:       getEnv("S3_ACCESS_KEY", ""),
			SecretKey:       getEnv("S3_SECRET_KEY", ""),
			PublicURL:       getEnv("S3_PUBLIC_URL", ""),
		},
		SMS: SMSConfig{
			Username: getEnv("NETGSM_USERNAME", ""),
			Password: getEnv("NETGSM_PASSWORD", ""),
			Header:   getEnv("NETGSM_HEADER", "KOYDENSEHRE"),
		},
		N8N: N8NConfig{
			WebhookURL:    getEnv("N8N_WEBHOOK_URL", ""),
			WebhookSecret: getEnv("N8N_WEBHOOK_SECRET", ""),
		},
		FCM: FCMConfig{
			ProjectID:          getEnv("FCM_PROJECT_ID", ""),
			ServiceAccountJSON: getEnv("FCM_SERVICE_ACCOUNT_JSON", ""),
		},
		DeepLink: DeepLinkConfig{
			AndroidPackage:     getEnv("ANDROID_PACKAGE_NAME", "com.koydensehire.koyden_sehire"),
			AndroidSHA256Certs: sha256Certs,
			AppleAppID:         getEnv("APPLE_APP_ID", ""),
		},
	}

	return cfg, nil
}

func getEnv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func mustEnv(key string) string {
	v := os.Getenv(key)
	if v == "" {
		panic(fmt.Sprintf("required environment variable %s is not set", key))
	}
	return v
}
