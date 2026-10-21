# Tanıdıkla güven ve pazar yeri sürümü — 17 Ağustos 2026

Bu belge 018–022 migration zinciriyle gelen çoklu hizmet, doğrulanmış iş,
değerlendirme, güven operasyonları, push ve kapalı beta değişikliklerinin güvenli
yayın notudur. Canlı veri veya secret içermez.

## Yayın kapsamı

- Bir ana ilanda 1–20 bağımsız hizmet kalemi ve yedi fiyatlandırma türü
- İş talebi, rol kontrollü durum geçişleri, snapshot ve audit geçmişi
- Yalnız tamamlanan işlere bağlı kör değerlendirme akışı
- İlan/alt hizmet/mesaj/kullanıcı/iş/değerlendirme şikâyetleri ve risk sinyalleri
- Web iş takibi, profil geçmişi, hizmet seçimi ve beta geri bildirimi
- Flutter çoklu hizmet oluşturma/düzenleme, iş takibi, değerlendirme ve güven işlemleri
- Admin iş/anlaşmazlık/değerlendirme/risk/beta kuyrukları
- Şifreli cihaz tokenları, FCM/APNs gönderici ve yeniden denemeli push kuyruğu

## Güvenli production sırası

1. Aktif release yolunu, `public/` document root'unu ve çalışan `.env` dosyasını kaydet.
2. PostgreSQL'i custom formatta, `storage/uploads` klasörünü ve `.env` dosyasını
   ayrı ve erişimi sınırlı bir konuma yedekle.
3. Yeni kaynakları yükle; mevcut `.env`, upload, log ve yedek klasörlerinin üzerine yazma.
4. `composer install --no-dev --optimize-autoloader` çalıştır.
5. `php -c php.ini bin/migrate.php` ile 018, 019, 020, 021 ve 022'yi sırayla uygula.
6. E-posta, SMS, realtime ve push worker'larını yalnız ilgili secretlar girildikten
   sonra etkinleştir.
7. `GET /api/v1/health`, `/`, `/sitemap.xml`, `/robots.txt` ve `/admin/giris`
   salt-okunur kontrollerini yap.
8. Ayrı beta hesaplarıyla ilan paketi, iş talebi, kabul/tamamlama, çift değerlendirme
   engeli, block/report ve admin moderasyon akışını doğrula.

Örnek yedek komutları:

```bash
pg_dump --format=custom --file="backup-before-018-$(date +%Y%m%d-%H%M).dump" "$DATABASE_URL"
tar -czf "uploads-before-018-$(date +%Y%m%d-%H%M).tar.gz" storage/uploads
cp .env ".env.before-018-$(date +%Y%m%d-%H%M)"
```

## Gerekli fakat kaynak koda konmayacak secretlar

- SMTP sunucu/kullanıcı/parola ve gönderen adresi
- NetGSM kullanıcı/parola/onaylı başlık
- Centrifugo API anahtarı ve token secretı
- FCM proje kimliği ve servis hesabı JSON'u
- APNs team ID, key ID, bundle ID ve `.p8` anahtarı
- Güçlü `APP_KEY`, veritabanı parolası ve varsa obje depolama anahtarları

## Rollback

Migration'lar veri kaybını önlemek için additive tasarlanmıştır. İlk geri dönüş
adımı trafiği önceki release'e çevirmektir; 018–022 tabloları veya kolonları otomatik
silinmez. Önceki kod yeni kolonları yok sayabiliyorsa şema yerinde bırakılır. Şema
geri dönüşü zorunluysa bakım penceresinde yeni bir dump alınır, yeni tablolardaki
veri dışa aktarılır ve yalnız DBA onayıyla kaldırılır. Tam geri dönüşte pre-release
dump ayrı veritabanına restore edilir, upload arşivi doğrulanır ve trafik eski
release'e çevrilir.

## Bilinen yayın kapıları

- `tanidikla.com.tr` ve `www.tanidikla.com.tr` için DNS/TLS henüz yok.
- `www.tanidikla.com` ana domaine 308 yerine sayfayı doğrudan 200 döndürüyor.
- Canlı sağlık cevabı yeni entegrasyon durum alanlarını içermediğinden bu sürüm
  henüz canlıya alınmış değil.
- Yerel PostgreSQL servisi bulunmadığından DB bağlantılı testler bu makinede
  çalıştırılamadı; staging/production öncesi zorunludur.
- Mobil FCM/APNs cihaz kaydı için Firebase/Apple uygulama yapılandırma dosyaları ve
  hesap secretları gereklidir.
- Yoğun production kullanımı için OpenStreetMap public tile yerine kullanım
  politikasına uygun ticari veya self-hosted tile sağlayıcısı seçilmelidir.
