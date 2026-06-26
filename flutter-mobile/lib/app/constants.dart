class AppConstants {
  /// API base URL. Provided at build time via --dart-define=BASE_URL=...
  ///
  /// The default value targets the Android emulator's host loopback
  /// (10.0.2.2) on port 8080 for local development. **Release builds MUST
  /// override BASE_URL via --dart-define** — otherwise the production app
  /// would attempt cleartext HTTP to a non-routable address and silently
  /// fail. Use `assertReleaseBaseUrl()` at app startup to enforce this.
  static String get baseUrl {
    String url = const String.fromEnvironment(
      'BASE_URL',
      defaultValue: 'http://10.0.2.2:8080/api/v1',
    );
    
    // Protokol eksikse (örn: Sadece localhost veya 192.168.1.5 yazılmışsa) http:// ekle
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }

    if (url.endsWith('/api/v1') || url.endsWith('/api/v1/')) {
      return url;
    }
    if (url.endsWith('/api') || url.endsWith('/api/')) {
      return url.endsWith('/') ? '${url}v1' : '$url/v1';
    }
    return url.endsWith('/') ? '${url}api/v1' : '$url/api/v1';
  }

  /// Returns true when the baseUrl is still the development default.
  /// Call this in `main()` and abort the release build if true.
  static bool get isDevDefaultBaseUrl => baseUrl == 'http://10.0.2.2:8080/api/v1';

  /// Google Maps API key. Provided at build time via --dart-define=GOOGLE_MAPS_API_KEY=...
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  /// FCM Web VAPID key — Firebase Console → Project Settings →
  /// Cloud Messaging → Web configuration → Web Push certificates.
  /// Provide at build time: --dart-define=VAPID_KEY=BH...
  static const String vapidKey = String.fromEnvironment(
    'VAPID_KEY',
    defaultValue: '',
  );

  static const String appName = 'Köyden Şehre';
  static const String appTagline = 'Yerel üreticilerden taze ürünler';
  static const String appVersion = '1.0.0';

  static const Duration apiConnectTimeout = Duration(seconds: 30);
  static const Duration apiReceiveTimeout = Duration(seconds: 30);

  static const int productsPageSize = 20;
  static const int otpResendCooldownSeconds = 60;
  static const int otpLength = 6;

  static const int maxProductImages = 5;
  static const int maxProductImageBytes = 5 * 1024 * 1024;
  static const int maxProfileImageBytes = 2 * 1024 * 1024;
  static const int maxApplicationVideoBytes = 50 * 1024 * 1024;

  static const String platformInfoText = 'Köyden Şehre, üreticilerle alıcıları doğrudan buluşturan komisyonsuz '
      'bir platformdur. Platform üzerinden ödeme, sipariş, kargo veya '
      'uygulama içi mesajlaşma yapılmaz.';

  static const List<String> turkishCities = [
    'Adana', 'Adıyaman', 'Afyonkarahisar', 'Ağrı', 'Amasya',
    'Ankara', 'Antalya', 'Artvin', 'Aydın', 'Balıkesir',
    'Bilecik', 'Bingöl', 'Bitlis', 'Bolu', 'Burdur',
    'Bursa', 'Çanakkale', 'Çankırı', 'Çorum', 'Denizli',
    'Diyarbakır', 'Edirne', 'Elazığ', 'Erzincan', 'Erzurum',
    'Eskişehir', 'Gaziantep', 'Giresun', 'Gümüşhane', 'Hakkari',
    'Hatay', 'Isparta', 'Mersin', 'İstanbul', 'İzmir',
    'Kars', 'Kastamonu', 'Kayseri', 'Kırklareli', 'Kırşehir',
    'Kocaeli', 'Konya', 'Kütahya', 'Malatya', 'Manisa',
    'Kahramanmaraş', 'Mardin', 'Muğla', 'Muş', 'Nevşehir',
    'Niğde', 'Ordu', 'Rize', 'Sakarya', 'Samsun',
    'Siirt', 'Sinop', 'Sivas', 'Tekirdağ', 'Tokat',
    'Trabzon', 'Tunceli', 'Şanlıurfa', 'Uşak', 'Van',
    'Yozgat', 'Zonguldak', 'Aksaray', 'Bayburt', 'Karaman',
    'Kırıkkale', 'Batman', 'Şırnak', 'Bartın', 'Ardahan',
    'Iğdır', 'Yalova', 'Karabük', 'Kilis', 'Osmaniye', 'Düzce',
  ];
  static String formatDevUrl(String url) {
    if (url.isEmpty) return url;
    String formatted = url;
    if (isDevDefaultBaseUrl) {
      formatted = formatted
          .replaceAll('//localhost:', '//10.0.2.2:')
          .replaceAll('//127.0.0.1:', '//10.0.2.2:')
          .replaceAll('//minio:', '//10.0.2.2:');
    } else {
      formatted = formatted.replaceAll('//minio:', '//localhost:');
    }
    return formatted;
  }
}
