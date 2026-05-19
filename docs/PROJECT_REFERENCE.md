# Köyden Şehire — Proje Referansı

> Base URL: `https://api.koydensehire.com/api/v1`  
> Geliştirme: `http://localhost:8080/api/v1`

---

## İçindekiler

1. [Endpoint Listesi](#endpoint-listesi)
2. [Veritabanı Yapısı](#veritabanı-yapısı)
3. [Bağımlılıklar](#bağımlılıklar)

---

## Endpoint Listesi

### Public (Auth Gerektirmez)

| Method | Path | Açıklama |
|--------|------|----------|
| GET | `/health` | Sağlık kontrolü |
| POST | `/auth/login` | Giriş (phone + password) → JWT + refresh token |
| POST | `/auth/refresh` | Refresh token ile yeni token al |
| POST | `/auth/register/customer` | Müşteri kaydı (önce OTP doğrulaması zorunlu) |
| POST | `/otp/send` | OTP gönder (rate limited) |
| POST | `/otp/verify` | OTP doğrula (max 3 deneme) |
| GET | `/categories` | Alt kategorilerle birlikte kategori ağacı |
| GET | `/products` | Aktif ürünler (filtreli, sayfalı) |
| GET | `/products/:id` | Ürün detayı (çiftçi + kategori dahil) |
| GET | `/farmers/:id` | Çiftçi profili (public) |
| GET | `/farmers/:id/products` | Çiftçinin aktif ürünleri |
| GET | `/invites/validate?code=KYS-XXXX` | Davet kodu doğrula |
| POST | `/farmer-applications` | Çiftçi başvurusu gönder |
| POST | `/uploads/application-video/presigned-url` | Başvuru videosu için S3 presigned URL al |

**Ürün Filtre Parametreleri (`GET /products`):**
- `search`, `category_id`, `city`, `district`, `village`
- `min_price`, `max_price`, `stock_status`
- `sort`: `price_asc` | `price_desc` | (varsayılan: en yeni)
- `page`, `limit` (max 100)

---

### Farmer Endpointleri (`/farmer/*`)

> Bearer JWT gerektirir — `role=farmer`, `status=active`

| Method | Path | Açıklama |
|--------|------|----------|
| GET | `/farmer/dashboard` | Dashboard (karşılama mesajı) |
| GET | `/farmer/profile` | Kendi profilini görüntüle |
| PUT | `/farmer/profile` | Profil güncelle |
| GET | `/farmer/products` | Kendi ürün listesi |
| POST | `/farmer/products` | Yeni ürün oluştur (pending review) |
| GET | `/farmer/products/:id` | Kendi ürününü görüntüle |
| PUT | `/farmer/products/:id` | Ürün güncelle |
| PATCH | `/farmer/products/:id/status` | Stok durumunu güncelle |
| GET | `/farmer/invites` | Kendi davet kodları |
| POST | `/farmer/uploads/product-image` | Ürün görseli yükle |
| POST | `/farmer/uploads/profile-image` | Profil görseli yükle |

---

### Admin Endpointleri (`/admin/*`)

> Bearer JWT gerektirir — `role=admin`

#### Dashboard & Analitik

| Method | Path | Açıklama |
|--------|------|----------|
| GET | `/admin/dashboard` | İstatistikler (çiftçi, bekleyen başvuru, ürün sayıları) |
| GET | `/admin/analytics/city-density` | Şehre göre çiftçi yoğunluğu |
| GET | `/admin/analytics/invite-network` | Davet ağacı (iç içe ağaç yapısı) |

#### Başvurular

| Method | Path | Açıklama |
|--------|------|----------|
| GET | `/admin/applications` | Başvuru listesi (`?status=pending|needs_video|approved|rejected`) |
| GET | `/admin/applications/:id` | Başvuru detayı + video URL |
| POST | `/admin/applications/:id/approve` | Onayla → kullanıcı + çiftçi profili oluştur |
| POST | `/admin/applications/:id/reject` | Reddet (rejection_reason zorunlu) |
| POST | `/admin/applications/:id/request-video` | Video yüklemesi iste |

**Onay body:**
```json
{ "is_founding_farmer": false, "invite_quota": 3 }
```

**Red body:**
```json
{ "rejection_reason": "incomplete_info", "admin_note": "Opsiyonel açıklama" }
```

#### Çiftçiler

| Method | Path | Açıklama |
|--------|------|----------|
| GET | `/admin/farmers` | Tüm çiftçiler |
| GET | `/admin/farmers/:id` | Çiftçi detayı |
| POST | `/admin/farmers/:id/suspend` | Askıya al |
| POST | `/admin/farmers/:id/reactivate` | Aktifleştir |
| PATCH | `/admin/farmers/:id/founding` | Kurucu çiftçi flag'i ayarla |
| PATCH | `/admin/farmers/:id/invite-quota` | Davet kotası güncelle |

#### Ürünler

| Method | Path | Açıklama |
|--------|------|----------|
| GET | `/admin/products` | Tüm ürünler |
| GET | `/admin/products/:id` | Ürün detayı |
| POST | `/admin/products/:id/approve` | Onayla (status=active) |
| POST | `/admin/products/:id/reject` | Reddet (status=rejected) |
| POST | `/admin/products/:id/hide` | Gizle (status=hidden) |
| DELETE | `/admin/products/:id` | Ürünü sil |

#### Kategoriler

| Method | Path | Açıklama |
|--------|------|----------|
| GET | `/admin/categories` | Tüm kategoriler |
| POST | `/admin/categories` | Yeni kategori oluştur |
| PUT | `/admin/categories/:id` | Kategori güncelle |
| DELETE | `/admin/categories/:id` | Soft-delete |

---

### Yanıt Formatları

**Başarılı:**
```json
{ "success": true, "data": {}, "message": "" }
```

**Hata:**
```json
{ "success": false, "error": { "code": "SNAKE_CASE", "message": "Açıklama" } }
```

**Sayfalı:**
```json
{
  "success": true,
  "data": [...],
  "pagination": { "page": 1, "limit": 20, "total": 42, "total_pages": 3 }
}
```

---

## Veritabanı Yapısı

> PostgreSQL 15+ · UUID primary keys (`gen_random_uuid()`) · Tüm timestamp'ler UTC

### `users`

| Kolon | Tip | Notlar |
|-------|-----|--------|
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

| Kolon | Tip | Notlar |
|-------|-----|--------|
| `id` | uuid PK | |
| `user_id` | uuid FK → users | |
| `display_name` | varchar(255) | İşletme adı |
| `producer_type` | varchar(50) | Enum (aşağıya bakın) |
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

**`producer_type` değerleri:** `individual_farmer`, `family_producer`, `cooperative`, `small_producer`, `dairy_producer`, `beekeeper`, `olive_producer`, `other`

### `categories`

| Kolon | Tip | Notlar |
|-------|-----|--------|
| `id` | uuid PK | |
| `name` | varchar(100) | |
| `slug` | varchar(100) UNIQUE | |
| `parent_id` | uuid FK → categories nullable | NULL = kök kategori |
| `icon` | text nullable | |
| `sort_order` | int | default 0 |
| `is_active` | bool | default true |
| `created_at` | timestamp | |
| `updated_at` | timestamp | |

### `products`

| Kolon | Tip | Notlar |
|-------|-----|--------|
| `id` | uuid PK | |
| `farmer_id` | uuid FK → users | |
| `category_id` | uuid FK → categories | |
| `title` | varchar(255) | |
| `description` | text | |
| `price` | numeric(10,2) | |
| `unit` | varchar(20) | `kg`, `adet`, `lt`, vb. |
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

| Kolon | Tip | Notlar |
|-------|-----|--------|
| `id` | uuid PK | |
| `product_id` | uuid FK → products | |
| `image_url` | text | Tam CDN URL'i |
| `sort_order` | int | |
| `created_at` | timestamp | |

### `farmer_applications`

| Kolon | Tip | Notlar |
|-------|-----|--------|
| `id` | uuid PK | |
| `full_name` | varchar(255) | |
| `phone` | varchar(20) | |
| `email` | varchar(255) nullable | |
| `password_hash` | text | Onayda kullanıcı oluşturmak için |
| `business_name` | varchar(255) | |
| `producer_type` | varchar(50) | |
| `city`, `district`, `village` | varchar | |
| `bio` | text | |
| `product_categories` | jsonb | Kategori slug dizisi |
| `product_examples` | text | |
| `document_urls` | jsonb | URL dizisi |
| `application_video_key` | text nullable | S3 object key |
| `application_video_status` | varchar(20) | `missing` \| `uploaded` \| `requested` \| `not_required` |
| `invite_code_id` | uuid FK → invite_codes nullable | |
| `referred_by_user_id` | uuid FK → users nullable | |
| `application_source` | varchar(20) | `admin_created` \| `admin_invite` \| `farmer_invite` |
| `status` | varchar(20) | `pending` \| `approved` \| `rejected` \| `needs_video` |
| `rejection_reason` | varchar(50) nullable | |
| `reviewed_by` | uuid FK → users nullable | |
| `reviewed_at` | timestamp nullable | |
| `created_at` | timestamp | |
| `updated_at` | timestamp | |

> Unique constraint: `phone` WHERE `status IN ('pending', 'needs_video')`

### `invite_codes`

| Kolon | Tip | Notlar |
|-------|-----|--------|
| `id` | uuid PK | |
| `code` | varchar(20) UNIQUE | Format: KYS-XXXXXX |
| `owner_user_id` | uuid FK → users | |
| `owner_type` | varchar(20) | `admin` \| `farmer` |
| `max_uses` | int | |
| `used_count` | int | default 0 |
| `is_active` | bool | default true |
| `expires_at` | timestamp nullable | NULL = süresiz |
| `created_at` | timestamp | |
| `updated_at` | timestamp | |

### `invitations`

| Kolon | Tip | Notlar |
|-------|-----|--------|
| `id` | uuid PK | |
| `invite_code_id` | uuid FK → invite_codes | |
| `inviter_user_id` | uuid FK → users | |
| `application_id` | uuid FK → farmer_applications nullable | |
| `status` | varchar(20) | `submitted` \| `approved` \| `rejected` |
| `created_at` | timestamp | |
| `updated_at` | timestamp | |

### İlişki Diyagramı

```
users
  ├── farmer_profiles (1:1)
  ├── products (1:N, via farmer_id)
  ├── invite_codes (1:N)
  └── invitations (1:N, via inviter_user_id)

farmer_applications
  ├── invite_codes (N:1)
  └── users (N:1, via referred_by_user_id & reviewed_by)

products
  ├── categories (N:1)
  └── product_images (1:N)

categories
  └── categories (self-ref, parent_id)
```

---

## Bağımlılıklar

### Backend (Go 1.23)

#### Direkt Bağımlılıklar

| Paket | Versiyon | Amaç |
|-------|----------|------|
| `gofiber/fiber/v2` | v2.52.1 | HTTP framework |
| `jmoiron/sqlx` | v1.3.5 | PostgreSQL sorguları (raw SQL) |
| `lib/pq` | v1.10.9 | PostgreSQL driver |
| `redis/go-redis/v9` | v9.5.1 | Redis (OTP, token rotation) |
| `golang-jwt/jwt/v5` | v5.2.1 | JWT üretimi ve doğrulaması |
| `golang-migrate/migrate/v4` | v4.17.0 | Veritabanı migration |
| `aws/aws-sdk-go-v2/service/s3` | v1.51.4 | S3/R2 dosya depolama |
| `go-playground/validator/v10` | v10.19.0 | Request validation |
| `golang.org/x/crypto` | v0.21.0 | bcrypt şifre hash |

#### Dolaylı Bağımlılıklar (Seçilmiş)

| Paket | Amaç |
|-------|------|
| `google/uuid` | UUID üretimi |
| `gabriel-vasile/mimetype` | Dosya tipi tespiti |
| `valyala/fasthttp` | Fiber'ın HTTP alt katmanı |
| `klauspost/compress` | Sıkıştırma (brotli, gzip) |

---

### Flutter (SDK ≥3.3.0 / Flutter ≥3.19.0)

#### Routing & State

| Paket | Versiyon | Amaç |
|-------|----------|------|
| `go_router` | ^14.0.0 | Declarative routing |
| `get` | ^4.6.6 | GetX — state management, DI, navigation |

#### HTTP & Depolama

| Paket | Versiyon | Amaç |
|-------|----------|------|
| `dio` | ^5.4.0 | HTTP client (interceptor + auto-refresh) |
| `flutter_secure_storage` | ^9.0.0 | JWT token güvenli depolama |

#### Medya

| Paket | Versiyon | Amaç |
|-------|----------|------|
| `image_picker` | ^1.0.7 | Galeriden/kameradan fotoğraf seçimi |
| `video_compress` | ^3.1.2 | Başvuru videosu sıkıştırma |
| `cached_network_image` | ^3.3.1 | Görsel önbellekleme |

#### UI

| Paket | Versiyon | Amaç |
|-------|----------|------|
| `fl_chart` | ^0.69.0 | Admin dashboard grafikleri |
| `shimmer` | ^3.0.0 | Yükleme iskeleti animasyonu |
| `flutter_svg` | ^2.0.10 | SVG ikon desteği |

#### Yardımcı

| Paket | Versiyon | Amaç |
|-------|----------|------|
| `intl` | ^0.20.2 | Tarih, saat, para formatı (TR locale) |
| `url_launcher` | ^6.2.5 | Harici link / telefon açma |
| `permission_handler` | ^11.3.0 | Kamera, galeri izin yönetimi |
| `connectivity_plus` | ^6.0.3 | Ağ bağlantısı kontrolü |
| `share_plus` | ^9.0.0 | İçerik paylaşma |

#### Dev Bağımlılıkları

| Paket | Versiyon | Amaç |
|-------|----------|------|
| `flutter_lints` | ^3.0.0 | Lint kuralları |

---

*Son güncelleme: 2026-05-19*
