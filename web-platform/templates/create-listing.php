<?php

use App\Core\View;

$children = array_values(array_filter($categories, static fn (array $category): bool => $category['parent_id'] !== null));
$groups = array_values(array_filter($categories, static fn (array $category): bool => $category['parent_id'] === null));
?>
<section class="simple-shell create-shell">
  <span class="eyebrow"><?= !empty($editingId) ? 'İlan yönetimi' : 'Ücretsiz yayınla' ?></span>
  <h1><?= !empty($editingId) ? 'İlanını düzenle.' : 'İlanını webden oluştur.' ?></h1>
  <p><?= !empty($editingId) ? 'Yaptığın değişiklikler web ve mobil uygulamada birlikte güncellenir.' : 'Buradan yayınladığın ilan aynı anda mobil uygulamada da görünür.' ?></p>

  <form class="platform-form" data-listing-form data-editing-id="<?= View::escape((string) ($editingId ?? '')) ?>">
    <fieldset class="type-choice">
      <legend>Ne yapmak istiyorsun?</legend>
      <label><input type="radio" name="listing_type" value="service_offer" <?= $selectedType !== 'service_request' ? 'checked' : '' ?>><span><strong>Hizmet ver</strong><small>Yakınındaki müşteriler seni bulsun.</small></span></label>
      <label><input type="radio" name="listing_type" value="service_request" <?= $selectedType === 'service_request' ? 'checked' : '' ?>><span><strong>Hizmet al</strong><small>İhtiyacını yayınla, uygun kişiler ulaşsın.</small></span></label>
    </fieldset>

    <div class="form-grid">
      <label class="wide">Ana ilan başlığı<input name="headline" minlength="3" maxlength="140" required placeholder="Örn. Bilgisayar ve yazılım hizmetleri"></label>
      <label class="wide">Ana ilan özeti <small>(isteğe bağlı)</small><textarea name="summary" maxlength="1000" placeholder="Sunduğun hizmetleri kısaca tanıt"></textarea></label>
      <fieldset class="wide category-picker" data-category-picker>
        <legend>Kategori</legend>
        <p>Önce grubu aç, sonra ilanına en uygun kategoriyi seç.</p>
        <div class="category-picker-groups">
          <?php foreach ($groups as $groupIndex => $group): ?>
            <?php $groupChildren = array_values(array_filter($children, static fn (array $child): bool => $child['parent_id'] === $group['id'])); ?>
            <details class="category-picker-group" <?= $groupIndex === 0 ? 'open' : '' ?>>
              <summary>
                <span class="category-picker-icon" aria-hidden="true"><?= str_pad((string) ($groupIndex + 1), 2, '0', STR_PAD_LEFT) ?></span>
                <span><strong><?= View::escape($group['label']) ?></strong><small><?= count($groupChildren) ?> seçenek</small></span>
                <span class="category-picker-chevron" aria-hidden="true">⌄</span>
              </summary>
              <div class="category-picker-options">
                <?php foreach ($groupChildren as $category): ?>
                  <label class="category-option">
                    <input type="radio" name="category_id" value="<?= View::escape($category['id']) ?>">
                    <span><?= View::escape($category['label']) ?></span>
                  </label>
                <?php endforeach; ?>
              </div>
            </details>
          <?php endforeach; ?>
        </div>
      </fieldset>
      <label class="wide">İlk hizmetin adı<input name="title" minlength="3" maxlength="120" required placeholder="Örn. Bilgisayar formatlama"></label>
      <label class="wide">İlk hizmetin açıklaması<textarea name="description" minlength="10" maxlength="2000" required placeholder="Bu hizmetin kapsamını ayrıntılı anlat"></textarea></label>
      <fieldset class="wide listing-upload-card" data-listing-upload>
        <legend>İlan görselleri <small>(isteğe bağlı · en fazla 8)</small></legend>
        <label class="listing-upload-drop">
          <input name="images" type="file" accept="image/jpeg,image/png,image/webp" multiple>
          <span class="listing-upload-icon" aria-hidden="true">＋</span>
          <span><strong>Fotoğraf ekle</strong><small>JPEG, PNG veya WebP · Dosyaları buraya bırakabilir ya da bilgisayarından seçebilirsin.</small></span>
          <b>Görselleri seç</b>
        </label>
        <div class="listing-upload-preview" data-listing-upload-preview><span>Henüz görsel seçilmedi.</span></div>
      </fieldset>
      <fieldset class="wide location-picker" data-location-picker>
        <legend>Konum</legend>
        <p>Sabit iğnenin altına ilanının konumunu getir. Haritayı bıraktıktan sonra adres otomatik bulunur.</p>
        <button class="secondary-button location-current-button" type="button" data-use-current-location>⌖ Bulunduğum konumu işaretle</button>
        <div class="location-map-wrap">
          <div class="location-map" data-location-map aria-label="İlan konumunu seç"></div>
          <div class="location-center-pin" aria-hidden="true">
            <svg viewBox="0 0 24 24"><path d="M12 22s7-6.1 7-13A7 7 0 1 0 5 9c0 6.9 7 13 7 13Z"/><circle cx="12" cy="9" r="2.6"/></svg>
          </div>
          <div class="location-map-loading" data-location-map-loading>Harita hazırlanıyor…</div>
        </div>
        <input name="latitude" type="hidden" value="39.0000">
        <input name="longitude" type="hidden" value="35.0000">
        <input name="location_confirmed" type="hidden" value="0">
        <div class="location-result" data-location-result aria-live="polite">
          <span class="location-result-icon" aria-hidden="true">⌖</span>
          <span><strong data-location-title>Haritayı hareket ettir</strong><small data-location-status>Seçtiğin adres burada görünecek.</small></span>
          <button type="button" data-confirm-location disabled>Bu konumu doğrula</button>
        </div>
        <div class="location-address-fields location-public-fields" data-public-location-fields hidden>
          <label>Şehir<input name="city" value="" autocomplete="address-level1" placeholder="Örn. Ankara"></label>
          <label>İlçe<input name="district" value="Çankaya" autocomplete="address-level2"></label>
          <label>Mahalle<input name="neighborhood" value="Kızılay" autocomplete="address-level3"></label>
        </div>
        <div class="location-precision" role="group" aria-label="Konum görünürlüğü">
          <label><input type="radio" name="location_precision" value="exact"><span>İşletme adresi</span></label>
          <label><input type="radio" name="location_precision" value="neighborhood" checked><span>Yakın konum</span></label>
        </div>
        <div class="exact-address-panel" data-exact-address hidden>
          <div class="exact-address-head"><div><strong>Net adres bilgileri</strong><small>Bu bilgiler güvenli biçimde saklanır; ilan detayında tam adresin yayınlanmaz.</small></div><button class="secondary-button" type="button" data-geocode-address>Adresi haritada bul</button></div>
          <div class="exact-address-grid">
            <label>İl<input name="address_city" autocomplete="address-level1" placeholder="Örn. Ankara"></label>
            <label>İlçe<input name="address_district" autocomplete="address-level2" placeholder="Örn. Gölbaşı"></label>
            <label>Mahalle<input name="address_neighborhood" autocomplete="address-level3" placeholder="Örn. Eymir"></label>
            <label>Sokak / cadde<input name="street" autocomplete="street-address" placeholder="Örn. Göl Caddesi"></label>
            <label>Bina no<input name="building_number" placeholder="Örn. 18"></label>
            <label>Daire no <small>(isteğe bağlı)</small><input name="apartment_number" placeholder="Örn. 5"></label>
          </div>
          <label class="address-match-check"><input type="checkbox" name="address_matches_map" value="1"><span><strong>Haritadaki iğne ile yazdığım adres aynıdır</strong><small>Net adresli ilanı yayınlamadan önce eşleşmeyi kontrol et.</small></span></label>
        </div>
      </fieldset>
      <label>Fiyatlandırma<select name="pricing_unit"><option value="negotiable">Teklif üzerine</option><option value="fixed">Sabit fiyat</option><option value="hourly">Saatlik</option><option value="daily">Günlük</option><option value="per_session">Seans başına</option><option value="starting_at">Başlangıç fiyatı</option><option value="free">Ücretsiz</option></select></label>
      <label>Fiyat (TL)<input name="price_amount" type="number" min="0" step="0.01" placeholder="750"></label>
      <label>Para birimi<select name="currency"><option value="TRY">TRY · Türk lirası</option><option value="EUR">EUR · Euro</option><option value="USD">USD · ABD doları</option></select></label>
      <label>Tahmini süre <small>(dakika, isteğe bağlı)</small><input name="estimated_duration_minutes" type="number" min="5" max="525600" step="5" placeholder="60"></label>
      <fieldset class="wide service-items-editor" data-service-items-editor>
        <legend>Diğer hizmet kalemleri <small>(isteğe bağlı · en fazla 20)</small></legend>
        <p>Aynı konumdaki hizmetlerini tek ana ilanda topla. Her hizmet aramada ayrı eşleşir.</p>
        <div class="service-items-list" data-service-items-list></div>
        <button class="secondary-button" type="button" data-add-service-item>＋ Hizmet kalemi ekle</button>
      </fieldset>
      <fieldset class="wide service-radius-card" data-service-radius-card>
        <legend>Hizmet mesafesi <small>(isteğe bağlı)</small></legend>
        <div class="service-radius-head"><p>Müşterilerin seni görebileceği veya bu ilan için ulaşılabilecek azami alan.</p><strong data-service-radius-value>25 km</strong></div>
        <input name="service_radius_km" type="range" min="1" max="100" value="25" data-service-radius>
        <div class="service-radius-scale"><span>1 km</span><span>25 km</span><span>50 km</span><span>100 km</span></div>
        <label class="radius-unlimited-card"><input type="checkbox" name="service_radius_unlimited" value="1"><span><strong>Mesafe sınırı yok</strong><small>Online hizmet veriyorum veya farklı bölgelere gidebilirim.</small></span></label>
      </fieldset>
      <fieldset class="wide availability-card" data-offer-availability>
        <legend>Müsaitlik ve çalışma saatleri</legend>
        <label data-schedule-field>Çalışma saatlerin<input name="schedule_label" maxlength="200" placeholder="Örn. Hafta içi 09.00–18.00"></label>
        <div class="availability-options"><label class="check-field"><input name="urgent" type="checkbox"><span>Şu an müsaitim</span></label><label class="check-field"><input name="open_24_7" type="checkbox"><span>7 gün 24 saat hizmet veriyorum</span></label></div>
      </fieldset>
      <fieldset class="wide request-preferences-card" data-request-preferences hidden>
        <legend>Hizmet veren tercihin <small>(isteğe bağlı)</small></legend>
        <p>Seçim yapmazsan sana uygun tüm hizmet verenler ilanını görebilir.</p>
        <div class="request-preference-grid">
          <fieldset><legend>Profil türü</legend><label><input type="radio" name="preferred_provider_kind" value="" checked><span>Fark etmez</span></label><label><input type="radio" name="preferred_provider_kind" value="person"><span>Şahıs</span></label><label><input type="radio" name="preferred_provider_kind" value="business"><span>Kurumsal</span></label></fieldset>
          <fieldset><legend>Cinsiyet</legend><label><input type="radio" name="preferred_provider_gender" value="" checked><span>Fark etmez</span></label><label><input type="radio" name="preferred_provider_gender" value="female"><span>Kadın</span></label><label><input type="radio" name="preferred_provider_gender" value="male"><span>Erkek</span></label></fieldset>
        </div>
      </fieldset>
      <label class="check-field wide" data-request-urgent hidden><input name="request_urgent" type="checkbox"><span>Acil ihtiyacım var</span></label>
    </div>
    <div class="form-message" data-form-message role="status"></div>
    <button class="primary-button" type="submit"><?= !empty($editingId) ? 'Değişiklikleri kaydet' : 'İlanı ücretsiz yayınla' ?></button>
  </form>
</section>

<template data-service-item-template>
  <article class="service-item-editor" data-service-item>
    <header><strong>Hizmet kalemi</strong><div><button type="button" data-move-service-up aria-label="Yukarı taşı">↑</button><button type="button" data-move-service-down aria-label="Aşağı taşı">↓</button><button type="button" data-remove-service-item>Sil</button></div></header>
    <div class="service-item-grid">
      <label>Kategori<select data-item-field="category_id" required><option value="">Kategori seç</option><?php foreach ($children as $category): ?><option value="<?= View::escape($category['id']) ?>"><?= View::escape($category['label']) ?></option><?php endforeach; ?></select></label>
      <label>Hizmet adı<input data-item-field="title" minlength="3" maxlength="120" required></label>
      <label class="wide">Kısa açıklama<textarea data-item-field="description" minlength="10" maxlength="2000" required></textarea></label>
      <label>Fiyatlandırma<select data-item-field="pricing_unit"><option value="negotiable">Teklif üzerine</option><option value="fixed">Sabit fiyat</option><option value="hourly">Saatlik</option><option value="daily">Günlük</option><option value="per_session">Seans başına</option><option value="starting_at">Başlangıç fiyatı</option><option value="free">Ücretsiz</option></select></label>
      <label>Fiyat<input data-item-field="price_amount" type="number" min="0" step="0.01"></label>
      <label>Para birimi<select data-item-field="currency"><option value="TRY">TRY</option><option value="EUR">EUR</option><option value="USD">USD</option></select></label>
      <label>Tahmini süre (dk)<input data-item-field="estimated_duration_minutes" type="number" min="5" max="525600" step="5"></label>
      <label class="check-field wide"><input data-item-field="is_active" type="checkbox" checked><span>Bu hizmet aktif</span></label>
    </div>
  </article>
</template>
