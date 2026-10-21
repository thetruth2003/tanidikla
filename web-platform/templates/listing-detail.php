<?php

use App\Core\View;

$first = $listing['items'][0] ?? [];
$headline = (string)($listing['headline'] ?? $first['title'] ?? 'İlan');
$price = View::priceLabel($first['price_amount'] ?? null, $first['pricing_unit'] ?? 'negotiable');
?>
<section class="detail-shell">
  <div class="breadcrumb"><a href="/">Keşfet</a><span>›</span><span><?= View::escape($headline) ?></span></div>
  <div class="detail-grid">
    <article class="detail-main">
      <div class="detail-visual">
        <?php if (($listing['images'][0]['storage_path'] ?? '') !== ''): ?>
          <img src="<?= View::escape($listing['images'][0]['storage_path']) ?>" alt="<?= View::escape($first['title'] ?? 'İlan görseli') ?>" width="960" height="560">
        <?php else: ?><span><?= View::escape(mb_substr((string) ($first['title'] ?? 'H'), 0, 1)) ?></span><?php endif; ?>
      </div>
      <?php if (count($listing['images']) > 1): ?><div class="detail-thumbnails" aria-label="İlan görselleri"><?php foreach ($listing['images'] as $image): ?><button type="button" data-gallery-image="<?= View::escape($image['storage_path']) ?>"><img src="<?= View::escape($image['storage_path']) ?>" alt="" loading="lazy"></button><?php endforeach; ?></div><?php endif; ?>
      <div class="detail-heading"><div><span class="status-pill"><?= !empty($first['urgent']) ? 'Şu an müsait' : 'Aktif ilan' ?></span><h1><?= View::escape($headline) ?></h1><p>⌖ <?= View::escape($listing['public_neighborhood']) ?>, <?= View::escape($listing['public_district']) ?></p></div><strong><?= count($listing['items']) > 1 ? count($listing['items']).' farklı hizmet' : View::escape($price) ?></strong></div>
      <?php if (($listing['summary'] ?? '') !== ''): ?><div class="detail-content"><h2>İlan özeti</h2><p><?= nl2br(View::escape($listing['summary'])) ?></p></div><?php endif; ?>
      <div class="detail-content service-item-cards" data-service-item-picker><h2>Hizmet kalemleri</h2><p>İletişime geçmek istediğin hizmeti seç.</p><?php foreach ($listing['items'] as $index => $item): if (empty($item['is_active'])) continue; ?><label class="service-item-card"><input type="radio" name="selected_listing_item" value="<?= View::escape($item['id']) ?>" <?= $index === 0 ? 'checked' : '' ?>><span><strong><?= View::escape($item['title']) ?></strong><small><?= nl2br(View::escape($item['description'])) ?></small><?php if (!empty($item['estimated_duration_minutes'])): ?><em>Yaklaşık <?= (int)$item['estimated_duration_minutes'] ?> dakika</em><?php endif; ?></span><b><?= View::escape(View::priceLabel($item['price_amount'] ?? null, $item['pricing_unit'] ?? 'negotiable')) ?></b></label><?php endforeach; ?></div>
      <div class="detail-content"><div class="detail-map-heading"><div><h2>Haritadaki konumu</h2><p><?= $listing['location_precision'] === 'neighborhood' ? 'Gizlilik için yaklaşık mahalle konumu gösterilir.' : 'İlanda belirtilen konum gösterilir.' ?></p></div><a class="secondary-button" href="https://www.openstreetmap.org/?mlat=<?= View::escape((string) $listing['latitude']) ?>&mlon=<?= View::escape((string) $listing['longitude']) ?>#map=16/<?= View::escape((string) $listing['latitude']) ?>/<?= View::escape((string) $listing['longitude']) ?>" target="_blank" rel="noopener">Haritada aç ↗</a></div><a class="detail-map-link" href="https://www.openstreetmap.org/?mlat=<?= View::escape((string) $listing['latitude']) ?>&mlon=<?= View::escape((string) $listing['longitude']) ?>#map=16/<?= View::escape((string) $listing['latitude']) ?>/<?= View::escape((string) $listing['longitude']) ?>" target="_blank" rel="noopener" aria-label="İlan konumunu haritada aç"><div class="detail-location-map" data-detail-map data-latitude="<?= View::escape((string) $listing['latitude']) ?>" data-longitude="<?= View::escape((string) $listing['longitude']) ?>" data-title="<?= View::escape((string) ($first['title'] ?? 'İlan')) ?>" data-precision="<?= View::escape((string) $listing['location_precision']) ?>" aria-label="İlan konumu haritası"></div></a></div>
    </article>
    <aside class="seller-card">
      <span class="eyebrow">Hizmet veren</span>
      <div class="seller-head"><span class="seller-avatar"><?= View::escape(mb_substr($listing['owner_name'], 0, 1)) ?></span><div><h2><?= View::escape($listing['owner_name']) ?></h2><p>★ <?= number_format((float) $listing['owner_rating'], 1, ',') ?> · <?= (int) $listing['owner_review_count'] ?> değerlendirme</p></div></div>
      <p><?= View::escape($listing['owner_bio'] ?: 'Profil açıklaması henüz eklenmemiş.') ?></p>
      <a class="primary-button full-button owner-edit-button" href="/ilan/<?= View::escape($listing['id']) ?>/duzenle" data-owner-edit-listing hidden>İlanımı düzenle</a>
      <button class="primary-button full-button" type="button" data-start-conversation data-listing-id="<?= View::escape($listing['id']) ?>">Seçili hizmet için mesaj gönder</button>
      <?php if (($listing['listing_type'] ?? '') === 'service_offer'): ?><button class="secondary-button full-button" type="button" data-create-engagement data-listing-id="<?= View::escape($listing['id']) ?>">Hizmet talebi gönder</button><?php endif; ?>
      <a class="secondary-button full-button" href="/profil/<?= View::escape($listing['owner_id']) ?>">Profili görüntüle</a>
      <?php if (!empty($listing['owner_phone_visible'])): ?><button class="secondary-button full-button" type="button" data-reveal-phone data-profile-id="<?= View::escape($listing['owner_id']) ?>">Telefonu göster</button><?php endif; ?>
      <div class="seller-actions" data-listing-actions data-listing-id="<?= View::escape($listing['id']) ?>" data-owner-id="<?= View::escape($listing['owner_id']) ?>">
        <button type="button" data-favorite-listing>♡ Favoriye ekle</button>
        <button type="button" data-share-listing>↗ Paylaş</button>
        <button type="button" data-review-listing>★ Değerlendir</button>
        <button type="button" data-report-listing>⚑ Bildir</button>
        <button type="button" data-block-owner>⊘ Engelle</button>
      </div>
      <small><?= !empty($listing['owner_phone_visible']) ? 'Telefon yalnız giriş yapmış kullanıcılara, açık isteğin ardından gösterilir.' : 'Telefon numarası gizlidir. İletişim platform içinden başlatılır.' ?></small>
    </aside>
  </div>
</section>
