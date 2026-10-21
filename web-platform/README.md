# Tanıdıkla web platformu

Bu klasör mobil uygulamayla aynı veritabanını kullanacak üç parçayı içerir:

- düz PHP web sitesi,
- `/api/v1` altında sürümlendirilmiş JSON REST API,
- `/admin` altında korumalı yönetim paneli.

Laravel, Symfony veya başka bir PHP framework'ü kullanılmaz. Composer yalnızca
mevcut PHPMailer kurulumu için bulunur. Veritabanı PostgreSQL'dir. Production
kurulumunda PostGIS ve GiST konum indeksi kullanılır; PostGIS yüklenemeyen lokal
Windows ortamında geliştirmeyi durdurmayan indeksli koordinat/Haversine yedeği vardır.

## Tamamlanan platform özellikleri

- Argon2id parola, e-posta doğrulama/sıfırlama kuyruğu, kısa mobil access token ve dönen refresh token ailesi
- Web cookie + CSRF, mobil opaque bearer token, rate limit, CSP nonce ve güvenlik başlıkları
- Sunucu tarafı arama/filtre/sıralama/pagination, yaklaşık konum gizliliği ve PostGIS hazır şema
- İlan paketi, güvenli WebP görsel yükleme, lokal/S3 storage adapter ve sahipsiz dosya temizliği
- Favori, değerlendirme, bildirim, şikâyet, kullanıcı engelleme ve iki kişilik ilan konuşmaları
- Varsayılan kapalı telefon görünürlüğü, oturumlu/rate-limitli reveal ve privacy-safe ürün olayı
- DB-first mesaj outbox, web/mobil Centrifugo WebSocket bağlantısı ve üç saniyelik polling yedeği
- E-posta ve NetGSM SMS kuyruk worker'ları
- Normal kullanıcı oturumundan ayrı admin oturumu, granular RBAC, moderasyon ve audit log
- Sürümlü KVKK/yasal metin, açık rıza izi, veri dışa aktarma ve onaylı hesap anonimleştirme
- Canonical, Open Graph, sitemap, robots ve ilan yapılandırılmış verisi
- Şahıs/işletme profilleri, sabit 81 il ve 973 ilçe, hizmet alma/verme ilgi alanları
- Çoklu kategori, mesafe, müsaitlik, 7/24, doğrulama, cinsiyet ve profil türü filtreleri
- Adlandırılabilen kayıtlı aramalar ile ayrı profil düzenleme, ayarlar ve aktif ilan sayfaları

## Lokal adresler

- Web: `http://127.0.0.1:8080`
- API sağlık kontrolü: `http://127.0.0.1:8080/api/v1/health`
- Admin: `http://127.0.0.1:8080/admin`
- Admin girişi: `http://127.0.0.1:8080/admin/giris`
- Android emülatör API adresi: `http://10.0.2.2:8080/api/v1`
- Canlı site: `https://tanidikla.com`
- İkinci alan adı: `https://tanidikla.com.tr` (ana alana yönlendirilir)
- Canlı API adresi: `https://tanidikla.com/api/v1`

Lokal PHP API ve web sitesi aynı süreçte çalışır. Flutter uygulaması varsayılan
olarak `https://tanidikla.com/api/v1` adresini kullanır. Lokal API ile çalıştırmak
için `API_BASE_URL` dart-define değeri açıkça verilmelidir.

## Harita

Web haritası Leaflet 1.9.4 ile çalışır ve lokal geliştirmede OpenStreetMap
döşemelerini kullanır. Ana sayfada liste/harita geçişi, ilan işaretçileri ve
yakınımda arama; ilan detayında ise gizlilik seviyesine göre kesin veya yaklaşık
konum bulunur. Üretime çıkmadan önce yoğun trafiğe uygun bir harita döşeme
sağlayıcısı seçilmelidir.

## Hazırlık

Bu bilgisayardaki ilk lokal kurulum tamamlandı. Sonraki açılışlarda PowerShell'de
yalnızca `./dev.ps1` komutu yeterlidir. Başka bir bilgisayardaki elle kurulumda:

1. `.env.example` dosyasını `.env` olarak kopyala. Lokal kullanımda yalnız bu
   kopyada `APP_ENV=local`, `APP_DEBUG=true` ve `APP_URL=http://127.0.0.1:8080`
   değerlerini kullan; `.env.example` production için güvenli varsayımlarda kalır.
2. PostgreSQL'de `ankara_services` veritabanını ve `ankara_app` kullanıcısını oluştur.
3. `php -c php.ini bin/migrate.php` ile şemayı kur.
4. `php -c php.ini bin/seed.php` ile kategorileri ekle.
5. `./dev.ps1` ile lokal web sunucusunu başlat.

## Doğrulama

Web sunucusu çalışırken:

```powershell
node --check public/assets/app.js
./tests/live-smoke.ps1
php -c php.ini tests/realtime-token-smoke.php
```

Mobil uygulamada:

```powershell
dart format lib test
flutter analyze
flutter test
```

Canlı smoke testi geçici üç hesap oluşturur; Türkçe profil verisi, işletme profili,
ilgi alanları, gelişmiş filtreler, kayıtlı arama, ilan, mesaj, bildirim, ayrı admin
oturumu ve anonimleştirme akışını doğruladıktan sonra bütün geçici kayıtları siler.

## Worker'lar

Production zamanlayıcısında her dakika çalıştırılacak komutlar:

```powershell
php -c php.ini cron/send-emails.php
php -c php.ini cron/send-sms.php
php -c php.ini cron/publish-realtime.php
php -c php.ini cron/send-push.php
```

`cron/cleanup-storage.php` günlük çalıştırılmalıdır. Worker'lar `flock`,
`FOR UPDATE SKIP LOCKED`, artan geri bekleme ve tekrar deneme kullanır.

Sunucu, domain, SMTP, veritabanı ve depolama bilgileri kodda sabit değildir.
Gerçek sunucu bilgileri geldiğinde yalnızca ortam yapılandırması değişir.
Production kontrol listesi için `docs/DEPLOYMENT.md`, güvenlik/KVKK ayrıntıları
için `docs/SECURITY_AND_PRIVACY.md` okunmalıdır.
