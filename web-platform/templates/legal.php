<section class="simple-shell legal-shell">
  <span class="eyebrow">Yasal bilgilendirme</span>
  <?php if ($document === null): ?>
    <h1><?= App\Core\View::escape($title) ?></h1>
    <div class="setup-notice"><strong>Metin henüz yayımlanmadı.</strong><span>İçerik, hukuk ekibi tarafından yönetim panelinde onaylandıktan sonra burada gösterilecek. Hukuki içerik sistem tarafından üretilmez.</span></div>
  <?php else: ?>
    <h1><?= App\Core\View::escape($document['title']) ?></h1><p>Sürüm <?= App\Core\View::escape($document['version']) ?></p>
    <?php if (($document['configuration_complete'] ?? true) !== true): ?><div class="setup-notice legal-config-warning"><strong>Yayın yapılandırması tamamlanmadı.</strong><span>Veri sorumlusu adı, adresi ve KVKK iletişim bilgileri sunucu ortam değişkenlerine girilmeden bu metin canlı kullanıma hazır değildir.</span></div><?php endif; ?>
    <article class="legal-content"><?= nl2br(App\Core\View::escape($document['content'])) ?></article>
  <?php endif; ?>
</section>
