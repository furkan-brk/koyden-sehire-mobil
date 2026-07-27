# Köyden Şehire — Sistem Mimarisi & Teknoloji Seçimleri

Bu doküman, **Köyden Şehire** projesinin katmanlı sistem mimarisini, teknik altyapısını ve depo (repository) klasör yapısını detaylandırır.

---

## 1. Yüksek Seviye Mimari Şeması

Proje, istemci-sunucu (Client-Server) modeline dayanır ve tamamen **stateless (durumsuz)** bir REST API aracılığıyla haberleşir.

```
┌─────────────────────────────────────────────────────────────────┐
│                        İSTEMCİ KATMANI                          │
│                                                                 │
│   ┌───────────────────────────┐    ┌────────────────────────┐   │
│   │     Flutter Mobil App     │    │   Flutter Web (Admin)  │   │
│   │  (Android / iOS / Müşteri)│    │   (Yönetici Paneli)    │   │
│   └─────────────┬─────────────┘    └───────────┬────────────┘   │
└─────────────────┼──────────────────────────────┼────────────────┘
                  │  HTTPS / REST API            │
                  ▼                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                  GO API SUNUCUSU (Fiber v2)                     │
│                  http://localhost:8080                          │
│                                                                 │
│  [Middleware]: CORS, Rate Limiter, JWT Auth & Role Check        │
│                                                                 │
│     ┌──────────────────┬───────────────────┬────────────────┐   │
│     │   Public Rotalar │  Çiftçi Rotaları  │ Admin Rotaları │   │
│     │   /api/v1/...    │  /api/v1/farmer/* │ /api/v1/admin/*│   │
│     └────────┬─────────┘        └─────┬─────┘        └────┬─────┘   │
└──────────────┼────────────────────────┼───────────────────┼─────┘
               ▼                        ▼                   ▼
┌─────────────────────────────────────────────────────────────────┐
│                         VERİ KATMANI                            │
│                                                                 │
│   ┌────────────┐     ┌───────────┐     ┌───────────┐   ┌───────┐│
│   │ PostgreSQL │     │   Redis   │     │ MinIO/R2  │   │  n8n  ││
│   │ (Ana Veri) │     │ (OTP/Token│     │  (Medya   │   │(Bildir││
│   │            │     │  Caching) │     │ Depolama) │   │  im)  ││
│   └────────────┘     └───────────┘     └───────────┘   └───────┘│
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Teknoloji Seçimleri ve Gerekçeleri

### Backend (Sunucu)
* **Go 1.23:** Yüksek eşzamanlılık (concurrency) performansı, minimal CPU/RAM tüketimi ve hızlı derleme süreleri nedeniyle seçilmiştir.
* **Fiber v2:** Express.js benzeri sade API tasarımı sunan, Go tabanlı en hızlı HTTP framework'lerinden biridir.
* **SQLX:** Geliştiricinin SQL sorguları üzerinde tam kontrol sahibi olmasını sağlayan, ORM'lerin yavaşlığından uzak, hafif bir SQL wrapper aracıdır.
* **Redis 7:** Kısa ömürlü OTP (Tek Kullanımlık Şifre) kodları, rate-limit sayaçları ve JWT refresh token'ların hızlı takibi için önbellek (in-memory) katmanı olarak kullanılır.
* **Cloudflare R2 (S3 Uyumlu):** Trafik çıkış ücreti (egress fee) olmaması ve yüksek hızlı CDN entegrasyonu sunması sebebiyle üretim ortamı medya depolama çözümü olarak seçilmiştir. Yerel geliştirmede **MinIO** (dockerized) ile taklit edilir.
* **n8n:** Yönetimsel olayları (yeni çiftçi başvurusu, onay vb.) Slack veya e-posta gibi kanallara bildirmek için kullanılan hafif bir iş akışı otomasyon aracıdır.

### Frontend (İstemci)
* **Flutter & Dart (SDK ≥3.3.0):** Tek bir kod tabanından hem Android/iOS mobil uygulamalarını hem de web tabanlı Admin Panelini derleyebilmek için tercih edilmiştir.
* **GetX:** Reaktif state yönetimi, bağımlılık enjeksiyonu (dependency injection) ve kolay rota yönetimi sağlayan hafif bir pakettir.
* **go_router:** Flutter ekosisteminde declarative yönlendirme sunan, deep linking ve web url parametrelerini en iyi yöneten yönlendiricidir.
* **Dio:** HTTP istekleri için zengin interceptor (ara yazılım) desteği sunar. 401 (Unauthorized) hatalarında token yenileme (silent refresh) işlemini otomatikleştirir.

---

## 3. Depo (Repository) Klasör Yapısı

```
/
├── backend/                    # Go REST API Projesi
│   ├── cmd/
│   │   └── api/
│   │       └── main.go         # Uygulama giriş noktası (Wire-up & Rotalar)
│   ├── internal/               # İş mantığının (Domain) bulunduğu katman
│   │   ├── admin/              # Admin operasyonları
│   │   ├── audit/              # Admin Audit Log sistemi
│   │   ├── auth/               # JWT ve Kayıt işlemleri
│   │   ├── categories/         # Kategori ağacı
│   │   ├── config/             # Çevre değişkenleri okuyucu
│   │   ├── database/           # DB ve Redis bağlantı yöneticileri
│   │   ├── farmer_applications/ # Başvuru süreçleri
│   │   ├── farmers/            # Çiftçi profili yönetimi
│   │   ├── invites/            # Davet kodları
│   │   ├── middleware/         # Auth, Rate-Limit ve CORS ara yazılımları
│   │   ├── notifications/      # n8n webhook istemcisi
│   │   ├── otp/                # OTP oluşturma ve doğrulama
│   │   ├── products/           # Ürün CRUD ve Filtreleme
│   │   ├── uploads/            # Presigned URL servisleri
│   │   └── users/              # Genel kullanıcı işlemleri
│   ├── pkg/                    # Harici/Paylaşılan paketler (Providers)
│   │   ├── errors/             # Uygulama hata yapıları
│   │   ├── response/           # HTTP yanıt şablonları
│   │   ├── sms/                # Twilio SMS servisi & DevProvider stub
│   │   └── storage/            # S3/R2 depolama servisi & DevProvider stub
│   ├── migrations/             # golang-migrate SQL şemaları (000001 - 000016)
│   └── docs/                   # Detaylı backend teknik dokümanları
│
├── flutter-mobile/             # Flutter Mobil ve Web Admin Paneli
│   ├── lib/
│   │   ├── app/                # Tema, Rotalar ve Sabitler
│   │   ├── core/               # API İstemcisi, Güvenli Depolama ve Servisler
│   │   ├── bindings/           # GetX Dependency Injection dosyaları
│   │   ├── controllers/        # GetxController'lar (admin, farmer, public)
│   │   ├── services/           # Repository'ler (Thin API Wrappers)
│   │   ├── models/             # Dart veri modelleri (JSON serializers)
│   │   ├── views/              # Ekran tasarımları (UI widget'ları)
│   │   └── shared/             # Ortak kullanılan widget ve yardımcılar
│   └── pubspec.yaml            # Flutter paket bağımlılıkları
│
├── docker-compose.yml          # Yerel geliştirme ortamı docker yapılandırması
├── docker-compose.prod.yml     # Üretim ortamı docker yapılandırması
└── .env                        # Çevre değişkenleri dosyası
```

---

## 4. Yerel Geliştirme Ortamı ve Servisler

Yerel geliştirme ortamı tamamen `docker-compose.yml` üzerinden ayağa kaldırılır.

### Docker Servis Matrisi

| Servis | Container İçi Port | Ana Bilgisayar Portu | Kimlik Bilgisi (Default Dev) |
| :--- | :--- | :--- | :--- |
| **Go API** | `8080` | `8080` | Yok |
| **PostgreSQL** | `5432` | **`5433`** | `admin` / `localpass` (DB: `koydensehire`) |
| **Redis** | `6379` | `6379` | Yok |
| **MinIO (S3)** | `9000` | `9000` | Access: `minioadmin` / Secret: `minioadmin123` |
| **MinIO Console**| `9001` | `9001` | Web Arayüzü Yönetici Bilgileri |
| **n8n** | `5678` | `5678` | Yok |

> [!WARNING]
> PostgreSQL çakışmalarını önlemek için ana bilgisayar (host) portu **`5433`** olarak eşlenmiştir. Dış araçlardan bağlanırken bu porta dikkat edilmelidir.

---

## Bağlantılı Dosyalar
- [01_PROJECT_OVERVIEW.md](file:///c:/Projeler/koyden-sehire-mobil/docs/gemini/01_PROJECT_OVERVIEW.md)
- [03_DATABASE_SCHEMA.md](file:///c:/Projeler/koyden-sehire-mobil/docs/gemini/03_DATABASE_SCHEMA.md)
- [CLAUDE.md](file:///c:/Projeler/koyden-sehire-mobil/CLAUDE.md)
- [README.md](file:///c:/Projeler/koyden-sehire-mobil/README.md)
