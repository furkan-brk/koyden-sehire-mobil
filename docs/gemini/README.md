# Köyden Şehire — Gemini Bilgi Bankası Dizini (Knowledge Base Index)

Bu klasör, **Köyden Şehire** projesini bir Gemini Gem'ine (Özel Chatbot) veya herhangi bir yapay zeka modeline öğretmek, bağlam (context) olarak sunmak amacıyla hazırlanmış modüler teknik dokümanları içerir.

Proje üzerinde kod geliştirme, hata çözme veya planlama yaparken bu dokümanları yapay zekaya kaynak bilgi olarak yükleyebilirsiniz.

---

## Doküman Listesi ve Kapsamları

Aşağıdaki linkler üzerinden projenin farklı alanlarındaki teknik detaylara hızlıca ulaşabilirsiniz:

### 1. [01_PROJECT_OVERVIEW.md](file:///c:/Projeler/koyden-sehire-mobil/docs/gemini/01_PROJECT_OVERVIEW.md) — Proje Genel Bakış & Kullanıcı Rolleri
* Projenin temel iş modeli ve değer önerisi.
* Platform kuralları (sepet, ödeme ve kargo olmaması, doğrudan telefonla iletişim).
* **Müşteri (Customer)**, **Çiftçi (Farmer)** ve **Yönetici (Admin)** rollerinin yetki matrisi.

### 2. [02_ARCHITECTURE.md](file:///c:/Projeler/koyden-sehire-mobil/docs/gemini/02_ARCHITECTURE.md) — Sistem Mimarisi & Teknoloji Seçimleri
* Yüksek seviye sistem mimari şeması.
* Kullanılan diller, kütüphaneler ve veri depoları (Go, Fiber, Postgres, Redis, R2/MinIO, Flutter, GetX).
* Deponun (repository) klasör yapısı.
* Docker local geliştirme ortamı ayarları ve default dev şifreleri.

### 3. [03_DATABASE_SCHEMA.md](file:///c:/Projeler/koyden-sehire-mobil/docs/gemini/03_DATABASE_SCHEMA.md) — Veritabanı Şeması & SQL Kısıtlamaları
* Tablo detayları, veri tipleri, varsayılan değerler ve kısıtlamalar.
* UUID birincil anahtarlar ve UTC zaman damgası kuralları.
* Koşullu benzersiz telefon kısıtlaması (conditional unique index) ve ON DELETE silme davranışları.

### 4. [04_AUTH_AND_OTP_FLOW.md](file:///c:/Projeler/koyden-sehire-mobil/docs/gemini/04_AUTH_AND_OTP_FLOW.md) — Kimlik Doğrulama & OTP Akışı
* İki aşamalı doğrulama: OTP doğrulaması ve JWT yetkilendirmesi.
* Redis tabanlı OTP TTL (ömür) yönetimi ve rate-limiter hız sınırlama kuralları.
* **JWT Access Token** ve **Kriptografik Refresh Token Rotasyonu** mimarisi.
* Çiftçi başvuru ve müşteri kayıt akışlarının adım adım diyagramı.

### 5. [05_UPLOADS_AND_STORAGE.md](file:///c:/Projeler/koyden-sehire-mobil/docs/gemini/05_UPLOADS_AND_STORAGE.md) — Dosya Yükleme & Medya Depolama
* Direct-to-S3: API sunucusunu meşgul etmeden doğrudan S3/R2'ye presigned URL ile yükleme.
* Ürün resimleri, profil resimleri ve başvuru videolarının bucket dizin yerleşim kuralları.
* Güvenlik: Admin için başvuru videolarında anlık 1 saatlik GET presigned URL oluşturulması.

### 6. [06_FLUTTER_MOBILE.md](file:///c:/Projeler/koyden-sehire-mobil/docs/gemini/06_FLUTTER_MOBILE.md) — Flutter Mobil & Web Mimarisi
* Flutter katmanları, GetX Durum Yönetimi ve DI (AppBinding fenix/permanent) yapısı.
* `go_router` yönlendirme ve GetX auth state listener ile otomatik yönlendirme (Guard) mantığı.
* Dio Interceptor ile `401` hatalarında arka planda sessiz token yenileme (silent refresh) mekanizması.
* Derleme zamanında `--dart-define` ile API base URL enjeksiyonu.

### 7. [07_ADMIN_AUDIT_LOGS.md](file:///c:/Projeler/koyden-sehire-mobil/docs/gemini/07_ADMIN_AUDIT_LOGS.md) — Admin Audit Log Sistemi
* Loglama kuralları ve kapsam dışı bırakılan işlemler.
* Admin log tablosu yapısı ve JSONB nesne snapshotting stratejisi.
* Performans için veritabanı indeks planlaması.
* İşlem commit edildikten sonra asenkron (goroutine) log yazma yaklaşımı.

### 8. [08_OPEN_ISSUES_AND_TODOS.md](file:///c:/Projeler/koyden-sehire-mobil/docs/gemini/08_OPEN_ISSUES_AND_TODOS.md) — Açık Sorunlar & Yapılacaklar
* `notlar.md` dosyasından derlenen arayüz hataları, yönlendirme bugları ve UX görevleri.
* Detaylı bildirim senaryoları matris planı (hangi olayda kime, hangi kanalla ne bildirilecek?).
* Uzun vadeli yol haritası (FTS, caching, favorites).

---

## Nasıl Kullanılır?

### custom Gem veya Özel GPT Oluştururken:
Gemini'nin "Bilgi Ekle" (Add Knowledge) veya "Gems" sekmesinden bu klasördeki tüm `.md` dosyalarını (01 ile 08 arasındaki dosyalar) yükleyin. Talimatlar (Instructions) kısmına aşağıdaki ifadeyi ekleyebilirsiniz:
> "Sen Köyden Şehire projesinin teknik asistanısın. Sana yüklenen 01-08 arasındaki Markdown dosyalarında projenin tüm veri tabanı, mimari, servis ve frontend/backend detayları yer almaktadır. Lütfen kod yazarken, hata çözerken veya yeni özellik eklerken bu dokümanlardaki kurallara, dosya yollarına ve mimari standartlara harfiyen uy."

### Chat Üzerinden Doğrudan İletişimde:
Büyük bir değişiklik yapacağınızda ilgili konuya ait dosyayı (örneğin auth sisteminde değişiklik yapacaksanız [04_AUTH_AND_OTP_FLOW.md](file:///c:/Projeler/koyden-sehire-mobil/docs/gemini/04_AUTH_AND_OTP_FLOW.md) dosyasını) doğrudan chat penceresine kopyalayıp yapıştırarak Gemini'ye tam bağlam kazandırabilirsiniz.
