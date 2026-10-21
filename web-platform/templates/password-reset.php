<?php

use App\Core\View;
?>
<section class="auth-shell">
  <div class="auth-copy">
    <span class="eyebrow">Hesap güvenliği</span>
    <h1>Yeni şifreni belirle</h1>
    <p>Bağlantı tek kullanımlıktır ve şifre değiştiğinde bütün açık oturumlar kapatılır.</p>
  </div>
  <form class="auth-card" data-password-reset-form>
    <input type="hidden" name="token" value="<?= View::escape($token) ?>">
    <label>Yeni şifre<span class="password-input"><input type="password" name="password" minlength="10" maxlength="200" autocomplete="new-password" required><button type="button" data-toggle-password aria-label="Yeni şifreyi göster">Göster</button></span></label>
    <small class="password-help">En az 10 karakter; harf, rakam ve özel karakter kullan.</small>
    <label>Yeni şifre tekrar<span class="password-input"><input type="password" name="password_confirmation" minlength="10" maxlength="200" autocomplete="new-password" required><button type="button" data-toggle-password aria-label="Şifre tekrarını göster">Göster</button></span></label>
    <button class="primary-button full-button" type="submit">Şifremi yenile</button>
    <div class="form-message" data-form-message role="status"></div>
  </form>
</section>
