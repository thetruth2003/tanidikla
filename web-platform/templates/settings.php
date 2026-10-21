<section class="simple-shell settings-shell" data-settings-page>
  <div class="profile-heading"><div><span class="eyebrow">Hesap merkezi</span><h1>Ayarlar</h1><p>Güvenlik, bildirim, açık oturum ve gizlilik seçeneklerini buradan yönet.</p></div><a class="secondary-button" href="/profil">Profilime dön</a></div>

  <nav class="settings-shortcuts" aria-label="Ayar bölümleri"><a href="#dogrulama">Doğrulama</a><a href="#sifre">Şifre</a><a href="#oturumlar">Oturumlar</a><a href="#beta-geribildirim">Beta geri bildirimi</a><a href="#engellenenler">Engellediklerim</a><a href="#gizlilik">Gizlilik</a></nav>

  <section class="account-security" data-account-security>
    <div class="security-grid">
      <form class="security-card" id="dogrulama" data-email-change-form>
        <span class="security-icon">✉</span><h3>E-posta adresi</h3><p data-email-status>Durum yükleniyor…</p>
        <button class="secondary-button full-button" type="button" data-resend-verification hidden>Doğrulama e-postasını yeniden gönder</button>
        <label>Yeni e-posta<input type="email" name="new_email" autocomplete="email" required></label>
        <label>Mevcut şifre<span class="password-input"><input type="password" name="current_password" autocomplete="current-password" required><button type="button" data-toggle-password>Göster</button></span></label>
        <button class="primary-button full-button" type="submit">Doğrulama bağlantısı gönder</button><div class="form-message" data-form-message></div>
      </form>
      <form class="security-card" data-phone-verification-form>
        <span class="security-icon">☎</span><h3>Telefon doğrulama</h3><p data-phone-status>Durum yükleniyor…</p>
        <label>Telefon<input type="tel" name="phone" autocomplete="tel" placeholder="+905xxxxxxxxx" required></label>
        <button class="primary-button full-button" type="button" data-request-phone-code>SMS kodu gönder</button>
        <div data-phone-code-area hidden><label>6 haneli kod<input type="text" name="code" inputmode="numeric" pattern="[0-9]{6}" maxlength="6"></label><button class="primary-button full-button" type="submit">Telefonu doğrula</button></div>
        <div class="form-message" data-form-message></div>
      </form>
      <form class="security-card" id="sifre" data-password-change-form>
        <span class="security-icon">⌁</span><h3>Şifre değiştir</h3><p>Değişiklikten sonra diğer cihazlardaki oturumlar kapatılır.</p>
        <label>Mevcut şifre<span class="password-input"><input type="password" name="current_password" autocomplete="current-password" required><button type="button" data-toggle-password>Göster</button></span></label>
        <label>Yeni şifre<span class="password-input"><input type="password" name="password" minlength="10" autocomplete="new-password" required><button type="button" data-toggle-password>Göster</button></span></label>
        <label>Yeni şifre tekrar<span class="password-input"><input type="password" name="password_confirmation" minlength="10" autocomplete="new-password" required><button type="button" data-toggle-password>Göster</button></span></label>
        <small>En az 10 karakter; harf, rakam ve özel karakter.</small>
        <button class="primary-button full-button" type="submit">Şifreyi güncelle</button><div class="form-message" data-form-message></div>
      </form>
      <div class="security-card" id="oturumlar">
        <span class="security-icon">▣</span><h3>Açık oturumlar</h3><p>Hesabının açık olduğu tarayıcı ve mobil cihazları kontrol et.</p><div class="session-list" data-session-list>Yükleniyor…</div>
        <button class="secondary-button full-button" type="button" data-revoke-other-sessions>Diğer cihazlardan çıkış yap</button>
      </div>
    </div>
  </section>

  <section class="settings-section" data-notification-preferences><div><span class="eyebrow">Bildirimler</span><h2>İletişim tercihleri</h2><p>Yeni mesajlar için e-posta almak isteyip istemediğini seç.</p></div><label class="settings-toggle"><input name="message_email_notifications" type="checkbox"><span><strong>Mesaj e-posta bildirimi</strong><small>Yeni mesaj geldiğinde kayıtlı e-posta adresime bildir.</small></span></label><button class="primary-button" type="button" data-save-preferences>Tercihleri kaydet</button></section>

  <form class="settings-section beta-feedback-section" id="beta-geribildirim" data-beta-feedback-form>
    <div class="beta-feedback-intro"><span class="eyebrow">Kapalı beta</span><h2>Deneyimini bize ilet</h2><p>Hata, kullanım zorluğu veya önerini teknik ayrıntıları paylaşmadan güvenli biçimde gönder.</p><span class="beta-feedback-note">Gönderdiğin kayıt yalnızca ürün ekibi tarafından incelenir.</span></div>
    <div class="beta-feedback-fields">
      <label class="settings-field"><span>Geri bildirim türü</span><select name="kind" required><option value="bug">Hata</option><option value="usability">Kullanım zorluğu</option><option value="suggestion">Öneri</option><option value="other">Diğer</option></select></label>
      <label class="settings-field"><span>Kısa başlık</span><input name="title" minlength="3" maxlength="160" required placeholder="Örn. İlan düzenleme ekranı"></label>
      <label class="settings-field"><span>Ayrıntı</span><textarea name="details" minlength="10" maxlength="4000" rows="5" required placeholder="Ne yaptığını, ne beklediğini ve ne olduğunu yaz."></textarea></label>
      <div class="beta-feedback-actions"><div class="form-message" data-form-message aria-live="polite"></div><button class="primary-button" type="submit">Geri bildirimi gönder</button></div>
    </div>
  </form>

  <section class="settings-section blocked-users-section" id="engellenenler">
    <div><span class="eyebrow">Gizlilik ve iletişim</span><h2>Engellediğim kullanıcılar</h2><p>Engellediğin kişiler sana mesaj gönderemez ve ilanların üzerinden seninle etkileşim kuramaz. İstediğin zaman engeli kaldırabilirsin.</p></div>
    <div class="blocked-user-list" data-blocked-users aria-live="polite"><div class="blocked-user-empty">Engellediğin kişiler yükleniyor…</div></div>
  </section>

  <section class="settings-section privacy-center" id="gizlilik">
    <div><span class="eyebrow">Hesap ve gizlilik</span><h2>KVKK hakların ve verilerin</h2><p>Aydınlatma metnini incele, verilerinin kopyasını al veya KVKK kapsamındaki talebini güvenli biçimde ilet. Talepler en kısa sürede ve en geç 30 gün içinde yanıtlanır.</p></div>
    <div class="legal-link-grid"><a class="secondary-button" href="/kvkk">KVKK aydınlatma</a><a class="secondary-button" href="/gizlilik">Gizlilik politikası</a><a class="secondary-button" href="/cerez-politikasi">Çerez politikası</a></div>
    <div class="privacy-rights-grid">
      <button class="privacy-right-card" type="button" data-copy-data><strong>Verilerime eriş</strong><span>Hesabındaki verilerin taşınabilir bir kopyasını al.</span></button>
      <button class="privacy-right-card" type="button" data-privacy-request="correction"><strong>Düzeltme talebi</strong><span>Eksik veya yanlış kişisel verilerin düzeltilmesini iste.</span></button>
      <button class="privacy-right-card" type="button" data-privacy-request="objection"><strong>İtiraz veya inceleme</strong><span>Bir veri işleme faaliyetine itirazını ve gerekçeni ilet.</span></button>
      <button class="privacy-right-card danger" type="button" data-privacy-request="deletion"><strong>Silme talebi</strong><span>Şartları oluşmuşsa hesabının ve verilerinin silinmesini iste.</span></button>
    </div>
    <div class="privacy-request-history"><h3>Başvurularım</h3><div data-privacy-request-list>Yükleniyor…</div></div>
    <button class="dark-button" type="button" data-logout>Güvenli çıkış yap</button>
  </section>
</section>
