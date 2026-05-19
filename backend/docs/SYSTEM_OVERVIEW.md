# Köyden Şehire — Sistem Mimarisi & Teknik Spec

**Versiyon:** v1.1
**Tarih:** 2026-05-19
**Yazar:** Furkan BERK
**Hedef Kitle:** Teknik olmayan stakeholder'lar, proje ortakları, yöneticiler

---

## 1. Proje Özeti

**Köyden Şehire**, yerel üreticileri (çiftçiler, arıcılar, kooperatifler) tüketicilerle doğrudan buluşturan, **komisyonsuz** bir mobil listeme platformudur. Platform; ödeme, sipariş veya kargo altyapısı sunmaz — yalnızca keşfetme ve iletişim kurma ortamı sağlar.

### Temel Değer Önerisi

| Sorun | Çözüm |
|-------|-------|
| Üreticiler ürünlerini aracısız satamamaktadır | Doğrudan listeleyip alıcıyla iletişim kurar |
| Tüketiciler güvenilir yerel üretici bulamıyor | Davet sistemiyle kalite kontrolü yapılmış üreticiler |
| Pazar yeri komisyonları kazancı eritmektedir | Platform komisyon almaz |

---

## 2. Kullanıcı Rolleri

| Rol | Erişim | Nasıl Olunur |
|-----|--------|--------------|
| **Müşteri (Customer)** | Mobil uygulama — ürünleri keşfet, üretici profilini gör | Telefon + OTP ile kayıt |
| **Çiftçi (Farmer)** | Mobil uygulama — ürün ekle/yönet, profil düzenle, davet gönder | Davet kodu + başvuru + admin onayı |
| **Admin** | Web paneli — başvuruları onayla, ürün modere et, istatistikler | Sistem tarafından oluşturulur |

---

## 3. Yüksek Seviye Mimari

```
┌─────────────────────────────────────────────────────────┐
│                   İstemci Katmanı                        │
│                                                          │
│   ┌─────────────────────┐    ┌────────────────────────┐ │
│   │   Flutter Mobil App  │    │   Flutter Web (Admin)  │ │
│   │  (Android / iOS)     │    │   /admin/* rotaları    │ │
│   └─────────┬───────────┘    └──────────┬─────────────┘ │
└─────────────┼──────────────────────────┼───────────────-┘
              │  HTTPS / REST API         │
              ▼                           ▼
┌─────────────────────────────────────────────────────────┐
│               Go API Sunucusu (Fiber v2)                 │
│           http://api:8080  —  /api/v1/*                  │
│                                                          │
│  Public    │  Farmer (JWT)  │  Admin (JWT)               │
│  ─────────────────────────────────────────────           │
│  /otp      │  /farmer/*     │  /admin/*                  │
│  /auth     │                │                            │
│  /products │                │                            │
│  /farmers  │                │                            │
└──────┬───────────┬──────────────────┬───────────────────-┘
       │           │                  │
       ▼           ▼                  ▼
  ┌─────────┐  ┌───────┐       ┌──────────┐   ┌──────────┐
  │PostgreSQL│  │ Redis │       │ R2/MinIO │   │   n8n    │
  │(Ana DB)  │  │(OTP,  │       │(Medya    │   │(Webhook  │
  │          │  │Token) │       │Depolama) │   │Bildirimi)│
  └─────────┘  └───────┘       └──────────┘   └──────────┘
```

### Teknoloji Seçimleri

| Katman | Teknoloji | Neden |
|--------|-----------|-------|
| Backend dil | Go 1.23 | Düşük bellek tüketimi, yüksek eşzamanlılık |
| Web framework | Fiber v2 | Express benzeri API, Go'nun hızı |
| Veritabanı | PostgreSQL 16 | ACID uyumluluk, güçlü ilişkisel model |
| Cache / OTP depolama | Redis 7 | Hızlı key-value, TTL destekli OTP ve token yönetimi |
| Medya depolama | Cloudflare R2 (prod) / MinIO (dev) | S3 uyumlu, düşük egress maliyeti |
| SMS | Netgsm | Türkiye'de yaygın SMS sağlayıcısı |
| Bildirim akışı | n8n (webhook) | Kodsuz otomasyon; admin bildirimleri |
| Mobil / Web | Flutter (Dart) | Tek kod tabanı: Android, iOS, Web |
| State yönetimi | GetX | Reaktif state + DI + navigasyon |
| Routing | go_router | Deep link desteği, type-safe rotalar |
| HTTP istemcisi | Dio | Interceptor desteği (otomatik token yenileme) |

---

## 4. Backend — Teknik Detaylar

### 4.1 Paket Yapısı

Her domain `internal/<domain>/` altında tam bir dikey dilim olarak organize edilmiştir:

```
backend/
├── cmd/api/main.go              ← Uygulama başlangıcı, DI wiring, route kaydı
├── internal/
│   ├── admin/                   ← Admin panel operasyonları
│   ├── auth/                    ← Login, register, JWT, refresh token
│   ├── categories/              ← Kategori ağacı yönetimi
│   ├── config/                  ← Env var okuma, Config struct
│   ├── database/                ← PostgreSQL (sqlx) ve Redis bağlantı fabrikaları
│   ├── farmer_applications/     ← Başvuru akışı
│   ├── farmers/                 ← Çiftçi profil operasyonları
│   ├── invites/                 ← Davet kodu doğrulama ve listeleme
│   ├── middleware/              ← Auth, rate limit, CORS
│   ├── notifications/           ← n8n webhook servisi
│   ├── otp/                     ← OTP gönder/doğrula
│   ├── products/                ← Ürün CRUD, filtreleme
│   ├── uploads/                 ← Presigned URL üretimi
│   └── users/                   ← Kullanıcı profil okuma/güncelleme
├── pkg/
│   ├── errors/                  ← Uygulama hata tipleri
│   ├── response/                ← Fiber response yardımcıları
│   ├── sms/                     ← Netgsm + DevProvider
│   └── storage/                 ← R2/S3 + DevProvider
└── migrations/                  ← golang-migrate SQL dosyaları (000001…000015)
```

Her domain içindeki dosyalar:
- `model.go` → DB struct'ları (`db:` tag'leri ile)
- `repository.go` → Ham SQL sorguları; `sqlx` ile çalışır
- `service.go` → İş mantığı; repository'yi çağırır
- `handler.go` → Fiber HTTP handler; DTO doğrulama, service çağrısı, yanıt
- `dto.go` → Request/response veri tipleri

**Bağımlılık enjeksiyonu:** DI container kullanılmaz. Tüm bağımlılıklar `main.go` içinde elle oluşturulup birbirine aktarılır. Bu yaklaşım Go ekosistemine uygundur; testlerde mock geçişi arayüz (interface) üzerinden yapılır.

### 4.2 Middleware Zinciri

Her istek aşağıdaki middleware sırasından geçer:

```
[recover] → [logger] → [CORS] → [route handler]
                                       │
                              (korumalı route ise)
                                       │
                              [RequireAuth]       → JWT doğrulama + DB'den kullanıcı çek
                              [RequireRole]       → role == "farmer" veya "admin" kontrolü
                              [RequireActiveUser] → status == "active" kontrolü
```

**`RequireAuth` detayı:**

```go
// 1. Authorization: Bearer <token> header'ı kontrol
// 2. JWT imzasını doğrula (HS256, yalnızca HMAC yöntemi kabul edilir)
// 3. exp claim'i manuel olarak da kontrol et (defense in depth)
// 4. user_id claim'ini oku
// 5. DB'den kullanıcıyı getir — token geçerli ama kullanıcı silinmişse 401
// 6. user_id, role, status'u Fiber context'e locals olarak yaz
```

Bu yapı sayesinde token geçerli olsa bile askıya alınmış hesaplar her istekte reddedilir.

### 4.3 Rate Limiting

Tüm rate limit sayaçları Redis'te tutulur. Anahtarlar `rl:<tip>:<kapsam>` formatındadır.

| Endpoint | Kapsam | Limit |
|----------|--------|-------|
| `POST /otp/send` | telefon başına | 3 istek / saat |
| `POST /otp/send` | IP başına (telefon yoksa) | 3 istek / saat |
| `POST /auth/login` | IP başına | 30 istek / 15 dk |
| `POST /auth/login` | telefon başına | **5 istek / 15 dk** |
| `POST /auth/register/customer` | IP başına | 10 istek / 15 dk |
| `POST /auth/register/customer` | telefon başına | 3 istek / saat |
| `GET /invites/validate` | IP başına | 20 istek / saat |
| `POST /uploads/…/presigned-url` | IP başına | 10 istek / saat |
| `POST /uploads/…/presigned-url` | telefon başına | 5 istek / saat |

Login endpoint'i çift kapsam (IP + telefon) kullanır: IP limiti NAT arkasındaki büyük ağları korur (kampüs, ofis), telefon limiti ise tek hesaba kaba kuvvet saldırısını engeller.

### 4.4 Veritabanı & Sorgu Katmanı

- Tüm tablolarda UUID primary key (`gen_random_uuid()`)
- Tüm timestamp'ler UTC timezone'suz (`timestamp without time zone`)
- ORM kullanılmaz; ham SQL `sqlx` ile çalışır; struct mapping `db:` tag'leriyle yapılır
- `SELECT *` kullanılmaz; tüm sorgular sütunları açıkça listeler — alan kayması sessizce gerçekleşmez

**Ürün filtreleme sorgusu (dinamik WHERE):**

`ListPublic` metodu, aktif filtre sayısına göre parametre listesini büyütür:

```go
// Kök kategori seçildiğinde alt kategorileri de kapsar
if parentID == nil {
    subIDs := alt kategorileri getir
    conditions = append(conditions, "p.category_id IN (...)")
}
// Yaprak kategori seçildiğinde doğrudan eşleşir
```

Bu sayede "Meyve & Sebze" seçildiğinde "Domates", "Elma" gibi alt kategorilerdeki ürünler de listelenir.

### 4.5 Medya Depolama — Presigned URL Akışı

Medya dosyaları hiçbir zaman API sunucusundan geçmez; istemci doğrudan depolama katmanına (R2/MinIO) yükler:

```
İstemci                    API Sunucusu              Cloudflare R2
   │                            │                         │
   │  POST /farmer/uploads/…    │                         │
   │ ────────────────────────→  │                         │
   │                            │  Presigned PUT URL üret │
   │                            │ ──────────────────────→ │
   │                            │ ←────────────────────── │
   │  { upload_url, key }       │                         │
   │ ←───────────────────────── │                         │
   │                            │                         │
   │  PUT <upload_url> (dosya)  │                         │
   │ ────────────────────────────────────────────────────→│
   │  200 OK                    │                         │
   │ ←────────────────────────────────────────────────────│
   │                            │                         │
   │  POST /farmer/products     │                         │
   │  { image_urls: [key] }     │                         │
   │ ────────────────────────→  │                         │
```

**Depolama key desenleri:**

| Dosya tipi | Desen | Erişim |
|-----------|-------|--------|
| Ürün görseli | `products/images/{farmer_id}/{timestamp}.{ext}` | Public CDN |
| Profil görseli | `profiles/{user_id}/{timestamp}.{ext}` | Public CDN |
| Başvuru videosu (beklemede) | `application-videos/pending/{phone}/{timestamp}.mp4` | Private |
| Başvuru videosu (onaylı) | `application-videos/approved/{application_id}.mp4` | Private |

Videolar private'tır — admin izlemek istediğinde API 1 saatlik presigned GET URL üretir.

**Presigned URL süreleri:** PUT URL'leri 15 dakika, admin GET URL'leri 1 saat geçerlidir.

---

## 5. Kimlik Doğrulama — Tam Teknik Akış

### 5.1 JWT Yapısı

```json
{
  "user_id": "uuid-string",
  "role":    "admin | farmer | customer",
  "exp":     1234567890,
  "iat":     1234567890
}
```

- İmzalama: **HS256** (HMAC-SHA256)
- Yalnızca HMAC metodu kabul edilir (`WithValidMethods(["HS256"])`) — algoritma karışıklığı saldırısını engeller
- Erişim token süresi: `JWT_ACCESS_TOKEN_EXPIRY` env'den (varsayılan: 24 saat)

### 5.2 Refresh Token Sistemi

Refresh token'lar JWT değildir; 64 karakterlik kriptografik olarak rastgele hex string'lerdir:

```
issueRefreshToken():
  1. crypto/rand ile 32 byte rastgele veri üret
  2. hex.EncodeToString ile stringe çevir → 64 karakter
  3. Redis'e kaydet: refresh_token:{token} → user_id  (TTL: yapılandırılabilir)
  4. Token'ı istemciye döndür
```

**Token Rotasyonu:** Her `/auth/refresh` çağrısında:
1. Eski refresh token Redis'ten silinir
2. Yeni access token + refresh token çifti üretilir
3. Kullanılmış token tekrar kullanılamaz

### 5.3 OTP Mekanizması

```
Redis key yapısı:
  otp:{phone}           → "KOD:DENEME_SAYISI"    (TTL: 300 sn)
  otp_verified:{phone}  → "1"                     (TTL: 1800 sn)
  otp_send_cooldown:{phone} → "1"                 (TTL: cooldown süresi)
```

OTP akışı:

```
POST /otp/send
  → Cooldown kontrolü (Redis)
  → 6 haneli kod üret
  → Redis'e kaydet (TTL 5 dk, deneme sayısı: 0)
  → dev: stdout'a yaz | prod: Netgsm'e gönder

POST /otp/verify
  → otp:{phone} Redis'ten oku
  → Kod eşleşiyorsa: otp_verified:{phone} = "1" (TTL 30 dk) yaz, OTP sil
  → Kod yanlışsa: deneme sayısını artır
  → Deneme sayısı ≥ 3 ise: OTP'yi sil (MAX_ATTEMPTS hatası)
```

30 dakikalık `otp_verified` penceresi: müşteri kaydı veya çiftçi başvurusu bu süre içinde tamamlanmalıdır. Süre geçerse OTP adımı tekrarlanır.

### 5.4 Çiftçi Başvuru Akışı — Adım Adım

```
1. GET  /invites/validate?code=KYS-XXXXXX
         → is_active=true, used_count < max_uses, expires_at kontrolü

2. POST /otp/send  { phone }
3. POST /otp/verify { phone, code }
         → Redis'te otp_verified:{phone} = "1" oluşur

4. POST /uploads/application-video/presigned-url
         → Opsiyonel; video yüklenecekse presigned PUT URL alınır

5. POST /farmer-applications  { tüm form alanları + invite_code + video_key }
         → otp_verified:{phone} kontrolü
         → invite_code doğrulama + used_count artışı
         → farmer_applications tablosuna kayıt (status=pending)
         → otp_verified:{phone} Redis'ten silindi

6. Admin: POST /admin/applications/:id/approve
         → users tablosuna yeni satır (role=farmer, status=active)
         → farmer_profiles tablosuna profil satırı
         → invite_codes tablosuna çiftçinin kotası kadar yeni kod
         → n8n webhook ile bildirim tetiklenir
         → application.status = "approved"

7. POST /auth/login { phone, password }
         → access_token + refresh_token döner
```

### 5.5 Müşteri Kayıt Akışı

```
POST /otp/send  { phone }
POST /otp/verify { phone, code }
POST /auth/register/customer { phone, full_name, email, password }
  → otp_verified:{phone} Redis'ten kontrol ve SİL (tek kullanım)
  → bcrypt ile şifre hash'lenir (maliyet: 12)
  → users tablosuna role=customer, status=active olarak kayıt
  → access_token + refresh_token döner
```

---

## 6. Flutter Mobil — Teknik Detaylar

### 6.1 Katman Yapısı

```
flutter-mobile/lib/
├── main.dart                    ← AppBinding başlatır, GoRouter'ı ayarlar
├── app/
│   ├── app.dart                 ← MaterialApp.router
│   ├── router.dart              ← GoRouter tanımı + redirect mantığı
│   ├── theme.dart               ← Renk paleti, metin stilleri (PlusJakartaSans)
│   └── constants.dart           ← BASE_URL, timeout, boyut limitleri
├── core/
│   ├── api/api_client.dart      ← Dio wrapper; tüm HTTP çağrıları buradan
│   ├── api/api_endpoints.dart   ← Endpoint sabit stringleri
│   ├── services/auth_service.dart   ← Global auth state (GetxService)
│   ├── services/connectivity_service.dart
│   ├── storage/secure_storage_service.dart  ← Token + kullanıcı bilgisi
│   ├── errors/                  ← AppException + DioException eşleme
│   └── utils/                   ← Tarih, telefon, validasyon yardımcıları
├── bindings/
│   └── app_binding.dart         ← Uygulama geneli DI: core + tüm repolar + controllerlar
├── controllers/                 ← GetxController; rol bazlı alt klasörler
│   ├── admin/
│   ├── farmer/
│   └── public/
├── services/                    ← *_repository.dart; ApiClient üzerinden HTTP çağrıları
├── models/                      ← fromJson ile Dart modelleri; rol bazlı alt klasörler
├── views/                       ← Ekran widget'ları + alt widget'lar
│   ├── admin/
│   ├── auth/
│   ├── customer/
│   ├── farmer/
│   ├── farmer_application/
│   ├── otp/
│   ├── public/
│   └── splash/
└── shared/
    ├── widgets/                 ← AppButton, ProductCard, OtpInput, ShimmerCard…
    ├── extensions/              ← BuildContext, String uzantıları
    └── models/pagination_model.dart
```

### 6.2 Bağımlılık Enjeksiyonu (GetX)

`AppBinding.dependencies()` uygulama başladığında tek seferinde çalışır:

```
Kalıcı (permanent: true):
  SecureStorageService → AuthService → ConnectivityService → ApiClient
      ↑                                                          │
      └──────────────────────────────────────────────────────────┘
         (ApiClient, 401 alınca AuthService.handleUnauthorized() çağırır)

Lazy + fenix (ilk kullanımda oluşur, silinirse yeniden oluşturulur):
  *Repository sınıfları  →  *Controller sınıfları
```

`fenix: true` parametresi, bir ekrandan çıkıldığında GetX controller'ı temizlese bile sonraki girişte aynı fabrika ile yeniden oluşturulmasını sağlar.

### 6.3 Router & Auth Guard

`GoRouter` redirect fonksiyonu, `AuthService.status` değiştiğinde otomatik tetiklenir:

```dart
// _RouterRefreshListenable:
//   GetX ever() worker → AuthService.status değiştiğinde
//   → ChangeNotifier.notifyListeners() çağırır
//   → GoRouter redirect'i yeniden değerlendirir

Durum → Yönlendirme kuralı
─────────────────────────────────────────────────────
admin          → /admin/dashboard (admin harici rotalar izin verilmez)
farmerActive   → /farmer/dashboard (auth/register rotaları engellenir)
customerActive → public rotalar + /customer/* serbest; /farmer/* ve /admin/* engellenir
loggedOut      → /farmer/* ve /admin/* → /login'e yönlendirilir
```

Admin paneli (`/login/admin`, `/admin/*`) yalnızca `kIsWeb == true` olduğunda rota olarak kaydedilir. Mobil build'de bu rotalar tanımlı değildir; doğrudan gezinme girişimi 404 builder'a düşer.

### 6.4 HTTP İstemcisi — Dio + Auth Interceptor

`ApiClient` tüm HTTP metodlarını tek noktadan yönetir:

```
İstek:
  onRequest interceptor → token'ı SecureStorage'dan oku
                        → Authorization: Bearer <token> ekle

Yanıt 401 alınırsa:
  1. Bu zaten bir /auth/refresh çağrısıysa → clearAll + onUnauthorized() (sonsuz döngüyü kes)
  2. Refresh token yoksa → clearAll + onUnauthorized()
  3. Aksi hâlde:
     a. POST /auth/refresh { refresh_token }
     b. Yeni access_token + refresh_token'ı kaydet
     c. Orijinal isteği yeni token ile tekrarla → handler.resolve(retryResponse)
     d. Başarısız olursa → clearAll + onUnauthorized()

onUnauthorized() → AuthService.handleUnauthorized() → status = loggedOut → GoRouter /login'e yönlendirir
```

### 6.5 API Base URL Yapılandırması

URL derleme zamanında `--dart-define` ile enjekte edilir:

```bash
# Android emülatörü (varsayılan — host loopback)
flutter run
# BASE_URL = http://10.0.2.2:8080/api/v1

# Fiziksel cihaz veya özel ortam
flutter run --dart-define=BASE_URL=http://192.168.1.x:8080/api/v1

# Production release
flutter build apk --dart-define=BASE_URL=https://api.koydensehire.com/api/v1
```

`AppConstants.isDevDefaultBaseUrl` kontrolü ile production build'in geliştirme URL'iyle yayınlanması önlenebilir.

---

## 7. Veri Modeli

### 7.1 Şema Diyagramı

```
users
  id (PK, uuid)
  full_name, phone (UNIQUE), email (UNIQUE, nullable)
  password_hash (bcrypt-12), role, status
  phone_verified, phone_verified_at
     │
     ├── farmer_profiles (1:1, user_id FK)
     │     display_name, producer_type, city/district/village
     │     bio, profile_image_url, public_phone, show_phone
     │     is_verified, is_founding_farmer, invite_quota (default:2)
     │          │
     │          └── invite_codes (N, owner_user_id FK)
     │                code (UNIQUE, KYS-XXXXXX format)
     │                owner_type, max_uses, used_count
     │                is_active, expires_at (nullable)
     │                     │
     │                     └── invitations (N, invite_code_id FK)
     │                           inviter_user_id, application_id
     │                           status: submitted|approved|rejected
     │
     └── products (N, farmer_id FK)
           title, description, price (numeric 10,2), unit
           city, district, village
           status: pending|active|rejected|hidden
           stock_status: available|out_of_stock|limited
           admin_note, previous_status
                │
                └── product_images (N, product_id FK)
                      image_url (full CDN URL), sort_order

farmer_applications (bağımsız — onayda users'a dönüşür)
  full_name, phone, email, password_hash
  business_name, producer_type, city/district/village, bio
  product_categories (jsonb), document_urls (jsonb)
  application_video_key, application_video_status
  invite_code_id (FK), referred_by_user_id (FK)
  kvkk_accepted, platform_terms_accepted
  declares_own_production, declares_accurate_location, declares_not_intermediary
  status: pending|approved|rejected|needs_video
  rejection_reason, admin_note, reviewed_by, reviewed_at

categories (öz-referanslı ağaç)
  name, slug (UNIQUE), parent_id (nullable, FK → self)
  icon, sort_order, is_active
```

### 7.2 Önemli Kısıtlamalar

- `farmer_applications.phone` üzerinde koşullu unique: `WHERE status IN ('pending', 'needs_video')` — aynı telefonla birden fazla aktif başvuru yapılamaz
- `products.status` değişim akışı: `pending → active` (admin onayı), `active → hidden` (admin gizleme), `active/hidden → rejected`
- `farmer_applications.password_hash` başvuruda saklanır; onayda `users` tablosuna taşınır — başvurucu şifreyi başvuru aşamasında belirler

---

## 8. API Tasarım İlkeleri

### 8.1 Yanıt Formatı

Tüm endpoint'ler tutarlı bir zarfla yanıt verir:

```json
// Başarı
{ "success": true,  "data": { ... } }

// Hata
{ "success": false, "error": { "code": "HATA_KODU", "message": "Türkçe açıklama" } }
```

Hata kodları makine tarafından işlenebilir sabitlerdir:

| Kategori | Örnek Kodlar |
|----------|-------------|
| Auth | `UNAUTHORIZED`, `INVALID_CREDENTIALS`, `ACCOUNT_SUSPENDED` |
| OTP | `OTP_EXPIRED`, `INVALID_CODE`, `MAX_ATTEMPTS`, `COOLDOWN_ACTIVE` |
| Davet | `INVALID_CODE_FORMAT`, `CODE_EXPIRED` |
| Başvuru | `BAD_REQUEST`, `CONFLICT` |
| Genel | `NOT_FOUND`, `INTERNAL_ERROR` |

### 8.2 HTTP Durum Kodu Eşleşmesi

| Kod | Anlam |
|-----|-------|
| 200 | OK |
| 201 | Oluşturuldu |
| 400 | Geçersiz istek (doğrulama, format hatası) |
| 401 | Kimlik doğrulama gerekli (eksik/geçersiz token) |
| 403 | Yetersiz rol veya hesap askıda |
| 404 | Kaynak bulunamadı |
| 409 | Çakışma (zaten kayıtlı telefon/e-posta) |
| 429 | Rate limit aşıldı |
| 500 | Sunucu hatası |

---

## 9. Güvenlik Mimarisi

| Alan | Uygulama | Detay |
|------|----------|-------|
| Şifre hashleme | bcrypt | Maliyet: 12 (~300 ms/hash) |
| JWT imzalama | HS256 | Sadece HMAC; algoritma karışıklığı saldırısına karşı korumalı |
| JWT ömrü | Yapılandırılabilir | Varsayılan: 24 saat |
| Refresh token | 64 karakter hex | Redis'te saklanır; her kullanımda rotatlanır |
| OTP | 6 haneli | 5 dk TTL; 3 yanlış denemede geçersiz |
| OTP doğrulama penceresi | 30 dk | Müşteri kaydı veya başvuru bu sürede tamamlanmalı |
| Mobil depolama | flutter_secure_storage | Cihazın güvenli enclave'ı (Keychain/Keystore) |
| Medya erişimi | Public / Presigned | Görseller CDN'den public; videolar 1h presigned GET |
| CORS | Yapılandırılabilir | `APP_CORS_ORIGINS` env; production'da kısıtlı |
| Rate limiting | Redis tabanlı | Çift kapsam (IP + telefon); tablo §4.3'te |
| Middleware derinliği | Defense in depth | `exp` claim hem jwt kütüphanesi hem elle doğrulanır; kullanıcı her istekte DB'den çekilir |

---

## 10. Geliştirme & Üretim Ortamları

### 10.1 Yerel Geliştirme

```bash
# Tüm servisleri başlat (postgres:5433, redis:6379, minio:9000/9001, n8n:5678, api:8080)
docker compose up -d

# Health kontrolü
curl http://localhost:8080/api/v1/health

# Flutter (Android emülatör)
cd flutter-mobile && flutter run
```

**Geliştirme kolaylıkları:**
- `APP_ENV=development` → OTP kodları SMS yerine terminal'e yazdırılır
- Storage yapılandırılmamışsa `DevProvider` devreye girer; presigned URL'ler boş string döner (yükleme işlemleri sessizce başarısız olur)
- `APP_AUTO_MIGRATE=true` ile uygulama başlarken migration'lar otomatik çalışır

### 10.2 Üretim Ortamı

| Servis | Bileşen |
|--------|---------|
| API | Docker container (Dockerfile: `backend/Dockerfile`) |
| Veritabanı | Yönetilen PostgreSQL (Supabase, RDS vb.) |
| Cache | Yönetilen Redis |
| Medya | Cloudflare R2 |
| SMS | Netgsm (Türkiye) |
| Flutter derleme | `--dart-define=BASE_URL=https://api.koydensehire.com/api/v1` |

Production gereksinimler (`ENVIRONMENT.md`'den):
- `JWT_SECRET` → minimum 32 karakter rastgele string
- `APP_CORS_ORIGINS` → yalnızca izin verilen origin'ler
- `APP_ENV=production` → hassas veri log'lanmaz
- Gerçek `STORAGE_*` ve `SMS_*` yapılandırmaları zorunludur

---

## 11. Ölçeklenebilirlik Notları

- **API Stateless:** Go API sunucusu oturum durumu tutmaz; tüm geçici durum Redis'te, kalıcı durum PostgreSQL'dedir → yatay ölçekleme (birden fazla instance) doğrudan desteklenir
- **Medya bypass:** Dosya yüklemeleri API sunucusunu atlar, doğrudan R2'ye gider → bandwidth ve bellek baskısı sıfır
- **Kategori sorgusu:** Kök kategori filtrelemesi alt kategori ID'lerini dinamik olarak toplar; cache katmanı eklenmesi düşük eforla yapılabilir
- **DB bağlantı havuzu:** `DATABASE_MAX_CONNECTIONS` ve `DATABASE_MAX_IDLE` env ile yapılandırılır

---

## 12. Açık Konular & Planlanan Geliştirmeler

| Konu | Durum | Not |
|------|-------|-----|
| Push bildirim (FCM/APNs) | Planlanmadı | n8n webhook ile kısmi karşılanıyor |
| Ürün favori / kaydet | Backlog | Müşteri özelliği |
| Kategori/ürün önbelleği | Backlog | Redis ile düşük efor |
| Çiftçi-müşteri mesajlaşma | Kapsam dışı | Platform tasarım kararı |
| iOS TestFlight dağıtımı | Planlı | Flutter build hazır |
| Arama tam metin (FTS) | Backlog | Şu an ILIKE; pg_trgm ile geliştirilebilir |
| Admin log / audit trail | Eksik | Kim ne zaman onayladı kayıt altında değil |

---

## 13. Dokümantasyon Referansları

| Doküman | İçerik |
|---------|--------|
| [`AUTH_FLOW.md`](AUTH_FLOW.md) | OTP ve JWT akışı teknik detay |
| [`API_REFERENCE.md`](API_REFERENCE.md) | Tüm endpoint listesi |
| [`DATABASE_SCHEMA.md`](DATABASE_SCHEMA.md) | Tablo yapıları ve kısıtlamalar |
| [`ENVIRONMENT.md`](ENVIRONMENT.md) | Ortam değişkenleri ve production kontrol listesi |
| [`ERROR_FORMAT.md`](ERROR_FORMAT.md) | Hata kodları ve HTTP durum eşleşmesi |
| [`UPLOADS_AND_STORAGE.md`](UPLOADS_AND_STORAGE.md) | Presigned URL yükleme akışı |
| [`MOBILE_INTEGRATION_GUIDE.md`](MOBILE_INTEGRATION_GUIDE.md) | Flutter entegrasyon rehberi |
| [`openapi.yaml`](openapi.yaml) | OpenAPI 3.0 spesifikasyonu |
| [`POSTMAN_COLLECTION.json`](POSTMAN_COLLECTION.json) | Test koleksiyonu |
| [`../TESTING.md`](../TESTING.md) | Uçtan uca curl test rehberi |

---

*Bu doküman projenin anlık teknik durumunu yansıtır. Büyük mimari değişikliklerde güncellenmelidir.*
