# KVKK yayın kontrol listesi

Bu dosya hukuki danışmanlık yerine geçmez. Canlı yayından önce Türkiye'de kişisel verilerin korunması alanında çalışan bir hukukçu metinleri ve gerçek veri akışını kontrol etmelidir.

## Zorunlu sunucu ayarları

Canlı `.env` dosyasına aşağıdaki gerçek bilgiler girilmelidir:

- `LEGAL_CONTROLLER_NAME`: Veri sorumlusu gerçek kişi veya şirketin tam unvanı.
- `LEGAL_CONTROLLER_ADDRESS`: Veri sorumlusuna yapılacak yazılı başvuruların tebligat adresi.
- `LEGAL_CONTROLLER_EMAIL`: Daha önce sisteme bildirilmiş e-posta ile yapılacak KVKK başvurularının alınacağı adres.
- `LEGAL_CONTROLLER_KEP`: Varsa KEP adresi.
- `LEGAL_CONTROLLER_PHONE`: Varsa iletişim telefonu.
- `LEGAL_EFFECTIVE_DATE`: Metinlerin yürürlük tarihi.

Eksik zorunlu alan varsa web ve mobil metinlerinde yayın yapılandırması uyarısı görünür.

## Yayın adımları

1. Güncel API/web dosyalarını sunucuya yükle.
2. `php -c php.ini bin/migrate.php` komutunu çalıştır. `017_kvkk_legal_documents.sql` uygulanmalıdır.
3. `/kvkk`, `/gizlilik` ve `/cerez-politikasi` adreslerini kontrol et.
4. Yeni hesap açıp yalnız Kullanım Koşulları için sözleşme onayı istendiğini; KVKK metninin açık rıza gibi zorunlu tutulmadığını kontrol et.
5. Ayarlar > Hesap ve Gizlilik bölümünden erişim, düzeltme, itiraz ve silme talebi oluştur.
6. Yönetim panelinde KVKK talebinin düştüğünü ve yetkili rol dışında erişilemediğini kontrol et.
7. Kullanılan canlı servislerin (sunucu, veri tabanı, nesne depolama, e-posta, SMS, bildirim, harita, analitik) şirket/unvan ve veri bölgesi envanterini hukukçuya ver. Yurt dışı aktarım varsa KVKK m.9 mekanizması tamamlanmadan servisi etkinleştirme.
8. VERBİS kayıt yükümlülüğü ve istisna durumunu şirketin çalışan sayısı, mali bilançosu ve ana faaliyet alanına göre hukukçuyla değerlendir.

## Ürün kuralları

- İsteğe bağlı konum, kamera, galeri ve bildirim izinleri reddedilince uygulamanın izin gerektirmeyen bölümleri çalışmaya devam etmelidir.
- Tam adres ve kesin koordinat herkese açık API yanıtında bulunmamalıdır.
- Analitik ve pazarlama teknolojileri çerez izni verilmeden başlatılmamalıdır.
- Pazarlama/e-posta tercihleri KVKK aydınlatması ve Kullanım Koşulları onayıyla birleştirilmemelidir.
- Politika metni değişince yeni sürüm yayımlanmalı; eski kayıtlar sürüm ve zaman bilgisiyle korunmalıdır.
- İlgili kişi başvuruları en kısa sürede ve en geç 30 gün içinde gerekçeli olarak sonuçlandırılmalıdır.
