// "Uygulamada Aç" butonunun paylaşılan mantığı (apply / products / farmers).
//
// Neden gerekli: `location.href = 'koydensehire://...'` masaüstü tarayıcıda
// hiçbir şey yapmaz (şemayı karşılayan uygulama yok) ve uygulamanın kurulu
// olmadığı telefonlarda da sessizce başarısız olur. Buton "bozuk" görünür.
// Uygulama Flutter Web olarak da çalıştığı için (aynı go_router yolları,
// `usePathUrlStrategy` sayesinde temiz path'ler) tarayıcıda hedef doğrudan web
// sürümüdür. Durumlar:
//   • Masaüstü → web sürümündeki aynı yola yönlendirilir (deep link denenmez).
//   • Android  → intent:// denenir; uygulama kurulu değilse Chrome
//                browser_fallback_url ile web sürümüne düşer.
//   • iOS      → custom scheme denenir; 1.5 sn sonra sayfa hâlâ görünürse
//                (uygulamaya geçilmediyse) web sürümüne gidilir.
// Web adresi bilinmiyorsa (aşağıdaki PROD_WEB_APP_ORIGIN boşsa ve localhost
// değilsek) yönlendirme yerine ne yapılacağını anlatan uyarı gösterilir.
(function () {
  var ANDROID_PACKAGE = 'com.koydensehire.koyden_sehire';
  var SCHEME = 'koydensehire';
  var FAIL_HASH = '#app-yok';

  // Flutter Web sürümünün yayında olduğu origin. Boşsa web yönlendirmesi
  // yapılmaz (yalnızca uyarı gösterilir). VDS/tünel adresi belirlendiğinde
  // burayı doldurun, örn. 'https://app.koydensehire.com'.
  var PROD_WEB_APP_ORIGIN = '';
  // Yerel geliştirmede `flutter run -d chrome --web-port 3001` adresi.
  var DEV_WEB_APP_ORIGIN = 'http://localhost:3001';
  var UA = navigator.userAgent || '';
  var isAndroid = /android/i.test(UA);
  // iPadOS 13+ Safari kendini Mac gibi tanıtır; dokunma desteğiyle ayırt edilir.
  var isIOS =
    /iPad|iPhone|iPod/.test(UA) ||
    (/Macintosh/.test(UA) && navigator.maxTouchPoints > 1);
  var isMobile = isAndroid || isIOS;

  // Web sürümünün adresi: ?web=... > localhost ise dev adresi > prod sabiti.
  function webAppOrigin() {
    var override = new URLSearchParams(location.search).get('web');
    if (override) return override.replace(/\/+$/, '');
    if (/^(localhost|127\.0\.0\.1|\[::1\])$/.test(location.hostname)) {
      return DEV_WEB_APP_ORIGIN;
    }
    return PROD_WEB_APP_ORIGIN;
  }

  /**
   * @param {Object} opts
   * @param {string} opts.path      Uygulama içi yol, örn. 'apply' veya 'products/42'
   * @param {string} [opts.query]   '?invite=KYS-XXXXXX' gibi (baştaki ? dahil)
   * @param {HTMLElement} opts.button
   * @param {HTMLElement} opts.notice
   * @param {string} [opts.desktopMessage]
   * @param {string} [opts.notInstalledMessage]
   * @param {boolean} [opts.autoOpen] Sayfa açılışında otomatik denenir mi
   */
  window.initOpenApp = function (opts) {
    var query = opts.query || '';
    // Host segmenti ('app') şart: 'koydensehire://apply' yazılırsa 'apply' host
    // olarak parse edilir, path boş kalır ve go_router ana sayfayı açar.
    var customUrl = SCHEME + '://app/' + opts.path + query;

    // Flutter Web sürümündeki aynı yol (go_router path'leri birebir aynı).
    var origin = webAppOrigin();
    var webUrl = origin ? origin + '/' + opts.path + query : '';

    // Uygulama yoksa Chrome ERR_UNKNOWN_URL_SCHEME göstermek yerine buraya
    // döner: web sürümü varsa doğrudan ona, yoksa bu sayfaya #app-yok ile.
    var fallbackUrl = webUrl || location.href.split('#')[0] + FAIL_HASH;
    var intentUrl =
      'intent://app/' +
      opts.path +
      query +
      '#Intent;scheme=' + SCHEME +
      ';package=' + ANDROID_PACKAGE +
      ';S.browser_fallback_url=' + encodeURIComponent(fallbackUrl) +
      ';end';

    var desktopMessage =
      opts.desktopMessage ||
      'Uygulamada açma yalnızca telefonda çalışır. Bu sayfayı telefonunuzdan ' +
        'açın veya Köyden Şehre uygulamasını yükleyin.';
    var notInstalledMessage =
      opts.notInstalledMessage ||
      'Uygulama bulunamadı. Köyden Şehre uygulamasını yükledikten sonra tekrar deneyin.';

    function showNotice(text) {
      if (!opts.notice) return;
      opts.notice.textContent = text;
      opts.notice.hidden = false;
    }

    // Android fallback'ten döndüysek uygulama kurulu değil demektir.
    if (location.hash === FAIL_HASH) {
      showNotice(notInstalledMessage);
    }

    function tryOpen() {
      if (!isMobile) {
        // Tarayıcıda deep link'in karşılığı yok; web sürümüne git.
        if (webUrl) {
          location.href = webUrl;
        } else {
          showNotice(desktopMessage);
        }
        return;
      }
      if (isAndroid) {
        location.href = intentUrl; // başarısızsa fallbackUrl'e döner
        return;
      }
      // iOS: custom scheme; açılmadıysa web sürümüne düş.
      location.href = customUrl;
      setTimeout(function () {
        if (document.visibilityState !== 'visible') return;
        if (webUrl) {
          location.href = webUrl;
        } else {
          showNotice(notInstalledMessage);
        }
      }, 1500);
    }

    if (opts.button) {
      opts.button.addEventListener('click', tryOpen);
      if (!isMobile) {
        opts.button.textContent = webUrl ? 'Web’de Aç' : 'Uygulamada Aç (telefonda)';
      }
    }

    // Otomatik deneme: yalnızca Android'de ve fallback'ten dönmediysek
    // (yoksa sayfa ↔ intent arasında döngüye girer). iOS Safari, kullanıcı
    // jesti olmayan custom-scheme yönlendirmesinde hata popup'ı gösterir.
    if (opts.autoOpen && isAndroid && location.hash !== FAIL_HASH) {
      setTimeout(function () {
        location.href = intentUrl;
      }, 600);
    }
  };
})();
