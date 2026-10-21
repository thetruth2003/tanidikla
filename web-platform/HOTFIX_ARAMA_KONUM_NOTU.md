# Tanıdıkla arama ve konum hotfix'i

Bu paket, mevcut güncel web/API kurulumunun üzerine çıkarılmalıdır.

İçerik:

- Arama önerilerinde ilan kartları kaldırıldı; eşleşen kategoriler önceliklendirildi.
- Eşleşen kategori yoksa yalnız genel arama seçeneği gösteriliyor.
- Üst menüden “Tüm kategoriler” seçildiğinde detaylı filtrede kalmış eski kategori seçimleri de temizleniyor.
- Üst menüde aynı haritaya giden üç tekrar bağlantı kaldırıldı; tek “Hizmet bul/al” bağlantısı bırakıldı.
- “Ara” ve “Filtreleri uygula” işlemlerinden sonra sayfa harita bölümüne geri dönüyor.
- Mesafe sınırı kapalıyken uygulanan gizli 60 km filtresi kaldırıldı.
- Konum alma yüksek doğruluk başarısızsa ikinci yöntemle yeniden deneniyor.
- Konum izni hata mesajları anlaşılır hale getirildi.
- İzinli konum 15 km çevreyi gösterecek şekilde ortalanıyor.
- Konum yoksa harita Türkiye merkezinde açılıyor.
- Geçersiz veya Türkiye dışındaki koordinatlar haritayı okyanusa taşıyamıyor.
- Filtreli arama mevcut görünümde boşsa arama Türkiye geneline genişletiliyor; yine boşsa harita Türkiye merkezinde kalıyor.
- Haritanın Türkiye dışına sürüklenmesi sınırlandırıldı.
- Harita sağlayıcısı hata verirse OpenStreetMap yedeği deneniyor.
- Küfür/hakaret kontrolü ilan, mesaj, profil, kayıt adı ve yorumlarda API tarafında uygulanıyor.
- Filtre; noktalama/boşlukla bölme, yaygın rakam-harf değiştirme, uzatılmış harf, ek almış sözcük ve çok sözcüklü ağır hakaretleri yakalıyor.
- Sunucuya özel ilave kurallar `.env` içindeki `CONTENT_POLICY_EXTRA_BLOCKED` alanından eklenebiliyor.
- Ayarlar ekranındaki bölüm bağlantıları artık sayfayla beraber aşağı kayar; içeriklerin üstünü kapatan yapışkan menü kaldırıldı.
- Kapalı beta geri bildirim alanları sitenin form tasarımına uyarlandı ve doğru API adresine bağlandı.
- Ayarlara “Engellediğim kullanıcılar” bölümü eklendi; kullanıcı engeli onay penceresiyle kaldırılabiliyor.
- Tanıdıkla yatay logosu site başlığına, yazı logosu alt bilgiye ve kare amblemi yönetim paneline yerleştirildi.
- Kare amblem tarayıcı faviconu, Google arama sonucu ikonu, Apple ana ekran ikonu ve web uygulaması manifest ikonu olarak tanımlandı.
- Link paylaşım önizlemelerine Open Graph/Twitter görseli ve Google Organization logo yapılandırılmış verisi eklendi.

Yeni migration yoktur. `php bin/migrate.php` çalıştırmak bu hotfix için zorunlu değildir.
Dosyalar sunucuya çıkarıldıktan sonra PHP-FPM/OPcache kullanılıyorsa yeniden yüklenmesi önerilir.
