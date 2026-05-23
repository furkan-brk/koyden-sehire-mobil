# Database Schema — Köyden Şehre

PostgreSQL 15+. UUID primary keys via `gen_random_uuid()`. All timestamps in UTC without timezone.

---

## Tables

### `users`
| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `full_name` | varchar(255) | |
| `phone` | varchar(20) UNIQUE | Format: 05XXXXXXXXX |
| `email` | varchar(255) UNIQUE nullable | |
| `password_hash` | text | bcrypt cost 12 |
| `role` | varchar(20) | `admin` \| `farmer` |
| `status` | varchar(20) | `active` \| `suspended` |
| `phone_verified` | bool | default false |
| `phone_verified_at` | timestamp nullable | |
| `created_at` | timestamp | |
| `updated_at` | timestamp | |

### `farmer_profiles`
| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `user_id` | uuid FK → users | |
| `display_name` | varchar(255) | Business name |
| `producer_type` | varchar(50) | enum |
| `city` | varchar(100) | |
| `district` | varchar(100) | |
| `village` | varchar(100) | |
| `bio` | text | |
| `profile_image_url` | text nullable | |
| `public_phone` | varchar(20) | |
| `show_phone` | bool | default true |
| `is_verified` | bool | default false |
| `is_founding_farmer` | bool | default false |
| `invite_quota` | int | default 2 |
| `created_at` | timestamp | |
| `updated_at` | timestamp | |

**`producer_type` values:** `individual_farmer`, `family_producer`, `cooperative`, `small_producer`, `dairy_producer`, `beekeeper`, `olive_producer`, `other`

### `categories`
| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `name` | varchar(100) | |
| `slug` | varchar(100) UNIQUE | |
| `parent_id` | uuid FK → categories nullable | NULL = root category |
| `icon` | text nullable | |
| `sort_order` | int | default 0 |
| `is_active` | bool | default true |
| `created_at` | timestamp | |
| `updated_at` | timestamp | |

### `products`
| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `farmer_id` | uuid FK → users | |
| `category_id` | uuid FK → categories | |
| `title` | varchar(255) | |
| `description` | text | |
| `price` | numeric(10,2) | |
| `unit` | varchar(20) | `kg`, `adet`, `lt`, etc. |
| `city` | varchar(100) | |
| `district` | varchar(100) | |
| `village` | varchar(100) | |
| `status` | varchar(20) | `pending` \| `active` \| `rejected` \| `hidden` |
| `previous_status` | varchar(20) nullable | |
| `stock_status` | varchar(20) | `available` \| `out_of_stock` \| `limited` |
| `admin_note` | text nullable | |
| `created_at` | timestamp | |
| `updated_at` | timestamp | |

### `product_images`
| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `product_id` | uuid FK → products | |
| `image_url` | text | Full CDN URL |
| `sort_order` | int | |
| `created_at` | timestamp | |

### `farmer_applications`
| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `full_name` | varchar(255) | |
| `phone` | varchar(20) | |
| `email` | varchar(255) nullable | |
| `password_hash` | text | Used to create user on approval |
| `phone_verified` | bool | |
| `business_name` | varchar(255) | |
| `producer_type` | varchar(50) | |
| `city`, `district`, `village` | varchar | |
| `bio` | text | |
| `product_categories` | jsonb | Array of category slugs |
| `product_examples` | text | |
| `production_place_type` | varchar(50) nullable | |
| `document_urls` | jsonb | Array of URLs |
| `application_note` | text nullable | |
| `application_video_key` | text nullable | S3 object key |
| `application_video_status` | varchar(20) | `missing` \| `uploaded` \| `requested` \| `not_required` |
| `video_requested_at` | timestamp nullable | |
| `video_uploaded_at` | timestamp nullable | |
| `invite_code_id` | uuid FK → invite_codes nullable | |
| `referred_by_user_id` | uuid FK → users nullable | |
| `application_source` | varchar(20) | `admin_created` \| `admin_invite` \| `farmer_invite` |
| `kvkk_accepted` | bool | |
| `platform_terms_accepted` | bool | |
| `declares_own_production` | bool | |
| `declares_accurate_location` | bool | |
| `declares_not_intermediary` | bool | |
| `status` | varchar(20) | `pending` \| `approved` \| `rejected` \| `needs_video` |
| `rejection_reason` | varchar(50) nullable | enum |
| `admin_note` | text nullable | |
| `reviewed_by` | uuid FK → users nullable | |
| `reviewed_at` | timestamp nullable | |
| `created_at` | timestamp | |
| `updated_at` | timestamp | |

**Unique constraint:** `phone` WHERE `status IN ('pending', 'needs_video')`

### `invite_codes`
| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `code` | varchar(20) UNIQUE | Format: KYS-XXXXXX |
| `owner_user_id` | uuid FK → users | |
| `owner_type` | varchar(20) | `admin` \| `farmer` |
| `max_uses` | int | |
| `used_count` | int | default 0 |
| `is_active` | bool | default true |
| `expires_at` | timestamp nullable | NULL = never expires |
| `created_at` | timestamp | |
| `updated_at` | timestamp | |

### `invitations`
| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `invite_code_id` | uuid FK → invite_codes | |
| `inviter_user_id` | uuid FK → users | |
| `application_id` | uuid FK → farmer_applications nullable | |
| `status` | varchar(20) | `submitted` \| `approved` \| `rejected` |
| `created_at` | timestamp | |
| `updated_at` | timestamp | |

### `favorites`
| Column | Type | Notes |
|--------|------|-------|
| `user_id` | uuid FK → users | Cascade delete |
| `product_id` | uuid FK → products | Cascade delete |
| `created_at` | timestamptz | |

PK: `(user_id, product_id)`. Index: `idx_favorites_user_created` on `(user_id, created_at DESC)`.

---

## Migrations

Migrations are in `./migrations/` using `golang-migrate`.  
They run automatically on startup when `APP_AUTO_MIGRATE=true`.

To run manually:
```bash
migrate -path ./migrations -database "$DATABASE_URL" up
```
