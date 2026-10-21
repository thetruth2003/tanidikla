# Tanıdıkla son web/API sürümünü sunucuya yükleme

Bu rehber Linux sunucuda çalışan mevcut Tanıdıkla kurulumu içindir. ZIP dosyası
`.env`, `vendor`, kullanıcı görselleri, loglar, PostgreSQL data klasörü ve yedek
dump içermez. Mobil uygulama bu yayının parçası değildir.

## 1. Önce staging oluştur

Production veritabanında deneme yapma. Sunucuyu yöneten kişi production'ın son
yedeğinden `tanidikla_staging` adında ayrı bir PostgreSQL veritabanı oluştursun,
uygulamayı ayrı bir klasöre çıkarsın ve staging `.env` dosyasında yalnız DB adı ile
staging URL'sini değiştirsin. Staging dışarı açıksa parola/IP kısıtı kullanılmalıdır.

Staging proje klasöründe:

```bash
composer install --no-dev --optimize-autoloader
php -c php.ini bin/migrate.php
```

Migration tablosunda 018–022'nin uygulandığını kontrol et. Komut hata verirse
production'a geçme; hata çıktısını ve PostgreSQL logunu kaydet.

## 2. Staging E2E kabul testi

İki ayrı beta hesabı kullan: biri hizmet veren, biri hizmet alan. Şu sırayı tamamla:

1. Hizmet veren tek ilanda iki alt hizmet oluştursun.
2. Admin ilanı onaylasın.
3. İkinci alt hizmetin adıyla arama yap ve aynı ana ilanın bulunduğunu doğrula.
4. Hizmet alan, seçilen alt hizmet için talep oluştursun.
5. Hizmet veren kabul etsin, başlatsın ve tamamlandı işaretlesin.
6. Hizmet alan tamamlanmayı onaylasın.
7. İki taraf değerlendirme bıraksın; aynı tarafın ikinci değerlendirmesi reddedilsin.
8. Üçüncü/yetkisiz hesap iş durumunu değiştiremesin.
9. Kullanıcı engellenince yeni mesaj ve talep gönderilemesin.
10. Şikâyet admin güven kuyruğunda görünsün.
11. İlan düzenlenince geçmiş işteki hizmet/fiyat snapshot'ı değişmesin.

Sunucu ortamında ayrıca çalıştır:

```bash
php tests/listing-moderation-static-smoke.php
php tests/seo-static-smoke.php
php tests/trust-marketplace-static-smoke.php
php tests/admin-console-smoke.php
php tests/realtime-token-smoke.php
```

## 3. Production yedeği

Sunucuda mevcut uygulama klasörünü doğruladıktan sonra bakım penceresinde:

```bash
mkdir -p "$HOME/tanidikla-backup-$(date +%Y%m%d-%H%M)"
pg_dump -W -h DB_HOST -U DB_USER -d DB_NAME --format=custom \
  --file="$HOME/tanidikla-backup-$(date +%Y%m%d-%H%M)/database.dump"
tar -czf "$HOME/tanidikla-backup-$(date +%Y%m%d-%H%M)/uploads.tar.gz" storage/uploads
cp .env "$HOME/tanidikla-backup-$(date +%Y%m%d-%H%M)/env.backup"
```

`DB_HOST`, `DB_USER` ve `DB_NAME` yerine sunucudaki `.env` değerlerini yaz. Parolayı
komuta ekleme; `-W` ile sorulduğunda gir. Dump'ın boş olmadığını ve arşivin
açılabildiğini doğrulamadan yüklemeye başlama.

## 4. ZIP'i yükle

1. FileZilla ile ZIP'i sunucudaki proje klasörünün yanına yükle.
2. Sunucudaki `.env` ve `storage/uploads` klasörünü silme.
3. ZIP'i mevcut proje klasörüne çıkar. Pakette `.env` bulunmadığı için secretlar
   değişmez; runtime klasörleri de pakette yoktur.
4. Proje klasöründe çalıştır:

```bash
composer install --no-dev --optimize-autoloader
php -c php.ini bin/migrate.php
```

Sonra PHP-FPM/opcache yeniden yüklenmelidir. Sunucudaki servis adına göre örnek:

```bash
sudo systemctl reload php8.4-fpm
```

## 5. Production `.env` kontrolü

Şunlar kesin olmalı:

```dotenv
APP_ENV=production
APP_DEBUG=false
APP_URL=https://tanidikla.com
APP_HOST_ALIASES=www.tanidikla.com,tanidikla.com.tr,www.tanidikla.com.tr
BETA_MODE=true
```

Gerçek değerler yalnız sunucudaki `.env`/secret yöneticisinde tutulmalıdır:

- SMTP: `MAIL_ENABLED`, `MAIL_HOST`, `MAIL_PORT`, `MAIL_USERNAME`,
  `MAIL_PASSWORD`, `MAIL_ENCRYPTION`, `MAIL_FROM_ADDRESS`
- NetGSM: `SMS_ENABLED`, `NETGSM_USERNAME`, `NETGSM_PASSWORD`, `NETGSM_HEADER`
- Centrifugo: `CENTRIFUGO_ENABLED`, `CENTRIFUGO_API_URL`,
  `CENTRIFUGO_API_KEY`, `CENTRIFUGO_CLIENT_URL`, `CENTRIFUGO_TOKEN_SECRET`
- FCM: `PUSH_ENABLED`, `FCM_PROJECT_ID`, `FCM_SERVICE_ACCOUNT_JSON`
- APNs: `APNS_TEAM_ID`, `APNS_KEY_ID`, `APNS_BUNDLE_ID`,
  `APNS_PRIVATE_KEY`, `APNS_USE_SANDBOX`

Secret eksikse ilgili `*_ENABLED` değeri `false` kalmalı. Servis gerçek bir
başarı dönmeden kullanıcıya gönderildi mesajı gösterilmez.

## 6. Worker ve cron

Sunucu cron'una dakikalık olarak ekle:

```cron
* * * * * cd /SUNUCUDAKI/PROJE/YOLU && php -c php.ini cron/send-emails.php
* * * * * cd /SUNUCUDAKI/PROJE/YOLU && php -c php.ini cron/send-sms.php
* * * * * cd /SUNUCUDAKI/PROJE/YOLU && php -c php.ini cron/publish-realtime.php
* * * * * cd /SUNUCUDAKI/PROJE/YOLU && php -c php.ini cron/send-push.php
```

`/SUNUCUDAKI/PROJE/YOLU` gerçek proje yolu olmalıdır.

## 7. DNS ve 308 yönlendirme

- `www.tanidikla.com` → `tanidikla.com` CNAME
- `.com.tr` ana kayıt → aynı origin sunucu/proxy
- `www.tanidikla.com.tr` → `tanidikla.com.tr` CNAME
- Dört host da aynı uygulamanın `public/` document root'una ulaşmalı.
- Dört host için TLS geçerli olduktan sonra HSTS açık tutulmalı.

Uygulama `APP_HOST_ALIASES` içindeki hostları kod seviyesinde `308` ile
`https://tanidikla.com` adresine yönlendirir. DNS veya reverse proxy isteği PHP'ye
ulaştırmazsa bu yönlendirme çalışmaz.

Kontrol:

```bash
curl -I https://www.tanidikla.com/
curl -I https://tanidikla.com.tr/
curl -I https://www.tanidikla.com.tr/
```

Üçünün de `308` ve `Location: https://tanidikla.com/...` döndürmesi gerekir.

## 8. Harita sağlayıcısı

Production için MapTiler Cloud Flex önerildi. MapTiler hesabında yalnız
`tanidikla.com` ve mobil uygulama kimliklerine izinli bir anahtar oluştur. Sunucu
`.env` örneği:

```dotenv
MAP_TILE_URL=https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=GERCEK_ANAHTAR
MAP_TILE_ATTRIBUTION=&copy; MapTiler &copy; OpenStreetMap katkıcıları
MAP_TILE_MAX_ZOOM=19
```

Tarayıcı tile anahtarını görebileceği için anahtarı mutlaka domain ve kota ile
kısıtla. Test/lokal ortamda mevcut OSM URL'si kalabilir.

## 9. Firebase ve Apple mobil kurulumu

Bu dosyalar web ZIP'ine konmaz. Mobil uygulama yayınlanmadan önce:

- Firebase'de Android uygulaması aç, gerçek package name ile
  `google-services.json` indir ve Android app klasörüne ekle.
- Firebase servis hesabı JSON'unu yalnız backend secret alanına koy.
- Apple Developer'da App ID, APNs key ve provisioning oluştur.
- `GoogleService-Info.plist` dosyasını Xcode Runner target'ına ekle.
- APNs `.p8` anahtarını yalnız backend secret alanında sakla.

## 10. Beta daveti ve son kontrol

Admin panelinde **İşler ve güven → Beta kullanıcıları** bölümünden davet kodu
oluştur. Kod yalnız oluşturulduğu anda gösterildiği için parola yöneticisine kaydet.
İki ayrı e-posta/telefonla kayıt olup yukarıdaki E2E akışını tamamla.

Son salt-okunur kontroller:

```bash
curl -f https://tanidikla.com/api/v1/health
curl -f https://tanidikla.com/robots.txt
curl -f https://tanidikla.com/sitemap.xml
curl -f https://tanidikla.com/admin/giris
```

Health cevabında `database=ready` ve SMTP/SMS/realtime/push servislerinin gerçek
`configured/unconfigured` durumu görünmelidir.
