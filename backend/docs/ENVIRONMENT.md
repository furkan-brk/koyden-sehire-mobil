# Environment Variables — Köyden Şehre Backend

Copy `.env.example` to `.env` and fill in values before running.

---

## App

| Variable | Default | Description |
|----------|---------|-------------|
| `APP_ENV` | `development` | `development` or `production`. Controls debug logs, SMS provider |
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

## SMS (Netgsm)

Real SMS is only sent when `APP_ENV=production` **and** these are set; otherwise
OTP is logged to stdout (dev fallback also applies if left empty in prod-like
setups, so double-check `APP_ENV` and these three together before go-live).

| Variable | Required | Description |
|----------|----------|-------------|
| `NETGSM_USERNAME` | prod only | Netgsm account username |
| `NETGSM_PASSWORD` | prod only | Netgsm account password |
| `NETGSM_HEADER` | | Approved SMS sender name (default: `KOYDENSEHRE`) |

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
- [ ] `NETGSM_USERNAME` / `NETGSM_PASSWORD` set
- [ ] `CORS_ALLOWED_ORIGINS` restricted to the actual frontend domain(s), e.g. `https://koydensehire.netlify.app` (never leave the localhost defaults in prod)
- [ ] `S3_*` storage credentials set
- [ ] Default seed admin (`05000000000` / `admin123`, see `migrations/000012_seed_admin.up.sql`) password changed — the server refuses to start in production while it's unchanged (see `cmd/api/main.go`)
- [ ] Set `AUTO_MIGRATE=false` after the first successful production migration, to avoid every restart re-running migrate
