# İlan moderasyonu ve güvenli yayın akışı

Bu sürümde kullanıcıya toplam ilan kotası konulmaz. Kullanıcı farklı hizmetleri için istediği kadar ayrı ilan açabilir. Koruma; kısa süreli otomatik istek yağmuru, çift gönderim ve aynı içeriğin 24 saat içinde tekrar gönderilmesi üzerinde çalışır.

## Yeni akış

- Yeni ve düzenlenen ilan `pending` durumunda oluşturulur.
- İlan sahibi pending ilanını **İlanlarım** sayfasında görür; ilan herkese açık arama ve haritada görünmez.
- Yönetici panelindeki **Onay bekleyen ilanlar** kuyruğundan ilan onaylanabilir veya gerekçeyle reddedilebilir.
- Onaylanan ilan yayınlanır ve kategori eşleşme bildirimleri yalnız bu anda üretilir.
- Aynı istek anahtarının tekrar gönderilmesi ikinci ilan üretmez.
- Aynı kullanıcının aynı içerik ve yaklaşık aynı konumdaki kopya ilanı 24 saat boyunca engellenir.
- Haritada aynı kullanıcıya ait, aynı türde ve birbirine 150 metreden yakın ilanlar yalnız filtresiz görünümde tek sağlayıcı işaretinde gruplanır. Arama veya kategori filtresinde sadece eşleşen hizmet görünür.
- Favori, mesaj ve kayıtlı arama gibi oturum gerektiren eylemler girişten sonra kaldığı yerden tamamlanır.
- İlan formu tarayıcıda taslak olarak saklanır ve oturum sonrasında kurtarılır.

## Sunucu kurulumu

1. Veritabanı ve mevcut sunucu dosyalarının yedeğini alın.
2. Güncel paketi sunucuya yüklerken mevcut `.env` dosyasını ve `storage/` içindeki kullanıcı yüklemelerini koruyun.
3. Proje kökünde migration çalıştırın:

   ```bash
   php -c php.ini bin/migrate.php
   ```

4. Yönetici panelinde **İlan moderasyonu → Onay bekleyen ilanlar** kuyruğunu kontrol edin.

## Testler

Statik regresyon testi:

```bash
php tests/listing-moderation-static-smoke.php
```

Canlı akış testi yalnız ayrı test hesabı ve test ortamında çalıştırılmalıdır:

```powershell
powershell -ExecutionPolicy Bypass -File tests/listing-moderation-spam-live.ps1 `
  -BaseUrl http://127.0.0.1:8080 -Email test@example.test -Password 'TestPassword!2026'
```

Kısa süreli spam sınırını da sınamak için `-RunBurst` eklenir. Bu seçenek test hesabında çok sayıda pending ilan oluşturduğu için üretim hesabında çalıştırılmamalıdır.

Postman koleksiyonu: `tests/postman/Aninda-Moderasyon-Spam.postman_collection.json`.

