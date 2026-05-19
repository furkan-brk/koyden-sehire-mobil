# Admin Audit Log — Teknik Tasarım Dokümanı

**Versiyon:** v1.0 | **Tarih:** 2026-05-19 | **Yazar:** Furkan BERK  
**Durum:** Tasarım tamamlandı — implementasyon bekliyor

---

## 1. Kapsam

Aşağıdaki admin aksiyonları loglanmalıdır. Her aksiyon `action` sütununda sabit bir string sabiti olarak tutulur. Salt-okunur GET istekleri, dashboard/analytics sorguları ve health check loglanmaz.

### Başvuru İşlemleri (`target_type = 'application'`)

| Aksiyon Sabiti | Tetikleyen Endpoint |
|---|---|
| `APPLICATION_APPROVED` | `POST /admin/applications/:id/approve` |
| `APPLICATION_REJECTED` | `POST /admin/applications/:id/reject` |
| `APPLICATION_VIDEO_REQUESTED` | `POST /admin/applications/:id/request-video` |

### Ürün İşlemleri (`target_type = 'product'`)

| Aksiyon Sabiti | Tetikleyen Endpoint |
|---|---|
| `PRODUCT_APPROVED` | `POST /admin/products/:id/approve` |
| `PRODUCT_REJECTED` | `POST /admin/products/:id/reject` |
| `PRODUCT_HIDDEN` | `POST /admin/products/:id/hide` |
| `PRODUCT_DELETED` | `DELETE /admin/products/:id` |

### Çiftçi İşlemleri (`target_type = 'farmer'`)

| Aksiyon Sabiti | Tetikleyen Endpoint |
|---|---|
| `FARMER_SUSPENDED` | `POST /admin/farmers/:id/suspend` |
| `FARMER_REACTIVATED` | `POST /admin/farmers/:id/reactivate` |
| `FARMER_FOUNDING_SET` | `PATCH /admin/farmers/:id/founding` |
| `FARMER_INVITE_QUOTA_UPDATED` | `PATCH /admin/farmers/:id/invite-quota` |

### Kategori İşlemleri (`target_type = 'category'`)

| Aksiyon Sabiti | Tetikleyen Endpoint |
|---|---|
| `CATEGORY_CREATED` | `POST /admin/categories` |
| `CATEGORY_UPDATED` | `PUT /admin/categories/:id` |
| `CATEGORY_DELETED` | `DELETE /admin/categories/:id` |

---

## 2. Veri Modeli

### Tablo Şeması — `000016_create_admin_audit_logs.up.sql`

```sql
CREATE TYPE audit_action AS ENUM (
    'APPLICATION_APPROVED',
    'APPLICATION_REJECTED',
    'APPLICATION_VIDEO_REQUESTED',
    'PRODUCT_APPROVED',
    'PRODUCT_REJECTED',
    'PRODUCT_HIDDEN',
    'PRODUCT_DELETED',
    'FARMER_SUSPENDED',
    'FARMER_REACTIVATED',
    'FARMER_FOUNDING_SET',
    'FARMER_INVITE_QUOTA_UPDATED',
    'CATEGORY_CREATED',
    'CATEGORY_UPDATED',
    'CATEGORY_DELETED'
);

CREATE TYPE audit_target_type AS ENUM (
    'application',
    'product',
    'farmer',
    'category'
);

CREATE TABLE admin_audit_logs (
    id              UUID              PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id        UUID              NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    action          audit_action      NOT NULL,
    target_type     audit_target_type NOT NULL,
    target_id       UUID              NOT NULL,
    -- Hedefin o andaki durumunu human-readable saklayan snapshot:
    target_snapshot JSONB             NULL,
    -- Opsiyonel: admin'in işleme eklediği not/sebep (rejection_reason vb.)
    reason          TEXT              NULL,
    -- İstek meta verisi (IP, user-agent vb. gelecek genişleme)
    metadata        JSONB             NULL,
    created_at      TIMESTAMPTZ       NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_logs_admin_id      ON admin_audit_logs (admin_id);
CREATE INDEX idx_audit_logs_action        ON admin_audit_logs (action);
CREATE INDEX idx_audit_logs_target        ON admin_audit_logs (target_type, target_id);
CREATE INDEX idx_audit_logs_created_at    ON admin_audit_logs (created_at DESC);
CREATE INDEX idx_audit_logs_created_action ON admin_audit_logs (created_at DESC, action);
```

```sql
-- 000016_create_admin_audit_logs.down.sql
DROP TABLE IF EXISTS admin_audit_logs;
DROP TYPE IF EXISTS audit_action;
DROP TYPE IF EXISTS audit_target_type;
```

### Alan Açıklamaları

| Alan | Tip | Açıklama |
|---|---|---|
| `id` | UUID | Birincil anahtar |
| `admin_id` | UUID | İşlemi yapan admin (`users.id` FK) |
| `action` | ENUM | Aksiyon sabiti |
| `target_type` | ENUM | Hedef kaynak tipi |
| `target_id` | UUID | Hedef kaydın ID'si |
| `target_snapshot` | JSONB | İşlem anındaki kayıt özeti — kayıt silinse bile log korunur |
| `reason` | TEXT | Ret sebebi, admin notu (opsiyonel) |
| `metadata` | JSONB | IP, user-agent vb. gelecek genişleme alanı |
| `created_at` | TIMESTAMPTZ | Oluşturma zamanı (UTC) |

> **Tasarım kararı:** `target_snapshot` JSONB olarak seçilmiştir. Hedef kayıt silinse bile (`PRODUCT_DELETED`) log kaydı o anki veriyi korur. Audit loglar immutable'dır — Update/Delete metodları kasıtlı olarak Repository'ye eklenmemiştir.

---

## 3. Go Implementasyonu

### 3.1 Entegrasyon Stratejisi

Üç yaklaşım değerlendirildi:

| Yaklaşım | Karar | Gerekçe |
|---|---|---|
| Middleware | ❌ Reddedildi | HTTP katmanı, iş sonucunu bilemez; başarısız işlemler de loglanır |
| Her handler'da elle çağrı | ❌ Reddedildi | Unutma riski yüksek, tutarsızlık doğurur |
| Service katmanında, başarı sonrası goroutine | ✅ Seçildi | Non-blocking, iş akışını kesmez, tutarlı |

### 3.2 `internal/audit/` Paketi

```go
// internal/audit/repository.go
package audit

import (
    "context"
    "encoding/json"
    "fmt"
    "math"
    "strings"
    "time"

    "github.com/jmoiron/sqlx"
)

type Action string

const (
    ActionApplicationApproved       Action = "APPLICATION_APPROVED"
    ActionApplicationRejected       Action = "APPLICATION_REJECTED"
    ActionApplicationVideoRequested Action = "APPLICATION_VIDEO_REQUESTED"

    ActionProductApproved Action = "PRODUCT_APPROVED"
    ActionProductRejected Action = "PRODUCT_REJECTED"
    ActionProductHidden   Action = "PRODUCT_HIDDEN"
    ActionProductDeleted  Action = "PRODUCT_DELETED"

    ActionFarmerSuspended          Action = "FARMER_SUSPENDED"
    ActionFarmerReactivated        Action = "FARMER_REACTIVATED"
    ActionFarmerFoundingSet        Action = "FARMER_FOUNDING_SET"
    ActionFarmerInviteQuotaUpdated Action = "FARMER_INVITE_QUOTA_UPDATED"

    ActionCategoryCreated Action = "CATEGORY_CREATED"
    ActionCategoryUpdated Action = "CATEGORY_UPDATED"
    ActionCategoryDeleted Action = "CATEGORY_DELETED"
)

type TargetType string

const (
    TargetApplication TargetType = "application"
    TargetProduct     TargetType = "product"
    TargetFarmer      TargetType = "farmer"
    TargetCategory    TargetType = "category"
)

type Entry struct {
    ID             string     `db:"id"              json:"id"`
    AdminID        string     `db:"admin_id"        json:"admin_id"`
    Action         Action     `db:"action"          json:"action"`
    TargetType     TargetType `db:"target_type"     json:"target_type"`
    TargetID       string     `db:"target_id"       json:"target_id"`
    TargetSnapshot *string    `db:"target_snapshot" json:"target_snapshot,omitempty"`
    Reason         *string    `db:"reason"          json:"reason,omitempty"`
    Metadata       *string    `db:"metadata"        json:"metadata,omitempty"`
    CreatedAt      time.Time  `db:"created_at"      json:"created_at"`
    AdminFullName  *string    `db:"admin_full_name" json:"admin_full_name,omitempty"`
}

type CreateParams struct {
    AdminID        string
    Action         Action
    TargetType     TargetType
    TargetID       string
    TargetSnapshot interface{}
    Reason         *string
    Metadata       map[string]interface{}
}

type ListFilter struct {
    AdminID    string
    Action     Action
    TargetType TargetType
    TargetID   string
    DateFrom   *time.Time
    DateTo     *time.Time
    Page       int
    Limit      int
}

type Repository struct {
    db *sqlx.DB
}

func NewRepository(db *sqlx.DB) *Repository {
    return &Repository{db: db}
}

// Create, yeni bir audit log satırı ekler.
// Goroutine içinde çağrılması önerilir — hata iş akışını kesmemeli.
func (r *Repository) Create(ctx context.Context, p CreateParams) error {
    snapshotJSON, err := marshalNullableJSON(p.TargetSnapshot)
    if err != nil {
        return err
    }
    metaJSON, err := marshalNullableJSON(p.Metadata)
    if err != nil {
        return err
    }

    _, err = r.db.ExecContext(ctx, `
        INSERT INTO admin_audit_logs
            (admin_id, action, target_type, target_id,
             target_snapshot, reason, metadata)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
    `, p.AdminID, p.Action, p.TargetType, p.TargetID,
        snapshotJSON, p.Reason, metaJSON)
    return err
}

// List, filtrelenebilir sayfalı log listesi döner.
func (r *Repository) List(ctx context.Context, f ListFilter) ([]Entry, int, error) {
    where := []string{"1=1"}
    args := []interface{}{}
    idx := 1

    add := func(cond string, val interface{}) {
        where = append(where, fmt.Sprintf(cond, idx))
        args = append(args, val)
        idx++
    }

    if f.AdminID != ""    { add("aal.admin_id = $%d", f.AdminID) }
    if f.Action != ""     { add("aal.action = $%d", string(f.Action)) }
    if f.TargetType != "" { add("aal.target_type = $%d", string(f.TargetType)) }
    if f.TargetID != ""   { add("aal.target_id = $%d", f.TargetID) }
    if f.DateFrom != nil  { add("aal.created_at >= $%d", *f.DateFrom) }
    if f.DateTo != nil    { add("aal.created_at <= $%d", *f.DateTo) }

    wc := strings.Join(where, " AND ")

    var total int
    if err := r.db.GetContext(ctx, &total,
        fmt.Sprintf(`SELECT COUNT(*) FROM admin_audit_logs aal WHERE %s`, wc),
        args...); err != nil {
        return nil, 0, err
    }

    if f.Limit < 1 || f.Limit > 100 { f.Limit = 20 }
    if f.Page < 1 { f.Page = 1 }

    args = append(args, f.Limit, (f.Page-1)*f.Limit)
    rows, err := r.db.QueryxContext(ctx, fmt.Sprintf(`
        SELECT aal.id, aal.admin_id, aal.action, aal.target_type, aal.target_id,
               aal.target_snapshot, aal.reason, aal.metadata, aal.created_at,
               u.full_name AS admin_full_name
        FROM admin_audit_logs aal
        JOIN users u ON u.id = aal.admin_id
        WHERE %s
        ORDER BY aal.created_at DESC
        LIMIT $%d OFFSET $%d
    `, wc, idx, idx+1), args...)
    if err != nil {
        return nil, 0, err
    }
    defer rows.Close()

    var entries []Entry
    for rows.Next() {
        var e Entry
        if err := rows.StructScan(&e); err != nil {
            return nil, 0, err
        }
        entries = append(entries, e)
    }
    return entries, total, nil
}

func marshalNullableJSON(v interface{}) (*string, error) {
    if v == nil {
        return nil, nil
    }
    b, err := json.Marshal(v)
    if err != nil {
        return nil, err
    }
    s := string(b)
    return &s, nil
}
```

### 3.3 `admin.Service` Entegrasyonu

`admin.Service` yapısına `auditRepo` bağımlılığı eklenir:

```go
// internal/admin/service.go
import "github.com/koydensehire/backend/internal/audit"

type Service struct {
    repo      *Repository
    db        *sqlx.DB
    storage   storage.Provider
    appEnv    string
    auditRepo *audit.Repository  // YENİ
}

func NewService(repo *Repository, db *sqlx.DB, stor storage.Provider,
    appEnv string, auditRepo *audit.Repository) *Service {
    return &Service{repo: repo, db: db, storage: stor,
        appEnv: appEnv, auditRepo: auditRepo}
}
```

`ApproveApplication` — `tx.Commit()` başarısından sonra:

```go
if err := tx.Commit(); err != nil {
    return nil, apperrors.ErrInternal
}

// Non-blocking audit log
go func() {
    reason := "Başvuru onaylandı"
    _ = s.auditRepo.Create(context.Background(), audit.CreateParams{
        AdminID:    adminID,
        Action:     audit.ActionApplicationApproved,
        TargetType: audit.TargetApplication,
        TargetID:   appID,
        TargetSnapshot: map[string]interface{}{
            "farmer_name": app.FullName,
            "phone":       app.Phone,
            "user_id":     userID,
        },
        Reason: &reason,
    })
}()
```

`RejectApplication` — handler'da commit sonrası:

```go
go func() {
    _ = h.auditRepo.Create(context.Background(), audit.CreateParams{
        AdminID:    adminID,
        Action:     audit.ActionApplicationRejected,
        TargetType: audit.TargetApplication,
        TargetID:   id,
        TargetSnapshot: map[string]interface{}{
            "full_name": app.FullName,
            "phone":     app.Phone,
        },
        Reason: &req.RejectionReason,
    })
}()
```

### 3.4 `main.go` Wire-Up

```go
auditRepo    := audit.NewRepository(db)
adminRepo    := admin.NewRepository(db)
adminSvc     := admin.NewService(adminRepo, db, storageProvider, cfg.App.Env, auditRepo)
adminHandler := admin.NewHandler(adminSvc, db, notifSvc, auditRepo)
```

---

## 4. API Endpoint

### `GET /api/v1/admin/audit-logs`

**Yetkilendirme:** Bearer JWT, role=admin

**Query Parametreleri:**

| Parametre | Tip | Zorunlu | Açıklama |
|---|---|---|---|
| `page` | int | hayır | Varsayılan: 1 |
| `limit` | int | hayır | Varsayılan: 20, maks: 100 |
| `action` | string | hayır | `APPLICATION_APPROVED` vb. |
| `target_type` | string | hayır | `application`, `product`, `farmer`, `category` |
| `target_id` | UUID | hayır | Belirli bir kaydın geçmişi |
| `admin_id` | UUID | hayır | Belirli bir adminin işlemleri |
| `date_from` | ISO8601 | hayır | `2026-05-01T00:00:00Z` |
| `date_to` | ISO8601 | hayır | `2026-05-19T23:59:59Z` |

**Başarılı Yanıt (200):**

```json
{
  "success": true,
  "data": [
    {
      "id": "a1b2c3d4-...",
      "admin_id": "...",
      "admin_full_name": "Furkan BERK",
      "action": "APPLICATION_APPROVED",
      "target_type": "application",
      "target_id": "...",
      "target_snapshot": { "farmer_name": "Ali Yılmaz", "phone": "05300000000" },
      "reason": "Başvuru onaylandı",
      "created_at": "2026-05-19T10:30:00Z"
    }
  ],
  "pagination": {
    "page": 1, "limit": 20, "total": 143, "total_pages": 8
  }
}
```

**Router kaydı (`main.go`):**

```go
adminGroup.Get("/audit-logs", adminHandler.ListAuditLogs)
```

---

## 5. Performans — Index Stratejisi

| Senaryo | Kullanılan Index |
|---|---|
| "Bu admin ne yaptı?" | `idx_audit_logs_admin_id` |
| "Kaç başvuru onaylandı?" | `idx_audit_logs_action` |
| "Bu ürüne kim ne yaptı?" | `idx_audit_logs_target` (bileşik) |
| Son N kaydı göster | `idx_audit_logs_created_at` |
| Tarih aralığı + aksiyon filtresi | `idx_audit_logs_created_action` |

**Büyüme planı (>1M satır sonrası):**

```sql
-- Aylık range partitioning:
ALTER TABLE admin_audit_logs PARTITION BY RANGE (created_at);
CREATE TABLE admin_audit_logs_2026_05
    PARTITION OF admin_audit_logs
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
```

**Retention:** 2 yıllık saklama politikası önerilir. `pg_cron` ile arşivleme yapılabilir.

---

## 6. Migration Numarası

Mevcut en yüksek migration: `000015_add_customer_role`

Oluşturulacak dosyalar:
```
backend/migrations/000016_create_admin_audit_logs.up.sql
backend/migrations/000016_create_admin_audit_logs.down.sql
```

`APP_AUTO_MIGRATE=true` olduğunda `main.go`'daki `m.Up()` çağrısı tarafından otomatik uygulanır.

---

## 7. Uygulama Sırası

1. `000016_create_admin_audit_logs.up/down.sql` migration dosyalarını oluştur
2. `internal/audit/repository.go` paketini oluştur
3. `admin.Service` ve `admin.Handler` yapılarına `auditRepo` bağımlılığını ekle
4. `ApproveApplication`, `RejectApplication`, `RequestVideo` metodlarına commit sonrası goroutine log çağrısı ekle
5. `products`, `farmers`, `categories` handler'larına aynı pattern'i uygula
6. `main.go`'da wire-up'ı güncelle
7. `adminGroup.Get("/audit-logs", adminHandler.ListAuditLogs)` route'unu ekle

**Tahmini efor:** Backend implementasyonu ~1 gün, Flutter admin panel UI ~0.5 gün
