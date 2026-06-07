# Köyden Şehire — Dosya Yükleme & Medya Depolama Mimarisi

Bu doküman, **Köyden Şehire** projesinde dosyaların (görseller ve videolar) API sunucusu üzerinden geçirilmeden, güvenli ve performanslı bir şekilde doğrudan bulut depolama katmanına (Cloudflare R2 / MinIO) yüklenme sürecini (Presigned URL) açıklar.

---

## 1. Mimari Tasarım Kararı (Direct-to-S3)

Mobil ve web istemciler, yüksek boyutlu dosyaları (özellikle çiftçi başvuru videolarını) doğrudan API sunucusuna yüklemez. API sunucusunun bant genişliği ve bellek tüketimini korumak amacıyla **Presigned URL (Önceden İmzalanmış URL)** akışı tercih edilmiştir.

### Temel Akış Şeması

```
İstemci (Mobil/Web)          Go API Sunucusu           Cloudflare R2 (S3)
      │                            │                           │
      │ 1. POST /farmer/uploads/.. │                           │
      │ ─────────────────────────> │                           │
      │                            │ 2. Presigned PUT URL üret │
      │                            │ ────────────────────────> │
      │                            │ <──────────────────────── │
      │ 3. { upload_url, key }     │                           │
      │ <───────────────────────── │                           │
      │                                                        │
      │ 4. PUT <upload_url> (Binary file data)                 │
      │ ─────────────────────────────────────────────────────> │
      │ <───────────────────────────────────────────────────── │
      │ 5. 200 OK (Doğrudan S3'ten onay)                        │
      │                                                        │
      │ 6. POST /farmer/products                               │
      │    { image_keys: [key] }                               │
      │ ─────────────────────────>                             │
```

---

## 2. Presigned URL Üreten Endpoint'ler

### A. Ürün Görseli Yükleme (`POST /farmer/uploads/product-image`)
* **Yetki:** JWT Bearer Token (Rol: `farmer`, Durum: `active`)
* **İstek Body:** `{"content_type": "image/jpeg"}`
* **Yanıt:**
  ```json
  {
    "success": true,
    "data": {
      "upload_url": "https://koydensehire.r2.cloudflarestorage.com/products/images/...",
      "key": "products/images/df829a.../1780674000.jpg"
    }
  }
  ```

### B. Profil Resmi Yükleme (`POST /farmer/uploads/profile-image`)
* **Yetki:** JWT Bearer Token (Rol: `farmer`, Durum: `active`)
* **İstek Body:** `{"content_type": "image/png"}`

### C. Başvuru Videosu Yükleme (`POST /uploads/application-video/presigned-url`)
* **Yetki:** **Auth Gerektirmez** (Başvuru aşamasındaki kullanıcılar için telefon doğrulamasıyla çalışır).
* **İstek Body:**
  ```json
  {
    "phone": "05XXXXXXXXX",
    "invite_code": "KYS-FOUNDER",
    "content_type": "video/mp4"
  }
  ```

---

## 3. Depolama Dizin Yapısı (Key Patterns)

Dosyaların depolama bucket'ındaki yerleşim desenleri şu şekildedir:

| Dosya Tipi | Bucket Yerleşim Yolu (Key Pattern) | Erişim Politikası |
| :--- | :--- | :--- |
| **Ürün Görselleri** | `products/images/{farmer_id}/{timestamp}.{ext}` | Public (Genel Erişim) |
| **Profil Resimleri** | `profiles/{user_id}/{timestamp}.{ext}` | Public (Genel Erişim) |
| **Başvuru Videosu (Beklemede)** | `application-videos/pending/{phone}/{timestamp}.mp4` | Private (Özel Erişim) |
| **Başvuru Videosu (Onaylı)** | `application-videos/approved/{application_id}.mp4` | Private (Özel Erişim) |

---

## 4. Güvenlik ve İzin Yönetimi

### PUT ve GET Süre Limitleri (TTL)
* **PUT (Yükleme) Linkleri:** Üretilen yükleme URL'leri **15 dakika** geçerlidir. İstemci bu süre zarfında dosyayı yüklemezse link geçersiz olur.
* **GET (Okuma) Linkleri:**
  - Görseller public CDN üzerinden sunulur (`STORAGE_PUBLIC_URL`).
  - Çiftçi başvuru videoları **gizlidir (private)**. Admin panelinde bir yönetici videoyu izlemek istediğinde, API sunucusu anlık olarak **1 saat geçerli** bir presigned GET URL'i oluşturur. Süre dolunca videoya erişilemez.

### Desteklenen Dosya Tipleri ve Boyut Limitleri

| Dosya Grubu | Kabul Edilen MIME Tipleri | Önerilen Maksimum Boyut |
| :--- | :--- | :--- |
| **Resimler** | `image/jpeg`, `image/png`, `image/webp` | 5 MB (Ürün) / 2 MB (Profil) |
| **Videolar** | `video/mp4`, `video/quicktime` | 100 MB |

---

## 5. Geliştirme Ortamı Fallback (DevProvider)

Yerel geliştirmede Cloudflare R2 bilgileri tanımlanmamışsa veya boşsa, backend otomatik olarak `DevProvider` (no-op) sınıfına düşer.
* Bu durumda üretilen presigned URL'ler **boş string** olarak döner.
* İstemcide hata almamak ve dosya yükleme akışlarını simüle etmek için geliştirme ortamında `.env` içerisine yerel **MinIO** bilgileri girilmelidir.

### Çevre Değişkenleri Yapılandırması (`.env`)
```bash
STORAGE_ENDPOINT=http://localhost:9000
STORAGE_BUCKET=koydensehire
STORAGE_ACCESS_KEY=minioadmin
STORAGE_SECRET_KEY=minioadmin123
STORAGE_PUBLIC_URL=http://localhost:9000/koydensehire
```

---

## Bağlantılı Dosyalar
- [04_AUTH_AND_OTP_FLOW.md](file:///c:/Projeler/koyden-sehire-mobil/docs/gemini/04_AUTH_AND_OTP_FLOW.md)
- [UPLOADS_AND_STORAGE.md](file:///c:/Projeler/koyden-sehire-mobil/backend/docs/UPLOADS_AND_STORAGE.md)
