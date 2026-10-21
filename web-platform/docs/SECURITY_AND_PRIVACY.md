# Güvenlik ve KVKK uygulama notları

## Kimlik doğrulama

- Parolalar Argon2id ile hashlenir.
- Web oturumu HttpOnly cookie, idle timeout ve CSRF token ile korunur.
- Mobil access token kısa ömürlüdür; refresh token tek kullanımlı döner. Eski tokenın yeniden kullanımı bütün aileyi compromised/revoked yapar.
- Admin oturumu ayrı tablo, cookie, CSRF adı, Strict SameSite ve daha kısa idle timeout kullanır.
- Askıya alma bütün web, mobil ve admin oturumlarını iptal eder.

## Yetkilendirme ve veri güvenliği

- Admin endpointleri `role_permissions` üzerinden permission kontrolü yapar.
- Her moderasyon değişikliği aktör, hedef, metadata, IP ve zamanla `admin_audit_logs` tablosuna eklenir.
- Mesaj ve upload işlemlerinde sahiplik/üyelik sunucuda doğrulanır; kullanıcı engeli iki yönde uygulanır.
- Exact adres private tabloda kalır. Public nokta deterministik olmayan 350–650 metre gizlilik ofsetiyle gösterilir.
- Telefon numarası varsayılan olarak kapalıdır ve public profil/ilan yanıtına eklenmez. Kullanıcı açıkça görünür yaptığında bile yalnız oturumlu, engellenmemiş ve rate-limitli bir reveal isteğiyle döner; reveal olayı request ID ile kaydedilir.
- Görseller MIME/decode/piksel/boyut kontrolünden geçer, EXIF yönü uygulanır ve metadata içermeyen WebP olarak yeniden kodlanır.

## KVKK altyapısı

Hukuki metin uygulama tarafından uydurulmaz. Yetkili kişi hukuk ekibinin onaylı
metnini sürümleyip yayımlar; aynı türün önceki sürümü retired olur. Kullanıcı onayı
belge ID/sürüm, eylem, IP, user-agent ve zamanla tutulur.

Kullanıcı veri kopyasını API'den alabilir ve silme/düzeltme/itiraz talebi oluşturabilir.
Silme talebi yetkili tarafından tamamlandığında:

- e-posta ve profil anonimleştirilir,
- tüm oturum/tokenlar iptal edilir,
- ilanlar kaldırılır ve kesin adres temizlenir,
- kullanıcı görselleri storage'dan silinir,
- telefon numarası ve görünürlük tercihi temizlenir; ilişkili analytics kimlikleri anonimleştirilir,
- yazdığı değerlendirmeler yayından kaldırılır,
- karşı tarafın konuşma bütünlüğünü korumak için mesaj kaydı anonim kullanıcı kimliği altında kalır.

Saklama süreleri ve talep SLA'ları hukuk/uyum ekibi tarafından production öncesi
tanımlanmalıdır. `policy_documents` içine gerçek metin girilmeden yasal sayfalar açıkça
“henüz yayımlanmadı” durumu gösterir.
