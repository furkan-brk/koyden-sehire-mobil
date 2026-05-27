package middleware

import (
	"context"
	"fmt"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/koydensehire/backend/pkg/response"
	"github.com/redis/go-redis/v9"
)

type RateLimitConfig struct {
	KeyFunc func(c *fiber.Ctx) string
	Max     int
	Window  time.Duration
}

var phoneRateLimitWhitelist = map[string]struct{}{
	"05327300325": {},
}

func isWhitelistedPhone(phone string) bool {
	_, ok := phoneRateLimitWhitelist[phone]
	return ok
}

func RateLimit(rdb *redis.Client, cfg RateLimitConfig) fiber.Handler {
	return func(c *fiber.Ctx) error {
		key := "rl:" + cfg.KeyFunc(c)
		ctx := context.Background()

		count, err := rdb.Incr(ctx, key).Result()
		if err != nil {
			return c.Next()
		}

		if count == 1 {
			rdb.Expire(ctx, key, cfg.Window)
		}

		if count > int64(cfg.Max) {
			return response.TooManyRequests(c, "Çok fazla istek gönderdiniz, lütfen bekleyin")
		}

		return c.Next()
	}
}

func OTPSendRateLimit(rdb *redis.Client) fiber.Handler {
	return RateLimit(rdb, RateLimitConfig{
		KeyFunc: func(c *fiber.Ctx) string {
			var body struct {
				Phone string `json:"phone"`
			}
			c.BodyParser(&body)
			// Empty/invalid phone → fall back to IP to prevent attackers
			// from sharing a single "otp:" bucket and rate-limiting real users.
			if body.Phone == "" {
				return fmt.Sprintf("otp_ip:%s", c.IP())
			}
			if isWhitelistedPhone(body.Phone) {
				return fmt.Sprintf("otp_whitelist:%s", body.Phone)
			}
			return fmt.Sprintf("otp:%s", body.Phone)
		},
		Max:    3,
		Window: time.Hour,
	})
}

func LoginRateLimit(rdb *redis.Client) fiber.Handler {
	return func(c *fiber.Ctx) error {
		ctx := context.Background()

		var body struct {
			Phone string `json:"phone"`
		}
		c.BodyParser(&body)

		ipKey := fmt.Sprintf("rl:login_ip:%s", c.IP())
		ipCount, err := rdb.Incr(ctx, ipKey).Result()
		if err == nil && ipCount == 1 {
			rdb.Expire(ctx, ipKey, 15*time.Minute)
		}

		// Per-phone counter prevents attackers from churning IPs to brute
		// force a single account.
		var phoneCount int64
		if body.Phone != "" {
			if isWhitelistedPhone(body.Phone) {
				return c.Next()
			}
			phoneKey := fmt.Sprintf("rl:login_phone:%s", body.Phone)
			phoneCount, err = rdb.Incr(ctx, phoneKey).Result()
			if err == nil && phoneCount == 1 {
				rdb.Expire(ctx, phoneKey, 15*time.Minute)
			}
		}

		// IP limit is generous (covers NAT'd campus networks),
		// phone limit is tight (5 attempts per phone per 15 min).
		if ipCount > 30 || phoneCount > 5 {
			return response.TooManyRequests(c, "Çok fazla istek gönderdiniz, lütfen bekleyin")
		}
		return c.Next()
	}
}

func RegisterRateLimit(rdb *redis.Client) fiber.Handler {
	return func(c *fiber.Ctx) error {
		ctx := context.Background()

		var body struct {
			Phone string `json:"phone"`
		}
		c.BodyParser(&body)

		ipKey := fmt.Sprintf("rl:register_ip:%s", c.IP())
		ipCount, err := rdb.Incr(ctx, ipKey).Result()
		if err == nil && ipCount == 1 {
			rdb.Expire(ctx, ipKey, 15*time.Minute)
		}

		var phoneCount int64
		if body.Phone != "" {
			if isWhitelistedPhone(body.Phone) {
				return c.Next()
			}
			phoneKey := fmt.Sprintf("rl:register_phone:%s", body.Phone)
			phoneCount, err = rdb.Incr(ctx, phoneKey).Result()
			if err == nil && phoneCount == 1 {
				rdb.Expire(ctx, phoneKey, time.Hour)
			}
		}

		if ipCount > 10 || phoneCount > 3 {
			return response.TooManyRequests(c, "Çok fazla istek gönderdiniz, lütfen bekleyin")
		}
		return c.Next()
	}
}

func InviteValidateRateLimit(rdb *redis.Client) fiber.Handler {
	return RateLimit(rdb, RateLimitConfig{
		KeyFunc: func(c *fiber.Ctx) string {
			return fmt.Sprintf("invite:%s", c.IP())
		},
		Max:    20,
		Window: time.Hour,
	})
}

func VideoPresignRateLimit(rdb *redis.Client) fiber.Handler {
	return func(c *fiber.Ctx) error {
		ctx := context.Background()

		var body struct {
			Phone string `json:"phone"`
		}
		c.BodyParser(&body)

		ipKey := fmt.Sprintf("rl:video_presign_ip:%s", c.IP())
		ipCount, err := rdb.Incr(ctx, ipKey).Result()
		if err == nil && ipCount == 1 {
			rdb.Expire(ctx, ipKey, time.Hour)
		}

		// Only enforce phone bucket when phone is actually provided;
		// otherwise an attacker with malformed bodies could exhaust
		// the shared "" bucket and starve legitimate users.
		var phoneCount int64
		if body.Phone != "" {
			if isWhitelistedPhone(body.Phone) {
				return c.Next()
			}
			phoneKey := fmt.Sprintf("rl:video_presign:%s", body.Phone)
			phoneCount, err = rdb.Incr(ctx, phoneKey).Result()
			if err == nil && phoneCount == 1 {
				rdb.Expire(ctx, phoneKey, time.Hour)
			}
		}

		if phoneCount > 5 || ipCount > 10 {
			return response.TooManyRequests(c, "Çok fazla istek gönderdiniz, lütfen bekleyin")
		}

		return c.Next()
	}
}
