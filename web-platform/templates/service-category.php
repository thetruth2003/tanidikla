<?php

use App\Core\View;

$label = (string) $category['label'];
$locationLabel = $city !== null ? $city : 'Türkiye';
$total = (int) ($pagination['total'] ?? count($listings));
$page = (int) ($pagination['page'] ?? 1);
$pages = (int) ($pagination['pages'] ?? 0);
?>
<section class="seo-landing-hero">
  <nav class="seo-breadcrumb" aria-label="Sayfa yolu">
    <a href="/">Tanıdıkla</a><span>›</span>
    <?php if ($city !== null): ?><a href="<?= View::escape($categoryUrl) ?>"><?= View::escape($label) ?></a><span>›</span><?php endif; ?>
    <span aria-current="page"><?= View::escape($city !== null ? $city : $label) ?></span>
  </nav>
  <div class="seo-landing-grid">
    <div>
      <span class="eyebrow"><?= View::escape($city !== null ? $city . ' hizmetleri' : 'Hizmet kategorisi') ?></span>
      <h1><?= View::escape($city !== null ? $city . ' ' . $label . ' hizmetleri' : $label . ' hizmetleri') ?></h1>
      <p><?= View::escape($locationLabel) ?> genelindeki güncel <?= View::escape(mb_strtolower($label, 'UTF-8')) ?> ilanlarını incele, hizmet veren profillerini karşılaştır ve platform üzerinden güvenli biçimde iletişime geç.</p>
      <div class="seo-landing-actions">
        <a class="primary-button" href="/?type=service_offer&category=<?= View::escape((string) $category['id']) ?>#kesfet-haritasi">Haritada görüntüle</a>
        <a class="secondary-button" href="/ilan-ver?type=service_request">Ücretsiz talep oluştur</a>
      </div>
    </div>
    <aside class="seo-summary-card" aria-label="Kategori özeti">
      <strong><?= number_format($total, 0, ',', '.') ?></strong>
      <span>yayındaki eşleşen ilan</span>
      <small><?= View::escape($locationLabel) ?> · <?= View::escape($label) ?></small>
    </aside>
  </div>
</section>

<?php if ($relatedCities !== []): ?>
<section class="content-section seo-city-section">
  <div class="section-heading"><div><span class="eyebrow">Şehre göre keşfet</span><h2><?= View::escape($label) ?> ilanlarının bulunduğu şehirler</h2></div></div>
  <div class="seo-city-links">
    <?php foreach ($relatedCities as $location): ?>
      <a href="<?= View::escape($categoryUrl . '/' . $location['city_slug']) ?>"><strong><?= View::escape($location['city']) ?></strong><span><?= (int) $location['listing_count'] ?> ilan</span></a>
    <?php endforeach; ?>
  </div>
</section>
<?php endif; ?>

<section class="content-section listings-section seo-results-section">
  <div class="section-heading">
    <div><span class="eyebrow">Güncel sonuçlar</span><h2><?= View::escape($locationLabel) ?> <?= View::escape($label) ?> ilanları</h2></div>
  </div>
  <?php if ($listings === []): ?>
    <div class="empty-state"><span>⌕</span><h3>Bu kategoride henüz aktif ilan yok.</h3><p>İhtiyacını ücretsiz yayınlayarak hizmet verenlerden dönüş alabilirsin.</p><a class="primary-button" href="/ilan-ver?type=service_request">İlk talebi oluştur</a></div>
  <?php else: ?>
    <div class="listing-grid">
      <?php foreach ($listings as $listing): ?>
        <article class="listing-card">
          <a class="listing-cover" href="/ilan/<?= View::escape($listing['slug']) ?>">
            <?php if (!empty($listing['cover_image'])): ?><img src="<?= View::escape($listing['cover_image']) ?>" alt="<?= View::escape($listing['title']) ?>" loading="lazy" width="640" height="380"><?php else: ?><span><?= View::escape(mb_substr($listing['title'], 0, 1)) ?></span><?php endif; ?>
            <?php if (!empty($listing['urgent'])): ?><small>Şu an müsait</small><?php endif; ?>
          </a>
          <div class="listing-body">
            <div class="listing-meta"><span><?= View::escape($listing['public_district']) ?></span><span><?= View::escape($listing['public_city']) ?></span></div>
            <h3><a href="/ilan/<?= View::escape($listing['slug']) ?>"><?= View::escape($listing['title']) ?></a></h3>
            <p><?= View::escape(mb_substr($listing['description'], 0, 110)) ?></p>
            <div class="listing-footer"><span><?= View::escape($listing['owner_name']) ?> · ★ <?= number_format((float) $listing['owner_rating'], 1, ',') ?></span><strong><?= View::escape(View::priceLabel($listing['price_amount'], $listing['pricing_unit'])) ?></strong></div>
          </div>
        </article>
      <?php endforeach; ?>
    </div>
    <?php if ($pages > 1): ?>
      <nav class="seo-pagination" aria-label="Sonuç sayfaları">
        <?php if ($page > 1): ?><a rel="prev" href="<?= View::escape($canonicalBase . ($page - 1 > 1 ? '?page=' . ($page - 1) : '')) ?>">← Önceki</a><?php endif; ?>
        <span><?= $page ?> / <?= $pages ?></span>
        <?php if ($page < $pages): ?><a rel="next" href="<?= View::escape($canonicalBase . '?page=' . ($page + 1)) ?>">Sonraki →</a><?php endif; ?>
      </nav>
    <?php endif; ?>
  <?php endif; ?>
</section>

<section class="content-section seo-guide-section">
  <div><span class="eyebrow">Doğru hizmeti seç</span><h2><?= View::escape($label) ?> ararken nelere dikkat edilmeli?</h2></div>
  <div class="seo-guide-grid">
    <article><strong>İhtiyacını açık anlat</strong><p>Yapılacak işi, tercih ettiğin zamanı ve yaklaşık konumu ilanda net biçimde belirt.</p></article>
    <article><strong>Profili karşılaştır</strong><p>Hizmet verenin doğrulama durumunu, değerlendirmelerini ve önceki hizmetlerini incele.</p></article>
    <article><strong>Fiyatı netleştir</strong><p>İşe başlamadan önce kapsamı, ücret türünü ve varsa ek masrafları mesajlaşmada kesinleştir.</p></article>
  </div>
</section>
