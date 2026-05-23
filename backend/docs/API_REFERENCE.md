# API Reference — Köyden Şehre Backend

Base URL: `https://api.koydensehire.com/api/v1`  
Development: `http://localhost:8080/api/v1`

All responses follow the format:
```json
{"success": true, "data": {}, "message": ""}
{"success": false, "error": {"code": "ERROR_CODE", "message": "Human-readable message"}}
```

---

## Public Endpoints (No Auth)

### Health
| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Service health check |

### Auth
| Method | Path | Description |
|--------|------|-------------|
| POST | `/auth/login` | Login with phone + password → JWT + refresh token |
| POST | `/auth/refresh` | Rotate refresh token → new access + refresh token |
| POST | `/auth/register/customer` | Create customer account (requires OTP verified) |

**Login body:**
```json
{"phone": "05XXXXXXXXX", "password": "..."}
```

**Refresh body:**
```json
{"refresh_token": "<64-char-hex-token>"}
```
Response: same shape as login (`access_token`, `refresh_token`, `user`).  
The old refresh token is invalidated on every call (token rotation).  
Returns `401 INVALID_REFRESH_TOKEN` if token is missing or expired.

**Register customer body:**
```json
{
  "phone":     "05XXXXXXXXX",
  "full_name": "Ad Soyad",
  "email":     "ornek@email.com",
  "password":  "min8karakter"
}
```
Validation: `phone` exactly 11 chars starting with `05`; `full_name` 2–100 chars; `email` valid format max 255 chars; `password` 8–72 chars.  
**Precondition:** `POST /otp/verify` must have been called for the same phone within the last 30 minutes — the OTP verified marker is consumed on success.  
Returns `409 CONFLICT` if phone or email already registered; `400 OTP_NOT_VERIFIED` if OTP window expired.

### OTP
| Method | Path | Rate Limit |
|--------|------|-----------|
| POST | `/otp/send` | 1 per cooldown window |
| POST | `/otp/verify` | Max 3 attempts |

**Send body:** `{"phone": "05XXXXXXXXX"}`  
**Verify body:** `{"phone": "05XXXXXXXXX", "code": "123456"}`

### Categories
| Method | Path | Description |
|--------|------|-------------|
| GET | `/categories` | Tree with children |

### Products (Public)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/products` | Paginated active products |
| GET | `/products/:id` | Single product with farmer + category |
| GET | `/farmers/:id` | Public farmer profile |
| GET | `/farmers/:id/products` | Farmer's active products |

**Product filters (query params):**
- `search`, `category_id`, `city`, `district`, `village`
- `min_price`, `max_price`, `stock_status`
- `sort`: `price_asc` | `price_desc` | (default: newest)
- `page`, `limit` (max 100)

### Invites
| Method | Path | Description |
|--------|------|-------------|
| GET | `/invites/validate?code=KYS-XXXX` | Validate invite code |

### Farmer Applications
| Method | Path | Description |
|--------|------|-------------|
| POST | `/farmer-applications` | Submit application |
| POST | `/uploads/application-video/presigned-url` | Get S3 upload URL |

---

## Customer Endpoints (`/customer/*` — Bearer JWT, role=customer, status=active)

### Favorites

| Method | Path | Description |
|--------|------|-------------|
| GET | `/customer/favorites` | List favorited products (full product detail, active only) |
| POST | `/customer/favorites/:productId` | Add product to favorites (201) |
| DELETE | `/customer/favorites/:productId` | Remove product from favorites (200) |

**GET /customer/favorites** returns `{"success": true, "data": [PublicProduct...]}`.  
`POST` / `DELETE` return `{"success": true}`.  
Error codes: `PRODUCT_NOT_AVAILABLE` (400) if product is not active on add; `NOT_FOUND` (404) if product ID doesn't exist.

---

## Farmer Endpoints (`/farmer/*` — Bearer JWT, role=farmer, status=active)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/farmer/dashboard` | Welcome stub — returns greeting message (content will expand in future sprints) |
| GET | `/farmer/profile` | Get own profile |
| PUT | `/farmer/profile` | Update profile |
| GET | `/farmer/products` | Own product list |
| POST | `/farmer/products` | Create product (pending review) |
| GET | `/farmer/products/:id` | Get own product |
| PUT | `/farmer/products/:id` | Update product |
| PATCH | `/farmer/products/:id/status` | Set stock_status |
| GET | `/farmer/invites` | Own invite codes |
| POST | `/farmer/uploads/product-image` | Upload product image |
| POST | `/farmer/uploads/profile-image` | Upload profile image |

---

## Admin Endpoints (`/admin/*` — Bearer JWT, role=admin)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/admin/dashboard` | Stats (farmers, pending apps, products) |
| GET | `/admin/analytics/city-density` | Farmer count grouped by city |
| GET | `/admin/analytics/invite-network` | Full invite tree (who invited whom) |
| GET | `/admin/applications` | List applications |
| GET | `/admin/applications/:id` | Application detail + video URL |
| POST | `/admin/applications/:id/approve` | Approve → create user + farmer_profile |
| POST | `/admin/applications/:id/reject` | Reject with reason |

**`GET /admin/analytics/city-density` response:**
```json
{"success": true, "data": [{"city": "İzmir", "farmer_count": 42}, ...]}
```

**`GET /admin/analytics/invite-network` response** (nested tree):
```json
{
  "success": true,
  "data": {
    "id": "uuid", "name": "Ad Soyad", "invite_code": "KYS-7GHT92",
    "used_count": 3, "max_uses": 5,
    "children": [{"id": "...", "name": "...", "children": []}]
  }
}
```

**`GET /admin/applications` query params:**
- `status`: `pending` | `needs_video` | `approved` | `rejected` (omit for all)
- `page`, `limit` (default 20, max 100)

**`POST /admin/applications/:id/approve` body:**
```json
{
  "is_founding_farmer": false,
  "invite_quota": 3
}
```
`invite_quota` is optional — omit to use the system default (2).

**`POST /admin/applications/:id/reject` body:**
```json
{
  "rejection_reason": "incomplete_info",
  "admin_note": "Opsiyonel açıklama"
}
```
`rejection_reason` is **required**. `admin_note` is optional.
| POST | `/admin/applications/:id/request-video` | Request video upload |
| GET | `/admin/farmers` | All farmers |
| GET | `/admin/farmers/:id` | Farmer detail |
| POST | `/admin/farmers/:id/suspend` | Suspend farmer |
| POST | `/admin/farmers/:id/reactivate` | Reactivate farmer |
| PATCH | `/admin/farmers/:id/founding` | Set founding farmer flag |
| PATCH | `/admin/farmers/:id/invite-quota` | Update invite quota |
| GET | `/admin/products` | All products |
| GET | `/admin/products/:id` | Product detail |
| POST | `/admin/products/:id/approve` | Set status=active |
| POST | `/admin/products/:id/reject` | Set status=rejected |
| POST | `/admin/products/:id/hide` | Set status=hidden |
| DELETE | `/admin/products/:id` | Delete product |
| GET | `/admin/categories` | All categories |
| POST | `/admin/categories` | Create category |
| PUT | `/admin/categories/:id` | Update category |
| DELETE | `/admin/categories/:id` | Soft-delete category |

---

## Pagination Response Format

```json
{
  "success": true,
  "data": [...],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 42,
    "total_pages": 3
  }
}
```

## Error Codes

See [ERROR_FORMAT.md](ERROR_FORMAT.md) for full list.
