<?php

use App\Core\View;

$initial = mb_substr((string) $profile['display_name'], 0, 1);
?>
<?php
$genderLabels = ['female' => 'Kadın', 'male' => 'Erkek', 'other' => 'Diğer'];
$profileType = (string) ($profile['profile_type'] ?? 'person');
$displayTitle = $profileType === 'business' && !empty($profile['business_name']) ? $profile['business_name'] : $profile['display_name'];
?>
<section class="simple-shell public-profile-shell" data-public-profile data-profile-id="<?= View::escape($profile['id']) ?>">
  <div class="owner-profile-actions" data-owner-profile-actions hidden><a class="secondary-button" href="/profili-duzenle">Profili düzenle</a><a class="secondary-button" href="/ilanlarim">Aktif ilanlarım</a><a class="secondary-button" href="/ayarlar">Ayarlar</a></div>
  <div class="public-profile-head">
    <span class="seller-avatar"><?php if (!empty($profile['avatar_path'])): ?><img src="<?= View::escape($profile['avatar_path']) ?>" alt="<?= View::escape($displayTitle) ?> profil fotoğrafı"><?php else: ?><?= View::escape($initial) ?><?php endif; ?></span>
    <div><span class="eyebrow"><?= $profileType === 'business' ? 'Doğrulanabilir işletme profili' : 'Şahıs profili' ?></span><h1><?= View::escape($displayTitle) ?></h1><p><?= View::escape(implode(', ', array_filter([$profile['district'] ?? '', $profile['city'] ?? '']))) ?> · ★ <?= number_format((float) $profile['rating'], 1, ',') ?> (<?= (int) $profile['review_count'] ?> değerlendirme)</p><div class="profile-badges"><?php if (!empty($profile['is_verified'])): ?><span>✓ Doğrulanmış kullanıcı</span><?php endif; ?><?php if ($profileType === 'business'): ?><span>▣ İşletme</span><?php endif; ?><?php if (isset($genderLabels[$profile['gender'] ?? ''])): ?><span><?= View::escape($genderLabels[$profile['gender']]) ?></span><?php endif; ?></div></div>
  </div>
  <?php if ($profileType === 'business'): ?><div class="business-public-card"><h2>İşletme bilgileri</h2><dl><div><dt>İşletme adı</dt><dd><?= View::escape($profile['business_name'] ?? '') ?></dd></div><div><dt>Hizmet bölgesi</dt><dd><?= View::escape(trim(($profile['district'] ?? '').' '.($profile['city'] ?? ''))) ?></dd></div><div><dt>Hizmet alanları</dt><dd><?= View::escape($profile['business_services'] ?: 'Henüz belirtilmedi.') ?></dd></div></dl></div><?php endif; ?>
  <div class="profile-bio"><h2>Hakkında</h2><p><?= View::escape($profile['bio'] !== '' ? $profile['bio'] : 'Profil açıklaması henüz eklenmemiş.') ?></p></div>
  <?php $preferenceDetails = $profile['category_preferences']['details'] ?? ['receive' => [], 'provide' => []]; ?>
  <?php if (($preferenceDetails['receive'] ?? []) !== [] || ($preferenceDetails['provide'] ?? []) !== []): ?><div class="public-preferences"><div><h3>Hizmet almak istediği alanlar</h3><div class="profile-badges"><?php foreach ($preferenceDetails['receive'] ?? [] as $category): ?><span><?= View::escape($category['label']) ?></span><?php endforeach; ?></div></div><div><h3>Hizmet verdiği alanlar</h3><div class="profile-badges"><?php foreach ($preferenceDetails['provide'] ?? [] as $category): ?><span><?= View::escape($category['label']) ?></span><?php endforeach; ?></div></div></div><?php endif; ?>
  <?php if (!empty($profile['phone_visible'])): ?><button class="secondary-button" type="button" data-reveal-phone data-profile-id="<?= View::escape($profile['id']) ?>">Telefonu göster</button><?php endif; ?>
  <div class="profile-listings"><h2>Verdiği hizmetler</h2>
    <div class="compact-list">
      <?php if ($profile['services'] === []): ?><span>Henüz aktif hizmet ilanı yok.</span><?php endif; ?>
      <?php foreach ($profile['services'] as $service): ?>
        <article class="compact-listing"><div><strong><?= View::escape($service['title']) ?></strong><p><?= View::escape($service['description']) ?></p></div><small><?= View::escape(View::priceLabel($service['price_amount'], $service['pricing_unit'])) ?></small></article>
      <?php endforeach; ?>
    </div>
  </div>
  <div class="profile-listings"><h2>Değerlendirmeler</h2>
    <div class="compact-list">
      <?php if ($profile['reviews'] === []): ?><span>Henüz değerlendirme yok.</span><?php endif; ?>
      <?php foreach ($profile['reviews'] as $review): ?>
        <article class="compact-listing"><div><strong><?= View::escape($review['author_name']) ?> · ★ <?= number_format((float) $review['rating'], 1, ',') ?></strong><p><?= View::escape($review['comment']) ?></p></div></article>
      <?php endforeach; ?>
    </div>
  </div>
  <div class="profile-listings verified-work-history"><h2>Doğrulanmış iş geçmişi <span class="status-pill"><?= (int)$profile['completed_jobs'] ?> tamamlanan</span></h2>
    <div class="rating-distribution" aria-label="Puan dağılımı"><?php for ($rating=5;$rating>=1;$rating--): ?><span><b><?= $rating ?> ★</b><i><em style="width:<?= $profile['review_count'] > 0 ? min(100, ((int)($profile['rating_distribution'][(string)$rating] ?? 0) / (int)$profile['review_count']) * 100) : 0 ?>%"></em></i><small><?= (int)($profile['rating_distribution'][(string)$rating] ?? 0) ?></small></span><?php endfor; ?></div>
    <div class="compact-list"><?php if (($profile['recent_completed_jobs'] ?? []) === []): ?><span>Henüz platform üzerinden doğrulanmış tamamlanan iş yok.</span><?php endif; ?><?php foreach ($profile['recent_completed_jobs'] ?? [] as $job): ?><article class="compact-listing"><div><strong>✓ <?= View::escape($job['service_name_snapshot']) ?></strong><p>Doğrulanmış iş · <?= View::escape(date('d.m.Y', strtotime((string)$job['completed_at']))) ?></p></div></article><?php endforeach; ?></div>
  </div>
</section>
