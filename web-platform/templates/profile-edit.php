<?php

use App\Core\View;

$parentCategories = array_values(array_filter(
    $categories ?? [],
    static fn (array $category): bool => $category['parent_id'] === null,
));
?>
<section class="simple-shell profile-shell" data-profile-editor>
  <div class="profile-heading">
    <div><span class="eyebrow">Profil yönetimi</span><h1>Profili düzenle</h1><p>Herkese gösterilecek profil bilgilerini ve ilgi alanlarını burada yönet.</p></div>
    <a class="secondary-button" href="/profil">Profilimi görüntüle</a>
  </div>

  <form class="platform-form" data-profile-form>
    <section class="form-section-card">
      <div class="avatar-upload-row">
        <span class="avatar-preview" data-avatar-preview>H</span>
        <div class="avatar-upload-controls">
          <strong>Profil fotoğrafı</strong>
          <small>JPEG, PNG veya WebP · En fazla 8 MB. Fotoğraf isteğe bağlıdır ve istediğin zaman değiştirilebilir.</small>
          <div>
            <label class="secondary-button">Galeriden seç<input name="avatar_gallery" type="file" accept="image/jpeg,image/png,image/webp"></label>
            <label class="secondary-button">Kamerayı aç<input name="avatar_camera" type="file" accept="image/*" capture="user"></label>
            <button type="button" class="danger-outline-button" data-remove-avatar disabled>Fotoğrafı kaldır</button>
          </div>
          <span class="avatar-upload-status" data-avatar-upload-status aria-live="polite"></span>
        </div>
      </div>

      <div class="form-grid">
        <label>Görünen ad<input name="display_name" required minlength="2" maxlength="80" autocomplete="name"></label>
        <label>Profil türü<select name="profile_type" data-profile-type required><option value="person">Şahıs profili</option><option value="business">İşletme profili</option></select></label>
        <label>İl<select name="city" data-city-select required><option value="">İl seç</option></select></label>
        <label>İlçe<select name="district" data-district-select required disabled><option value="">Önce il seç</option></select></label>
        <label>Cinsiyet <small>(isteğe bağlı)</small><select name="gender"><option value="">Belirtmek istemiyorum</option><option value="female">Kadın</option><option value="male">Erkek</option><option value="other">Diğer</option><option value="prefer_not_to_say">Belirtmek istemiyorum</option></select></label>
        <label>Telefon<input name="phone_e164" type="tel" inputmode="tel" autocomplete="tel" placeholder="+905xxxxxxxxx"><small>Numaran varsayılan olarak gizlidir.</small></label>
        <label class="check-field wide"><input name="phone_visible" type="checkbox" value="true"> Telefonumu giriş yapmış kullanıcılara göster</label>
        <label class="wide">Hakkında<textarea name="bio" maxlength="500" placeholder="Deneyimini ve çalışma biçimini anlatabilirsin."></textarea></label>
      </div>
    </section>

    <section class="form-section-card business-fields" data-business-fields hidden>
      <div class="section-copy"><span class="eyebrow">İşletme profili</span><h2>İşletme bilgileri</h2><p>Bu bilgiler profilinde işletme rozetiyle birlikte gösterilir.</p></div>
      <div class="form-grid">
        <label>İşletme adı<input name="business_name" minlength="2" maxlength="120" autocomplete="organization"></label>
        <label>Açık adres<input name="business_address" minlength="5" maxlength="300" autocomplete="street-address"></label>
        <label class="wide">Verdiğin hizmetler<textarea name="business_services" maxlength="1000" placeholder="İşletmenin uzmanlık alanlarını ve sunduğu hizmetleri yaz."></textarea></label>
      </div>
    </section>

    <section class="form-section-card">
      <div class="section-copy"><span class="eyebrow">Kişiselleştirme</span><h2>İlgilendiğin hizmetler</h2><p>Ana kategorileri seçebilirsin. Seçimler isteğe bağlıdır ve yeni ilan bildirimlerinin sana uygun olmasını sağlar.</p></div>
      <div class="preference-columns">
        <fieldset><legend>Hizmet almak istediklerim</legend><div class="preference-chip-grid">
          <?php foreach ($parentCategories as $category): ?><label class="preference-chip"><input type="checkbox" name="receive_category_ids" value="<?= View::escape($category['id']) ?>"><span><?= View::escape($category['label']) ?></span></label><?php endforeach; ?>
        </div></fieldset>
        <fieldset><legend>Hizmet vermek istediklerim</legend><div class="preference-chip-grid">
          <?php foreach ($parentCategories as $category): ?><label class="preference-chip"><input type="checkbox" name="provide_category_ids" value="<?= View::escape($category['id']) ?>"><span><?= View::escape($category['label']) ?></span></label><?php endforeach; ?>
        </div></fieldset>
      </div>
    </section>

    <div class="form-message" data-form-message role="status"></div>
    <div class="sticky-form-actions"><a class="secondary-button" href="/profil">Vazgeç</a><button class="primary-button" type="submit">Değişiklikleri kaydet</button></div>
  </form>
</section>
