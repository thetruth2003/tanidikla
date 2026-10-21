<?php

use App\Core\View;

$register = $mode === 'register';
$returnTo = (string) ($returnTo ?? ($register ? '/profili-duzenle' : '/'));
$terms = array_values(array_filter($policies ?? [], static fn (array $policy): bool => $policy['document_type'] === 'terms'));
$notices = array_values(array_filter($policies ?? [], static fn (array $policy): bool => $policy['document_type'] !== 'terms'));
$policyPath = static fn (string $type): string => match ($type) {
    'terms' => '/kullanim-kosullari',
    'kvkk_notice' => '/kvkk',
    'cookie_policy' => '/cerez-politikasi',
    default => '/gizlilik',
};
?>
<section class="auth-shell">
  <div class="auth-intro">
    <span class="eyebrow">Tek hesap, iki platform</span>
    <h1><?= $register ? 'Ücretsiz hesabını oluştur.' : 'Tekrar hoş geldin.' ?></h1>
    <p>Webde başladığın ilana uygulamada devam et; mesajların ve profilin her yerde yanında olsun.</p>
    <ul><li>Yakınındaki hizmetleri keşfet</li><li>Ücretsiz hizmet veya iş ilanı yayınla</li><li>Güvenli biçimde mesajlaş</li></ul>
  </div>
  <div class="auth-card">
    <h2><?= $register ? 'Hesap oluştur' : 'Giriş yap' ?></h2>
    <p><?= $register ? 'Birkaç bilgiyle hemen başlayabilirsin.' : 'E-posta ve şifrenle devam et.' ?></p>
    <form data-auth-form data-mode="<?= View::escape($mode) ?>" data-return-to="<?= View::escape($returnTo) ?>">
      <?php if ($register): ?>
        <label>Görünen ad veya işletme adı<input name="display_name" required minlength="2" maxlength="80" autocomplete="name"></label>
        <label>Profil türü<select name="profile_type" required><option value="person">Şahıs profili</option><option value="business">İşletme profili</option></select></label>
      <?php endif; ?>
      <label>E-posta<input name="email" required type="email" autocomplete="email"></label>
      <label>Şifre<span class="password-input"><input name="password" required type="password" minlength="10" maxlength="200" autocomplete="<?= $register ? 'new-password' : 'current-password' ?>"><button type="button" data-toggle-password aria-label="Şifreyi göster">Göster</button></span></label>
      <?php if ($register): ?>
        <small class="password-help">En az 10 karakter; harf, rakam ve özel karakter kullan.</small>
        <label>Şifreyi tekrar yaz<span class="password-input"><input name="password_confirmation" required type="password" minlength="10" maxlength="200" autocomplete="new-password"><button type="button" data-toggle-password aria-label="Şifre tekrarını göster">Göster</button></span></label>
        <label class="preference-check"><input type="checkbox" name="message_email_notifications" value="true"><span>Yeni mesaj geldiğinde e-posta ile bildirim almak istiyorum.</span></label>
        <?php if (\App\Core\Config::bool('BETA_MODE')): ?>
          <label>Kapalı beta davet kodu<input name="beta_invite_code" required maxlength="120" autocomplete="one-time-code" placeholder="Davet kodunu yaz"></label>
        <?php endif; ?>
      <?php else: ?>
        <button class="auth-link-button" type="button" data-forgot-password>Şifremi unuttum</button>
      <?php endif; ?>
      <?php if ($register && $terms !== []): ?>
        <fieldset class="consent-field"><legend>Sözleşme onayı</legend>
          <?php foreach ($terms as $policy): ?><label><input type="checkbox" name="policy_ids" value="<?= View::escape($policy['id']) ?>" required><span><a href="<?= View::escape($policyPath((string) $policy['document_type'])) ?>" target="_blank"><?= View::escape($policy['title']) ?></a>’nı okudum ve kabul ediyorum.</span></label><?php endforeach; ?>
        </fieldset>
      <?php endif; ?>
      <?php if ($register && $notices !== []): ?>
        <div class="legal-notice-links"><strong>Verilerin hakkında bilgilendirme</strong><p>Kayıt sırasında kişisel verilerinin nasıl işlendiğini aşağıdaki metinlerden inceleyebilirsin. Bunlar açık rıza veya sözleşme onayı değildir.</p><div>
          <?php foreach ($notices as $policy): ?><a href="<?= View::escape($policyPath((string) $policy['document_type'])) ?>" target="_blank"><?= View::escape($policy['title']) ?></a><?php endforeach; ?>
        </div></div>
      <?php endif; ?>
      <div class="form-message" data-form-message role="status"></div>
      <button class="primary-button full-button" type="submit"><?= $register ? 'Ücretsiz hesap oluştur' : 'Giriş yap' ?></button>
    </form>
    <p class="auth-switch"><?= $register ? 'Zaten hesabın var mı?' : 'Henüz hesabın yok mu?' ?> <a href="<?= $register ? '/giris' : '/kayit' ?>?return_to=<?= rawurlencode($returnTo) ?>"><?= $register ? 'Giriş yap' : 'Ücretsiz kaydol' ?></a></p>
  </div>
</section>
