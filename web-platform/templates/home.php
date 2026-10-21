<?php

use App\Core\View;
use App\Core\RequestContext;

$selectedType = (string) ($query['type'] ?? 'service_offer');
$term = (string) ($query['q'] ?? '');
$selectedCategory = (string) ($query['category'] ?? '');
$selectedCategoriesValue = $query['categories'] ?? [];
$selectedCategories = is_array($selectedCategoriesValue)
    ? array_values(array_map('strval', $selectedCategoriesValue))
    : array_values(array_filter(array_map('trim', explode(',', (string) $selectedCategoriesValue))));
if ($selectedCategory !== '' && !in_array($selectedCategory, $selectedCategories, true)) $selectedCategories[] = $selectedCategory;
$hasRadiusFilter = isset($query['radius_meters']) && (int) $query['radius_meters'] > 0;
$selectedRadius = max(1000, min(100000, (int) ($query['radius_meters'] ?? 20000)));
$filterChecked = static fn (string $key): bool => filter_var($query[$key] ?? false, FILTER_VALIDATE_BOOL);
$selectedGender = (string) ($query['gender'] ?? '');
$selectedProviderKind = (string) ($query['provider_kind'] ?? '');
$advancedOpen = $selectedCategories !== []
    || $filterChecked('available_now') || $filterChecked('open_24_7') || $filterChecked('verified_only')
    || $selectedGender !== '' || $selectedProviderKind !== '' || isset($query['radius_meters']);
$groups = array_values(array_filter($categories, static fn (array $category): bool => $category['parent_id'] === null));
$children = array_values(array_filter($categories, static fn (array $category): bool => $category['parent_id'] !== null));
$selectedCategoryRow = current(array_filter($children, static fn (array $category): bool => $category['id'] === $selectedCategory));
$selectedCategoryLabel = is_array($selectedCategoryRow) ? (string)$selectedCategoryRow['label'] : 'Tüm kategoriler';
$categoryLabels = [];
foreach ($children as $child) $categoryLabels[(string) $child['id']] = (string) $child['label'];
$initialFilterLabels = [];
foreach ($selectedCategories as $categoryId) {
    if (isset($categoryLabels[$categoryId])) $initialFilterLabels[] = $categoryLabels[$categoryId];
}
if ($initialFilterLabels === [] && $selectedCategory !== '' && isset($categoryLabels[$selectedCategory])) {
    $initialFilterLabels[] = $categoryLabels[$selectedCategory];
}
if ($filterChecked('available_now')) $initialFilterLabels[] = 'Şu an müsait';
if ($filterChecked('open_24_7')) $initialFilterLabels[] = '7/24 açık';
if ($filterChecked('verified_only')) $initialFilterLabels[] = 'Doğrulanmış kullanıcı';
if ($selectedProviderKind === 'person') $initialFilterLabels[] = 'Şahıs';
if ($selectedProviderKind === 'business') $initialFilterLabels[] = 'Kurumsal';
if ($selectedGender === 'female') $initialFilterLabels[] = 'Kadın';
if ($selectedGender === 'male') $initialFilterLabels[] = 'Erkek';
if ($hasRadiusFilter) $initialFilterLabels[] = ($selectedRadius / 1000) . ' km';
$mapListingSource = is_array($mapListingRows ?? null) ? $mapListingRows : $listings;
$mapListings = array_map(static fn (array $listing): array => [
    'id' => $listing['id'],
    'slug' => $listing['slug'],
    'title' => $listing['title'],
    'owner_name' => $listing['owner_name'],
    'district' => $listing['public_district'],
    'neighborhood' => $listing['public_neighborhood'],
    'latitude' => $listing['latitude'],
    'longitude' => $listing['longitude'],
    'distance_meters' => $listing['distance_meters'],
    'price_amount' => $listing['price_amount'],
    'pricing_unit' => $listing['pricing_unit'],
    'urgent' => $listing['urgent'],
    'grouped' => (bool) ($listing['grouped'] ?? false),
    'service_count' => (int) ($listing['service_count'] ?? 1),
    'services' => array_map(static fn (array $service): array => [
        'id' => $service['id'] ?? null,
        'slug' => $service['slug'] ?? '',
        'title' => $service['title'] ?? '',
        'category_id' => $service['category_id'] ?? '',
        'price_amount' => $service['price_amount'] ?? null,
        'pricing_unit' => $service['pricing_unit'] ?? 'negotiable',
        'urgent' => (bool) ($service['urgent'] ?? false),
    ], is_array($listing['services'] ?? null) ? $listing['services'] : []),
], $mapListingSource);
?>
<section class="hero-shell">
  <div class="hero-copy">
    <span class="eyebrow">Konumuna göre keşfet</span>
    <h1>Yakınındaki hizmeti bul,<br><em>işini kolayca hallet.</em></h1>
    <p>Ustadan özel derse, temizlikten yol yardımına kadar ihtiyacını ücretsiz yayınla veya yakınındaki hizmet verenleri keşfet.</p>
  </div>
  <div class="hero-stat-card" aria-label="Platform özellikleri">
    <div><strong>2 yönlü</strong><span>Hizmet ver veya hizmet al</span></div>
    <div><strong>Konumlu</strong><span>Yakınındaki sonuçları gör</span></div>
    <div><strong>Ücretsiz</strong><span>İlanını kolayca yayınla</span></div>
  </div>
</section>

<section class="search-panel" aria-label="Hizmet arama">
  <div class="mode-tabs" role="tablist">
    <a class="<?= $selectedType === 'service_offer' ? 'active' : '' ?>" href="/?type=service_offer#kesfet-haritasi">Hizmet bul</a>
    <a class="<?= $selectedType === 'service_request' ? 'active' : '' ?>" href="/?type=service_request#kesfet-haritasi">İş bul</a>
  </div>
  <form class="search-form" method="get" action="/#kesfet-haritasi">
    <input type="hidden" name="type" value="<?= View::escape($selectedType) ?>">
    <input type="hidden" name="lat" value="<?= View::escape((string) ($query['lat'] ?? '')) ?>">
    <input type="hidden" name="lng" value="<?= View::escape((string) ($query['lng'] ?? '')) ?>">
    <div class="search-field-wrap" data-search-suggest>
      <label class="search-field"><span aria-hidden="true">⌕</span><input name="q" value="<?= View::escape($term) ?>" placeholder="Elektrikçi, temizlik, kurye ara" autocomplete="off" aria-autocomplete="list" aria-expanded="false" aria-controls="home-search-suggestions"></label>
      <div class="search-suggestions" id="home-search-suggestions" role="listbox" aria-label="Arama önerileri" hidden></div>
    </div>
    <div class="category-select" data-category-select>
      <input type="hidden" name="category" value="<?= View::escape($selectedCategory) ?>">
      <button class="category-field" type="button" aria-haspopup="listbox" aria-expanded="false">
        <span class="category-field-icon" aria-hidden="true">▦</span>
        <span class="category-field-label" data-category-label><?= View::escape($selectedCategoryLabel) ?></span>
        <span class="category-field-chevron" aria-hidden="true"></span>
      </button>
      <div class="category-menu" role="listbox" aria-label="Kategori seç" hidden>
        <button type="button" class="category-menu-all <?= $selectedCategory === '' ? 'selected' : '' ?>" role="option" aria-selected="<?= $selectedCategory === '' ? 'true' : 'false' ?>" data-category-option data-value="" data-label="Tüm kategoriler"><span>⌕</span><strong>Tüm kategoriler</strong><small>Bütün hizmet ve iş ilanları</small></button>
        <?php foreach ($groups as $groupIndex => $group): ?>
          <?php $menuChildren = array_values(array_filter($children, static fn (array $child): bool => $child['parent_id'] === $group['id'])); ?>
          <?php if ($menuChildren === []) continue; ?>
          <section class="category-menu-group">
            <h3><span><?= str_pad((string)($groupIndex + 1), 2, '0', STR_PAD_LEFT) ?></span><?= View::escape($group['label']) ?></h3>
            <div>
              <?php foreach ($menuChildren as $category): ?>
                <button type="button" class="<?= $selectedCategory === $category['id'] ? 'selected' : '' ?>" role="option" aria-selected="<?= $selectedCategory === $category['id'] ? 'true' : 'false' ?>" data-category-option data-value="<?= View::escape($category['id']) ?>" data-label="<?= View::escape($category['label']) ?>"><?= View::escape($category['label']) ?></button>
              <?php endforeach; ?>
            </div>
          </section>
        <?php endforeach; ?>
      </div>
    </div>
    <button class="search-button" type="submit">Ara</button>
    <button class="location-button" type="button" data-nearby>⌖ Yakınımda ara</button>
    <button class="filter-toggle-button" type="button" data-filter-toggle aria-expanded="<?= $advancedOpen ? 'true' : 'false' ?>"><span>⚙</span> Filtreler <b data-filter-count></b></button>
    <div class="active-filter-summary" data-active-filter-summary <?= $initialFilterLabels === [] ? 'hidden' : '' ?>>
      <span class="active-filter-summary-title">Aktif filtreler</span>
      <div data-active-filter-chips><?php foreach ($initialFilterLabels as $label): ?><span><?= View::escape($label) ?></span><?php endforeach; ?></div>
      <button type="button" data-clear-active-filters>Temizle</button>
    </div>
    <div class="advanced-filter-panel" data-advanced-filters <?= $advancedOpen ? '' : 'hidden' ?>>
      <div class="advanced-filter-head"><div><span class="eyebrow">Detaylı arama</span><h3>Sonuçları sana göre daralt</h3><p>Birden fazla kategori seçersen eşleşen kategorilerin tamamı gösterilir.</p></div><button type="button" class="filter-close-button" data-filter-close aria-label="Filtreleri kapat">×</button></div>
      <div class="advanced-filter-grid">
        <section class="filter-block filter-categories"><div class="filter-block-title"><strong>Kategoriler</strong><small>Bir veya daha fazla seçebilirsin</small></div><div class="multi-category-list">
          <?php foreach ($groups as $group): ?>
            <?php $filterChildren = array_values(array_filter($children, static fn (array $child): bool => $child['parent_id'] === $group['id'])); ?>
            <?php if ($filterChildren === []) continue; ?>
            <?php $groupHasSelection = count(array_intersect($selectedCategories, array_map(static fn (array $item): string => (string) $item['id'], $filterChildren))) > 0; ?>
            <details <?= $groupHasSelection ? 'open' : '' ?>><summary><?= View::escape($group['label']) ?><span><?= count($filterChildren) ?> alan</span></summary><div>
              <?php foreach ($filterChildren as $category): ?><label><input type="checkbox" name="categories[]" value="<?= View::escape($category['id']) ?>" data-filter-label="<?= View::escape($category['label']) ?>" <?= in_array((string) $category['id'], $selectedCategories, true) ? 'checked' : '' ?>><span><?= View::escape($category['label']) ?></span></label><?php endforeach; ?>
            </div></details>
          <?php endforeach; ?>
        </div></section>
        <section class="filter-block filter-distance"><div class="filter-block-title"><strong>Mesafe</strong><small>Konumundan itibaren</small></div><div class="filter-range-value"><strong data-radius-filter-value><?= $hasRadiusFilter ? ($selectedRadius / 1000) . ' km' : 'Mesafe sınırı yok' ?></strong><span>çapında</span></div><input type="range" name="radius_meters" min="1000" max="100000" step="1000" value="<?= $selectedRadius ?>" data-radius-filter <?= $hasRadiusFilter ? '' : 'disabled' ?>><div class="filter-range-scale"><span>1 km</span><span>100 km</span></div><label class="filter-unlimited"><input type="checkbox" data-radius-unlimited <?= $hasRadiusFilter ? '' : 'checked' ?>><span>Mesafe sınırı yok</span></label><p class="filter-location-note">Konum izni verdiğinde mesafe filtresi etkinleşir.</p></section>
        <section class="filter-block"><div class="filter-block-title"><strong>Müsaitlik</strong><small>Çalışma durumu</small></div><div class="filter-switch-list"><label><input type="checkbox" name="available_now" value="1" <?= $filterChecked('available_now') ? 'checked' : '' ?>><span><strong>Şu an müsait</strong><small>Hemen hizmet verebilenler</small></span></label><label><input type="checkbox" name="open_24_7" value="1" <?= $filterChecked('open_24_7') ? 'checked' : '' ?>><span><strong>7/24 açık</strong><small>Günün her saati ulaşılabilenler</small></span></label><label><input type="checkbox" name="verified_only" value="1" <?= $filterChecked('verified_only') ? 'checked' : '' ?>><span><strong>Doğrulanmış kullanıcı</strong><small>E-posta ve telefonu doğrulanmış</small></span></label></div></section>
        <section class="filter-block filter-provider"><div class="filter-block-title"><strong>Hizmet veren</strong><small>Birini veya ikisini seçebilirsin</small></div><input type="hidden" name="provider_kind" value="<?= View::escape($selectedProviderKind) ?>"><fieldset class="filter-chip-group"><legend>Profil türü</legend><div><label><input type="checkbox" value="person" data-provider-kind-choice <?= $selectedProviderKind === 'person' ? 'checked' : '' ?>><span>Şahıs</span></label><label><input type="checkbox" value="business" data-provider-kind-choice <?= $selectedProviderKind === 'business' ? 'checked' : '' ?>><span>Kurumsal</span></label></div></fieldset><fieldset class="filter-chip-group"><legend>Cinsiyet</legend><div><label><input type="checkbox" value="female" data-gender-choice <?= $selectedGender === 'female' ? 'checked' : '' ?>><span>Kadın</span></label><label><input type="checkbox" value="male" data-gender-choice <?= $selectedGender === 'male' ? 'checked' : '' ?>><span>Erkek</span></label></div></fieldset><input type="hidden" name="gender" value="<?= View::escape($selectedGender) ?>"></section>
      </div>
      <div class="saved-search-area"><div><strong>Kayıtlı aramalarım</strong><small>Aynı filtreleri tekrar girmek zorunda kalma.</small></div><div class="saved-search-list" data-saved-search-list><span>Giriş yaptığında kayıtlı aramaların burada görünür.</span></div></div>
      <div class="advanced-filter-actions"><a class="secondary-button" href="/?type=<?= View::escape($selectedType) ?>#kesfet-haritasi">Filtreleri temizle</a><button class="secondary-button" type="button" data-save-search>Filtreyi favorilere kaydet</button><button class="primary-button" type="submit">Filtreleri uygula</button></div>
    </div>
  </form>
</section>

<section class="home-map-section" id="kesfet-haritasi" aria-labelledby="home-map-title">
  <div class="location-onboarding" data-location-onboarding hidden>
    <div><strong>Yakınındaki ilanları bulalım</strong><span>Konumun yalnızca yakın sonuçları göstermek için kullanılır; tam konumun diğer kullanıcılara açıklanmaz.</span></div>
    <div><button class="primary-button" type="button" data-location-allow>Konumumu kullan</button><button class="secondary-button" type="button" data-location-manual>Haritadan seçeceğim</button></div>
  </div>
  <div class="home-map-heading">
    <div><span class="eyebrow">Canlı keşif haritası</span><h2 id="home-map-title">İlanları doğrudan haritada gör</h2><p>Haritayı taşıdığında yalnız ekranda kalan alan yeniden yüklenir.</p></div>
    <button type="button" class="map-reset-button" data-map-recenter>⌖ Konumuma dön</button>
  </div>
  <div class="home-map-frame" data-map-view>
    <div class="listing-map" data-listing-map aria-label="Görünen alandaki ilanlar"></div>
    <div class="map-result-status" data-map-status aria-live="polite">İlanlar hazırlanıyor…</div>
  </div>
  <script nonce="<?= View::escape(RequestContext::cspNonce()) ?>" type="application/json" data-map-listings><?= json_encode($mapListings, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT) ?></script>
</section>

<?php if (($banners ?? []) !== []): ?><section class="content-section banner-strip"><?php foreach ($banners as $banner): ?><a href="<?= View::escape($banner['target_url'] ?: '/') ?>"><strong><?= View::escape($banner['title']) ?></strong><span><?= View::escape($banner['body']) ?></span></a><?php endforeach; ?></section><?php endif; ?>

<?php if ($groups !== []): ?>
<section class="content-section category-section">
  <div class="section-heading"><div><span class="eyebrow">Kategoriler</span><h2>Ne için desteğe ihtiyacın var?</h2></div></div>
  <div class="category-grid">
    <?php foreach ($groups as $index => $group): ?>
      <?php $groupChildren = array_values(array_filter($children, static fn (array $child): bool => $child['parent_id'] === $group['id'])); ?>
      <a class="category-card color-<?= ($index % 3) + 1 ?>" href="/hizmet/<?= View::escape($group['seo_slug'] ?? '') ?>">
        <span class="category-number">0<?= $index + 1 ?></span>
        <h3><?= View::escape($group['label']) ?></h3>
        <p><?= View::escape(implode(' · ', array_slice(array_column($groupChildren, 'label'), 0, 3))) ?></p>
        <span class="arrow">→</span>
      </a>
    <?php endforeach; ?>
  </div>
</section>
<?php endif; ?>

<section class="content-section listings-section">
  <div class="section-heading">
    <div><span class="eyebrow">Yakınındaki sonuçlar</span><h2><?= $selectedType === 'service_request' ? 'Yeni iş fırsatları' : 'Önerilen hizmetler' ?></h2></div>
  </div>

  <div>
    <?php if ($connectionError): ?>
      <div class="setup-notice"><strong>Lokal web hazır.</strong><span><?= View::escape($connectionError) ?></span></div>
    <?php elseif ($listings === []): ?>
      <div class="empty-state"><span>⌕</span><h3>Bu aramada henüz ilan yok.</h3><p>İlk ilanı ücretsiz olarak sen oluşturabilirsin.</p><a class="primary-button" href="/ilan-ver">Ücretsiz ilan ver</a></div>
    <?php else: ?>
      <div class="listing-grid">
      <?php foreach ($listings as $listing): ?>
        <article class="listing-card">
          <a class="listing-cover" href="/ilan/<?= View::escape($listing['slug']) ?>">
            <?php if (!empty($listing['cover_image'])): ?><img src="<?= View::escape($listing['cover_image']) ?>" alt="<?= View::escape($listing['title']) ?>" loading="lazy" width="640" height="380"><?php else: ?><span><?= View::escape(mb_substr($listing['title'], 0, 1)) ?></span><?php endif; ?>
            <?php if (!empty($listing['urgent'])): ?><small>Şu an müsait</small><?php endif; ?>
          </a>
          <div class="listing-body">
            <div class="listing-meta"><span><?= View::escape($listing['public_district']) ?></span><span><?= $listing['distance_meters'] !== null ? number_format($listing['distance_meters'] / 1000, 1, ',', '.') . ' km' : View::escape($listing['public_neighborhood']) ?></span></div>
            <h3><a href="/ilan/<?= View::escape($listing['slug']) ?>"><?= View::escape($listing['title']) ?></a></h3>
            <p><?= View::escape(mb_substr($listing['description'], 0, 110)) ?></p>
            <div class="listing-footer"><span><?= View::escape($listing['owner_name']) ?> · ★ <?= number_format((float) $listing['owner_rating'], 1, ',') ?></span><strong><?= View::escape(View::priceLabel($listing['price_amount'], $listing['pricing_unit'])) ?></strong></div>
          </div>
        </article>
      <?php endforeach; ?>
      </div>
    <?php endif; ?>
    </div>
</section>

<section class="action-band">
  <div><span class="eyebrow">İki taraf için tek platform</span><h2>Hizmet mi arıyorsun, iş mi arıyorsun?</h2></div>
  <div><a class="light-button" href="/ilan-ver?type=service_request">Ücretsiz hizmet al</a><a class="outline-light-button" href="/ilan-ver?type=service_offer">Ücretsiz hizmet ver</a></div>
</section>
