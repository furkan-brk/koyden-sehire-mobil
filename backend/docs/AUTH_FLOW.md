# Auth Flow — Köyden Şehre

## Overview

The platform uses two-stage auth:
1. **OTP phone verification** (required before farmer application or sensitive actions)
2. **JWT Bearer tokens** (for authenticated API calls)

---

## Farmer Registration Flow

```
1. POST /otp/send          {"phone": "05XXXXXXXXX"}
   → Redis: otp:{phone} = "CODE:0"  (TTL: 300s)
   → Dev: code logged to stdout (also sent via Twilio if SMS_FORCE_SEND=true)
   → Prod: code sent via Twilio SMS

2. POST /otp/verify        {"phone": "...", "code": "123456"}
   → Redis: otp_verified:{phone} = "1"  (TTL: 1800s)
   → Max 3 attempts before OTP invalidated

3. POST /farmer-applications  {full application body}
   → Checks otp_verified:{phone} exists
   → Checks invite_code valid (is_active, used_count < max_uses, expires_at)
   → Creates farmer_applications record (status=pending)
   → Clears otp_verified:{phone}
   → Increments invite_codes.used_count

4. Admin reviews → POST /admin/applications/:id/approve
   → Creates users record (role=farmer, status=active)
   → Creates farmer_profiles record
   → Creates invite_codes for farmer
   → Sets application status=approved

5. Farmer logs in: POST /auth/login
   → Returns JWT access token (role=farmer)
```

---

## Admin Login Flow

```
POST /auth/login  {"phone": "05000000000", "password": "admin123"}
→ Returns JWT with role=admin
```

---

## JWT Structure

```json
{
  "user_id": "uuid",
  "role": "admin|farmer",
  "exp": 1234567890,
  "iat": 1234567890
}
```

**Token expiry:** Configured via `JWT_ACCESS_TOKEN_EXPIRY` (default: 24h)

---

## Middleware Stack

```
requireAuth      → validates Bearer JWT, injects user_id + role to context
requireFarmer    → checks role == "farmer"
requireAdmin     → checks role == "admin"
requireActive    → checks user.status == "active"
```

**Farmer routes:** `requireAuth + requireFarmer + requireActive`  
**Admin routes:** `requireAuth + requireAdmin`

---

## OTP Rate Limiting

- **Send rate limit:** 1 request per `OTP_RESEND_COOLDOWN_SECONDS` (default 60s) per phone
- **Verify:** Max `OTP_MAX_ATTEMPTS` (default 3) before code invalidated
- **OTP expiry:** `OTP_EXPIRY_SECONDS` (default 300s = 5min)
- **Verified flag TTL:** 1800s (30min) — farmer must submit application within this window

---

## Invite Code System

- Format: `KYS-XXXXXX` (uppercase alphanumeric suffix)
- Special code: `KYS-FOUNDER` (admin-owned, max 50 uses)
- Farmer-created codes: quota from `farmer_profiles.invite_quota`
- Validation: `is_active=true`, `used_count < max_uses`, `expires_at IS NULL OR expires_at > NOW()`
