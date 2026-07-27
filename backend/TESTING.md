# TESTING.md — Köyden Şehre Backend API Test Guide

Tüm curl komutları `localhost:8080`'e karşı çalıştırılır.  
`$ADMIN_TOKEN` ve `$FARMER_TOKEN` değişkenlerini aşağıdaki login adımlarından alın.

---

## 1. Health Check

```bash
curl -s http://localhost:8080/api/v1/health | python3 -m json.tool
```

**Beklenen:**
```json
{"status":"ok","database":"ok","redis":"ok","version":"1.0.0"}
```

---

## 2. Admin Login

```bash
export ADMIN_TOKEN=$(curl -s -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"phone":"05000000000","password":"admin123"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['access_token'])")

echo $ADMIN_TOKEN
```

---

## 3. Categories (Public)

```bash
curl -s http://localhost:8080/api/v1/categories | python3 -m json.tool
```

**Beklenen:** Her root kategori için `children` array'i dolu olarak gelir.

---

## 4. Invite Code Validate

```bash
curl -s "http://localhost:8080/api/v1/invites/validate?code=KYS-FOUNDER" | python3 -m json.tool
```

**Beklenen:**
```json
{"success":true,"data":{"valid":true,"code":"KYS-FOUNDER","remaining":49}}
```

---

## 5. OTP Send

```bash
curl -s -X POST http://localhost:8080/api/v1/otp/send \
  -H "Content-Type: application/json" \
  -d '{"phone":"05321234567"}' | python3 -m json.tool
```

Development ortamında OTP kodu sunucu logunda görünür:
```bash
docker compose logs api | grep "OTP for"
```

---

## 6. OTP Verify

```bash
curl -s -X POST http://localhost:8080/api/v1/otp/verify \
  -H "Content-Type: application/json" \
  -d '{"phone":"05321234567","code":"BURAYA_KOD"}' | python3 -m json.tool
```

---

## 7. Farmer Application (POST)

OTP verify tamamlandıktan sonra:

```bash
curl -s -X POST http://localhost:8080/api/v1/farmer-applications \
  -H "Content-Type: application/json" \
  -d '{
    "invite_code": "KYS-FOUNDER",
    "full_name": "Mehmet Yılmaz",
    "phone": "05321234567",
    "email": "mehmet@example.com",
    "password": "test1234",
    "business_name": "Mehmet Amcanın Çiftliği",
    "producer_type": "family_producer",
    "city": "Bursa",
    "district": "Kestel",
    "village": "Saitabat",
    "bio": "Bursa Kestelden taze çilek ve sebze.",
    "product_categories": ["meyve","sebze"],
    "product_examples": "Çilek, domates, salatalık",
    "production_place_type": "family_land",
    "kvkk_accepted": true,
    "platform_terms_accepted": true,
    "declares_own_production": true,
    "declares_accurate_location": true,
    "declares_not_intermediary": true
  }' | python3 -m json.tool
```

**Beklenen:** `"success":true` + `application_id`

---

## 8. Admin — Applications List

```bash
curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
  http://localhost:8080/api/v1/admin/applications | python3 -m json.tool
```

İsteğe bağlı filtre:
```bash
curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
  "http://localhost:8080/api/v1/admin/applications?status=pending&page=1&limit=20" | python3 -m json.tool
```

---

## 9. Admin — Approve Application

```bash
APP_ID="9cde4998-c284-4af2-9d6b-12a907a47d88"

curl -s -X POST http://localhost:8080/api/v1/admin/applications/$APP_ID/approve \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"is_founding_farmer": true, "invite_quota": 5}' | python3 -m json.tool
```

**Beklenen:** `user_id`, `farmer_name`, `invite_code` döner.

---

## 10. Farmer Login

```bash
export FARMER_TOKEN=$(curl -s -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"phone":"05321234567","password":"test1234"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['access_token'])")

echo $FARMER_TOKEN
```

---

## 11. Farmer Profile

```bash
curl -s -H "Authorization: Bearer $FARMER_TOKEN" \
  http://localhost:8080/api/v1/farmer/profile | python3 -m json.tool
```

---

## 12. Farmer Invites

```bash
curl -s -H "Authorization: Bearer $FARMER_TOKEN" \
  http://localhost:8080/api/v1/farmer/invites | python3 -m json.tool
```

---

## 13. Farmer — Create Product

```bash
# Önce kategori ID'si alın
curl -s http://localhost:8080/api/v1/categories | python3 -c "
import sys,json
cats = json.load(sys.stdin)['data']
for c in cats:
    for ch in c.get('children',[]):
        print(ch['id'], ch['name'])
"

curl -s -X POST http://localhost:8080/api/v1/farmer/products \
  -H "Authorization: Bearer $FARMER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "category_id": "KATEGORI_ID",
    "title": "Günlük Köy Çileği",
    "description": "Saitabat köyünden taze çilek.",
    "price": 120,
    "unit": "kg",
    "city": "Bursa",
    "district": "Kestel",
    "village": "Saitabat",
    "stock_status": "available",
    "image_urls": []
  }' | python3 -m json.tool
```

---

## 14. Farmer — Product List

```bash
curl -s -H "Authorization: Bearer $FARMER_TOKEN" \
  http://localhost:8080/api/v1/farmer/products | python3 -m json.tool
```

---

## 15. Admin — Approve Product

```bash
PRODUCT_ID="0381da37-58f2-4db9-9565-7d25270db5e6"

curl -s -X POST http://localhost:8080/api/v1/admin/products/$PRODUCT_ID/approve \
  -H "Authorization: Bearer $ADMIN_TOKEN" | python3 -m json.tool
```

---

## 16. Public Products

```bash
curl -s http://localhost:8080/api/v1/products | python3 -m json.tool
```

Filtreleme:
```bash
curl -s "http://localhost:8080/api/v1/products?city=Bursa&sort=price_asc&limit=10" | python3 -m json.tool
```

---

## Ortam Değişkenleri

| Değişken | Açıklama |
|---|---|
| `APP_ENV` | `development` → debug loglar açık, dev SMS provider |
| `DATABASE_URL` | PostgreSQL bağlantı stringi |
| `REDIS_URL` | Redis bağlantı stringi |
| `JWT_SECRET` | JWT imzalama anahtarı |
| `TWILIO_ACCOUNT_SID` | Twilio Account SID (prod) |
| `TWILIO_AUTH_TOKEN` | Twilio Auth Token (prod) |
| `TWILIO_FROM_NUMBER` | Gönderici numarası, E.164 (prod) — veya `TWILIO_MESSAGING_SERVICE_SID` |
| `SMS_FORCE_SEND` | `true` → development'ta da gerçek SMS gönderilir |

Tüm değişkenler için: [docs/ENVIRONMENT.md](docs/ENVIRONMENT.md)
