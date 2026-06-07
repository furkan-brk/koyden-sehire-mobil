# Köyden Şehire — Proje Genel Bakış & Kullanıcı Rolleri

Bu doküman, **Köyden Şehire** projesinin işlevsel amacını, hedef kitlesini ve kullanıcı yetkilerini tanımlar. Projeyi bir Gemini Gem veya yapay zeka modeline öğretirken başlangıç noktası olarak kullanılmalıdır.

---

## 1. Proje Özeti

**Köyden Şehire**, yerel üreticileri (çiftçiler, arıcılar, kooperatifler, aile üreticileri) tüketicilerle (müşteriler) doğrudan buluşturan, **komisyonsuz** bir mobil listeleme platformudur.

### Temel Prensipler ve Tasarım Kararları

1. **Doğrudan İletişim:** Platform, alıcı ve satıcıyı buluşturduktan sonra devreden çıkar. Tüm pazarlık, teslimat ve ödeme süreçleri taraflar arasında doğrudan yürütülür.
2. **Sipariş & Ödeme Yok:** Uygulama içerisinde bir sepet, ödeme geçidi, sipariş takip mekanizması veya kargo entegrasyonu **bulunmaz**.
3. **Mesajlaşma Yok:** Uygulama içi bir anlık mesajlaşma sistemi yoktur. Müşteriler çiftçilere, çiftçilerin profillerinde paylaştıkları genel telefon numarası üzerinden (arama veya WhatsApp yoluyla) ulaşır.
4. **Kalite Kontrol (Davet Sistemi):** Her önüne gelen üretici doğrudan platformda ürün listeleyemez. Kaliteyi ve güvenilirliği korumak adına **davet kodu + başvuru + admin onayı** zinciri uygulanır.

---

## 2. Temel Değer Önerileri

| Mevcut Sorun | Köyden Şehire Çözümü |
| :--- | :--- |
| **Aracı Komisyonları:** Pazar yerleri üreticinin kâr marjını eritir. | **Sıfır Komisyon:** Platform listeleme için ücret veya komisyon almaz. |
| **Güvenilirlik ve Doğallık:** Alıcılar doğal/yerel ürünlerin kaynağını doğrulayamıyor. | **Modere Edilen Üreticiler:** Her çiftçi video ve belgelerle doğrulanır, davet zinciriyle ağa katılır. |
| **Pazara Erişim Zorluğu:** Küçük üretici dijital pazarlama yapamıyor. | **Basit Mobil Arayüz:** Çiftçiler kolayca ürün ekleyebilir, profil oluşturabilir. |

---

## 3. Kullanıcı Rolleri ve Erişim Matrisi

Sistemde üç temel rol tanımlanmıştır: **Müşteri (Customer)**, **Çiftçi (Farmer)** ve **Yönetici (Admin)**.

### A. Müşteri (Customer)
* **Kayıt:** Telefon numarası + OTP doğrulaması ile hızlı kayıt olur.
* **Erişim:** Mobil uygulama üzerinden çalışır. Kayıt olmadan da ürünleri keşfedebilir ve üretici profillerini görüntüleyebilir. Kayıtlı müşteriler, favori/kaydetme gibi gelecekteki özellikleri kullanacaktır.
* **Yetkiler:**
  - Kategorilere göre ürün listeleme ve arama.
  - Ürün detaylarını ve çiftçi profillerini (isim, bio, telefon, konum) inceleme.
  - Çiftçi ile doğrudan telefon/WhatsApp üzerinden iletişime geçme.

### B. Çiftçi (Farmer)
* **Kayıt:** Sadece geçerli bir **Davet Kodu (Invite Code)**, OTP doğrulaması, profil bilgileri ve opsiyonel tanıtım videosu içeren bir başvuru ile kayıt aşamasına geçer. Admin onayından sonra hesabı aktifleşir.
* **Erişim:** Mobil uygulama üzerinden çiftçi paneline erişir.
* **Yetkiler:**
  - Ürün ekleme, güncelleme, pasife alma (stok durumu: `available`, `out_of_stock`, `limited`).
  - Profilini güncelleme (işletme adı, bio, konum, profil resmi, gösterilecek telefon).
  - Kendisine tanımlanan kota dahilinde yeni davet kodları üretme ve diğer üreticileri platforma davet etme.

### C. Yönetici (Admin)
* **Kayıt:** Sistem yöneticileri tarafından veritabanı düzeyinde oluşturulur. Genel kullanıcılar admin olamaz.
* **Erişim:** Yalnızca Web Admin Paneli üzerinden erişim sağlar (güvenlik nedeniyle mobil uygulamadan admin rotalarına erişilemez).
* **Yetkiler:**
  - **Başvuru Yönetimi:** Çiftçi başvurularını inceleme, tanıtım videolarını izleme, onaylama veya reddetme.
  - **Çiftçi Moderasyonu:** Aktif çiftçi listesini yönetme, kurucu çiftçi (founding farmer) statüsü verme, davet kotalarını güncelleme, kurallara uymayan hesapları askıya alma (`suspend`) veya tekrar aktifleştirme.
  - **Ürün Moderasyonu:** Yeni eklenen ürünleri onaylama (onaylanana kadar ürünler public listede görünmez), sakıncalı ürünleri reddetme, gizleme veya silme.
  - **Kategori Yönetimi:** Hiyerarşik kategori ağacını düzenleme (ekleme, güncelleme, pasife alma).
  - **İstatistik & Analiz:** Şehir bazlı üretici yoğunluğu, davet ağacı ilişkileri gibi analitik verileri inceleme.
  - **Audit Log (Denetim Günlüğü):** Hangi adminin hangi işlemi ne zaman yaptığını (immutably) takip etme.

---

## 4. Kullanıcı Durumları (Status)

Kullanıcıların sistemdeki erişim yetkileri rollerinin yanı sıra durumlarına bağlıdır:

* **Active (Aktif):** Tüm normal işlemleri gerçekleştirebilir.
* **Suspended (Askıda):** Hesabı admin tarafından dondurulmuştur. Giriş yapabilir ancak API korumalı kaynaklara erişmek istediğinde `ACCOUNT_SUSPENDED` hatası alır ve işlem yapamaz.
* **Pending (Beklemede):** Başvuru aşamasındaki çiftçiler için geçerlidir. Henüz sisteme giriş yapamazlar.

---

## Bağlantılı Dosyalar
- [02_ARCHITECTURE.md](file:///c:/Projeler/koyden-sehire-mobil/docs/gemini/02_ARCHITECTURE.md)
- [README.md](file:///c:/Projeler/koyden-sehire-mobil/README.md)
