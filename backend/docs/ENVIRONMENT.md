# Environment Variables — Köyden Şehre Backend

Copy `.env.example` to `.env` and fill in values before running.

---

## App

| Variable | Default | Description |
|----------|---------|-------------|
| `APP_ENV` | `development` | `development` or `production`. Controls debug logs and whether OTP SMS is really sent (see `SMS_FORCE_SEND`) |
| `APP_PORT` | `8080` | HTTP listen port |
| `APP_BASE_URL` | `http://localhost:8080` | Used in generated URLs |
| `AUTO_MIGRATE` | `true` | Run DB migrations on startup |
| `CORS_ALLOWED_ORIGINS` | `http://localhost:3000,http://localhost:8080` | Comma-separated allowed origins |

## Database

| Variable | Required | Description |
|----------|----------|-------------|
| `DATABASE_URL` | ✅ | PostgreSQL DSN: `postgres://user:pass@host:5432/db?sslmode=disable` |
| `DATABASE_MAX_CONNECTIONS` | | Default: 10 |
| `DATABASE_MAX_IDLE` | | Default: 5 |

## Redis

| Variable | Required | Description |
|----------|----------|-------------|
| `REDIS_URL` | ✅ | `redis://localhost:6379` |
| `REDIS_PASSWORD` | | Leave empty if no auth |

## JWT

| Variable | Required | Description |
|----------|----------|-------------|
| `JWT_SECRET` | ✅ | Min 32-char random string |
| `JWT_ACCESS_TOKEN_EXPIRY` | | Default: `24h`. Format: `24h`, `1h`, `30m` |

## OTP

| Variable | Default | Description |
|----------|---------|-------------|
| `OTP_EXPIRY_SECONDS` | `300` | OTP validity window (5 min) |
| `OTP_MAX_ATTEMPTS` | `3` | Wrong attempts before invalidation |
| `OTP_RESEND_COOLDOWN_SECONDS` | `60` | Seconds between resend requests |

## SMS (Twilio)

Provider selection (`cmd/api/main.go`): if the Twilio credentials below are set,
the Twilio Messages API is used. If they are empty, `APP_ENV=development` falls
back to `DevProvider` (messages logged to stdout only) and any other env makes
the server **exit** at startup.

Delivery is additionally gated by env: with `APP_ENV=development` the OTP is
logged and returned in the API response as `dev_code`, and no SMS is sent unless
`SMS_FORCE_SEND=true`. In `production` SMS is always sent.

Phone numbers are stored as `05xxxxxxxxx` and normalized to E.164 (`+905xxxxxxxxx`)
by `sms.ToE164` before being handed to Twilio.

| Variable | Required | Description |
|----------|----------|-------------|
| `TWILIO_ACCOUNT_SID` | prod only | Twilio Account SID (Console → Account Info) |
| `TWILIO_AUTH_TOKEN` | prod only | Twilio Auth Token |
| `TWILIO_FROM_NUMBER` | prod only¹ | Sender number in E.164, e.g. `+15551234567` |
| `TWILIO_MESSAGING_SERVICE_SID` | | Messaging Service SID — used instead of `TWILIO_FROM_NUMBER` when set |
| `SMS_FORCE_SEND` | | Default `false`. `true` sends real SMS in `development` too (real-device testing). While on, OTP resend cooldown is enforced in dev as well, to avoid unbounded paid sends. |

¹ Either `TWILIO_FROM_NUMBER` or `TWILIO_MESSAGING_SERVICE_SID` must be set.

> Twilio trial accounts can only send to **verified** numbers. Turkish OTP texts
> contain non-ASCII characters, so Twilio bills them as UCS-2 (70 chars/segment);
> the current OTP message stays within one segment.

## Storage (Cloudflare R2 / S3-compatible)

| Variable | Required | Description |
|----------|----------|-------------|
| `S3_ENDPOINT` | ✅ | R2/S3 endpoint URL |
| `S3_PRESIGN_ENDPOINT` | | Public-facing endpoint for presigned URLs, if different from `S3_ENDPOINT` |
| `S3_BUCKET` | ✅ | Bucket name |
| `S3_ACCESS_KEY` | ✅ | Access key ID |
| `S3_SECRET_KEY` | ✅ | Secret access key |
| `S3_PUBLIC_URL` | ✅ | Public CDN URL for serving images |

## n8n Webhooks

| Variable | Required | Description |
|----------|----------|-------------|
| `N8N_WEBHOOK_URL` | | n8n webhook base URL |
| `N8N_WEBHOOK_SECRET` | | Shared secret for webhook auth |

---

## Docker Compose

In `docker-compose.yml`, variables are read from `.env` automatically.  
The `api` service passes them as environment variables to the container.

## Production Checklist

- [ ] `APP_ENV=production` — required for real SMS delivery (otherwise OTP only logs to stdout and login is broken for real users)
- [ ] Strong `JWT_SECRET` (32+ chars)
- [ ] `DATABASE_URL` points to prod DB with SSL
- [ ] `TWILIO_ACCOUNT_SID` / `TWILIO_AUTH_TOKEN` set, plus `TWILIO_FROM_NUMBER` or `TWILIO_MESSAGING_SERVICE_SID` (the server refuses to start in production without them)
- [ ] `CORS_ALLOWED_ORIGINS` restricted to the actual frontend domain(s), e.g. `https://koydensehire.netlify.app` (never leave the localhost defaults in prod)
- [ ] `S3_*` storage credentials set
- [ ] Default seed admin (`05000000000` / `admin123`, see `migrations/000012_seed_admin.up.sql`) password changed — the server refuses to start in production while it's unchanged (see `cmd/api/main.go`)
- [ ] Set `AUTO_MIGRATE=false` after the first successful production migration, to avoid every restart re-running migrate
