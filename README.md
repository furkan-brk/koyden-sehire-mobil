# Köyden Şehire

Yerel üreticileri alıcılarla doğrudan buluşturan, komisyonsuz listeme platformu.  
Platform üzerinden ödeme, sipariş, kargo veya uygulama içi mesajlaşma yapılmaz.

---

## Repo Yapısı

```
/
├── backend/          # Go 1.23 REST API (Fiber v2)
├── flutter-mobile/   # Flutter mobil uygulama + web admin paneli
├── docker-compose.yml          # Yerel geliştirme ortamı
└── docker-compose.prod.yml     # Üretim ortamı
```

---

## Hızlı Başlangıç

### 1. Backend (Docker)

```bash
cp .env.example .env       # değerleri düzenle
docker compose up -d       # postgres, redis, minio, n8n, api başlar
```

API hazır olduğunu doğrula:

```bash
curl http://localhost:8080/api/v1/health
# {"status":"ok","database":"ok","redis":"ok","version":"1.0.0"}
```

### 2. Flutter (Mobil)

```bash
cd flutter-mobile
flutter pub get
flutter run                # Android emülatör — varsayılan BASE_URL 10.0.2.2:8080
```

Fiziksel cihaz veya farklı ortam:

```bash
flutter run --dart-define=BASE_URL=http://<ip>:8080/api/v1
```

### 3. Flutter (Web — Admin Paneli)

```bash
cd flutter-mobile
flutter run -d chrome --dart-define=BASE_URL=http://localhost:8080/api/v1
```

---

## Servisler

| Servis | Adres | Kimlik Bilgisi |
|--------|-------|----------------|
| **API** | http://localhost:8080 | — |
| **PostgreSQL** | localhost:**5433** | admin / localpass |
| **Redis** | localhost:6379 | — |
| **MinIO** (S3) | http://localhost:9000 | minioadmin / minioadmin123 |
| **MinIO Konsol** | http://localhost:9001 | minioadmin / minioadmin123 |
| **n8n** | http://localhost:5678 | — |

> ⚠️ PostgreSQL host portu **5433**'tür (container içi 5432 → dış 5433).

### Varsayılan Yönetici Hesabı

| Alan | Değer |
|------|-------|
| Telefon | `05000000000` |
| Şifre | `admin123` |
| Rol | admin (yalnızca web paneli) |

---

## Kullanıcı Rolleri

| Rol | Erişim | Hesap Oluşturma |
|-----|--------|-----------------|
| **Müşteri** | Mobil — ürün keşfet, üretici profili gör | Telefon + OTP ile kayıt |
| **Çiftçi** | Mobil — ürün ekle/yönet, davet gönder | Davet kodu + başvuru + admin onayı |
| **Admin** | Web paneli — başvuru/ürün/çiftçi yönetimi | Sistem tarafından oluşturulur |

---

## API Özeti

Tüm route'lar `/api/v1` önekiyle başlar.

### Public (auth gerektirmez)
| Method | Endpoint | Açıklama |
|--------|----------|----------|
| GET | `/health` | Sağlık kontrolü |
| POST | `/otp/send` | Telefona OTP gönder |
| POST | `/otp/verify` | OTP doğrula |
| POST | `/auth/login` | Giriş → access + refresh token |
| POST | `/auth/refresh` | Token yenile (rotasyon) |
| POST | `/auth/register/customer` | Müşteri kaydı (OTP zorunlu) |
| GET | `/categories` | Kategori ağacı |
| GET | `/products` | Ürün listesi (filtrelenebilir) |
| GET | `/products/:id` | Ürün detayı |
| GET | `/farmers/:id` | Üretici profili |
| GET | `/farmers/:id/products` | Üreticinin ürünleri |
| GET | `/invites/validate?code=KYS-XXX` | Davet kodu doğrulama |

### Çiftçi Başvurusu
| Method | Endpoint | Açıklama |
|--------|----------|----------|
| POST | `/farmer-applications` | Başvuru gönder |
| POST | `/uploads/application-video/presigned-url` | Video yükleme URL'i al |

### Çiftçi Paneli (`/farmer/*` — JWT, role=farmer, status=active)
| Method | Endpoint | Açıklama |
|--------|----------|----------|
| GET/PUT | `/farmer/profile` | Profil oku / güncelle |
| GET/POST | `/farmer/products` | Ürünleri listele / yeni ekle |
| GET/PUT | `/farmer/products/:id` | Ürün detay / güncelle |
| PATCH | `/farmer/products/:id/status` | Stok durumu güncelle |
| GET | `/farmer/invites` | Davet kodlarım |
| POST | `/farmer/uploads/product-image` | Ürün görseli yükle |
| POST | `/farmer/uploads/profile-image` | Profil görseli yükle |

### Admin Paneli (`/admin/*` — JWT, role=admin)
| Method | Endpoint | Açıklama |
|--------|----------|----------|
| GET | `/admin/dashboard` | İstatistikler |
| GET | `/admin/analytics/city-density` | Şehir bazlı çiftçi yoğunluğu |
| GET | `/admin/analytics/invite-network` | Davet ağacı |
| GET/POST | `/admin/applications` | Başvuru listesi |
| POST | `/admin/applications/:id/approve` | Başvuru onayla |
| POST | `/admin/applications/:id/reject` | Başvuru reddet |
| GET | `/admin/farmers` | Çiftçi yönetimi |
| GET | `/admin/products` | Ürün moderasyonu |
| GET/POST/PUT/DELETE | `/admin/categories` | Kategori yönetimi |
| GET | `/admin/audit-logs` | Admin işlem geçmişi |

---

## Davet Kodu Sistemi

- Format: `KYS-XXXXXX` (6 karakterli büyük harf + rakam)
- Özel kod: `KYS-FOUNDER` (50 kullanım hakkı, admin sahipli)
- Onaylanan her çiftçiye varsayılan 2 davet kotası verilir
- Kurucu çiftçiler (Founding Farmer) rozet alır

---

## Flutter Mimarisi

| Katman | Konum | Teknoloji |
|--------|-------|-----------|
| Routing | `lib/app/router.dart` | `go_router` + GoRouter; redirect guard GetX `AuthService.status`'ı izler |
| Auth state | `lib/core/services/auth_service.dart` | `GetxService`; `flutter_secure_storage`'da kalıcı |
| HTTP | `lib/core/api/api_client.dart` | `Dio` + `_AuthInterceptor`; 401 alınca token otomatik yenilenir |
| State / DI | GetX (`Get.lazyPut`, `fenix: true`) | `AppBinding` tüm bağımlılıkları başlangıçta kaydeder |
| Views | `lib/views/` | `admin/`, `auth/`, `farmer/`, `public/`, `customer/` |
| Controllers | `lib/controllers/` | GetxController; rol bazlı alt klasörler |
| Repositories | `lib/services/*_repository.dart` | ApiClient üzerinden HTTP; typed model döner |
| Shared | `lib/shared/widgets/` | AppButton, ProductCard, OtpInput, ShimmerCard… |

**Admin paneli** yalnızca web'de (`kIsWeb == true`) çalışır. Mobil build'de `/admin/*` rotaları kayıtlı değildir.

**API base URL** derleme zamanında `--dart-define=BASE_URL=...` ile enjekte edilir.  
Varsayılan `http://10.0.2.2:8080/api/v1` yalnızca Android emülatörde çalışır.

---

## Backend Mimarisi

```
backend/
├── cmd/api/main.go              ← DI wiring, route kaydı, graceful shutdown
├── internal/
│   ├── admin/                   ← Admin panel; audit log entegrasyonu
│   ├── audit/                   ← Admin işlem geçmişi (immutable log)
│   ├── auth/                    ← JWT, refresh token rotasyonu, müşteri kaydı
│   ├── categories/              ← Hiyerarşik kategori ağacı
│   ├── config/                  ← Env var → Config struct
│   ├── database/                ← PostgreSQL (sqlx) + Redis fabrikaları
│   ├── farmer_applications/     ← Başvuru akışı
│   ├── farmers/                 ← Çiftçi profil operasyonları
│   ├── invites/                 ← Davet kodu sistemi
│   ├── middleware/              ← Auth (JWT), CORS, rate limit
│   ├── notifications/           ← n8n webhook
│   ├── otp/                     ← OTP gönder / doğrula
│   ├── products/                ← Ürün CRUD, dinamik filtreleme
│   ├── uploads/                 ← Presigned URL üretimi
│   └── users/                   ← Profil okuma / güncelleme
├── pkg/
│   ├── errors/                  ← Uygulama hata tipleri
│   ├── response/                ← Fiber yanıt yardımcıları
│   ├── sms/                     ← Twilio + DevProvider (dev'de stdout)
│   └── storage/                 ← Cloudflare R2/S3 + DevProvider
└── migrations/                  ← 000001…000016 golang-migrate SQL
```

**Her domain:** `model.go` → `repository.go` (ham SQL) → `service.go` (iş mantığı) → `handler.go` (HTTP)

### Rate Limiting

| Endpoint | Kapsam | Limit |
|----------|--------|-------|
| `POST /otp/send` | telefon | 3 istek / saat |
| `POST /auth/login` | telefon | 5 istek / 15 dk |
| `POST /auth/login` | IP | 30 istek / 15 dk |
| `POST /auth/register/customer` | telefon | 3 istek / saat |
| `GET /invites/validate` | IP | 20 istek / saat |

### Medya Depolama

Dosyalar API sunucusundan geçmez — presigned URL ile doğrudan R2/MinIO'ya yüklenir:

```
İstemci → POST /uploads/…  → API (presigned URL üretir)
İstemci → PUT <presigned_url>  → R2/MinIO (doğrudan)
```

| Tip | Erişim | Max Boyut |
|-----|--------|-----------|
| Ürün görseli | Public CDN | 5 MB |
| Profil görseli | Public CDN | 2 MB |
| Başvuru videosu | Presigned GET (1 saat) | 100 MB |

---

## Migration'lar

Uygulama başlarken `APP_AUTO_MIGRATE=true` ile otomatik çalışır.  
Manuel çalıştırmak için:

```bash
migrate -path backend/migrations \
  -database "postgres://admin:localpass@localhost:5433/koydensehire?sslmode=disable" up
```

Mevcut migration'lar (000001–000016):
- 000001–000011: Temel şema (users, profiles, products, OTP, raporlar)
- 000012–000014: Seed verisi (admin, kategoriler, kurucu davet kodu)
- 000015: Müşteri rolü
- 000016: Admin audit log tablosu

---

## Geliştirme Notları

- `APP_ENV=development` → OTP kodları SMS yerine terminal'e yazılır
- Storage yapılandırılmamışsa `DevProvider` devreye girer; yükleme işlemleri sessizce başarısız olur
- `SELECT *` kullanılmaz; tüm sorgular sütunları açıkça listeler
- Videolar private: admin izlerken 1 saatlik presigned GET URL üretilir
- Görseller public CDN üzerinden sunulur

---

## Dokümantasyon

| Doküman | İçerik |
|---------|--------|
| [`backend/docs/SYSTEM_OVERVIEW.md`](backend/docs/SYSTEM_OVERVIEW.md) | Sistem mimarisi ve teknik spec (stakeholder odaklı) |
| [`backend/docs/API_REFERENCE.md`](backend/docs/API_REFERENCE.md) | Tüm endpoint listesi, request/response şemaları |
| [`backend/docs/AUTH_FLOW.md`](backend/docs/AUTH_FLOW.md) | OTP + JWT akışı teknik detay |
| [`backend/docs/DATABASE_SCHEMA.md`](backend/docs/DATABASE_SCHEMA.md) | Tablo yapıları ve kısıtlamalar |
| [`backend/docs/AUDIT_LOG_SPEC.md`](backend/docs/AUDIT_LOG_SPEC.md) | Admin audit log teknik tasarımı |
| [`backend/docs/ENVIRONMENT.md`](backend/docs/ENVIRONMENT.md) | Ortam değişkenleri ve production kontrol listesi |
| [`backend/docs/ERROR_FORMAT.md`](backend/docs/ERROR_FORMAT.md) | Hata kodları ve HTTP durum eşleşmesi |
| [`backend/docs/UPLOADS_AND_STORAGE.md`](backend/docs/UPLOADS_AND_STORAGE.md) | Presigned URL yükleme akışı |
| [`backend/docs/MOBILE_INTEGRATION_GUIDE.md`](backend/docs/MOBILE_INTEGRATION_GUIDE.md) | Flutter entegrasyon rehberi |
| [`backend/docs/openapi.yaml`](backend/docs/openapi.yaml) | OpenAPI 3.0 spesifikasyonu |
| [`backend/docs/POSTMAN_COLLECTION.json`](backend/docs/POSTMAN_COLLECTION.json) | Postman koleksiyonu (otomatik token) |
| [`backend/TESTING.md`](backend/TESTING.md) | Uçtan uca curl test rehberi |
| [`CLAUDE.md`](CLAUDE.md) | Claude Code geliştirici rehberi |
