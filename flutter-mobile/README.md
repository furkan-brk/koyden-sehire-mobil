# Köyden Şehire — Flutter Uygulaması

Üreticilerle alıcıları doğrudan buluşturan komisyonsuz platformun Flutter uygulaması.  
Android, iOS ve Web (admin paneli) hedeflerini tek kod tabanından destekler.

---

## Gereksinimler

- Flutter ≥ 3.19.0
- Dart SDK ≥ 3.3.0
- Backend servisleri çalışıyor olmalı → kök dizindeki `docker compose up -d`

---

## Çalıştırma

```bash
flutter pub get

# Android emülatör (varsayılan — 10.0.2.2:8080)
flutter run

# Fiziksel Android / iOS cihaz
flutter run --dart-define=BASE_URL=http://<yerel-ip>:8080/api/v1

# iOS simülatör
flutter run --dart-define=BASE_URL=http://localhost:8080/api/v1

# Web (admin paneli)
flutter run -d chrome --dart-define=BASE_URL=http://localhost:8080/api/v1
```

> **Release build:** `BASE_URL` mutlaka override edilmelidir.  
> `AppConstants.isDevDefaultBaseUrl` ile production'da varsayılan URL kullanılması önlenebilir.

---

## Proje Yapısı

```
lib/
├── main.dart                    ← AppBinding başlatır, GoRouter ayarlanır
├── app/
│   ├── app.dart                 ← MaterialApp.router
│   ├── router.dart              ← GoRouter tanımı + auth redirect guard
│   ├── theme.dart               ← Renk paleti, tipografi (PlusJakartaSans)
│   └── constants.dart           ← BASE_URL, timeout, boyut limitleri
├── core/
│   ├── api/
│   │   ├── api_client.dart      ← Dio wrapper; 401'de otomatik token yenileme
│   │   └── api_endpoints.dart   ← Endpoint sabit stringleri
│   ├── bindings/app_binding.dart ← Global DI: tüm servis ve controller kayıtları
│   ├── services/
│   │   ├── auth_service.dart    ← Global auth state (GetxService)
│   │   └── connectivity_service.dart
│   ├── storage/secure_storage_service.dart ← Token + kullanıcı bilgisi
│   ├── errors/                  ← AppException, DioException eşleme
│   └── utils/                   ← Tarih, telefon, validasyon yardımcıları
├── bindings/                    ← Route bazlı GetX binding'leri
│   ├── admin/
│   └── (diğer route'lar AppBinding'de lazy kayıtlı)
├── controllers/                 ← GetxController; rol bazlı alt klasörler
│   ├── admin/
│   ├── farmer/
│   └── public/
├── services/                    ← *_repository.dart; typed HTTP çağrıları
├── models/                      ← fromJson Dart modelleri; rol bazlı
├── views/                       ← Ekran widget'ları
│   ├── admin/                   ← Web-only (kIsWeb kontrolü)
│   ├── auth/
│   ├── customer/
│   ├── farmer/
│   ├── farmer_application/
│   ├── otp/
│   ├── public/
│   └── splash/
└── shared/
    ├── widgets/                 ← AppButton, ProductCard, OtpInput, ShimmerCard…
    ├── extensions/              ← BuildContext, String uzantıları
    └── models/pagination_model.dart
```

---

## Mimari Kararlar

### State Yönetimi — GetX
- `AuthService` (`GetxService`, `permanent: true`) → global auth state
- `AppBinding.dependencies()` → tüm bağımlılıklar uygulama başında `lazyPut(fenix: true)` ile kaydedilir
- Controller'lar `Get.find<T>()` ile erişilir; ekran kapatılınca temizlenir, tekrar açılınca yeniden oluşturulur

### Routing — GoRouter + GetX Köprüsü
`_RouterRefreshListenable`, GetX `ever()` worker'ı ile `AuthService.status`'ı dinler ve `ChangeNotifier.notifyListeners()` çağırarak GoRouter'ın redirect'ini yeniden değerlendirir.

```
AuthStatus                → GoRouter redirect
─────────────────────────────────────────────
admin                     → /admin/dashboard
farmerActive              → /farmer/dashboard (auth sayfaları engellenir)
customerActive            → public + /customer/* serbest
loggedOut/unknown         → /farmer/*, /admin/* → /login
```

### HTTP — Dio + AuthInterceptor
- Her istek `Authorization: Bearer <token>` header'ı ile gider
- 401 alınırsa: refresh token → yeni access token → orijinal isteği tekrarla
- Refresh başarısız olursa: `SecureStorage` temizlenir → `AuthService.handleUnauthorized()` → logout

### Admin Paneli — Web Only
`/login/admin` ve `/admin/*` rotaları yalnızca `kIsWeb == true` olduğunda GoRouter'a kaydedilir. Mobil build'de bu rotalar yoktur.

---

## Bağımlılıklar (Özet)

| Paket | Kullanım |
|-------|----------|
| `get` | State, DI, lifecycle |
| `go_router` | Tip-güvenli navigasyon, deep link |
| `dio` | HTTP, interceptor |
| `flutter_secure_storage` | Token ve kullanıcı bilgisi |
| `image_picker` + `video_compress` | Medya seçimi ve sıkıştırma |
| `cached_network_image` | Görsel önbellekleme |
| `shimmer` | Yükleme iskelet animasyonu |
| `fl_chart` | Admin dashboard grafikleri |
| `connectivity_plus` | Çevrimdışı algılama |

---

## Kapsam Dışı (Tasarım Kararı)

- Uygulama içi ödeme, sipariş, kargo
- Çiftçi–müşteri mesajlaşma
- Push bildirim (FCM/APNs)
- Çevrimdışı önbellekleme (kategori listesi dışında)
