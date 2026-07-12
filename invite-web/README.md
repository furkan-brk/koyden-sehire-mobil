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
