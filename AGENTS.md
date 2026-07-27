# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

---

## Project Overview

**Köyden Şehire** — commission-free marketplace connecting local farmers/producers directly with buyers. The platform has no in-app payments, orders, or messaging; it is a listing/discovery tool only.

Three user roles: **admin** (web panel only), **farmer** (mobile app), **customer** (mobile app, can browse without account).

---

## Repository Structure

```
/
├── backend/          # Go 1.23 REST API (Fiber v2)
├── flutter-mobile/   # Flutter mobile + web admin panel
├── docker-compose.yml          # Local dev: postgres, redis, minio, api, n8n
└── docker-compose.prod.yml
```

---

## Backend

### Running Locally

```bash
# From repo root — starts postgres, redis, minio, n8n, and the Go API
docker compose up -d

# Health check
curl http://localhost:8080/api/v1/health
```

> **Note:** `docker-compose.yml` maps postgres to **host port 5433** (not 5432) to avoid conflicts.

### Running Without Docker (Go only)

```bash
cd backend
cp .env.example .env   # fill in DB URL, JWT secret, etc.
go run ./cmd/api/main.go
```

Auto-migrate is controlled by `AUTO_MIGRATE=true` in `.env`. In development, OTP codes are printed to stdout instead of being sent via SMS; storage falls back to a dev placeholder if S3/R2 credentials are missing.

### Manual Migrations

```bash
# From backend/
migrate -path migrations -database "postgres://admin:localpass@localhost:5433/koydensehire?sslmode=disable" up
```

### Default Dev Credentials

| Resource | Value |
|----------|-------|
| Admin phone | `05000000000` |
| Admin password | `admin123` |
| Postgres | `admin / localpass` @ `localhost:5433` |
| MinIO console | `http://localhost:9001` — `minioadmin / minioadmin123` |
| n8n | `http://localhost:5678` |

### Architecture

Each domain lives under `internal/<domain>/` with four files:
- `model.go` — DB structs with `db:` tags
- `repository.go` — raw SQL via `sqlx`
- `service.go` — business logic
- `handler.go` — Fiber HTTP handler
- `dto.go` — request/response types (where needed)

Global wiring (dependency injection, routes, middleware) is in `cmd/api/main.go`. There is no DI container — everything is manually constructed.

**Key packages:**
- `internal/config/` — reads env vars into a typed `Config` struct
- `internal/middleware/` — `RequireAuth` (JWT validation), `RequireRole`, `RequireActiveUser`, rate limiters
- `pkg/storage/` — S3/R2 provider + `DevProvider` stub
- `pkg/sms/` — Twilio provider + `DevProvider` stub (`SMS_FORCE_SEND=true` ile dev'de de gerçek gönderim)
- `internal/notifications/` — n8n webhook calls

**All API routes** are prefixed `/api/v1`. Route groups: public, `/farmer` (requireAuth + requireFarmer + requireActive), `/admin` (requireAuth + requireAdmin).

**Error format** — all errors follow `{"success": false, "error": {"code": "SNAKE_CASE", "message": "..."}}`. See `backend/docs/ERROR_FORMAT.md`.

**Storage** — product/profile images are public URLs via `STORAGE_PUBLIC_URL`; application videos are private, served via presigned GET URLs (1h expiry).

---

## Flutter Mobile

### Running

```bash
cd flutter-mobile
flutter pub get

# Android emulator (default BASE_URL points to 10.0.2.2:8080)
flutter run

# Physical device or custom API URL
flutter run --dart-define=BASE_URL=http://<your-ip>:8080/api/v1

# Release build MUST override BASE_URL
flutter build apk --dart-define=BASE_URL=https://api.koydensehire.com/api/v1
```

### Architecture

| Layer | Location | Notes |
|-------|----------|-------|
| Routing | `lib/app/router.dart` | `go_router` + `GoRouter`; redirect guards use GetX `AuthService.status` |
| Auth state | `lib/core/services/auth_service.dart` | `GetxService`; persisted via `flutter_secure_storage` |
| HTTP | `lib/core/api/api_client.dart` | `Dio` + `_AuthInterceptor`; auto-refresh on 401 |
| Controllers | `lib/controllers/` | GetX `GetxController`; grouped by role (admin/, farmer/, public/) |
| Bindings | `lib/bindings/` | Lazy-registered per-route dependencies |
| Repositories | `lib/services/*_repository.dart` | Thin API call wrappers; return typed models |
| Models | `lib/models/` | Plain Dart classes with `fromJson`; grouped by domain |
| Shared widgets | `lib/shared/widgets/` | Reusable UI components (AppButton, ProductCard, OtpInput, etc.) |
| Theme / constants | `lib/app/theme.dart`, `lib/app/constants.dart` | PlusJakartaSans font, color palette, API timeouts |

**Admin panel** is web-only: the `/login/admin` route and `AdminLoginScreen` are registered only when `kIsWeb == true`. The `ShellRoute` in the router wraps all `/admin/*` routes with a shared Drawer (`AdminShell`).

**GoRouter ↔ GetX bridge** — `_RouterRefreshListenable` (in `router.dart`) listens to `AuthService.status` via an `ever()` worker and calls `notifyListeners()` so GoRouter re-evaluates redirect guards whenever auth state changes.

**API base URL** is set at compile time via `--dart-define=BASE_URL=...`. The default (`http://10.0.2.2:8080/api/v1`) only works on Android emulators. Use `AppConstants.isDevDefaultBaseUrl` to guard release builds.

### Auth Flow Summary

1. OTP send → verify (Redis TTL 5 min, max 3 attempts)
2. Farmer application (requires valid invite code + OTP verified within 30 min)
3. Admin approves → farmer account created
4. Login → JWT access + refresh tokens stored in secure storage
5. 401 on any request → `_AuthInterceptor` auto-refreshes via `POST /auth/refresh`

Customer registration: OTP verify → `POST /auth/register/customer` (OTP verified state consumed server-side).

### Invite Code Format

`KYS-XXXXXX` (6 uppercase alphanumeric). Special: `KYS-FOUNDER` (50 uses, admin-owned).

---

## Documentation Index (`backend/docs/`)

| File | Content |
|------|---------|
| `API_REFERENCE.md` | Full endpoint reference |
| `AUTH_FLOW.md` | OTP + JWT flow detail |
| `DATABASE_SCHEMA.md` | All tables and constraints |
| `ENVIRONMENT.md` | All env vars + production checklist |
| `ERROR_FORMAT.md` | Error codes and HTTP status mapping |
| `UPLOADS_AND_STORAGE.md` | Presigned URL upload flow |
| `MOBILE_INTEGRATION_GUIDE.md` | Flutter/React Native integration notes |
| `openapi.yaml` | OpenAPI 3.0 spec |
| `POSTMAN_COLLECTION.json` | Postman collection with auto-token capture |
| `backend/TESTING.md` | End-to-end curl test walkthrough |
