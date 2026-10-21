# Birleşik üretim paketi — 13 Ağustos 2026

Bu sürüm önceki geri bildirim geliştirmelerini, web giriş CSRF düzeltmesini ve
13 Ağustos yönetim/arama arayüzü değişikliklerini tek pakette toplar.

## Kritik davranışlar

- `removed` ve `paused` durumları geri alınabilir moderasyon işlemleridir.
- Kalıcı silme ayrı bir `DELETE` işlemidir; yalnız `super_admin` rolüne verilen
  `users.delete` veya `listings.delete` izniyle çalışır.
- Kalıcı silmede en az 5 karakter neden ve `KALICI OLARAK SİL` onayı zorunludur.
- Yönetici hesabı, işlem yapan hesabın kendisi veya denetim kaydı sahibi eski
  yönetici hesabı kullanıcı silme ekranından kalıcı silinemez.
- Kullanıcı kalıcı silmesinde KVKK talebi engeli kontrollü kaldırılır, ilişkili
  veriler foreign key zinciriyle; yüklenen dosyalar storage adapter ile temizlenir.
- Arama önerileri yalnız aktif ilan ve kategorileri döndürür; `pg_trgm` ve
  `unaccent` ile Türkçe karakter/yazım hatası toleransı sağlar.

## Yükleme sonrası zorunlu komut

```bash
php -c php.ini bin/migrate.php
```

Çıktıda `010_account_feedback_security.sql` ve `011_admin_hard_delete.sql`
uygulanmış veya daha önce uygulandığı için atlanmış görünmelidir. Ardından
PHP-FPM/opcache yeniden yüklenmeli ve `/api/v1/health` kontrol edilmelidir.
