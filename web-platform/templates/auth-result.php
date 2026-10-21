<?php

use App\Core\View;
?>
<section class="auth-shell">
  <div class="auth-copy">
    <span class="eyebrow">Hesap güvenliği</span>
    <h1><?= View::escape($heading) ?></h1>
    <p><?= View::escape($message) ?></p>
    <a class="primary-button" href="/giris">Giriş sayfasına git</a>
  </div>
</section>
