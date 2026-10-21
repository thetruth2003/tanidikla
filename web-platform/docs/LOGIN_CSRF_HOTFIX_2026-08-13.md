# Web giriş CSRF hotfix — 13 Ağustos 2026

## Sorun

Tarayıcıda eski bir web oturumundan kalan `ankara_csrf` çerezi bulunduğunda,
giriş formu yeni `ankara_pre_auth_csrf` değeri yerine eski değeri
gönderebiliyordu. Bu nedenle kullanıcı ilk denemeden sonra şifresini düzeltse
bile `419 csrf_failed` hatası görebiliyordu.

## Düzeltme

- Giriş, kayıt ve şifre kurtarma işlemleri daima pre-auth CSRF değerini
  önceliklendirir.
- Pre-auth değeri eskimişse `/api/v1/auth/csrf` üzerinden otomatik yenilenir ve
  işlem sayfa yenilenmeden yalnız bir kez tekrar edilir.
- Güvenlik kaldırılmamıştır; double-submit CSRF kontrolü ve giriş rate limit'i
  korunmuştur.
- API hataları istemcide HTTP durum ve hata koduyla taşınır.

## Sunucuya gidecek dosyalar

- `public/assets/app.js`
- `public/index.php`
- `src/Security/AuthService.php`

Dosyalar yüklendikten sonra PHP-FPM/opcache kullanılıyorsa servis yeniden
yüklenmeli veya opcache temizlenmelidir. Bu hotfix veritabanı değişikliği
içermez; ancak ana sürümün `010_account_feedback_security.sql` migration'ı
sunucuda ayrıca uygulanmış olmalıdır.
