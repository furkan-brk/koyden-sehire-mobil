# invite-web

Davet ve ürün linklerinin açıldığı statik site — Netlify'da
**https://koydensehire.netlify.app** adresinde yayında.

> ⚠️ Neden Cloudflare Pages değil: `*.pages.dev` ve `*.workers.dev`
> alan adları Türkiye'de erişime engelli (TFF/BTK kararı, Kasım 2025).
> Türkiye'deki kullanıcılar o adresleri hiç açamıyor.

## Dosyalar

- `apply/index.html` — `/apply?invite=KYS-XXXXXX` sayfası: kodu gösterir,
  `koydensehire://app/apply?invite=...` deep link'iyle uygulamayı açmayı
  dener. (Custom scheme'de `app/` host segmenti şart — hostsuz yazılırsa
  path boş kalır ve go_router ana sayfayı açar.)
- `products/index.html` — `/products/<id>` ürün paylaşım linki sayfası;
  `koydensehire://app/products/<id>` ile uygulamada ürün detayını açar.
- `open-app.js` — üç sayfanın paylaştığı "Uygulamada Aç" mantığı. Uygulama
  Flutter Web olarak da çalıştığı ve `usePathUrlStrategy()` sayesinde
  go_router yolları birebir aynı olduğu için tarayıcıdaki hedef doğrudan web
  sürümüdür (`<web-origin>/apply?invite=…`, `<web-origin>/products/<id>`).
  - **Masaüstü:** custom scheme'i karşılayacak uygulama yok (tarayıcı sessizce
    yutuyordu, buton bozuk görünüyordu) → web sürümündeki aynı yola
    yönlendirilir. Web adresi bilinmiyorsa ne yapılacağını anlatan uyarı çıkar.
  - **Android:** `intent://app/<yol>#Intent;scheme=koydensehire;package=…;
    S.browser_fallback_url=<web sürümü veya bu sayfa#app-yok>;end`. Uygulama
    kurulu değilse Chrome `ERR_UNKNOWN_URL_SCHEME` yerine web sürümüne düşer.
    Web adresi tanımsızsa sayfaya `#app-yok` ile döner ve "uygulama
    bulunamadı" uyarısı çıkar; otomatik deneme `#app-yok` varken
    tekrarlanmaz (sonsuz döngü olurdu).
  - **iOS:** custom scheme denenir; 1.5 sn sonra sayfa hâlâ görünürse
    (uygulamaya geçilmediyse) web sürümüne gidilir.

  **Web adresi nasıl belirlenir** (`open-app.js` başındaki sabitler):
  1. `?web=https://...` query parametresi (test için, prod sayfadan dev
     uygulamaya bakmak dahil),
  2. sayfa `localhost`/`127.0.0.1`'den servis ediliyorsa `DEV_WEB_APP_ORIGIN`
     (`http://localhost:3001` — `flutter run -d chrome --web-port 3001`),
  3. aksi halde `PROD_WEB_APP_ORIGIN`. **Bu sabit şu an boş** — Flutter Web
     sürümünün yayın adresi (VDS/cloudflared tüneli veya ikinci bir Netlify
     sitesi) belirlendiğinde doldurulmalı, yoksa paylaşılan linkler
     masaüstünde içeriği açmak yerine uyarı gösterir.
- `_redirects` — `/products/*` isteklerini products sayfasına rewrite eder.
- `.well-known/assetlinks.json` — Android App Links doğrulaması
  (paket adı + imza SHA-256 parmak izi). İmza anahtarı değişirse
  (örn. release keystore oluşturulursa) fingerprint'i buraya ekleyip
  yeniden deploy edin:

  ```bash
  keytool -list -v -keystore <keystore> -alias <alias> | grep SHA256
  ```

- `.well-known/apple-app-site-association` — iOS Universal Links
  (appID = TeamID `4R4TSA4998` + bundle `com.koydensehire.koydenSehire`).
- `_headers` — AASA dosyasının `application/json` içerik tipiyle servis
  edilmesini sağlar (Netlify uzantısız dosyaya octet-stream verir).

Otomatik uygulama açma yalnızca Android tarayıcılarında denenir; iOS
Safari'de uygulama yüklü değilse otomatik custom-scheme yönlendirmesi
hata popup'ı gösterdiğinden orada yalnızca buton kullanılır.

## Yerel test

```bash
# 1) Web sürümü
cd flutter-mobile && flutter run -d chrome --web-port 3001 \
  --dart-define=BASE_URL=http://localhost:8080/api/v1

# 2) Davet sayfası
cd invite-web && python -m http.server 5601
# http://localhost:5601/apply/index.html?invite=KYS-E08HHI
```

Sayfa localhost'tan servis edildiği için buton "Web'de Aç" olur ve
`http://localhost:3001/apply?invite=KYS-E08HHI` adresine yönlendirir.
Yayındaki sayfayı dev uygulamaya bağlamak için:
`https://koydensehire.netlify.app/apply?invite=KYS-E08HHI&web=http://localhost:3001`

## Deploy

```bash
# Repo kökünden (bir kez: npx netlify-cli login)
npx netlify-cli deploy --dir invite-web --prod --site koydensehire --no-build
```

## Gerçek domain (koydensehire.com) alındığında

1. Domain'i Netlify sitesine custom domain olarak bağlayın.
2. `AndroidManifest.xml`'deki App Links filtresine host olarak ekleyin.
3. `ios/Runner/Runner.entitlements`'a `applinks:koydensehire.com` geri ekleyin.
4. `WEB_BASE_URL` dart-define'ını güncelleyin.
