<section class="admin-console" data-admin-page>
  <div class="admin-mobile-bar">
    <button type="button" class="admin-menu-button" data-admin-menu aria-label="Yönetim menüsünü aç">☰</button>
    <div><strong>Tanıdıkla Yönetim</strong><small>Operasyon merkezi</small></div>
    <span class="admin-live-dot" title="Sistem çevrimiçi"></span>
  </div>

  <aside class="admin-sidebar" data-admin-sidebar>
    <div class="admin-brand">
      <span class="admin-brand-symbol"><img src="/assets/brand/tanidikla-symbol.png" width="1254" height="1254" alt=""></span>
      <div><strong>Tanıdıkla</strong><small>Yönetim merkezi</small></div>
    </div>
    <div class="admin-environment"><span></span> Canlı sistem</div>
    <nav aria-label="Yönetim menüsü">
      <small>OPERASYON</small>
      <button class="active" data-admin-tab="overview"><span>01</span>Genel bakış</button>
      <button data-admin-tab="reports"><span>02</span>Şikâyet merkezi <b data-nav-count="reports"></b></button>
      <button data-admin-tab="listings"><span>03</span>İlan moderasyonu <b data-nav-count="listings"></b></button>
      <button data-admin-tab="trust"><span>04</span>İşler ve güven <b data-nav-count="trust"></b></button>
      <button data-admin-tab="users"><span>05</span>Kullanıcılar</button>
      <small>İÇERİK VE UYUM</small>
      <button data-admin-tab="categories"><span>06</span>Kategori yönetimi</button>
      <button data-admin-tab="banners"><span>07</span>Banner yönetimi</button>
      <button data-admin-tab="privacy"><span>08</span>KVKK talepleri</button>
      <button data-admin-tab="audit"><span>09</span>Denetim kayıtları</button>
    </nav>
    <div class="admin-sidebar-footer">
      <a href="/" target="_blank" rel="noopener">Siteyi görüntüle ↗</a>
      <button class="admin-logout" type="button" data-admin-logout>Güvenli çıkış</button>
    </div>
  </aside>
  <button class="admin-sidebar-backdrop" type="button" data-admin-menu-close aria-label="Menüyü kapat"></button>

  <main class="admin-main">
    <header class="admin-topbar">
      <div>
        <span class="admin-breadcrumb">Yönetim / <b data-admin-breadcrumb>Genel bakış</b></span>
        <h1 data-admin-title>Platform genel bakışı</h1>
        <p data-admin-subtitle>Platformun sağlığını ve bekleyen operasyon işlerini tek ekrandan takip et.</p>
      </div>
      <div class="admin-topbar-actions">
        <span class="admin-secure-pill">● Güvenli yönetim oturumu</span>
        <button type="button" class="admin-icon-button" data-admin-refresh title="Sayfayı yenile">↻</button>
      </div>
    </header>

    <div class="admin-toast" data-admin-toast role="status" aria-live="polite" hidden></div>

    <section class="admin-panel" data-admin-panel="overview">
      <div class="admin-stats admin-stats-primary">
        <article><span class="admin-stat-icon tone-teal">K</span><div><small>Toplam kullanıcı</small><strong data-admin-stat="users">—</strong><em>Aktif hesaplar</em></div></article>
        <article><span class="admin-stat-icon tone-blue">İ</span><div><small>Aktif ilan</small><strong data-admin-stat="active_listings">—</strong><em><b data-admin-stat="listings_waiting">—</b> işlem bekliyor</em></div></article>
        <article><span class="admin-stat-icon tone-orange">Ş</span><div><small>Açık şikâyet</small><strong data-admin-stat="open_reports">—</strong><em><b data-admin-stat="urgent_reports">—</b> yüksek öncelik</em></div></article>
        <article><span class="admin-stat-icon tone-purple">K</span><div><small>KVKK talebi</small><strong data-admin-stat="privacy_requests">—</strong><em>Yanıt bekleyen</em></div></article>
      </div>
      <div class="admin-overview-grid">
        <article class="admin-card">
          <div class="admin-card-heading"><div><small>MODERASYON DAĞILIMI</small><h2>Şikâyet kategorileri</h2></div><button type="button" data-go-tab="reports">Tümünü aç →</button></div>
          <div class="admin-breakdown" data-overview-report-breakdown></div>
        </article>
        <article class="admin-card">
          <div class="admin-card-heading"><div><small>SON İŞLEMLER</small><h2>Yönetim hareketleri</h2></div></div>
          <div class="admin-activity" data-overview-activity></div>
        </article>
      </div>
      <div class="admin-risk-note" data-admin-risk-note><strong>Operasyon özeti</strong><span data-admin-stat="overdue_reports">—</span> şikâyet 24 saati geçti. Öncelikli kuyruğu düzenli kontrol et.</div>
    </section>

    <section class="admin-panel" data-admin-panel="reports" hidden>
      <div class="admin-section-intro">
        <div><span class="eyebrow">MODERASYON KUYRUĞU</span><h2>Şikâyetleri türüne göre yönet</h2><p>Yeni şikâyet olmasa bile tüm şikâyet türlerini ve sayılarını bu ekranda görebilirsin.</p></div>
      </div>
      <div class="report-category-grid" data-report-summary></div>
      <form class="admin-filterbar" data-report-filters>
        <label class="admin-search"><span>⌕</span><input name="q" placeholder="Kişi, ilan veya açıklama ara"></label>
        <label><span>Durum</span><select name="status"><option value="">Tüm durumlar</option><option value="open">Yeni</option><option value="reviewing">İnceleniyor</option><option value="resolved">Çözüldü</option><option value="rejected">Reddedildi</option></select></label>
        <label><span>Kategori</span><select name="reason"><option value="">Tüm kategoriler</option><option value="spam">Spam</option><option value="fraud">Dolandırıcılık</option><option value="harassment">Taciz</option><option value="inappropriate">Uygunsuz içerik</option><option value="safety">Güvenlik</option><option value="other">Diğer</option></select></label>
        <label><span>Öncelik</span><select name="priority"><option value="">Tüm öncelikler</option><option value="critical">Kritik</option><option value="high">Yüksek</option><option value="normal">Normal</option><option value="low">Düşük</option></select></label>
        <button class="admin-filter-button" type="submit">Filtrele</button>
      </form>
      <div class="admin-data-card"><div class="admin-data-heading"><strong>Şikâyet kayıtları</strong><span data-admin-result-count="reports">0 kayıt</span></div><div class="admin-table" data-admin-reports></div></div>
    </section>

    <section class="admin-panel" data-admin-panel="listings" hidden>
      <div class="admin-section-intro"><div><span class="eyebrow">İÇERİK KALİTESİ</span><h2>İlan moderasyonu</h2><p>İlanları durum, tür ve şikâyet sayısına göre incele; not bırakarak yayından kaldır veya yeniden etkinleştir.</p></div></div>
      <button class="admin-pending-queue" type="button" data-open-pending-listings>
        <span class="admin-pending-icon">⌛</span>
        <span><small>YAYIN ÖNCESİ KONTROL</small><strong>Onay bekleyen ilanlar</strong><em>Yeni ilanları risk işaretleriyle inceleyip yayınla veya reddet.</em></span>
        <b data-pending-listing-count>0</b><i>İncele →</i>
      </button>
      <form class="admin-filterbar compact" data-listing-filters>
        <label class="admin-search"><span>⌕</span><input name="q" placeholder="İlan veya kullanıcı ara"></label>
        <label><span>Durum</span><select name="status"><option value="">Tüm durumlar</option><option value="pending">Onay bekliyor</option><option value="active">Aktif</option><option value="rejected">Reddedildi</option><option value="paused">Duraklatıldı</option><option value="removed">Kaldırıldı</option></select></label>
        <label><span>İlan türü</span><select name="type"><option value="">Tüm türler</option><option value="service_offer">Hizmet veren</option><option value="service_request">Hizmet arayan</option></select></label>
        <button class="admin-filter-button" type="submit">Filtrele</button>
      </form>
      <div class="admin-data-card"><div class="admin-data-heading"><strong>İlan kayıtları</strong><span data-admin-result-count="listings">0 kayıt</span></div><div class="admin-table" data-admin-listings></div></div>
    </section>

    <section class="admin-panel" data-admin-panel="users" hidden>
      <div class="admin-section-intro"><div><span class="eyebrow">HESAP YÖNETİMİ</span><h2>Kullanıcılar</h2><p>Hesapları, rollerini, ilan sayılarını ve açık şikâyetlerini görüntüle.</p></div></div>
      <form class="admin-filterbar compact" data-user-filters>
        <label class="admin-search"><span>⌕</span><input name="q" placeholder="Ad veya e-posta ara"></label>
        <label><span>Hesap</span><select name="status"><option value="">Tüm hesaplar</option><option value="active">Aktif</option><option value="suspended">Askıda</option></select></label>
        <label><span>Rol</span><select name="role"><option value="">Tüm roller</option><option value="user">Kullanıcı</option><option value="moderator">Moderatör</option><option value="admin">Yönetici</option><option value="super_admin">Süper yönetici</option></select></label>
        <button class="admin-filter-button" type="submit">Filtrele</button>
      </form>
      <div class="admin-data-card"><div class="admin-data-heading"><strong>Kullanıcı kayıtları</strong><span data-admin-result-count="users">0 kayıt</span></div><div class="admin-table" data-admin-users></div></div>
    </section>

    <section class="admin-panel" data-admin-panel="trust" hidden>
      <div class="admin-section-intro admin-section-actions"><div><span class="eyebrow">GÜVEN VE PAZARYERİ OPERASYONU</span><h2>İşler, değerlendirmeler ve riskler</h2><p>Anlaşmazlıkları, doğrulanmış değerlendirmeleri, otomatik risk sinyallerini ve beta geri bildirimlerini tek kuyrukta yönet.</p></div><button class="admin-primary-action" type="button" data-create-beta-invite>+ Beta daveti oluştur</button></div>
      <div class="admin-trust-grid">
        <div class="admin-data-card"><div class="admin-data-heading"><strong>İş ve anlaşmazlık kuyruğu</strong><span data-admin-result-count="engagements">0 kayıt</span></div><div class="admin-table" data-admin-engagements></div></div>
        <div class="admin-data-card"><div class="admin-data-heading"><strong>Değerlendirme moderasyonu</strong><span data-admin-result-count="reviews">0 kayıt</span></div><div class="admin-table" data-admin-review-queue></div></div>
        <div class="admin-data-card"><div class="admin-data-heading"><strong>Risk sinyalleri</strong><span data-admin-result-count="risks">0 kayıt</span></div><div class="admin-table" data-admin-risks></div></div>
        <div class="admin-data-card"><div class="admin-data-heading"><strong>Kapalı beta geri bildirimleri</strong><span data-admin-result-count="beta">0 kayıt</span></div><div class="admin-table" data-admin-beta-feedback></div></div>
        <div class="admin-data-card"><div class="admin-data-heading"><strong>Beta kullanıcıları</strong><span data-admin-result-count="beta-members">0 kullanıcı</span></div><div class="admin-table" data-admin-beta-members></div></div>
      </div>
    </section>

    <section class="admin-panel" data-admin-panel="categories" hidden>
      <div class="admin-section-intro admin-section-actions"><div><span class="eyebrow">İÇERİK MİMARİSİ</span><h2>Kategori ağacı</h2><p>Ana kategorileri ve alt kategorileri tek yerden oluştur, düzenle, sırala ve güvenli biçimde arşivle.</p></div><button class="admin-primary-action" type="button" data-category-create>+ Yeni kategori</button></div>
      <div class="category-admin-summary"><article><small>Toplam kategori</small><strong data-category-stat="total">—</strong></article><article><small>Ana kategori</small><strong data-category-stat="parents">—</strong></article><article><small>Alt kategori</small><strong data-category-stat="children">—</strong></article><article><small>Pasif kategori</small><strong data-category-stat="inactive">—</strong></article></div>
      <div class="admin-data-card"><div class="admin-data-heading"><strong>Hiyerarşik kategori listesi</strong><label class="admin-mini-search">⌕ <input data-category-search placeholder="Kategori ara"></label></div><div class="category-tree" data-admin-categories></div></div>
    </section>

    <section class="admin-panel" data-admin-panel="banners" hidden>
      <div class="admin-section-intro admin-section-actions"><div><span class="eyebrow">KAMPANYA YÖNETİMİ</span><h2>Bannerlar</h2><p>Web ve mobilde gösterilecek duyuru alanlarını tarih aralığı ve yerleşim bilgisiyle yönet.</p></div><button class="admin-primary-action" type="button" data-banner-create>+ Yeni banner</button></div>
      <div class="admin-data-card"><div class="admin-data-heading"><strong>Banner kayıtları</strong><span data-admin-result-count="banners">0 kayıt</span></div><div class="admin-table" data-admin-banners></div></div>
    </section>

    <section class="admin-panel" data-admin-panel="privacy" hidden>
      <div class="admin-section-intro"><div><span class="eyebrow">YASAL UYUM</span><h2>KVKK ve politika yönetimi</h2><p>Kullanıcı taleplerini sonuçlandır; hukuk ekibinin onayladığı metinleri sürümlü olarak yayımla.</p></div></div>
      <details class="admin-form-disclosure"><summary>+ Yeni yasal metin taslağı</summary><form class="admin-policy-form platform-form" data-admin-policy-form><div class="form-grid"><label>Metin türü<select name="document_type"><option value="privacy_policy">Gizlilik politikası</option><option value="terms">Kullanım koşulları</option><option value="kvkk_notice">KVKK aydınlatma</option><option value="cookie_policy">Çerez politikası</option></select></label><label>Sürüm<input name="version" required placeholder="2026-08"></label><label class="wide">Başlık<input name="title" required></label><label class="wide">Hukuk ekibinin onaylı metni<textarea name="content" required></textarea></label></div><button class="primary-button" type="submit">Taslağı kaydet</button></form></details>
      <div class="admin-data-card"><div class="admin-data-heading"><strong>KVKK başvuruları</strong></div><div class="admin-table" data-admin-privacy></div></div>
    </section>

    <section class="admin-panel" data-admin-panel="audit" hidden>
      <div class="admin-section-intro"><div><span class="eyebrow">GÜVENLİK VE İZLENEBİLİRLİK</span><h2>Denetim kayıtları</h2><p>Yönetici işlemlerinin kim, ne zaman ve hangi kayıt üzerinde yapıldığını incele.</p></div></div>
      <div class="admin-data-card"><div class="admin-data-heading"><strong>Değiştirilemez işlem izi</strong><span>Son 500 işlem</span></div><div class="admin-table" data-admin-audit></div></div>
    </section>
  </main>

  <dialog class="admin-dialog" data-admin-dialog>
    <div class="admin-dialog-shell"><header><div><small data-dialog-eyebrow>KAYIT DETAYI</small><h2 data-dialog-title>Detay</h2></div><button type="button" data-dialog-close aria-label="Kapat">×</button></header><div class="admin-dialog-body" data-dialog-body></div></div>
  </dialog>

  <dialog class="admin-dialog" data-category-dialog>
    <form class="admin-dialog-shell" data-category-form>
      <header><div><small>KATEGORİ YÖNETİMİ</small><h2 data-category-dialog-title>Yeni kategori</h2></div><button type="button" data-category-dialog-close aria-label="Kapat">×</button></header>
      <div class="admin-dialog-body admin-form-grid">
        <input type="hidden" name="editing_id">
        <label>Kategori adı<input name="label" required maxlength="120" placeholder="Örn. Klima Servisi"></label>
        <label>Teknik kod<input name="id" required maxlength="64" pattern="[a-z0-9_]+" placeholder="klima_servisi"><small>Sonradan değişmez; küçük harf ve alt çizgi kullan.</small></label>
        <label>Ana kategori<select name="parent_id"><option value="">— Ana kategori olarak oluştur —</option></select></label>
        <label>Sıralama<input name="sort_order" type="number" min="0" value="0"></label>
        <div class="admin-check-grid"><label><input name="is_active" type="checkbox" checked> Aktif</label><label><input name="is_selectable" type="checkbox" checked> İlanlarda seçilebilir</label><label><input name="is_open_ended" type="checkbox"> Açık uçlu kategori</label></div>
      </div>
      <footer><button type="button" class="admin-secondary-action" data-category-dialog-cancel>Vazgeç</button><button type="submit" class="admin-primary-action">Kategoriyi kaydet</button></footer>
    </form>
  </dialog>

  <dialog class="admin-dialog" data-banner-dialog>
    <form class="admin-dialog-shell" data-banner-form>
      <header><div><small>KAMPANYA YÖNETİMİ</small><h2 data-banner-dialog-title>Yeni banner</h2></div><button type="button" data-banner-dialog-close aria-label="Kapat">×</button></header>
      <div class="admin-dialog-body admin-form-grid">
        <input type="hidden" name="id"><label>Başlık<input name="title" required maxlength="160"></label><label>Yerleşim<select name="placement"><option value="home">Ana sayfa</option><option value="mobile_home">Mobil ana sayfa</option><option value="listing">İlan sayfası</option></select></label><label class="wide">Açıklama<textarea name="body" maxlength="500"></textarea></label><label class="wide">Hedef bağlantı<input name="target_url" type="url" placeholder="https://..."></label><label>Başlangıç<input name="starts_at" type="datetime-local"></label><label>Bitiş<input name="ends_at" type="datetime-local"></label><div class="admin-check-grid"><label><input name="is_active" type="checkbox" checked> Aktif</label></div>
      </div>
      <footer><button type="button" class="admin-secondary-action" data-banner-dialog-cancel>Vazgeç</button><button type="submit" class="admin-primary-action">Bannerı kaydet</button></footer>
    </form>
  </dialog>
</section>
