# Tanıdıkla WEB/API sunucu güncellemesi — 17 Ağustos 2026

Güncel, komut komut yayın rehberi `SUNUCUYA_YUKLEME_2026-08-17.md`
dosyasındadır. Çakışma halinde yeni rehberi esas al.

Bu paket web sitesi, `/api/v1` API'si ve yönetim panelinin birlikte çalışan yeni
sürümüdür. Paket mevcut `.env`, kullanıcı görselleri, loglar, PostgreSQL data
klasörü ve yedekleri içermez.

## Güvenli yükleme sırası

1. Sunucuda mevcut uygulama klasörünün ve PostgreSQL veritabanının yedeğini al.
2. Sunucudaki `.env` ve `storage/uploads` klasörünü kesinlikle silme/değiştirme.
3. ZIP içindeki dosyaları mevcut proje klasörüne çıkar.
4. Proje klasöründe `composer install --no-dev --optimize-autoloader` çalıştır.
5. `php -c php.ini bin/migrate.php` çalıştır. Son sürümde
   `010_account_feedback_security.sql`, `011_admin_hard_delete.sql` ve
   `012_profile_preferences_and_it_categories.sql` ile
   `013_business_profiles_saved_searches_and_filters.sql`,
   `014_optional_listing_scope_and_request_preferences.sql`,
   `015_private_address_apartment.sql`,
   `016_listing_moderation_and_submission_safety.sql` ve
   `017_kvkk_legal_documents.sql` ile çoklu hizmet ve güven sistemi için
   `018_multi_service_listings.sql`,
   `019_service_engagements_and_verified_reviews.sql`,
   `020_reports_risk_and_closed_beta.sql`,
   `021_trust_operations_and_push_devices.sql` ve
   `022_beta_member_activity.sql` uygulanmalıdır;
   migration mevcut ilan veya hesapları kendiliğinden silmez.
6. `APP_ENV=production`, `APP_DEBUG=false` ve
   `APP_URL=https://tanidikla.com` ve
   `APP_HOST_ALIASES=www.tanidikla.com,tanidikla.com.tr,www.tanidikla.com.tr`
   değerlerini kontrol et. İki alan adına da TLS sertifikası kurulmalıdır.
7. E-posta için SMTP, telefon doğrulama için NetGSM ve anlık mesajlar için
   Centrifugo ayarlarını `.env` içinde gerçek değerlerle etkinleştir. Ayarları
   olmayan servisi `false` bırak; sistem sahte başarı üretmez.
8. E-posta, SMS ve realtime worker komutlarını her dakika; storage cleanup
   komutunu günlük çalıştır.
9. `https://tanidikla.com/api/v1/health`, web kayıt/giriş, ilan haritası,
   mesajlaşma ve `/admin/giris` ekranlarını kontrol et.
10. Google Search Console doğrulama değerini `GOOGLE_SITE_VERIFICATION` alanına
    yaz; ardından `https://tanidikla.com/sitemap.xml` adresini Search Console'a
    gönder. Ayrıntılı sıra `docs/GOOGLE_SEO_YAYIN_KONTROL_LISTESI.md` içindedir.
11. Yayına çıkmadan önce yerel `admin@local.test` yönetici e-postasını gerçek
    yönetici e-postasıyla değiştir ve hesaba güçlü, benzersiz bir parola ata.

`bin/seed.php` yalnız kategori ağacı eksikse çalıştırılır. Canlı veritabanına
demo kullanıcı veya demo ilan yüklenmez; release öncesinde yalnız gerçek yönetici
hesabı, kategori ağacı ve yayımlanmış yasal metinler bulunmalıdır.

## Bu sürümde gelen ana değişiklikler

- İlan oluşturma, mesajlar, favoriler, bildirimler, profil ve ayarlar giriş
  gerektirir; kullanıcı girişten sonra geldiği sayfaya geri döner
- Girişten önce başlatılan favori ve kayıtlı filtre işlemleri güvenli biçimde
  saklanır ve başarılı girişten sonra otomatik tamamlanır
- İlan formu tarayıcıda taslak olarak korunur; oturum veya bağlantı kesilse bile
  form verileri geri yüklenebilir
- Yeni ve düzenlenen ilanlar önce `pending` durumuna alınır; yönetici onayından
  sonra harita, arama ve herkese açık ilan detayında yayınlanır
- Yönetim paneline risk işaretleri ve hızlı onay/reddetme işlemleri bulunan
  "Onay bekleyen ilanlar" kuyruğu eklendi
- Kullanıcıya toplam ilan kotası konulmadı; bunun yerine aynı ilanı 24 saat
  içinde kopyalama, çift gönderim/idempotency ve kısa süreli otomatik istek
  saldırıları API seviyesinde engellenir
- Aynı kullanıcının birbirine yakın konumdaki ilanları haritada tek işarette
  gruplanır. Kategori aramasında yalnız eşleşen hizmet, tüm ilan görünümünde ise
  o noktadaki bütün hizmetler gösterilir
- Tarayıcının eski `alert`, `confirm` ve `prompt` pencereleri kaldırılarak site
  tasarımıyla uyumlu modal ve bildirim sistemi kullanıldı
- Postman moderasyon/spam koleksiyonu ile statik ve canlı güvenlik testleri
  pakete eklendi

- Güçlü parola, iki kez parola, parola gösterme, şifre/e-posta değiştirme,
  telefon OTP doğrulaması ve oturum yönetimi
- Mesaj e-posta bildirimi tercihi ve görünür bildirim rozetleri
- Türkiye geneli gerçek konum merkezi, açıklamalı konum izni ve ilan hizmet
  yarıçapı
- Web menüsünden haritaya otomatik kaydırma ve cookie tercih merkezi
- Mesajlarda doğru sağ/sol yönü, seçili konuşma, profil bağlantısı ve özel
  fotoğraf eki
- Profil fotoğrafını önizleme/değiştirme/kaldırma
- Yorumu tekrar açıp düzenleme ve sunucu tarafı uygunsuz içerik doğrulaması
- Admin ilan kaldırma/kullanıcı askıya alma/kategori yönetimi mevcut güvenli
  moderasyon ve denetim kayıtlarıyla korunmuştur
- Eski CSRF çerezi yüzünden ikinci giriş denemesinin kilitlenmesi giderildi;
  giriş güvenliği kaldırılmadan CSRF değeri otomatik yenileniyor
- Arama alanına ilan/kategori önerileri ve Türkçe karakter/yazım hatası toleransı
  eklendi; kategori seçici site tasarımıyla uyumlu özel menüye dönüştürüldü
- Harita altındaki teknik test açıklaması ile ziyaretçi footer'ındaki yönetim
  bağlantısı kaldırıldı; yönetim paneline `/admin/giris` adresiyle erişilir
- Süper yönetici için ilan ve normal kullanıcı hesabını gerçek verileri ve bağlı
  dosyalarıyla kalıcı silme eklendi. İşlem neden, geri alınamaz onay ve denetim
  kaydı gerektirir; askıya alma/yayını durdurma geri alınabilir seçeneklerdir
- Web ve mobil profil akışları sabit 81 il ve 973 ilçe seçimi, isteğe bağlı
  cinsiyet ve profil fotoğrafı ile hizmet alma/verme ilgi alanlarını içerir
- Profil ilgi alanları ana kategori seviyesinde saklanır; aynı şehirde bu ana
  kategorinin altına yeni ilan açıldığında eşleşen kullanıcıya uygulama içi
  bildirim ve realtime olayı oluşturulur
- Profil ekranı herkese açık görünüm olarak ayrıldı; profil düzenleme, aktif
  ilanlar, favoriler ve güvenlik ayarları ayrı profesyonel sayfalara taşındı
- Şahıs ve işletme profili desteği; işletme adı, açık adres ve verilen hizmetler
  alanları eklendi
- Mesaj kutusu "Hizmet al" ve "Hizmet ver" sekmelerine ayrıldı; konuşma
  listesinde profil fotoğrafları gösterilir
- Aramaya çoklu kategori, 5–100 km mesafe, şu an müsait, 7/24 açık,
  doğrulanmış kullanıcı, cinsiyet ve şahıs/işletme filtreleri eklendi
- Kullanıcılar filtre kombinasyonlarını otomatik oluşturulan açıklayıcı özetle
  kaydedebilir; favori ilanlar ve kayıtlı filtreler ayrı sekmelerden yönetilir
- Web ilan formunda isteğe bağlı/sınırsız hizmet mesafesi, profesyonel görsel
  yükleme, yakın konum ve gizli tam adres akışları ayrıldı; tam adreste il, ilçe,
  mahalle, sokak, bina ve daire bilgileri ile harita eşleşmesi doğrulanır
- İlan sahibi ilan detayından doğrudan düzenleme ekranına geçebilir; tarayıcı
  uyarıları sağ-alt site bildirimlerine taşındı
- Yönetim panelindeki ilan, şikâyet ve kullanıcı filtreleri; özel açılır menü
  oku, odak durumu, tutarlı boşluklar ve profesyonel aksiyon düğmeleriyle yenilendi
- Bilgisayar ve BT ana kategorisi; format/işletim sistemi, modem-ağ ve yazılım
  desteği gibi alt kategorilerle eklendi
- Kullanıcı adı, biyografi/açıklama ve serbest metin alanlarında Türkçe Unicode
  karakterleri kabul edilir
- Gerçek ilanlara dayalı kategori ve şehir açılış sayfaları, canonical URL,
  robots meta, Open Graph, Organization/Service/Breadcrumb/ItemList verileri ve
  dinamik sitemap eklendi; yönetim ekranları arama motorlarına kapatıldı
- Web sitesi ve yönetim panelindeki görünen marka Tanıdıkla olarak güncellendi

## Harici servis gerektirenler

- Gerçek e-posta doğrulama ve şifre sıfırlama: SMTP
- Gerçek telefon OTP: NetGSM
- Arka planda işletim sistemi push bildirimi: FCM/APNs kurulumu
- Otomatik profil fotoğrafı moderasyonu: harici moderasyon sağlayıcısı
- Yoğun üretim haritası: kullanım şartlarına uygun ticari veya self-hosted tile
  sağlayıcısı

Bu servislerin anahtarları kaynak koda veya ZIP'e konulmamalıdır; yalnızca
sunucudaki `.env`/secret yöneticisinde tutulmalıdır.
