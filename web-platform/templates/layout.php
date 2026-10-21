<?php

use App\Core\Config;
use App\Core\RequestContext;
use App\Core\View;

$appName = Config::string('APP_NAME', 'Tanıdıkla');
$adminArea = str_starts_with((string) $bodyClass, 'admin');
$appUrl = rtrim(Config::string('APP_URL'), '/');
$brandSymbolPath = '/assets/brand/tanidikla-symbol.png';
$brandHorizontalPath = '/assets/brand/tanidikla-logo-horizontal.png';
$brandWordmarkPath = '/assets/brand/tanidikla-wordmark.png';
$defaultOpenGraphImage = $appUrl !== '' ? $appUrl . $brandHorizontalPath : $brandHorizontalPath;
$resolvedOpenGraphImage = is_string($openGraphImage) && $openGraphImage !== '' ? $openGraphImage : $defaultOpenGraphImage;
$robots = $adminArea ? 'noindex,nofollow,noarchive' : (string) ($robots ?? 'index,follow,max-image-preview:large');
$googleSiteVerification = trim(Config::string('GOOGLE_SITE_VERIFICATION'));
$mapTileUrl = Config::string('MAP_TILE_URL', 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
$mapTileAttribution = Config::string('MAP_TILE_ATTRIBUTION', '&copy; OpenStreetMap katkıcıları');
$mapTileMaxZoom = max(1, min(22, Config::int('MAP_TILE_MAX_ZOOM', 19)));
$appCssVersion = (string) filemtime(APP_ROOT . '/public/assets/app.css');
$appJsVersion = (string) filemtime(APP_ROOT . '/public/assets/app.js');
$adminCssVersion = (string) filemtime(APP_ROOT . '/public/assets/admin-console.css');
$adminJsVersion = (string) filemtime(APP_ROOT . '/public/assets/admin-console.js');
?>
<!doctype html>
<html lang="tr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="<?= View::escape($description) ?>">
  <meta name="theme-color" content="#061d57">
  <meta name="application-name" content="<?= View::escape($appName) ?>">
  <meta name="apple-mobile-web-app-title" content="<?= View::escape($appName) ?>">
  <meta name="map-tile-url" content="<?= View::escape($mapTileUrl) ?>">
  <meta name="map-tile-attribution" content="<?= View::escape($mapTileAttribution) ?>">
  <meta name="map-tile-max-zoom" content="<?= View::escape((string) $mapTileMaxZoom) ?>">
  <meta name="robots" content="<?= View::escape($robots) ?>">
  <?php if ($googleSiteVerification !== ''): ?><meta name="google-site-verification" content="<?= View::escape($googleSiteVerification) ?>"><?php endif; ?>
  <meta property="og:type" content="<?= View::escape($openGraphType) ?>">
  <meta property="og:site_name" content="<?= View::escape($appName) ?>">
  <meta property="og:locale" content="tr_TR">
  <meta property="og:title" content="<?= View::escape($title) ?>">
  <meta property="og:description" content="<?= View::escape($description) ?>">
  <?php if (is_string($canonical) && $canonical !== ''): ?><meta property="og:url" content="<?= View::escape($canonical) ?>"><?php endif; ?>
  <meta property="og:image" content="<?= View::escape($resolvedOpenGraphImage) ?>">
  <meta property="og:image:width" content="2172">
  <meta property="og:image:height" content="724">
  <meta property="og:image:alt" content="Tanıdıkla logosu">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="<?= View::escape($title) ?>">
  <meta name="twitter:description" content="<?= View::escape($description) ?>">
  <meta name="twitter:image" content="<?= View::escape($resolvedOpenGraphImage) ?>">
  <meta name="twitter:image:alt" content="Tanıdıkla logosu">
  <?php if (is_string($canonical) && $canonical !== ''): ?>
    <link rel="canonical" href="<?= View::escape($canonical) ?>">
  <?php endif; ?>
  <title><?= View::escape($title) ?></title>
  <link rel="icon" type="image/png" sizes="1254x1254" href="<?= View::escape($brandSymbolPath) ?>">
  <link rel="apple-touch-icon" href="<?= View::escape($brandSymbolPath) ?>">
  <link rel="manifest" href="/site.webmanifest">
  <?php if (is_array($structuredData)): ?>
    <script nonce="<?= View::escape(RequestContext::cspNonce()) ?>" type="application/ld+json"><?= json_encode($structuredData, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT) ?></script>
  <?php endif; ?>
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin="">
  <link rel="stylesheet" href="/assets/app.css?v=<?= View::escape($appCssVersion) ?>">
  <?php if ($bodyClass === 'admin-console-page'): ?><link rel="stylesheet" href="/assets/admin-console.css?v=<?= View::escape($adminCssVersion) ?>"><?php endif; ?>
  <script defer src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
  <script defer src="/assets/app.js?v=<?= View::escape($appJsVersion) ?>"></script>
  <?php if ($bodyClass === 'admin-console-page'): ?><script defer src="/assets/admin-console.js?v=<?= View::escape($adminJsVersion) ?>"></script><?php endif; ?>
</head>
<body class="<?= View::escape($bodyClass) ?>">
  <?php if (!$adminArea): ?><header class="site-header">
    <div class="header-inner">
      <a class="brand" href="/" aria-label="Ana sayfa">
        <img class="brand-logo" src="<?= View::escape($brandHorizontalPath) ?>" width="2172" height="724" alt="<?= View::escape($appName) ?>">
      </a>
      <nav class="main-nav" aria-label="Ana menü">
        <a href="/#kesfet-haritasi">Hizmet bul/al</a>
        <a href="/mesajlar">Mesajlar</a>
        <a href="/islerim">İşlerim</a>
        <a href="/favoriler">Favoriler</a>
      </nav>
      <div class="header-actions">
        <a class="text-button guest-action" href="/giris">Giriş yap</a>
        <a class="text-button signed-action notification-link" href="/bildirimler" hidden>Bildirimler <span data-notification-count hidden>0</span></a>
        <a class="primary-button" href="/ilan-ver">Ücretsiz ilan ver</a>
        <div class="account-menu signed-action" data-account-menu-root hidden>
          <button class="avatar-button" type="button" data-account-menu aria-label="Hesap menüsünü aç" aria-haspopup="menu" aria-expanded="false">H</button>
          <div class="account-menu-popover" data-account-menu-popover role="menu" hidden>
            <div class="account-menu-head"><span class="account-menu-avatar" data-account-menu-avatar>H</span><span><strong data-account-menu-name>Hesabım</strong><small>Profil ve hesap yönetimi</small></span></div>
            <a href="/profil" role="menuitem"><span>◯</span><span><strong>Profilim</strong><small>Herkesin gördüğü profil</small></span></a>
            <a href="/profili-duzenle" role="menuitem"><span>✎</span><span><strong>Profili düzenle</strong><small>Bilgiler ve ilgi alanları</small></span></a>
            <a href="/ilanlarim" role="menuitem"><span>▤</span><span><strong>Aktif ilanlarım</strong><small>Yayındaki ilanlarını yönet</small></span></a>
            <a href="/islerim" role="menuitem"><span>✓</span><span><strong>İşlerim</strong><small>Talep ve tamamlanma süreçleri</small></span></a>
            <a href="/favoriler" role="menuitem"><span>♡</span><span><strong>Favoriler</strong><small>Kaydettiğin ilanlar</small></span></a>
            <a href="/ayarlar" role="menuitem"><span>⚙</span><span><strong>Ayarlar</strong><small>Güvenlik ve bildirimler</small></span></a>
            <button type="button" class="account-menu-logout" data-account-logout role="menuitem"><span>↪</span><span><strong>Çıkış yap</strong><small>Bu cihazdaki oturumu kapat</small></span></button>
          </div>
        </div>
      </div>
    </div>
  </header><?php endif; ?>

  <main><?= $content ?></main>

  <?php if (!$adminArea): ?><section class="app-download">
    <div>
      <span class="eyebrow">Cebinde de yanında</span>
      <h2>Tanıdık hizmetlere uygulamadan daha hızlı ulaş.</h2>
      <p>İlanlarını ve mesajlarını web ile mobil arasında kesintisiz kullan.</p>
    </div>
    <span class="dark-button" aria-label="Mobil uygulama yakında">Mobil uygulama yakında</span>
  </section>

  <footer class="site-footer">
    <div><img class="footer-brand-logo" src="<?= View::escape($brandWordmarkPath) ?>" width="2172" height="724" loading="lazy" alt="<?= View::escape($appName) ?>"><p>Yakındaki ihtiyacı doğru hizmetle buluşturur.</p></div>
    <div><a href="/">Keşfet</a><a href="/ilan-ver">İlan ver</a><a href="/giris">Hesabım</a></div>
    <div><a href="/kullanim-kosullari">Kullanım koşulları</a><a href="/kvkk">KVKK aydınlatma</a><a href="/gizlilik">Gizlilik politikası</a><a href="/cerez-politikasi">Çerez politikası</a><button class="footer-link-button" type="button" data-cookie-settings>Çerez tercihleri</button></div>
  </footer>

  <section class="cookie-consent" data-cookie-consent hidden aria-label="Çerez tercihleri" aria-live="polite">
    <div class="cookie-consent-copy">
      <strong>Çerez tercihlerin</strong>
      <p>Oturum ve güvenlik için zorunlu çerezleri kullanıyoruz. Analitik ve pazarlama çerezleri ancak izin verirsen etkinleşir. <a href="/cerez-politikasi">Çerez politikası</a></p>
    </div>
    <div class="cookie-options" data-cookie-options hidden>
      <label><input type="checkbox" checked disabled><span>Zorunlu <small>Her zaman açık</small></span></label>
      <label><input type="checkbox" data-cookie-analytics><span>Analitik <small>Kullanımı iyileştirmemize yardımcı olur</small></span></label>
      <label><input type="checkbox" data-cookie-marketing><span>Pazarlama <small>Kişiselleştirilmiş iletişim için</small></span></label>
    </div>
    <div class="cookie-actions">
      <button type="button" class="secondary-button" data-cookie-reject>Reddet</button>
      <button type="button" class="secondary-button" data-cookie-manage>Tercihleri yönet</button>
      <button type="button" class="primary-button" data-cookie-accept>Tümünü kabul et</button>
      <button type="button" class="primary-button" data-cookie-save hidden>Tercihleri kaydet</button>
    </div>
  </section>

  <nav class="mobile-nav" aria-label="Mobil menü">
    <a href="/">⌖<span>Keşfet</span></a>
    <a href="/ilan-ver">＋<span>İlan ver</span></a>
    <a href="/mesajlar">◇<span>Mesajlar</span></a>
    <a href="/favoriler">♡<span>Favoriler</span></a>
    <a href="/profil">○<span>Profil</span></a>
  </nav>
  <?php endif; ?>
</body>
</html>
