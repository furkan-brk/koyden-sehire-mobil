# Köyden Şehire — Açık Sorunlar & Yapılacaklar Listesi

Bu doküman, projede aktif olarak çözülmesi bekleyen hataları, kullanıcı deneyimi (UX) iyileştirmelerini ve `notlar.md` dosyasından derlenen yapılacaklar (TODO) listesini içerir. Gemini Gem'in kod yazarken veya planlama yaparken bu hedefleri önceliklendirmesi gerekir.

---

## 1. `notlar.md` Analizi & Çözülecek Maddeler

Projenin kök dizinindeki `notlar.md` dosyasında yer alan maddelerin teknik detayları ve çözüm stratejileri aşağıda listelenmiştir:

### 🟥 Öncelikli Hatalar & Buglar

#### 1. "Bildirimler Yüklenemedi çöz"
* **Sorun:** Flutter mobil uygulamasında bildirimler sayfasına girildiğinde "Bildirimler Yüklenemedi" hatası alınıyor.
* **Analiz:** API'deki notifications endpoint'i ile istemcideki servis çağrısı arasındaki veri formatı uyumsuzluğu veya n8n webhook dönüş hatası kontrol edilmeli.

#### 2. "Tüketici ekranında Market Ana sayfa çakışması çöz"
* **Sorun:** Müşteri (Customer) arayüzünde alt gezinme çubuğu (Bottom Navigation Bar) üzerinde "Market" ve "Ana Sayfa" sekmelerinin durumları çakışıyor, geçişlerde sayfa state'leri birbirini bozuyor.
* **Analiz:** GoRouter shell route yapısı veya GetX controller'larının lifecycle (`onInit`, `onDelete`) durumları incelenmeli.

---

### 🟨 Arayüz (UI/UX) ve Yönlendirme İyileştirmeleri

#### 3. "Profil Ekranı Sayfalara yönlendirsin"
* **Sorun:** Profil ekranındaki butonlar/kartlar şu an işlevsiz veya yanlış yere yönlendiriyor.
* **Çözüm:** Profil ekranından; "Ürünlerim", "Bilgilerimi Güncelle", "Davet Kodlarım", "Çıkış Yap" gibi alt sayfalara yönlendirmelerin `context.go()` veya `context.push()` ile go_router üzerinden bağlanması gerekiyor.

#### 4. "Üretici Panel ve Ürünlerim sayfaları güncellenecek"
* **Görev:** Çiftçi (Farmer) paneli ana ekranı ve çiftçinin kendi ürünlerini listelediği sayfanın tasarımı modernleştirilmeli.
* **Çözüm:** Ürün durumları (`active`, `pending`, `rejected`) görsel etiketlerle (Badge) ayrılmalı ve daha temiz kart tasarımlarına geçilmeli.

#### 5. "Ürün yükleme ekranı ve ürün kısımları görselleştirilmeli"
* **Görev:** Çiftçinin ürün ekleme arayüzü çok sade ve form ağırlıklı.
* **Çözüm:** Resim yükleme alanı sürükle-bırak veya görsel seçim kutularıyla zenginleştirilmeli. Ürün birimleri (kg, lt, adet) için seçim bileşenleri (Dropdown/Segmented Control) eklenmeli.

#### 6. "Stich'e bakarak ui'ları daha güzel ve tutarlı hale getir"
* **Görev:** Tasarım rehberi veya "Stich" referans tasarımına uyularak tüm uygulamanın renk, font (Plus Jakarta Sans) ve bileşen tutarlılığı (Design System) optimize edilmeli.

---

### 🟩 Test ve Altyapı İşleri

#### 7. "Android ve IOS için bildirimleri test et"
* **Görev:** Firebase Cloud Messaging (FCM) ve Apple Push Notification service (APNs) entegrasyonlarının cihazlar üzerinde uçtan uca test edilmesi.

#### 8. "Snackbar servis test et"
* **Görev:** GetX veya ScaffoldMessenger tabanlı ortak uyarı/hata gösterim mekanizmasının (Snackbar) farklı senaryolarda (internet kesintisi, sunucu hatası, başarı mesajları) kararlılığının test edilmesi.

---

## 2. Bildirim Matrisi Planlaması

`notlar.md` dosyasındaki *13. madde: "Bildirim atılacak kısımlar ve hangi tür kullanıcılara hangi tür bildirimlerin ne zaman gideceğinin planlanması"* kapsamında önerilen bildirim senaryoları matrisi:

| Tetikleyici Olay (Event) | Alıcı Rolü | Bildirim Kanalı | Gönderilecek İçerik |
| :--- | :--- | :--- | :--- |
| **Çiftçi Başvurusu Gönderildi** | Admin | n8n / Webhook | "Yeni çiftçi başvurusu alındı: {işletme_adı}" |
| **Başvuru Onaylandı** | Çiftçi | SMS / Push | "Tebrikler, başvurunuz onaylandı! Giriş yapabilirsiniz." |
| **Başvuru Reddedildi** | Çiftçi | SMS / Push | "Başvurunuz reddedildi. Sebep: {rejection_reason}" |
| **Ek Video İstendi** | Çiftçi | SMS / Push | "Başvurunuz için ek tanıtım videosu gerekiyor. Lütfen yükleyin." |
| **Yeni Ürün Yüklendi** | Admin | n8n / Webhook | "Onay bekleyen yeni ürün: {ürün_başlığı} - Çiftçi: {ad}" |
| **Ürün Onaylandı** | Çiftçi | Push Bildirim | "Ürününüz onaylandı ve yayına alındı: {ürün_başlığı}" |
| **Ürün Reddedildi** | Çiftçi | Push Bildirim | "Ürününüz reddedildi. Not: {admin_note}" |
| **Davet Kodu Kullanıldı** | Çiftçi (Davet Sahibi) | Push Bildirim | "Davet kodunuzla yeni bir üretici başvurdu!" |

---

## 3. Uzun Vadeli Yol Haritası (Backlog)

1. **Arama Algoritması Geliştirme (PostgreSQL Full-Text Search):** Mevcut `ILIKE` sorguları yerine `pg_trgm` uzantısı kullanılarak yazım hatalarını tolere eden gelişmiş arama entegrasyonu.
2. **Favori/Kaydetme Özelliği:** Müşterilerin beğendikleri çiftçileri veya ürünleri takibe alabilmesi.
3. **Kategori Önbellekleme (Caching):** Çok sık değişmeyen kategori ağacının Redis'te cache'lenmesi ve API yanıt sürelerinin düşürülmesi.

---

## Bağlantılı Dosyalar
- [01_PROJECT_OVERVIEW.md](file:///c:/Projeler/koyden-sehire-mobil/docs/gemini/01_PROJECT_OVERVIEW.md)
- [04_AUTH_AND_OTP_FLOW.md](file:///c:/Projeler/koyden-sehire-mobil/docs/gemini/04_AUTH_AND_OTP_FLOW.md)
- [notlar.md](file:///c:/Projeler/koyden-sehire-mobil/notlar.md)
