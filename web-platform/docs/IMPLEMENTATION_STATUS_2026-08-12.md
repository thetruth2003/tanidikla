# Feedback uygulama durumu — 12 Ağustos 2026

## Tamamlananlar

- Web ve Flutter kayıt ekranında parola tekrarı, ortak güçlü parola politikası,
  göster/gizle düğmeleri ve mesaj e-posta tercihi
- E-posta doğrulama/sıfırlama akışının korunması; e-posta değişikliği,
  şifre değişikliği, telefon OTP ve aktif oturumların yönetimi
- Mobil girişin secure storage + dönen refresh token ile hatırlanması; web
  oturumunun güvenli cookie ile korunması
- Ankara sabit merkezinin kaldırılması; web/mobil açıklamalı izin, gerçek konum,
  tarafsız Türkiye fallback'i ve ilan başına 1–100 km hizmet alanı
- Web menü bağlantılarından canlı keşif haritasına smooth scroll
- Zorunlu/analitik/pazarlama cookie tercih ekranı
- Profil fotoğrafı önizleme, kamera/galeri seçimi, değiştirme ve kaldırma
- Web mesaj balonlarında gerçek gönderene göre sağ/sol yön, seçili konuşma,
  diğer kişinin profiline geçiş ve güvenli özel mesaj fotoğrafları
- Web/mobil bildirim rozetleri, mevcut realtime + polling fallback ve isteğe bağlı
  mesaj e-posta kuyruğu
- Mevcut değerlendirmeyi getirip düzenleme ve backend içerik politikası
- Admin ilan moderasyonu ve kullanıcı askıya alma akışlarının korunması; kategori,
  şikâyet ve denetim ekranlarının profesyonel panelde kalması
- Production hata detaylarının gizlenmesi; sahte uygulama indirme bağlantısı ve
  kullanıcıya görünen test öğelerinin release akışından çıkarılması

## Bilerek sahte tamamlanmayan harici işler

- SMTP/NetGSM/Centrifugo değerleri sunucuda girilmeden ilgili teslimat kanalı
  başarılı görünmez.
- FCM/APNs arka plan push bildirimi ve otomatik görsel moderasyon sağlayıcısı
  henüz bağlanmamıştır. Uygulama içi bildirim/realtime çalışır; provider alanları
  `.env.example` içinde kapalıdır.
- Müsaitlik bugün `urgent/şu an müsait` ve serbest çalışma saati metniyle güvenli
  biçimde gösterilir. Yanlış kırmızı “kapalı” durumu üretmemek için saat dilimli,
  yapılandırılmış takvim modeli ayrı uyumlu migration fazına bırakılmıştır.
- Public OpenStreetMap tile servisi test için uygundur; yoğun ticari trafik öncesi
  uygun sağlayıcı seçilmelidir.

## Doğrulama sonuçları

- PHP lint: geçti
- JavaScript syntax: geçti
- PostgreSQL migration 010: yerel veritabanında geçti, mevcut veriler korundu
- API/web live smoke: health, kayıt, ilan, harita, mesaj, yorum, bildirim, admin,
  CSRF/IDOR/XSS kontrolleri geçti
- Flutter analyze: sorun yok
- Flutter test: 27 test geçti
