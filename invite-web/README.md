# invite-web

Davet linklerinin açıldığı statik site — Netlify'da
**https://koydensehire.netlify.app** adresinde yayında.

> ⚠️ Neden Cloudflare Pages değil: `*.pages.dev` ve `*.workers.dev`
> alan adları Türkiye'de erişime engelli (TFF/BTK kararı, Kasım 2025).
> Türkiye'deki kullanıcılar o adresleri hiç açamıyor.

- `apply/index.html` — `/apply?invite=KYS-XXXXXX` sayfası: kodu gösterir,
  `koydensehire://apply?invite=...` deep link'iyle uygulamayı açmayı dener.
- `.well-known/assetlinks.json` — Android App Links doğrulaması
  (paket adı + imza SHA-256 parmak izi). İmza anahtarı değişirse
  (örn. release keystore oluşturulursa) fingerprint'i buraya ekleyip
  yeniden deploy edin:

  ```bash
  keytool -list -v -keystore <keystore> -alias <alias> | grep SHA256
  ```

## Deploy

```bash
# Repo kökünden (bir kez: npx netlify-cli login)
npx netlify-cli deploy --dir invite-web --prod --site koydensehire --no-build
```

Gerçek `koydensehire.com` domain'i alındığında: domain'i Netlify sitesine
custom domain olarak bağlayın, `AndroidManifest.xml`'deki App Links
filtresine host olarak ekleyin ve `WEB_BASE_URL` dart-define'ını güncelleyin.
