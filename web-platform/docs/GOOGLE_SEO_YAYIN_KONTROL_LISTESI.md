# Tanıdıkla Google SEO yayın kontrol listesi

Bu proje, `https://tanidikla.com` adresini tek ana (canonical) alan adı kabul eder. `www` ve `.com.tr` adresleri aynı içeriği çoğaltmak yerine kalıcı olarak ana alana yönlendirilmelidir.

## Sunucu ayarları

`.env` dosyasında aşağıdaki değerler bulunmalıdır:

```env
APP_ENV=production
APP_NAME="Tanıdıkla"
APP_URL=https://tanidikla.com
APP_HOST_ALIASES=www.tanidikla.com,tanidikla.com.tr,www.tanidikla.com.tr
GOOGLE_SITE_VERIFICATION=search-console-tarafindan-verilen-deger
```

- Dört alan adı için DNS kaydı, HTTPS sertifikası ve web sunucusu host kaydı hazırlanır.
- Alias alan adları `308` ile `https://tanidikla.com` alanına yönlendirilir.
- `https://tanidikla.com/robots.txt` ve `https://tanidikla.com/sitemap.xml` açılarak kontrol edilir.
- Yönetim, giriş ve sorgu parametreli filtre ekranları arama sonuçlarına alınmaz.

## Google Search Console

1. Search Console'da `tanidikla.com` için alan adı mülkü oluşturulur ve DNS TXT kaydıyla doğrulanır.
2. Ayarlar tamamlandıktan sonra `https://tanidikla.com/sitemap.xml` gönderilir.
3. Ana sayfa ile en güçlü gerçek kategori sayfaları URL Denetimi aracından kontrol edilir ve dizine eklenmesi istenir.
4. Sayfa dizine ekleme, Core Web Vitals ve Performans raporları düzenli izlenir.
5. `.com.tr` alanı aynı sitenin kopyası olarak yayınlanmaz; ana alan adına yönlenir.

## İçerik ve sıralama yaklaşımı

- `/hizmet/elektrikci`, `/hizmet/kurye-ve-tasima` gibi kategori sayfaları gerçek ilanları gösterir.
- `/hizmet/elektrikci/ankara` gibi şehir sayfaları yalnız o şehirde aktif ilan varsa sitemap'e girer.
- Kategori başlıkları, açıklamaları ve görünür içerik kullanıcıya bilgi vermelidir; görünmeyen anahtar kelime doldurma yapılmaz.
- Gerçek müşteri değerlendirmeleri, doğrulanmış profiller, özgün hizmet açıklamaları ve güncel ilanlar sıralama için teknik etiketlerden daha değerlidir.
- Aynı metni yüzlerce boş şehir sayfasına kopyalamak yerine yalnız faydalı ve gerçek sonuç bulunan sayfalar yayınlanır.

## İşletme görünürlüğü

Tanıdıkla'nın müşterilerin ziyaret edebildiği veya gerçek hizmet verdiği doğrulanabilir bir işletme konumu varsa Google İşletme Profili açılabilir. Sanal veya sahte adres kullanılmamalıdır. Profilde ad, web adresi, telefon ve çalışma bilgileri sitedeki bilgilerle tutarlı olmalıdır.

## Beklenti

Bu altyapı Google'ın siteyi doğru taramasına ve anlamasına yardım eder; belirli bir kelimede birinci sıra garantisi vermez. Sıralama rekabet, sitenin yaşı, kullanıcı deneyimi, içerik kalitesi, güven sinyalleri ve gerçek kullanım verileriyle zaman içinde oluşur.
