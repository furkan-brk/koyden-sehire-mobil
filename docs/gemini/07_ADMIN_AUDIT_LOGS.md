# Köyden Şehire — Admin Audit Log (Denetim Günlüğü) Sistemi

Bu doküman, yöneticilerin (adminlerin) platform üzerinde gerçekleştirdiği hassas işlemleri imza altına alan ve geri dönük takip edilebilirlik sağlayan **Admin Audit Log** sisteminin teknik tasarımını açıklar.

---

## 1. Kapsam ve Temel Kurallar

1. **Sadece Değişiklikler Loglanır:** Salt-okunur (GET) istekleri, arama sorguları, dashboard/analitik görüntülemeleri ve sistem sağlık kontrolleri (health check) loglanmaz. Yalnızca veri üzerinde değişiklik (Insert, Update, Delete) yapan yönetici işlemleri kaydedilir.
2. **Değiştirilemezlik (Immutability):** Log verileri bir kez yazıldıktan sonra asla güncellenemez veya silinemez. Veritabanı katmanında (Repository) Update veya Delete metotları tanımlanmamıştır.
3. **Anlık Durum Koruması (Snapshotting):** Loglanan nesne gelecekte sistemden tamamen silinse bile (`PRODUCT_DELETED` gibi), log satırındaki `target_snapshot` (JSONB) alanı sayesinde işlemin yapıldığı andaki veri içeriği aynen korunur.

---

## 2. Loglanan Aksiyonlar ve Hedef Tipleri

Denetim günlükleri 4 ana gruba ayrılır (`target_type`):

### A. Başvurular (`target_type = 'application'`)
* `APPLICATION_APPROVED`: Çiftçi başvurusunun onaylanması.
* `APPLICATION_REJECTED`: Çiftçi başvurusunun reddedilmesi.
* `APPLICATION_VIDEO_REQUESTED`: Çiftçiden ek tanıtım videosu istenmesi.

### B. Ürünler (`target_type = 'product'`)
* `PRODUCT_APPROVED`: Çiftçi tarafından eklenen ürünün onaylanıp yayına alınması.
* `PRODUCT_REJECTED`: Ürünün reddedilmesi.
* `PRODUCT_HIDDEN`: Ürünün listeden gizlenmesi.
* `PRODUCT_DELETED`: Ürünün sistemden silinmesi.

### C. Çiftçiler (`target_type = 'farmer'`)
* `FARMER_SUSPENDED`: Çiftçi hesabının askıya alınması.
* `FARMER_REACTIVATED`: Askıdaki çiftçi hesabının tekrar aktifleştirilmesi.
* `FARMER_FOUNDING_SET`: Kurucu çiftçi (Founding Farmer) rozetinin verilmesi/alınması.
* `FARMER_INVITE_QUOTA_UPDATED`: Çiftçinin davet kod sınırının değiştirilmesi.

### D. Kategoriler (`target_type = 'category'`)
* `CATEGORY_CREATED`: Yeni ürün kategorisi oluşturulması.
* `CATEGORY_UPDATED`: Kategori adı, sırası veya durumunun güncellenmesi.
* `CATEGORY_DELETED`: Kategorinin silinmesi.

---

## 3. Veritabanı Tasarımı

Sistemde iki adet PostgreSQL ENUM tipi ve ana log tablosu bulunur.

```sql
CREATE TYPE audit_action AS ENUM (
    'APPLICATION_APPROVED', 'APPLICATION_REJECTED', 'APPLICATION_VIDEO_REQUESTED',
    'PRODUCT_APPROVED', 'PRODUCT_REJECTED', 'PRODUCT_HIDDEN', 'PRODUCT_DELETED',
    'FARMER_SUSPENDED', 'FARMER_REACTIVATED', 'FARMER_FOUNDING_SET', 'FARMER_INVITE_QUOTA_UPDATED',
    'CATEGORY_CREATED', 'CATEGORY_UPDATED', 'CATEGORY_DELETED'
);

CREATE TYPE audit_target_type AS ENUM ('application', 'product', 'farmer', 'category');

CREATE TABLE admin_audit_logs (
    id              UUID              PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id        UUID              NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    action          audit_action      NOT NULL,
    target_type     audit_target_type NOT NULL,
    target_id       UUID              NOT NULL,
    target_snapshot JSONB             NULL, -- O anki veri kopyası
    reason          TEXT              NULL, -- Ret sebebi veya açıklama notu
    metadata        JSONB             NULL, -- IP, User-Agent vb.
    created_at      TIMESTAMPTZ       NOT NULL DEFAULT NOW()
);
```

### Performans ve İndeksleme Stratejisi
Yüksek veri hacimlerinde sorguların hızlı çalışması için aşağıdaki indeksler tanımlanmıştır:
* `idx_audit_logs_admin_id`: "Bu admin ne yaptı?" sorguları için.
* `idx_audit_logs_action`: "Kaç başvuru onaylandı?" istatistiği için.
* `idx_audit_logs_target` (Bileşik İndeks): `(target_type, target_id)` sütunları üzerinde kuruludur. Belirli bir ürün veya çiftçinin tüm geçmişini listelemek için kullanılır.
* `idx_audit_logs_created_at` (Azalan): Günlükleri en yeniye göre sayfalamak için.

---

## 4. Go Implementasyonu & Goroutine Stratejisi

Audit Log yazma işlemleri asenkron ve non-blocking (bloke etmeyen) şekilde tasarlanmıştır.

* **Neden Servis Katmanı?** HTTP Middleware katmanı işlemin başarıyla tamamlanıp tamamlanmadığını bilemez (Örn: DB hatası nedeniyle rollback olmuş bir işlem loglanmamalıdır). Bu yüzden loglama, veritabanı işlemi (Transaction) başarıyla **Commit** edildikten hemen sonra tetiklenir.
* **Goroutine Kullanımı:** Veritabanına log yazma gecikmesinin ana iş akışını (örneğin adminin onay butonuna basma yanıt süresini) etkilememesi için log yazma fonksiyonu ayrı bir Go kanalı veya `go func()` (goroutine) içerisinde çalıştırılır.

```go
// Örnek: Başvuru Onaylama Sonrası Loglama Akışı
if err := tx.Commit(); err != nil {
    return nil, err
}

go func() {
    reason := "Başvuru onaylandı ve kullanıcı tanımlandı."
    _ = s.auditRepo.Create(context.Background(), audit.CreateParams{
        AdminID:    adminID,
        Action:     audit.ActionApplicationApproved,
        TargetType: audit.TargetApplication,
        TargetID:   appID,
        TargetSnapshot: map[string]interface{}{
            "full_name": app.FullName,
            "phone":     app.Phone,
        },
        Reason: &reason,
    })
}()
```

---

## 5. Admin API Endpoint (`GET /api/v1/admin/audit-logs`)

Yöneticilerin geçmiş günlükleri filtreleyip incelemesini sağlar.
* **Yetki:** Bearer JWT, `role = 'admin'`
* **Filtreler (Query Params):** `page`, `limit`, `action`, `target_type`, `target_id`, `admin_id`, `date_from`, `date_to`
* **Örnek Yanıt:**
  ```json
  {
    "success": true,
    "data": [
      {
        "id": "e92a83cf-...",
        "admin_id": "8c7b82f0-...",
        "admin_full_name": "Furkan BERK",
        "action": "APPLICATION_APPROVED",
        "target_type": "application",
        "target_id": "fa839c01-...",
        "target_snapshot": {
          "farmer_name": "Ahmet Yılmaz",
          "phone": "05551234567"
        },
        "reason": "Başvuru onaylandı ve kullanıcı tanımlandı.",
        "created_at": "2026-06-06T10:00:00Z"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 143,
      "total_pages": 8
    }
  }
  ```

---

## Bağlantılı Dosyalar
- [03_DATABASE_SCHEMA.md](file:///c:/Projeler/koyden-sehire-mobil/docs/gemini/03_DATABASE_SCHEMA.md)
- [AUDIT_LOG_SPEC.md](file:///c:/Projeler/koyden-sehire-mobil/backend/docs/AUDIT_LOG_SPEC.md)
