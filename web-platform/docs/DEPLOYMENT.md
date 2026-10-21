# Production deployment

## Gereksinimler

- PHP 8.4, `curl`, `fileinfo`, `gd`, `mbstring`, `openssl`, `pdo_pgsql`, `pgsql`
- PostgreSQL ve PostGIS; uygulama kullanıcısına yalnız gerekli şema yetkileri
- HTTPS reverse proxy, gerçek domain, SMTP hesabı
- Tercihen S3 uyumlu obje depolama
- Realtime isteniyorsa Centrifugo 6.x ve TLS ile korunan internal HTTP API
- SMS isteniyorsa NetGSM API alt kullanıcısı, SMS yetkisi ve onaylı gönderici adı
- Android push için Firebase proje kimliği ve servis hesabı; iOS push için APNs takım, anahtar, bundle kimliği ve `.p8` özel anahtarı

## Kurulum sırası

1. Mevcut deployment'ta önce PostgreSQL ve yüklenen dosyaların yedeğini al.
2. Veritabanı ve uygulama rolünü oluştur; `postgis`, `pg_trgm`, `unaccent`, `pgcrypto` extension'larını etkinleştir.
3. `.env.example` dosyasını secret yöneticisindeki production değerleriyle doldur. Mevcut `.env` dosyasını ZIP içeriğiyle değiştirme; `.env` web root dışında ve okunamaz izinlerde kalmalıdır.
4. Yeni dosyaları yüklerken sunucudaki `storage/uploads`, `storage/logs` ve yedekleri koru. Release ZIP'i bu çalışma zamanı verilerini içermez.
5. `composer install --no-dev --optimize-autoloader` çalıştır.
6. `php -c php.ini bin/migrate.php` çalıştır. `bin/seed.php` yalnız kategori ağacı eksikse kullanılır; canlı ortama demo ilan veya demo kullanıcı taşınmaz.
7. `public/` klasörünü tek web root olarak yayınla; `src`, `database`, `storage` ve `.env` doğrudan servis edilmemelidir.
8. `APP_ENV=production`, `APP_DEBUG=false`, `APP_URL=https://tanidikla.com`, `APP_HOST_ALIASES=www.tanidikla.com,tanidikla.com.tr,www.tanidikla.com.tr` ve güvenli rastgele `APP_KEY` değerlerini doğrula. Her iki alan adında da geçerli TLS sertifikası bulunmalıdır.
9. SMTP, S3, Centrifugo ve NetGSM'i ayrı ayrı health/sandbox hesabıyla doğrula. Sağlayıcısı kurulmamış e-posta/SMS/push özelliğini etkinleştirme.
10. `send-emails.php`, `send-sms.php`, `publish-realtime.php` ve `send-push.php` worker komutlarını dakikalık; storage temizliğini günlük zamanla.
11. `/api/v1/health`, kayıt/giriş, ilan haritası, mesaj ve admin girişini production verisini değiştirmeyen hesaplarla kontrol et.
12. Yerel `admin@local.test` hesabını yayından önce gerçek yönetici e-postasına taşı ve güçlü, benzersiz bir parola belirle.

## Centrifugo

`CENTRIFUGO_API_URL` internal `/api` adresidir. `CENTRIFUGO_API_KEY` yalnız backend
worker tarafından okunur. API portu internete açılmamalıdır. `CENTRIFUGO_CLIENT_URL`
istemcilerin ulaşacağı TLS WebSocket adresidir (production'da `wss://.../connection/websocket`).
`CENTRIFUGO_TOKEN_SECRET`, Centrifugo `client.token.hmac_secret_key` ile aynı, güçlü ve
gizli değerdir; tarayıcıya yalnız kısa ömürlü imzalı bağlantı tokenı gönderilir. Token,
kullanıcıyı sadece kendi `user:{id}` ve üyesi olduğu `conversation:{id}` kanallarına
sunucu taraflı abone eder. Uygulama önce mesajı PostgreSQL'e ve `realtime_outbox`
tablosuna yazar; yayın başarısız olsa bile veri kaybolmaz, web ve mobil istemciler üç
saniyelik artımlı polling ile devam eder.

## Yedekleme ve geri dönüş

- Her deployment öncesi `pg_dump --format=custom` ve obje depolama envanteri alın.
- Migration'lar additive tasarlanmıştır. Kod geri alınacaksa önce eski kodun yeni
  kolonları tolere ettiği doğrulanır; veri kaybettiren otomatik down migration kullanılmaz.
- Günlük tam, saatlik artımlı/WAL yedeği; farklı hesap/bölgede saklama ve aylık geri yükleme tatbikatı önerilir.
- `storage/backups` lokal geliştirme yedeğidir, production yedek sistemi değildir.

Önerilen release öncesi komut sırası (parolayı komut satırına yazmadan):

```bash
pg_dump --format=custom --file="backup-before-018-$(date +%Y%m%d-%H%M).dump" "$DATABASE_URL"
tar -czf "uploads-before-018-$(date +%Y%m%d-%H%M).tar.gz" storage/uploads
cp .env ".env.before-018-$(date +%Y%m%d-%H%M)"
php -c php.ini bin/migrate.php
```

018–022 migration'ları additive olduğundan normal rollback yöntemi önce önceki kod paketine dönmek, ardından bu kodun yeni kolonları yok saydığını doğrulamaktır. Veriyi korumak için tablolar otomatik silinmez. Şema geri dönüşü gerçekten gerekirse bakım penceresinde önce yeni bir dump alınır; yalnız 018–022 ile eklenen tablo/kolonlar veri dışa aktarıldıktan sonra DBA onayıyla kaldırılır. En güvenli tam geri dönüş, doğrulanmış pre-release dump ve upload arşivini ayrı bir veritabanına geri yükleyip trafik yönlendirmesini eski release'e çevirmektir.

## İzleme

JSON loglar request ID, kullanıcı ID, HTTP durum ve süre taşır. Reverse proxy aynı
`X-Request-ID` değerini loglamalıdır. Alarm eşikleri: artan 5xx, auth rate-limit,
kuyrukta yaşlanan işler, storage hataları, DB bağlantı doygunluğu ve outbox retry.

OpenStreetMap public tile servisi production yoğun trafik için varsayılan sağlayıcı
olarak kullanılmamalı; kullanım politikasına uygun ticari veya self-hosted tile
sağlayıcı seçilmelidir.
