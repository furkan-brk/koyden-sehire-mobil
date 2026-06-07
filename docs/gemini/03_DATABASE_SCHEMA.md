# Köyden Şehire — Veritabanı Şeması & SQL Kısıtlamaları

Bu doküman, **Köyden Şehire** projesinde kullanılan ilişkisel PostgreSQL veritabanı yapısını, tablo sütun tiplerini, anahtarları (PK/FK) ve veritabanı düzeyindeki kısıtlamaları detaylandırır.

---

## 1. Genel Prensipler

* **PostgreSQL 15+** özellikleri temel alınmıştır.
* **UUID Anahtarlar:** Tüm tablolarda birincil anahtar (Primary Key) olarak `gen_random_uuid()` fonksiyonu kullanılarak rastgele UUID'ler atanır.
* **UTC Zaman:** Zaman damgası (Timestamp) sütunlarının tamamı UTC saat dilimine göre, saat dilimi bilgisi olmadan (`timestamp without time zone`) saklanır.
* **Ham SQL Tercihi:** Projede ORM kullanılmamış, SQL sorguları doğrudan `sqlx` aracılığıyla yazılmıştır. Model struct'larında eşleştirme yapmak için `db:"sutun_adi"` etiketleri bulunur.

---

## 2. Tablo Detayları

### A. `users` (Kullanıcılar)
Sisteme giriş yapabilen tüm hesapların (Müşteri, Çiftçi, Admin) ana verisini tutar.

| Sütun | Veri Tipi | Kısıtlamalar (Constraints) | Açıklama |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY`, `DEFAULT gen_random_uuid()` | Benzersiz kullanıcı kimliği |
| `full_name` | `VARCHAR(255)` | `NOT NULL` | Ad ve Soyad |
| `phone` | `VARCHAR(20)` | `UNIQUE`, `NOT NULL` | Format: `05XXXXXXXXX` |
| `email` | `VARCHAR(255)` | `UNIQUE`, `NULLABLE` | İletişim e-posta adresi |
| `password_hash` | `TEXT` | `NOT NULL` | bcrypt (cost 12) ile şifrelenmiş parola |
| `role` | `VARCHAR(20)` | `NOT NULL` | `admin`, `farmer`, `customer` |
| `status` | `VARCHAR(20)` | `NOT NULL`, `DEFAULT 'active'` | `active`, `suspended` |
| `phone_verified` | `BOOLEAN` | `NOT NULL`, `DEFAULT false` | Telefon numarası onaylandı mı? |
| `phone_verified_at`| `TIMESTAMP` | `NULLABLE` | Telefonun doğrulandığı tarih |
| `created_at` | `TIMESTAMP` | `NOT NULL`, `DEFAULT NOW()` | Kayıt tarihi |
| `updated_at` | `TIMESTAMP` | `NOT NULL`, `DEFAULT NOW()` | Güncelleme tarihi |

### B. `farmer_profiles` (Çiftçi Profilleri)
Çiftçi rolündeki kullanıcıların (`role = 'farmer'`) ek profil bilgilerini tutar. `users` tablosuyla 1:1 ilişkilidir.

| Sütun | Veri Tipi | Kısıtlamalar (Constraints) | Açıklama |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY`, `DEFAULT gen_random_uuid()` | Profil ID |
| `user_id` | `UUID` | `REFERENCES users(id) ON DELETE CASCADE`, `NOT NULL` | İlişkili kullanıcı ID |
| `display_name` | `VARCHAR(255)` | `NOT NULL` | İşletme / Çiftlik / Dükkan Adı |
| `producer_type` | `VARCHAR(50)` | `NOT NULL` | Üretici kategorisi (Enum benzeri) |
| `city` | `VARCHAR(100)` | `NOT NULL` | İl |
| `district` | `VARCHAR(100)` | `NOT NULL` | İlçe |
| `village` | `VARCHAR(100)` | `NOT NULL` | Mahalle / Köy / Belde |
| `bio` | `TEXT` | `NOT NULL` | Kendini ve üretim şeklini anlatan yazı |
| `profile_image_url`| `TEXT` | `NULLABLE` | Profil resmi CDN URL'i |
| `public_phone` | `VARCHAR(20)` | `NOT NULL` | Müşterilerin arayacağı telefon |
| `show_phone` | `BOOLEAN` | `NOT NULL`, `DEFAULT true` | Telefon numarası profilde gösterilsin mi? |
| `is_verified` | `BOOLEAN` | `NOT NULL`, `DEFAULT false` | Güvenilir/Onaylı çiftçi işareti |
| `is_founding_farmer`| `BOOLEAN` | `NOT NULL`, `DEFAULT false` | Kurucu Çiftçi (Founding Farmer) rozeti |
| `invite_quota` | `INTEGER` | `NOT NULL`, `DEFAULT 2` | Kalan davet kodu oluşturma limiti |
| `created_at` | `TIMESTAMP` | `NOT NULL`, `DEFAULT NOW()` | Oluşturulma tarihi |
| `updated_at` | `TIMESTAMP` | `NOT NULL`, `DEFAULT NOW()` | Güncelleme tarihi |

> **`producer_type` Olası Değerleri:** `individual_farmer` (Bireysel Çiftçi), `family_producer` (Aile İşletmesi), `cooperative` (Kooperatif), `small_producer` (Küçük Üretici), `dairy_producer` (Süt/Süt Ürünü Üreticisi), `beekeeper` (Arıcı), `olive_producer` (Zeytin/Zeytinyağı Üreticisi), `other` (Diğer).

### C. `categories` (Kategoriler)
Ürünlerin listeleneceği hiyerarşik kategori yapısını tutar. Öz-referanslı (self-referencing) bir yapıdır.

| Sütun | Veri Tipi | Kısıtlamalar (Constraints) | Açıklama |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY`, `DEFAULT gen_random_uuid()` | Kategori ID |
| `name` | `VARCHAR(100)` | `NOT NULL` | Kategori Adı (Örn: Süt Ürünleri) |
| `slug` | `VARCHAR(100)` | `UNIQUE`, `NOT NULL` | URL dostu isim (Örn: sut-urunleri) |
| `parent_id` | `UUID` | `REFERENCES categories(id) ON DELETE SET NULL`, `NULLABLE` | Üst Kategori ID (NULL ise kök kategori) |
| `icon` | `TEXT` | `NULLABLE` | UI üzerinde gösterilecek ikon veya görsel |
| `sort_order` | `INTEGER` | `NOT NULL`, `DEFAULT 0` | Sıralama önceliği |
| `is_active` | `BOOLEAN` | `NOT NULL`, `DEFAULT true` | Kategori aktif mi? (Soft-delete için) |
| `created_at` | `TIMESTAMP` | `NOT NULL`, `DEFAULT NOW()` | Oluşturulma tarihi |
| `updated_at` | `TIMESTAMP` | `NOT NULL`, `DEFAULT NOW()` | Güncelleme tarihi |

### D. `products` (Ürünler)
Çiftçiler tarafından yüklenen ve alıcılara sergilenen ürünlerin bilgisidir.

| Sütun | Veri Tipi | Kısıtlamalar (Constraints) | Açıklama |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY`, `DEFAULT gen_random_uuid()` | Ürün ID |
| `farmer_id` | `UUID` | `REFERENCES users(id) ON DELETE CASCADE`, `NOT NULL` | Ürünü ekleyen çiftçi |
| `category_id` | `UUID` | `REFERENCES categories(id) ON DELETE RESTRICT`, `NOT NULL` | Ürünün kategorisi |
| `title` | `VARCHAR(255)` | `NOT NULL` | Ürün başlığı (Örn: Doğal Çam Balı) |
| `description` | `TEXT` | `NOT NULL` | Detaylı açıklama |
| `price` | `NUMERIC(10,2)`| `NOT NULL` | Fiyat (Örn: 350.00) |
| `unit` | `VARCHAR(20)` | `NOT NULL` | Fiyat birimi (`kg`, `lt`, `adet`, `bag` vb.) |
| `city` | `VARCHAR(100)` | `NOT NULL` | Ürünün bulunduğu il |
| `district` | `VARCHAR(100)` | `NOT NULL` | Ürünün bulunduğu ilçe |
| `village` | `VARCHAR(100)` | `NOT NULL` | Ürünün bulunduğu mahalle/köy |
| `status` | `VARCHAR(20)` | `NOT NULL`, `DEFAULT 'pending'` | `pending`, `active`, `rejected`, `hidden` |
| `previous_status` | `VARCHAR(20)` | `NULLABLE` | Durum değişikliklerinde eski durum |
| `stock_status` | `VARCHAR(20)` | `NOT NULL`, `DEFAULT 'available'` | `available`, `out_of_stock`, `limited` |
| `admin_note` | `TEXT` | `NULLABLE` | Ürün reddedildiğinde admin notu |
| `created_at` | `TIMESTAMP` | `NOT NULL`, `DEFAULT NOW()` | Oluşturulma tarihi |
| `updated_at` | `TIMESTAMP` | `NOT NULL`, `DEFAULT NOW()` | Güncelleme tarihi |

### E. `product_images` (Ürün Görselleri)
Ürünlere ait fotoğrafların URL bilgileridir. Ürün silinirse bu görseller de veritabanından silinir.

| Sütun | Veri Tipi | Kısıtlamalar (Constraints) | Açıklama |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY`, `DEFAULT gen_random_uuid()` | Görsel ID |
| `product_id` | `UUID` | `REFERENCES products(id) ON DELETE CASCADE`, `NOT NULL` | Ürün ID |
| `image_url` | `TEXT` | `NOT NULL` | Görselin tam CDN adresi |
| `sort_order` | `INTEGER` | `NOT NULL`, `DEFAULT 0` | Gösterim sırası (küçük olan ilk gösterilir) |
| `created_at` | `TIMESTAMP` | `NOT NULL`, `DEFAULT NOW()` | Oluşturulma tarihi |

### F. `farmer_applications` (Çiftçi Başvuruları)
Yeni çiftçilerin sisteme kaydolurken doldurduğu form verilerini tutar. Bu tablo bağımsızdır, onay sürecinde veriler `users` ve `farmer_profiles` tablolarına taşınır.

| Sütun | Veri Tipi | Kısıtlamalar (Constraints) | Açıklama |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY`, `DEFAULT gen_random_uuid()` | Başvuru ID |
| `full_name` | `VARCHAR(255)` | `NOT NULL` | Çiftçi Adı Soyadı |
| `phone` | `VARCHAR(20)` | `NOT NULL` | Telefon numarası |
| `email` | `VARCHAR(255)` | `NULLABLE` | E-posta adresi |
| `password_hash` | `TEXT` | `NOT NULL` | Kayıt onaylandığında kullanılacak şifre |
| `business_name` | `VARCHAR(255)` | `NOT NULL` | İşletme Adı |
| `producer_type` | `VARCHAR(50)` | `NOT NULL` | Üretici Kategorisi |
| `city` | `VARCHAR(100)` | `NOT NULL` | İl |
| `district` | `VARCHAR(100)` | `NOT NULL` | İlçe |
| `village` | `VARCHAR(100)` | `NOT NULL` | Köy / Mahalle |
| `bio` | `TEXT` | `NOT NULL` | Tanıtım yazısı |
| `product_categories`| `JSONB` | `NOT NULL` | Üretilen ürün kategorilerinin slug listesi |
| `product_examples` | `TEXT` | `NOT NULL` | Üreteceği ürünlerden örnekler |
| `document_urls` | `JSONB` | `NOT NULL` | Çiftçilik belgesi vb. belgelerin linkleri |
| `application_video_key`| `TEXT` | `NULLABLE` | Tanıtım videosu S3 nesne anahtarı (key) |
| `application_video_status`| `VARCHAR(20)`| `NOT NULL`, `DEFAULT 'missing'` | `missing`, `uploaded`, `requested`, `not_required` |
| `invite_code_id` | `UUID` | `REFERENCES invite_codes(id) ON DELETE SET NULL` | Başvuru için kullanılan davet kodu ID'si |
| `referred_by_user_id`| `UUID` | `REFERENCES users(id) ON DELETE SET NULL` | Davet eden çiftçinin kullanıcı ID'si |
| `kvkk_accepted` | `BOOLEAN` | `NOT NULL`, `DEFAULT false` | KVKK onay kutusu |
| `platform_terms_accepted`| `BOOLEAN`| `NOT NULL`, `DEFAULT false` | Kullanım koşulları onay kutusu |
| `declares_own_production`| `BOOLEAN`| `NOT NULL`, `DEFAULT false` | Aracı değil kendi üretiyor beyanı |
| `declares_accurate_location`| `BOOLEAN`| `NOT NULL`, `DEFAULT false`| Konum doğruluğu beyanı |
| `declares_not_intermediary`| `BOOLEAN`| `NOT NULL`, `DEFAULT false` | Komisyoncu / aracı olmadığı beyanı |
| `status` | `VARCHAR(20)` | `NOT NULL`, `DEFAULT 'pending'` | `pending`, `approved`, `rejected`, `needs_video` |
| `rejection_reason` | `VARCHAR(50)` | `NULLABLE` | Reddedilme gerekçesi |
| `reviewed_by` | `UUID` | `REFERENCES users(id) ON DELETE SET NULL` | Başvuruyu inceleyen Admin |
| `reviewed_at` | `TIMESTAMP` | `NULLABLE` | İncelendiği tarih |
| `created_at` | `TIMESTAMP` | `NOT NULL`, `DEFAULT NOW()` | Başvuru tarihi |
| `updated_at` | `TIMESTAMP` | `NOT NULL`, `DEFAULT NOW()` | Güncelleme tarihi |

### G. `invite_codes` (Davet Kodları)
Sisteme yeni çiftçileri dahil etmek için kullanılan davet kodları.

| Sütun | Veri Tipi | Kısıtlamalar (Constraints) | Açıklama |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY`, `DEFAULT gen_random_uuid()` | Davet Kodu ID |
| `code` | `VARCHAR(20)` | `UNIQUE`, `NOT NULL` | `KYS-XXXXXX` formatında kod |
| `owner_user_id` | `UUID` | `REFERENCES users(id) ON DELETE CASCADE` | Koda sahip olan kullanıcı ID'si |
| `owner_type` | `VARCHAR(20)` | `NOT NULL` | Kodun sahibi tipi: `admin` veya `farmer` |
| `max_uses` | `INTEGER` | `NOT NULL`, `DEFAULT 1` | Maksimum kullanım limiti |
| `used_count` | `INTEGER` | `NOT NULL`, `DEFAULT 0` | Şu ana kadarki kullanım sayısı |
| `is_active` | `BOOLEAN` | `NOT NULL`, `DEFAULT true` | Kod aktif mi? |
| `expires_at` | `TIMESTAMP` | `NULLABLE` | Son kullanma tarihi (NULL ise sınırsız) |
| `created_at` | `TIMESTAMP` | `NOT NULL`, `DEFAULT NOW()` | Oluşturulma tarihi |
| `updated_at` | `TIMESTAMP` | `NOT NULL`, `DEFAULT NOW()` | Güncelleme tarihi |

### H. `invitations` (Davet Geçmişi)
Kullanılan davet kodlarının kullanım detaylarını loglar.

| Sütun | Veri Tipi | Kısıtlamalar (Constraints) | Açıklama |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY`, `DEFAULT gen_random_uuid()` | İlişki ID |
| `invite_code_id` | `UUID` | `REFERENCES invite_codes(id) ON DELETE CASCADE` | Kullanılan kod ID |
| `inviter_user_id` | `UUID` | `REFERENCES users(id) ON DELETE CASCADE` | Davet eden çiftçinin ID'si |
| `application_id` | `UUID` | `REFERENCES farmer_applications(id) ON DELETE CASCADE`| Davet edilen başvurunun ID'si |
| `status` | `VARCHAR(20)` | `NOT NULL`, `DEFAULT 'submitted'` | `submitted`, `approved`, `rejected` |
| `created_at` | `TIMESTAMP` | `NOT NULL`, `DEFAULT NOW()` | Kullanım tarihi |
| `updated_at` | `TIMESTAMP` | `NOT NULL`, `DEFAULT NOW()` | Güncelleme tarihi |

### I. `admin_audit_logs` (Admin Denetim Logları)
Admin işlemlerini izlemek ve güvenceye almak için oluşturulmuştur. Bu tablonun detayları `07_ADMIN_AUDIT_LOGS.md` dosyasında açıklanmıştır.

---

## 3. Önemli Kısıtlamalar (Constraints) ve SQL İndeksleri

### Koşullu Benzersiz Telefon Kısıtlaması (Conditional Unique)
Çiftçi başvurularında, bir telefon numarasıyla aynı anda birden fazla aktif başvuru yapılamaz. Ancak reddedilen veya onaylanan başvurular geçmişte kalabileceğinden, kısıtlama yalnızca durum `pending` veya `needs_video` iken geçerlidir.

```sql
CREATE UNIQUE INDEX idx_applications_active_phone
ON farmer_applications(phone)
WHERE status IN ('pending', 'needs_video');
```

### Önemli Dış Anahtar Silme Davranışları (ON DELETE)
* Bir `users` kaydı silinirse, ona ait `farmer_profiles`, `products`, `invite_codes` ve `invitations` kayıtları da **Cascade** olarak silinir.
* Bir kategori silinmek istendiğinde, o kategoriye bağlı ürünler bulunuyorsa veritabanı koruma sağlar (`ON DELETE RESTRICT`). Kategorinin `is_active = false` yapılarak gizlenmesi (soft delete) önerilir.

---

## Bağlantılı Dosyalar
- [02_ARCHITECTURE.md](file:///c:/Projeler/koyden-sehire-mobil/docs/gemini/02_ARCHITECTURE.md)
- [04_AUTH_AND_OTP_FLOW.md](file:///c:/Projeler/koyden-sehire-mobil/docs/gemini/04_AUTH_AND_OTP_FLOW.md)
- [07_ADMIN_AUDIT_LOGS.md](file:///c:/Projeler/koyden-sehire-mobil/docs/gemini/07_ADMIN_AUDIT_LOGS.md)
- [PROJECT_REFERENCE.md](file:///c:/Projeler/koyden-sehire-mobil/docs/PROJECT_REFERENCE.md)
