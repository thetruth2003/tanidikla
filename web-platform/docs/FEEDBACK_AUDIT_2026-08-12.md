# Feedback audit — 12 Ağustos 2026

Bu belge kod değişikliklerinden önce web, API, yönetim paneli ve Flutter istemcisinin
gerçek davranışının incelenmesiyle hazırlanmıştır. Test ilanları ve test hesapları
korunacaktır.

| Geri bildirim | Mevcut durum | Kök neden / yapılacak iş | Katman | Risk | Dış servis | Test |
|---|---|---|---|---|---|---|
| Şifre kurtarma | Var, web akışı tamam; mobil yalnız talep gönderebiliyor | Mobilde keşfedilebilirliği artır, web akışını koru | API/web/mobil | Orta | SMTP | Token tekrar kullanım testi |
| Kayıtta iki şifre | Yok | Web ve mobil doğrulama alanı; backend confirmation kontrolü | API/web/mobil | Düşük | Hayır | Eşleşmeyen parola reddi |
| Güçlü parola | Backend yalnız uzunluk kontrol ediyor | Ortak harf/rakam/özel karakter ve yaygın parola kontrolü | API/web/mobil | Orta | Hayır | Zayıf/güçlü parola matrisi |
| Şifre göster/gizle | Mobilde var, webde yok | Web kayıt/giriş/reset alanlarına erişilebilir düğme | Web | Düşük | Hayır | Klavye/tıklama testi |
| E-posta doğrulama | Token, mail kuyruğu ve route var | SMTP kapalıyken otomatik doğrulama mevcut; production ayarı ve görünür durum iyileştirilecek | API/web/mobil | Yüksek | SMTP | Süre/tek kullanım/yeniden gönderim |
| Telefon doğrulama | Telefon alanı ve SMS adapter var; doğrulama yok | Hashlenmiş OTP, süre/deneme/resend limiti ve doğrulanmış durum | API/web/mobil | Yüksek | SMS | OTP süre/deneme testi |
| E-posta/telefon/şifre değişimi | Yok | Yeniden parola kontrolü olan Hesap ve Güvenlik API/UI | API/web/mobil | Yüksek | SMTP/SMS | Yetki ve oturum iptali |
| Girişi hatırlama | Zaten var | Web secure cookie, mobil secure storage + refresh rotation korunacak; oturum yönetimi görünür yapılacak | API/web/mobil | Yüksek | Hayır | Yeniden açma/çıkış testi |
| Mesaj e-posta tercihi | Yok | Profil tercihi ve mesaj kuyruğu entegrasyonu | DB/API/web/mobil | Orta | SMTP | Opt-in/opt-out testi |
| İlk konum ve harita merkezi | Kısmen var; web butonla ister, iki istemci Ankara varsayımına sahip | Açıklamalı izin, gerçek konuma merkezleme, reddedilince manuel kullanım | Web/mobil | Yüksek | Hayır | İzin kabul/red/hata |
| Harita hareketinde sorgu | Webde var; mobil yalnız ilk merkez çevresini indiriyor | Mobil görünür alan sorgusu ve debounce; web davranışı korunacak | API/web/mobil | Orta | Hayır | Viewport ve limit testi |
| İlanda mevcut konum | Mobil talep konum seçicide var, diğer akışlarda keşfedilebilir değil | Ortak “Bulunduğum konumu işaretle” UX’i ve açık onay | Web/mobil | Orta | Hayır | GPS/manual seçim |
| Hizmet yarıçapı | Yok | İlan bazında 1–100 km alanı; geriye uyumlu 25 km varsayılanı | DB/API/web/mobil | Orta | Hayır | Arama kapsama testi |
| Menüden haritaya kaydırma | Yok | Home linklerinde hash + smooth scroll + sticky offset | Web | Düşük | Hayır | Masaüstü/mobil geri tuşu |
| Debug/test temizliği | Mobil test girişi yalnız debug modunda; webde sahte sosyal giriş yok, test verisi gerçek seed | Production flag’lerini doğrula; test kayıtlarını silme | Web/mobil | Düşük | Hayır | Release smoke |
| Cookie tercihleri | Yok | Zorunlu/analitik/pazarlama tercih merkezi; non-essential script gate | Web | Orta | Hayır | Kabul/red/yeniden açma |
| Profil fotoğrafı UX | Upload var, temel görünüyor | Önizleme, değiştir/kaldır, ilerleme/hata; mevcut media güvenliğini koru | API/web/mobil | Orta | Storage | MIME/boyut/görünürlük |
| Fotoğrafların görünmesi | Media endpoint ve URL üretimi var | Avatar URL’lerini mesaj/ilan/profil boyunca tekleştir | API/web/mobil | Orta | Storage | Relative/HTTPS URL |
| Müsaitlik | Serbest `schedule_label` var | Durum metni + renk/ikon; yapılandırılmış takvim sonraki uyumlu faz | Web/mobil | Düşük | Hayır | Üç durum görünümü |
| Mesaj bildirimleri | Unread, notification, realtime ve polling fallback zaten var | Kullanıcı bunu göremiyor; global rozet ve e-posta tercihi ekle | API/web/mobil | Orta | Push/SMTP | Gelen mesaj/duplicate testi |
| Mesaj yönleri | Mobil doğru; web sender kimliğini sınıfa çevirmiyor | Web balonlarını gerçek oturum kullanıcısına göre hizala | Web/API | Orta | Hayır | İki hesap testi |
| Seçili konuşma | Mobil ekran ayrı; web row seçili kalmıyor | `aria-selected` ve güçlü active stil | Web | Düşük | Hayır | Fare/klavye testi |
| Mesaj fotoğrafı | Yok | Mevcut güvenli media pipeline üstünde private attachment ilişkisi | DB/API/web/mobil | Yüksek | Storage | IDOR/MIME/EXIF testi |
| Mesajdan profile gitme | Conversation API `other_user_id` veriyor; UI linklemiyor | Başlık/avatar profil bağlantısı | Web/mobil | Düşük | Hayır | Engelli/silinmiş kullanıcı |
| Yorum düzenleme | API zaten var; UI yalnız yeni yorum akışını gösteriyor | Mevcut yorumu getirip düzenleme UX’i; yeni endpoint kopyalama | Web/mobil | Orta | Hayır | Sahiplik/tek yorum testi |
| Küfür/spam | Report sistemi var; metin filtresi yok | Backend içerik doğrulaması + kullanıcıya anlaşılır hata; report kuyruğunu koru | API/web/mobil/admin | Orta | Hayır | Kötü içerik/rate limit |
| Web/mobil yorum yetkisi | Yetki backendde conversation ilişkisine bağlı | Web ve mobil aynı hata/izin verisini kullanacak | API/web/mobil | Yüksek | Hayır | IDOR/ilişki testi |
| Admin ilan kaldırma | Zaten var | Panel görünürlüğü/confirm/neden alanını doğrula; soft delete korunacak | Admin/API | Yüksek | Hayır | Audit/geri açma |
| Admin kullanıcı askıya alma | Zaten var ve oturumları iptal ediyor | Panel keşfedilebilirliği/confirm/neden; kalıcı silme eklenmeyecek | Admin/API | Yüksek | Hayır | RBAC/audit/session revoke |

## Uygulama kararı

- Önce hesap güvenliği ve doğrulama tamamlanacaktır.
- Sonra konum/hizmet yarıçapı, mesaj/fotoğraf ve görünürlük sorunları ele alınacaktır.
- E-posta, SMS, push ve storage için sahte başarı üretilmeyecek; kapalı provider
  kullanıcıya açık bir hata verir ve gerekli ortam değişkenleri belgelenir.
- Production verisine doğrudan yazılmayacak ve deployment yapılmayacaktır.
