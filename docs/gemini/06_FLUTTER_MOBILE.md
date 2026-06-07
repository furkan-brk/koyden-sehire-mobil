# Köyden Şehire — Flutter Mobil & Web Mimarisi

Bu doküman, **Köyden Şehire** projesinin Flutter (Dart) tabanlı mobil ve web admin panel mimarisini, durum yönetimini (State Management), yönlendirme sistemini (Routing) ve API entegrasyon yapısını detaylandırır.

---

## 1. Mimari Katmanlar

Uygulama, sorumlulukların ayrılması (Separation of Concerns) prensibine göre katmanlandırılmıştır:

```
┌─────────────────────────────────────────────────────────────┐
│                      UI KATMANI (Views)                     │
│  lib/views/...                                              │
│  - Rol bazlı klasörler: admin, auth, customer, farmer, public │
│  - Shared Widget'lar (AppButton, ProductCard, OtpInput)    │
└──────────────────────────────┬──────────────────────────────┘
                               │ Kullanıcı Aksiyonları
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                 KONTROL KATMANI (Controllers)               │
│  lib/controllers/...                                        │
│  - GetxController sınıfları (İş mantığı ve UI state)        │
└──────────────────────────────┬──────────────────────────────┘
                               │ Veri İsteği
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                 VERİ KATMANI (Repositories)                 │
│  lib/services/*_repository.dart                             │
│  - ApiClient üzerinden HTTP istekleri                       │
│  - Dart modellerine (fromJson) dönüşüm                       │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Durum Yönetimi & Bağımlılık Enjeksiyonu (GetX)

Uygulamanın başlangıcında, `AppBinding` vasıtasıyla tüm temel servisler, depolar (repositories) ve denetleyiciler (controllers) kaydedilir.

### Bağımlılık Ömürleri (Dependency Lifecycle)
1. **Kalıcı Servisler (`permanent: true`):** Uygulama açık olduğu sürece bellekten silinmeyen servislerdir.
   - `SecureStorageService`: Token'ların cihaz hafızasında güvenli saklanması.
   - `AuthService`: Kullanıcının login/logout durumu ve aktif rol bilgisi.
   - `ConnectivityService`: İnternet bağlantı durumu.
   - `ApiClient`: Dio tabanlı HTTP istemcisi.
2. **Lazy/Fenix Yüklemeler (`fenix: true`):** İlk kez ihtiyaç duyulduğunda oluşturulan, ekran kapatıldığında bellekten temizlenen ancak o ekrana tekrar girildiğinde otomatik olarak yeniden üretilen sınıflardır. Controller ve Repository'ler bu yöntemle kaydedilir.

---

## 3. Declarative Yönlendirme (GoRouter) & Auth Guard

Yönlendirme sistemi `go_router` ile yönetilir. GetX `AuthService`'deki kimlik doğrulama durumu ile GoRouter arasında bir köprü kurulmuştur.

### GoRouter ↔ GetX Köprüsü (`_RouterRefreshListenable`)
`AuthService.status` reaktif bir değişkendir. Router dosyasında tanımlı `_RouterRefreshListenable` sınıfı, GetX'in `ever()` işçisini (worker) kullanarak bu durumu dinler. Durum her değiştiğinde `notifyListeners()` çağrılarak GoRouter'ın yönlendirme guard'larını tetiklemesi sağlanır.

```dart
// lib/app/router.dart
class _RouterRefreshListenable extends ChangeNotifier {
  _RouterRefreshListenable(AuthService authService) {
    ever(authService.status, (_) => notifyListeners());
  }
}
```

### Rota Koruma (Guard) Kuralları
* **Admin Yetkisi:** `/admin/*` altındaki tüm rotalar `role == "admin"` olmasını gerektirir.
* **Çiftçi Yetkisi:** `/farmer/*` altındaki tüm rotalar `role == "farmer"` ve `status == "active"` olmasını gerektirir.
* **Ziyaretçi Kısıtlaması:** Giriş yapmış bir kullanıcı tekrar `/login` veya `/register` rotalarına gidemez; doğrudan ilgili dashboard ekranına yönlendirilir.
* **Mobil/Web Ayrımı:** Admin paneli rotaları (`/login/admin`, `/admin/*`) yalnızca **`kIsWeb == true`** olduğunda router'a kaydedilir. Mobil derlemede bu rotalar tanımsızdır (404 döner).

---

## 4. HTTP İstemcisi — Dio + Otomatik Token Yenileme

Tüm HTTP çağrıları `ApiClient` sınıfı üzerinden yapılır. Dio interceptor yapısı kullanılarak kimlik doğrulama süreci tamamen otomatikleştirilmiştir.

### `_AuthInterceptor` Çalışma Akışı (JWT Silent Refresh)

```
[İstek Gönderiliyor] ──> Header'a "Bearer <access_token>" ekle
                                │
                        [Yanıt Alındı]
                                │
                 ┌──────────────┴──────────────┐
           (HTTP 200 OK)                 (HTTP 401 Unauthorized)
                 │                             │
          İşlemi tamamla            1. Gelen istek /auth/refresh mi?
                                       (Evet ise -> Oturumu kapat, döngüyü kır)
                                    2. refresh_token var mı? (Yoksa -> Oturumu kapat)
                                    3. Sunucuya istek at: POST /auth/refresh
                                       { refresh_token }
                                                │
                                       ┌────────┴────────┐
                                   (Başarılı)        (Başarısız/401)
                                       │                 │
                              Yeni token'ları kaydet   Oturumu kapat,
                              Orijinal isteği yeni     kullanıcıyı /login'e
                              token ile tekrar gönder   yönlendir.
```

---

## 5. API Base URL Yapılandırması

API adresi derleme zamanında (compile-time) `--dart-define` parametresi ile enjekte edilir:

```bash
# Android emülatörü (Varsayılan - Localhost loopback)
flutter run

# Fiziksel cihaz ile test (Yerel IP adresi belirtilmeli)
flutter run --dart-define=BASE_URL=http://192.168.1.100:8080/api/v1

# Canlı ortam derlemesi (Production)
flutter build apk --dart-define=BASE_URL=https://api.koydensehire.com/api/v1
```

> [!IMPORTANT]
> `AppConstants.isDevDefaultBaseUrl` kontrolü, canlı ortam (release) build'lerinde yanlışlıkla yerel test URL'inin (`10.0.2.2`) kullanılmasını engelleyen koruyucu bir mekanizma içerir.

---

## Bağlantılı Dosyalar
- [02_ARCHITECTURE.md](file:///c:/Projeler/koyden-sehire-mobil/docs/gemini/02_ARCHITECTURE.md)
- [04_AUTH_AND_OTP_FLOW.md](file:///c:/Projeler/koyden-sehire-mobil/docs/gemini/04_AUTH_AND_OTP_FLOW.md)
- [MOBILE_INTEGRATION_GUIDE.md](file:///c:/Projeler/koyden-sehire-mobil/backend/docs/MOBILE_INTEGRATION_GUIDE.md)
