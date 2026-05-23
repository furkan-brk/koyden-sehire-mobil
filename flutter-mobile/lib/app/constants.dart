class AppConstants {
  /// API base URL. Provided at build time via --dart-define=BASE_URL=...
  ///
  /// The default value targets the Android emulator's host loopback
  /// (10.0.2.2) on port 8080 for local development. **Release builds MUST
  /// override BASE_URL via --dart-define** — otherwise the production app
  /// would attempt cleartext HTTP to a non-routable address and silently
  /// fail. Use `assertReleaseBaseUrl()` at app startup to enforce this.
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://10.0.2.2:8080/api/v1',
  );

  /// Returns true when the baseUrl is still the development default.
  /// Call this in `main()` and abort the release build if true.
  static bool get isDevDefaultBaseUrl => baseUrl == 'http://10.0.2.2:8080/api/v1';

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
}
