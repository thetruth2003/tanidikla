(() => {
  const root = document.querySelector('[data-admin-page]');
  if (!root) return;

  const reasonLabels = {
    spam: 'Spam ve yanıltıcı içerik',
    fraud: 'Dolandırıcılık şüphesi',
    harassment: 'Taciz ve kötü davranış',
    inappropriate: 'Uygunsuz içerik',
    safety: 'Güvenlik riski',
    other: 'Diğer bildirimler',
  };
  const reasonShort = { spam: 'Spam', fraud: 'Dolandırıcılık', harassment: 'Taciz', inappropriate: 'Uygunsuz', safety: 'Güvenlik', other: 'Diğer' };
  const statusLabels = { open: 'Yeni', reviewing: 'İnceleniyor', resolved: 'Çözüldü', rejected: 'Reddedildi', active: 'Aktif', pending: 'Onay bekliyor', processing: 'İşleniyor', paused: 'Yayın durduruldu', removed: 'Yayından kaldırıldı', completed: 'Tamamlandı', draft: 'Taslak' };
  const priorityLabels = { critical: 'Kritik', high: 'Yüksek', normal: 'Normal', low: 'Düşük' };
  const actionLabels = {
    'report.update': 'Şikâyet güncellendi', 'category.create': 'Kategori oluşturuldu', 'category.update': 'Kategori güncellendi',
    'category.archive': 'Kategori arşivlendi', 'category.delete': 'Kategori silindi', 'listing.moderate': 'İlan yönetildi',
    'listing.delete_permanent': 'İlan kalıcı silindi', 'user.delete_permanent': 'Kullanıcı kalıcı silindi',
    'user.suspend': 'Kullanıcı askıya alındı', 'user.unsuspend': 'Kullanıcı yeniden açıldı', 'banner.save': 'Banner kaydedildi',
    'banner.delete': 'Banner silindi',
  };
  const pageMeta = {
    overview: ['Genel bakış', 'Platform genel bakışı', 'Platformun sağlığını ve bekleyen operasyon işlerini tek ekrandan takip et.'],
    reports: ['Şikâyetler', 'Şikâyet merkezi', 'Bildirimleri kategori, öncelik ve durum bilgisiyle incele ve sonuçlandır.'],
    listings: ['İlanlar', 'İlan moderasyonu', 'Yayınlanan içeriklerin kalitesini ve güvenliğini yönet.'],
    trust: ['İşler ve güven', 'Güven operasyonları', 'Anlaşmazlıkları, değerlendirmeleri, risk sinyallerini ve beta geri bildirimlerini yönet.'],
    users: ['Kullanıcılar', 'Kullanıcı yönetimi', 'Hesap durumlarını, rolleri ve platform etkinliğini takip et.'],
    categories: ['Kategoriler', 'Kategori yönetimi', 'Ana ve alt kategorilerden oluşan içerik ağacını yönet.'],
    banners: ['Bannerlar', 'Banner yönetimi', 'Web ve mobil kampanya alanlarını planla ve yayımla.'],
    privacy: ['KVKK', 'KVKK ve politika yönetimi', 'Yasal talepleri ve sürümlü politika metinlerini yönet.'],
    audit: ['Denetim kayıtları', 'Denetim kayıtları', 'Yönetim alanındaki kritik işlemleri geriye dönük incele.'],
  };
  const state = { currentTab: 'overview', categories: [], banners: [], categorySearch: '', canDeleteListings: false, canDeleteUsers: false };
  const number = new Intl.NumberFormat('tr-TR');

  const el = (tag, className = '', text) => {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  };
  const setText = (selector, value) => { const node = root.querySelector(selector); if (node) node.textContent = value; };
  const formatDate = (value) => value ? new Intl.DateTimeFormat('tr-TR', { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(value)) : '—';
  const bool = (value) => value === true || value === 'true' || value === 1 || value === '1';
  const badge = (text, tone = 'neutral') => el('span', `admin-badge ${tone}`, text);
  const actionButton = (label, run, tone = '') => {
    const button = el('button', `admin-row-button ${tone}`.trim(), label);
    button.type = 'button';
    button.addEventListener('click', run);
    return button;
  };
  const emptyState = (title, copy) => {
    const box = el('div', 'admin-empty-state');
    box.append(el('span', 'admin-empty-icon', '✓'), el('strong', '', title), el('p', '', copy));
    return box;
  };
  const loadingState = (box) => {
    box.replaceChildren();
    const skeleton = el('div', 'admin-loading');
    for (let index = 0; index < 4; index += 1) skeleton.append(el('span'));
    box.append(skeleton);
  };
  const queryFromForm = (form) => {
    const params = new URLSearchParams();
    if (!form) return '';
    new FormData(form).forEach((value, key) => { if (String(value).trim()) params.set(key, String(value).trim()); });
    const query = params.toString();
    return query ? `?${query}` : '';
  };
  const showToast = (message, tone = 'success') => {
    const toast = root.querySelector('[data-admin-toast]');
    toast.className = `admin-toast ${tone}`;
    toast.textContent = message;
    toast.hidden = false;
    clearTimeout(showToast.timer);
    showToast.timer = window.setTimeout(() => { toast.hidden = true; }, 3800);
  };
  const handleError = (error) => {
    if (error.status === 401 || error.status === 419) window.location.assign('/admin/giris');
    else showToast(error.message || 'İşlem tamamlanamadı.', 'error');
  };
  const setResultCount = (key, count) => setText(`[data-admin-result-count="${key}"]`, `${number.format(count)} kayıt`);

  const detailRows = (rows) => {
    const grid = el('dl', 'admin-detail-grid');
    rows.forEach(([label, value]) => {
      const cell = el('div');
      cell.append(el('dt', '', label), el('dd', '', value || '—'));
      grid.append(cell);
    });
    return grid;
  };
  const dialog = root.querySelector('[data-admin-dialog]');
  const closeDialog = () => dialog.open && dialog.close();
  root.querySelector('[data-dialog-close]').addEventListener('click', closeDialog);
  dialog.addEventListener('click', (event) => { if (event.target === dialog) closeDialog(); });
  const openDialog = (title, eyebrow, content) => {
    setText('[data-dialog-title]', title);
    setText('[data-dialog-eyebrow]', eyebrow);
    root.querySelector('[data-dialog-body]').replaceChildren(content);
    dialog.showModal();
  };

  const loadOverview = async () => {
    const data = await adminApi('/stats');
    ['users', 'active_listings', 'listings_waiting', 'open_reports', 'urgent_reports', 'overdue_reports', 'privacy_requests'].forEach((key) => {
      setText(`[data-admin-stat="${key}"]`, number.format(Number(data[key] || 0)));
    });
    const navCount = root.querySelector('[data-nav-count="reports"]');
    navCount.textContent = Number(data.open_reports || 0) ? number.format(Number(data.open_reports)) : '';
    const pendingListings = Number(data.pending_listings || 0);
    const listingNavCount = root.querySelector('[data-nav-count="listings"]');
    if (listingNavCount) listingNavCount.textContent = pendingListings ? number.format(pendingListings) : '';
    setText('[data-pending-listing-count]', number.format(pendingListings));

    const breakdown = root.querySelector('[data-overview-report-breakdown]');
    breakdown.replaceChildren();
    const counts = Object.fromEntries((data.reports_by_reason || []).map((item) => [item.reason, Number(item.open_count || 0)]));
    const max = Math.max(1, ...Object.values(counts));
    Object.entries(reasonLabels).forEach(([reason, label]) => {
      const row = el('button', 'admin-breakdown-row');
      row.type = 'button';
      const labelBox = el('span'); labelBox.append(el('strong', '', label), el('small', '', `${number.format(counts[reason] || 0)} açık kayıt`));
      const meter = el('i'); const fill = el('b'); fill.style.width = `${Math.max(4, ((counts[reason] || 0) / max) * 100)}%`; meter.append(fill);
      row.append(labelBox, meter);
      row.addEventListener('click', () => { switchTab('reports'); const select = root.querySelector('[data-report-filters] [name="reason"]'); select.value = reason; loadReports().catch(handleError); });
      breakdown.append(row);
    });

    const activity = root.querySelector('[data-overview-activity]');
    activity.replaceChildren();
    if (!(data.recent_activity || []).length) activity.append(emptyState('Henüz işlem yok', 'Yönetim işlemleri burada zaman sırasıyla görünecek.'));
    (data.recent_activity || []).forEach((item) => {
      const row = el('div', 'admin-activity-row');
      row.append(el('span', '', '•'), el('div'));
      row.lastChild.append(el('strong', '', actionLabels[item.action] || item.action), el('small', '', `${item.admin_name} · ${formatDate(item.created_at)}`));
      activity.append(row);
    });
  };

  const renderReportSummary = (summary = {}) => {
    const box = root.querySelector('[data-report-summary]');
    box.replaceChildren();
    const indexed = Object.fromEntries((summary.by_reason || []).map((item) => [item.reason, item]));
    Object.entries(reasonLabels).forEach(([reason, label], index) => {
      const item = indexed[reason] || { open_count: 0, reviewing_count: 0, total_count: 0 };
      const card = el('button', `report-category-card tone-${(index % 6) + 1}`);
      card.type = 'button';
      card.append(el('span', 'report-category-symbol', String(index + 1).padStart(2, '0')));
      const copy = el('div'); copy.append(el('strong', '', label), el('small', '', `${number.format(Number(item.open_count || 0))} yeni · ${number.format(Number(item.reviewing_count || 0))} inceleniyor`));
      card.append(copy, el('b', '', number.format(Number(item.total_count || 0))));
      card.addEventListener('click', () => { const select = root.querySelector('[data-report-filters] [name="reason"]'); select.value = select.value === reason ? '' : reason; loadReports().catch(handleError); });
      box.append(card);
    });
  };

  const openReport = (item) => {
    const wrapper = el('div');
    wrapper.append(detailRows([
      ['Şikâyet kategorisi', reasonLabels[item.reason] || item.reason], ['Kayıt durumu', statusLabels[item.status] || item.status],
      ['Bildiren kullanıcı', `${item.reporter_name} (${item.reporter_email})`], ['Hedef', item.listing_title || item.reported_user_name || 'Kayıt'],
      ['Oluşturulma', formatDate(item.created_at)], ['Atanan yönetici', item.assigned_admin_name || 'Henüz atanmadı'],
    ]));
    const description = el('section', 'admin-detail-note'); description.append(el('small', '', 'KULLANICI AÇIKLAMASI'), el('p', '', item.details || 'Açıklama eklenmemiş.')); wrapper.append(description);
    if (item.listing_slug) { const link = el('a', 'admin-external-link', 'İlanı yeni sekmede görüntüle ↗'); link.href = `/ilan/${encodeURIComponent(item.listing_slug)}`; link.target = '_blank'; link.rel = 'noopener'; wrapper.append(link); }
    const form = el('form', 'admin-action-form');
    const statusLabel = el('label', '', 'Durum'); const status = el('select'); status.name = 'status';
    [['open','Yeni'],['reviewing','İnceleniyor'],['resolved','Çözüldü'],['rejected','Reddedildi']].forEach(([value, label]) => { const option = el('option', '', label); option.value = value; option.selected = item.status === value; status.append(option); }); statusLabel.append(status);
    const priorityLabel = el('label', '', 'Öncelik'); const priority = el('select'); priority.name = 'priority';
    Object.entries(priorityLabels).forEach(([value, label]) => { const option = el('option', '', label); option.value = value; option.selected = (item.priority || 'normal') === value; priority.append(option); }); priorityLabel.append(priority);
    const noteLabel = el('label', 'wide', 'Yönetim notu'); const note = el('textarea'); note.name = 'admin_note'; note.maxLength = 2000; note.value = item.admin_note || ''; note.placeholder = 'İnceleme sonucu, kanıt veya alınan aksiyonu yaz...'; noteLabel.append(note);
    const footer = el('footer'); footer.append(actionButton('Vazgeç', closeDialog, 'secondary'), actionButton('Değişiklikleri kaydet', () => form.requestSubmit(), 'primary'));
    form.append(statusLabel, priorityLabel, noteLabel, footer);
    form.addEventListener('submit', async (event) => {
      event.preventDefault();
      try { await adminApi(`/reports/${item.id}`, { method: 'PUT', body: JSON.stringify(Object.fromEntries(new FormData(form).entries())) }); closeDialog(); showToast('Şikâyet kaydı güncellendi.'); await Promise.all([loadReports(), loadOverview()]); } catch (error) { handleError(error); }
    });
    wrapper.append(form);
    openDialog(item.listing_title || item.reported_user_name || 'Şikâyet detayı', 'MODERASYON KAYDI', wrapper);
  };

  const loadReports = async () => {
    const box = root.querySelector('[data-admin-reports]'); loadingState(box);
    const data = await adminApi(`/reports${queryFromForm(root.querySelector('[data-report-filters]'))}`);
    const items = data.items || []; renderReportSummary(data.summary || {}); setResultCount('reports', items.length); box.replaceChildren();
    if (!items.length) { box.append(emptyState('Bu filtrede şikâyet yok', 'Yeni bir bildirim geldiğinde kategori, öncelik ve detayları burada görünecek.')); return; }
    items.forEach((item) => {
      const row = el('article', 'admin-record');
      const leading = el('span', `admin-record-leading priority-${item.priority || 'normal'}`, reasonShort[item.reason]?.slice(0, 1) || '!');
      const content = el('div', 'admin-record-content');
      const title = el('div', 'admin-record-title'); title.append(el('strong', '', item.listing_title || item.reported_user_name || 'Bildirilen kayıt'), badge(reasonShort[item.reason] || item.reason, 'teal'), badge(statusLabels[item.status] || item.status, item.status));
      content.append(title, el('p', '', item.details || 'Kullanıcı açıklama eklememiş.'), el('small', '', `${item.reporter_name} tarafından · ${formatDate(item.created_at)} · ${priorityLabels[item.priority] || 'Normal'} öncelik`));
      const actions = el('div', 'admin-record-actions'); actions.append(actionButton('Detayı incele', () => openReport(item), 'primary'));
      row.append(leading, content, actions); box.append(row);
    });
  };

  const permanentDelete = async (resource, item, label, reload) => {
    const values = await window.siteFormModal({
      eyebrow: 'GERİ ALINAMAZ İŞLEM',
      title: resource === 'users' ? 'Hesabı kalıcı sil' : 'İlanı kalıcı sil',
      description: `“${label}” ve bağlı kayıtları sunucudan kaldırmak için denetim nedenini yaz.`,
      confirmText: 'Sonraki adıma geç',
      fields: [{ name: 'reason', label: 'Kalıcı silme nedeni', type: 'textarea', minLength: 5, placeholder: 'En az 5 karakterle işlemin nedenini açıkla…' }],
      validate: (input) => input.reason.trim().length < 5 ? 'Kalıcı silme nedeni en az 5 karakter olmalıdır.' : '',
    });
    if (!values) return;
    const confirmed = await window.siteConfirm(`“${label}” ve bağlı veriler sunucudan kalıcı olarak silinecek. Bu işlem geri alınamaz.`, {
      title: 'Kalıcı silme işlemini onayla',
      confirmText: 'Kalıcı olarak sil',
    });
    if (!confirmed) return;
    try {
      const result = await adminApi(`/${resource}/${item.id}`, {
        method: 'DELETE',
        body: JSON.stringify({ reason: values.reason.trim(), confirmation: 'KALICI OLARAK SİL' }),
      });
      closeDialog();
      const cleanupWarning = Number(result.storage_failed || 0) > 0 ? ' Bazı dosyalar depolamadan temizlenemedi; sunucu kayıtlarını kontrol et.' : '';
      showToast(`${resource === 'users' ? 'Hesap' : 'İlan'} kalıcı olarak silindi.${cleanupWarning}`, cleanupWarning ? 'error' : 'success');
      await Promise.all([reload(), loadOverview()]);
    } catch (error) {
      handleError(error);
    }
  };

  const openListing = (item) => {
    let flags = item.moderation_flags || [];
    if (typeof flags === 'string') { try { flags = JSON.parse(flags); } catch (_) { flags = []; } }
    const wrapper = el('div');
    wrapper.append(detailRows([
      ['İlan sahibi', item.owner_name], ['İlan türü', item.listing_type === 'service_offer' ? 'Hizmet veren' : 'Hizmet arayan'],
      ['Kategori', item.category_id], ['Konum', [item.public_neighborhood,item.public_district,item.public_city].filter(Boolean).join(', ')],
      ['Açık şikâyet', number.format(Number(item.open_reports || 0))], ['Gönderim tarihi', formatDate(item.submitted_at || item.created_at)],
      ['Otomatik risk puanı', `${number.format(Number(item.moderation_score || 0))} / 100`],
      ['Risk işaretleri', flags.length ? flags.join(', ') : 'Otomatik risk işareti yok'],
    ]));
    if (item.status === 'active') { const link = el('a', 'admin-external-link', 'İlanı yeni sekmede görüntüle ↗'); link.href = `/ilan/${encodeURIComponent(item.slug)}`; link.target = '_blank'; link.rel = 'noopener'; wrapper.append(link); }
    const form = el('form', 'admin-action-form one-column');
    const statusLabel = el('label', '', 'Yayın durumu'); const status = el('select'); status.name = 'status';
    [['pending','Onay bekliyor'],['active','Onayla ve yayınla'],['rejected','Reddet / düzenleme iste'],['paused','Yayını durdur'],['removed','Yayından kaldır']].forEach(([value,label]) => { const option=el('option','',label); option.value=value; option.selected=item.status===value; status.append(option); }); statusLabel.append(status);
    const noteLabel=el('label','','Moderasyon notu'); const note=el('textarea'); note.name='note'; note.maxLength=1000; note.value=item.moderation_note||''; note.placeholder='Durum değişikliğinin nedenini yaz...'; noteLabel.append(note);
    const footer=el('footer'); footer.append(actionButton('Vazgeç',closeDialog,'secondary'));
    if (item.status === 'pending') {
      footer.append(
        actionButton('Reddet',()=>{status.value='rejected';form.requestSubmit();},'danger'),
        actionButton('Onayla ve yayınla',()=>{status.value='active';form.requestSubmit();},'primary'),
      );
    } else footer.append(actionButton('İlanı güncelle',()=>form.requestSubmit(),'primary'));
    form.append(statusLabel,noteLabel,footer);
    form.addEventListener('submit',async(event)=>{ event.preventDefault(); if(status.value==='rejected'&&note.value.trim().length<5){showToast('Reddetme nedenini kullanıcı için en az 5 karakterle yaz.','error');note.focus();return;} try{ await adminApi(`/listings/${item.id}/moderation`,{method:'PUT',body:JSON.stringify(Object.fromEntries(new FormData(form).entries()))}); closeDialog(); showToast(status.value==='active'?'İlan onaylandı ve yayınlandı.':'İlan durumu güncellendi.'); await Promise.all([loadListings(),loadOverview()]); }catch(error){handleError(error);} });
    wrapper.append(form);
    if (state.canDeleteListings) {
      const danger=el('section','admin-danger-zone');
      const dangerCopy=el('div'); dangerCopy.append(el('strong','','Kalıcı silme'),el('p','','İlanı, bağlı görselleri ve ilişkili kayıtları sunucudan geri alınamaz biçimde siler.'));
      danger.append(dangerCopy,actionButton('İlanı kaldır (kalıcı sil)',()=>permanentDelete('listings',item,item.title||item.slug,loadListings),'danger'));
      wrapper.append(danger);
    }
    openDialog(item.title || item.slug,'İLAN MODERASYONU',wrapper);
  };

  const loadListings = async () => {
    const box=root.querySelector('[data-admin-listings]'); loadingState(box);
    const data=await adminApi(`/listings${queryFromForm(root.querySelector('[data-listing-filters]'))}`); const items=data.items||[]; state.canDeleteListings=bool(data.capabilities?.permanent_delete); setResultCount('listings',items.length); const pending=Number(data.summary?.pending||0); setText('[data-pending-listing-count]',number.format(pending)); const nav=root.querySelector('[data-nav-count="listings"]'); if(nav)nav.textContent=pending?number.format(pending):''; box.replaceChildren();
    if(!items.length){box.append(emptyState('İlan bulunamadı','Filtreleri temizleyerek diğer ilanları görüntüleyebilirsin.'));return;}
    items.forEach((item)=>{ const row=el('article',`admin-record ${item.status==='pending'?'pending-review':''}`); const leading=el('span','admin-record-leading listing',item.listing_type==='service_offer'?'HV':'HA'); const content=el('div','admin-record-content'); const title=el('div','admin-record-title'); title.append(el('strong','',item.title||item.slug),badge(statusLabels[item.status]||item.status,item.status)); if(Number(item.moderation_score)>0)title.append(badge(`Risk ${item.moderation_score}` ,Number(item.moderation_score)>=50?'danger':'neutral')); if(Number(item.open_reports)>0)title.append(badge(`${item.open_reports} şikâyet`,'danger')); content.append(title,el('p','',`${item.owner_name} · ${item.public_district||'Konum yok'} · ${item.category_id||'Kategori yok'}`),el('small','',`${item.listing_type==='service_offer'?'Hizmet veren':'Hizmet arayan'} · ${formatDate(item.submitted_at||item.created_at)}`)); const actions=el('div','admin-record-actions'); actions.append(actionButton(item.status==='pending'?'İncele ve onayla':'Yönet',()=>openListing(item),'primary')); row.append(leading,content,actions);box.append(row); });
  };

  const openUser = (item) => {
    const wrapper=el('div'); wrapper.append(detailRows([['E-posta',item.email],['Rol',item.role],['Konum',[item.district,item.city].filter(Boolean).join(', ')],['İlan sayısı',number.format(Number(item.listing_count||0))],['Açık şikâyet',number.format(Number(item.open_report_count||0))],['Kayıt tarihi',formatDate(item.created_at)],['E-posta doğrulama',item.email_verified_at?'Doğrulandı':'Bekliyor'],['Hesap durumu',bool(item.is_suspended)?'Askıda':'Aktif']]));
    if(item.suspended_reason){const note=el('section','admin-detail-note warning');note.append(el('small','','ASKI NEDENİ'),el('p','',item.suspended_reason));wrapper.append(note);}
    const form=el('form','admin-action-form one-column'); const reasonLabel=el('label','',bool(item.is_suspended)?'Hesabı yeniden aç':'Askıya alma nedeni'); const reason=el('textarea');reason.name='reason';reason.maxLength=500;reason.required=!bool(item.is_suspended);reason.placeholder='Güvenlik veya politika ihlalini açıklayın...';reasonLabel.append(reason); const footer=el('footer');footer.append(actionButton('Vazgeç',closeDialog,'secondary'),actionButton(bool(item.is_suspended)?'Askıyı kaldır':'Hesabı askıya al',()=>form.requestSubmit(),bool(item.is_suspended)?'primary':'danger'));form.append(reasonLabel,footer);
    form.addEventListener('submit',async(event)=>{event.preventDefault();try{await adminApi(`/users/${item.id}/suspension`,{method:'PUT',body:JSON.stringify({suspended:!bool(item.is_suspended),reason:reason.value})});closeDialog();showToast(bool(item.is_suspended)?'Hesap yeniden etkinleştirildi.':'Hesap askıya alındı.');await loadUsers();}catch(error){handleError(error);}});
    wrapper.append(form);
    if(state.canDeleteUsers&&item.role==='user'){
      const danger=el('section','admin-danger-zone');
      const dangerCopy=el('div');dangerCopy.append(el('strong','','Hesabı kalıcı sil'),el('p','','Hesabı, ilanları, mesaj bağlantılarını ve yüklenen dosyaları geri alınamaz biçimde sunucudan siler.'));
      danger.append(dangerCopy,actionButton('Hesabı kaldır (kalıcı sil)',()=>permanentDelete('users',item,item.display_name,loadUsers),'danger'));
      wrapper.append(danger);
    }
    openDialog(item.display_name,'KULLANICI HESABI',wrapper);
  };

  const loadUsers=async()=>{const box=root.querySelector('[data-admin-users]');loadingState(box);const data=await adminApi(`/users${queryFromForm(root.querySelector('[data-user-filters]'))}`);const items=data.items||[];state.canDeleteUsers=bool(data.capabilities?.permanent_delete);setResultCount('users',items.length);box.replaceChildren();if(!items.length){box.append(emptyState('Kullanıcı bulunamadı','Arama veya filtre ölçütlerini değiştirebilirsin.'));return;}items.forEach((item)=>{const row=el('article','admin-record');const initials=(item.display_name||'?').split(/\s+/).slice(0,2).map((part)=>part[0]).join('').toUpperCase();const leading=el('span','admin-record-leading user',initials);const content=el('div','admin-record-content');const title=el('div','admin-record-title');title.append(el('strong','',item.display_name),badge(item.role,'neutral'),badge(bool(item.is_suspended)?'Askıda':'Aktif',bool(item.is_suspended)?'danger':'active'));content.append(title,el('p','',`${item.email} · ${item.district||item.city||'Konum yok'}`),el('small','',`${item.listing_count||0} ilan · ${item.open_report_count||0} açık şikâyet · ${formatDate(item.created_at)}`));const actions=el('div','admin-record-actions');actions.append(actionButton('Profili yönet',()=>openUser(item),'primary'));row.append(leading,content,actions);box.append(row);});};

  const categoryDialog=root.querySelector('[data-category-dialog]'); const categoryForm=root.querySelector('[data-category-form]');
  const closeCategoryDialog=()=>categoryDialog.open&&categoryDialog.close();
  root.querySelector('[data-category-dialog-close]').addEventListener('click',closeCategoryDialog); root.querySelector('[data-category-dialog-cancel]').addEventListener('click',closeCategoryDialog); categoryDialog.addEventListener('click',(event)=>{if(event.target===categoryDialog)closeCategoryDialog();});
  const categoryDescendants=(id)=>{const found=new Set([id]);let changed=true;while(changed){changed=false;state.categories.forEach((item)=>{if(item.parent_id&&found.has(item.parent_id)&&!found.has(item.id)){found.add(item.id);changed=true;}});}return found;};
  const categoryPath=(item)=>{const labels=[item.label];let parent=state.categories.find((candidate)=>candidate.id===item.parent_id);while(parent){labels.unshift(parent.label);parent=state.categories.find((candidate)=>candidate.id===parent.parent_id);}return labels.join(' / ');};
  const slugify=(value)=>value.toLocaleLowerCase('tr-TR').replace(/[ç]/g,'c').replace(/[ğ]/g,'g').replace(/[ı]/g,'i').replace(/[ö]/g,'o').replace(/[ş]/g,'s').replace(/[ü]/g,'u').replace(/[^a-z0-9]+/g,'_').replace(/^_+|_+$/g,'').slice(0,64);
  const openCategoryDialog=(item=null,parentId='')=>{categoryForm.reset();categoryForm.elements.editing_id.value=item?.id||'';categoryForm.elements.label.value=item?.label||'';categoryForm.elements.id.value=item?.id||'';categoryForm.elements.id.disabled=Boolean(item);categoryForm.elements.sort_order.value=item?.sort_order||0;categoryForm.elements.is_active.checked=item?bool(item.is_active):true;categoryForm.elements.is_selectable.checked=item?bool(item.is_selectable):true;categoryForm.elements.is_open_ended.checked=item?bool(item.is_open_ended):false;setText('[data-category-dialog-title]',item?'Kategoriyi düzenle':parentId?'Alt kategori ekle':'Yeni kategori');const parentSelect=categoryForm.elements.parent_id;parentSelect.replaceChildren();const emptyOption=el('option','','— Ana kategori olarak oluştur —');emptyOption.value='';parentSelect.append(emptyOption);const excluded=item?categoryDescendants(item.id):new Set();state.categories.filter((candidate)=>!excluded.has(candidate.id)).forEach((candidate)=>{const option=el('option','',categoryPath(candidate));option.value=candidate.id;option.selected=(item?.parent_id||parentId)===candidate.id;parentSelect.append(option);});categoryDialog.showModal();};
  categoryForm.elements.label.addEventListener('input',()=>{if(!categoryForm.elements.editing_id.value)categoryForm.elements.id.value=slugify(categoryForm.elements.label.value);});
  categoryForm.addEventListener('submit',async(event)=>{event.preventDefault();const editingId=categoryForm.elements.editing_id.value;const payload={label:categoryForm.elements.label.value,id:editingId||categoryForm.elements.id.value,parent_id:categoryForm.elements.parent_id.value,sort_order:Number(categoryForm.elements.sort_order.value||0),is_active:categoryForm.elements.is_active.checked,is_selectable:categoryForm.elements.is_selectable.checked,is_open_ended:categoryForm.elements.is_open_ended.checked};try{await adminApi(editingId?`/categories/${encodeURIComponent(editingId)}`:'/categories',{method:editingId?'PUT':'POST',body:JSON.stringify(payload)});closeCategoryDialog();showToast(editingId?'Kategori güncellendi.':'Yeni kategori oluşturuldu.');await loadCategories();}catch(error){handleError(error);}});
  const deleteCategory=async(item)=>{const used=Number(item.child_count||0)+Number(item.listing_count||0)>0;const message=used?`“${item.label}” kullanımda. Kalıcı silinmeyecek, pasife alınarak arşivlenecek.`:`“${item.label}” kalıcı olarak silinecek.`;if(!(await window.siteConfirm(message,{title:used?'Kategori arşivlensin mi?':'Kategori silinsin mi?',confirmText:used?'Kategoriyi arşivle':'Kategoriyi sil'})))return;try{const result=await adminApi(`/categories/${encodeURIComponent(item.id)}`,{method:'DELETE'});showToast(result.message||'Kategori kaldırıldı.');await loadCategories();}catch(error){handleError(error);}};
  const renderCategoryNode=(item,level=0)=>{const node=el('article',`category-node ${bool(item.is_active)?'':'inactive'}`);node.style.setProperty('--category-level',level);const marker=el('span','category-node-marker',level?'↳':String(item.sort_order||0));const content=el('div','category-node-content');const title=el('div');title.append(el('strong','',item.label),badge(bool(item.is_active)?'Aktif':'Pasif',bool(item.is_active)?'active':'neutral'),badge(bool(item.is_selectable)?'Seçilebilir':'Grup','teal'));content.append(title,el('small','',`${item.id} · ${item.child_count||0} alt kategori · ${item.listing_count||0} ilan`));const actions=el('div','category-node-actions');actions.append(actionButton('+ Alt kategori',()=>openCategoryDialog(null,item.id)),actionButton('Düzenle',()=>openCategoryDialog(item),'primary'),actionButton(Number(item.child_count||0)+Number(item.listing_count||0)>0?'Arşivle':'Sil',()=>deleteCategory(item),'danger'));node.append(marker,content,actions);return node;};
  const renderCategories=()=>{const box=root.querySelector('[data-admin-categories]');box.replaceChildren();const search=state.categorySearch.toLocaleLowerCase('tr-TR');const visible=search?state.categories.filter((item)=>categoryPath(item).toLocaleLowerCase('tr-TR').includes(search)):state.categories;const visibleIds=new Set(visible.map((item)=>item.id));const childrenByParent=new Map();state.categories.forEach((item)=>{const key=item.parent_id||'';if(!childrenByParent.has(key))childrenByParent.set(key,[]);childrenByParent.get(key).push(item);});let rendered=0;const appendTree=(item,level)=>{if(search&&!visibleIds.has(item.id)&&!(childrenByParent.get(item.id)||[]).some((child)=>visibleIds.has(child.id)))return;if(!search||visibleIds.has(item.id)){box.append(renderCategoryNode(item,level));rendered+=1;}(childrenByParent.get(item.id)||[]).forEach((child)=>appendTree(child,level+1));};(childrenByParent.get('')||[]).forEach((item)=>appendTree(item,0));if(!rendered)box.append(emptyState('Kategori bulunamadı','Arama metnini değiştir veya yeni kategori oluştur.'));};
  const loadCategories=async()=>{const box=root.querySelector('[data-admin-categories]');loadingState(box);const data=await adminApi('/categories');state.categories=data.items||[];setText('[data-category-stat="total"]',number.format(state.categories.length));setText('[data-category-stat="parents"]',number.format(state.categories.filter((item)=>!item.parent_id).length));setText('[data-category-stat="children"]',number.format(state.categories.filter((item)=>item.parent_id).length));setText('[data-category-stat="inactive"]',number.format(state.categories.filter((item)=>!bool(item.is_active)).length));renderCategories();};

  const bannerDialog=root.querySelector('[data-banner-dialog]');const bannerForm=root.querySelector('[data-banner-form]');const closeBannerDialog=()=>bannerDialog.open&&bannerDialog.close();root.querySelector('[data-banner-dialog-close]').addEventListener('click',closeBannerDialog);root.querySelector('[data-banner-dialog-cancel]').addEventListener('click',closeBannerDialog);bannerDialog.addEventListener('click',(event)=>{if(event.target===bannerDialog)closeBannerDialog();});
  const toLocalInput=(value)=>value?new Date(value).toISOString().slice(0,16):'';
  const openBannerDialog=(item=null)=>{bannerForm.reset();bannerForm.elements.id.value=item?.id||'';bannerForm.elements.title.value=item?.title||'';bannerForm.elements.body.value=item?.body||'';bannerForm.elements.target_url.value=item?.target_url||'';bannerForm.elements.placement.value=item?.placement||'home';bannerForm.elements.starts_at.value=toLocalInput(item?.starts_at);bannerForm.elements.ends_at.value=toLocalInput(item?.ends_at);bannerForm.elements.is_active.checked=item?bool(item.is_active):true;setText('[data-banner-dialog-title]',item?'Bannerı düzenle':'Yeni banner');bannerDialog.showModal();};
  bannerForm.addEventListener('submit',async(event)=>{event.preventDefault();const id=bannerForm.elements.id.value;const payload=Object.fromEntries(new FormData(bannerForm).entries());payload.is_active=bannerForm.elements.is_active.checked;delete payload.id;try{await adminApi(id?`/banners/${id}`:'/banners',{method:id?'PUT':'POST',body:JSON.stringify(payload)});closeBannerDialog();showToast('Banner kaydedildi.');await loadBanners();}catch(error){handleError(error);}});
  const loadBanners=async()=>{const box=root.querySelector('[data-admin-banners]');loadingState(box);const data=await adminApi('/banners');state.banners=data.items||[];setResultCount('banners',state.banners.length);box.replaceChildren();if(!state.banners.length){box.append(emptyState('Henüz banner yok','Web veya mobil için ilk kampanya alanını oluşturabilirsin.'));return;}state.banners.forEach((item)=>{const row=el('article','admin-record');const leading=el('span','admin-record-leading banner','B');const content=el('div','admin-record-content');const title=el('div','admin-record-title');title.append(el('strong','',item.title),badge(bool(item.is_active)?'Aktif':'Pasif',bool(item.is_active)?'active':'neutral'),badge(item.placement,'teal'));content.append(title,el('p','',item.body||item.target_url||'Açıklama eklenmemiş.'),el('small','',`${item.starts_at?formatDate(item.starts_at):'Hemen'} — ${item.ends_at?formatDate(item.ends_at):'Süresiz'}`));const actions=el('div','admin-record-actions');actions.append(actionButton('Düzenle',()=>openBannerDialog(item),'primary'),actionButton('Sil',async()=>{if(!(await window.siteConfirm(`“${item.title}” bannerı kalıcı olarak kaldırılacak.`,{title:'Banner silinsin mi?',confirmText:'Bannerı sil'})))return;try{await adminApi(`/banners/${item.id}`,{method:'DELETE'});showToast('Banner silindi.');await loadBanners();}catch(error){handleError(error);}},'danger'));row.append(leading,content,actions);box.append(row);});};

  const loadPrivacy=async()=>{const box=root.querySelector('[data-admin-privacy]');loadingState(box);const data=await adminApi('/privacy/requests');const items=data.items||[];box.replaceChildren();if(!items.length){box.append(emptyState('Bekleyen KVKK talebi yok','Yeni bir başvuru geldiğinde kimlik ve talep bilgileri burada görünecek.'));return;}items.forEach((item)=>{const row=el('article','admin-record');const leading=el('span','admin-record-leading privacy','K');const content=el('div','admin-record-content');const title=el('div','admin-record-title');title.append(el('strong','',`${item.request_type} · ${item.display_name}`),badge(statusLabels[item.status]||item.status,item.status));content.append(title,el('p','',item.details||'Açıklama yok'),el('small','',`${item.email} · ${formatDate(item.created_at)}`));const actions=el('div','admin-record-actions');['processing','completed','rejected'].forEach((status)=>actions.append(actionButton(statusLabels[status]||status,async()=>{try{await adminApi(`/privacy/requests/${item.id}`,{method:'PUT',body:JSON.stringify({status})});showToast('KVKK talebi güncellendi.');await loadPrivacy();}catch(error){handleError(error);}},status==='rejected'?'danger':'')));row.append(leading,content,actions);box.append(row);});};
  const loadAudit=async()=>{const box=root.querySelector('[data-admin-audit]');loadingState(box);const data=await adminApi('/audit');const items=data.items||[];box.replaceChildren();if(!items.length){box.append(emptyState('Denetim kaydı yok','Kritik yönetim işlemleri burada saklanacak.'));return;}items.forEach((item)=>{const row=el('article','admin-audit-row');row.append(el('span','admin-audit-marker','•'));const content=el('div');content.append(el('strong','',actionLabels[item.action]||item.action),el('small','',`${item.admin_name} · ${item.entity_type} ${item.entity_id||''}`));row.append(content,el('time','',formatDate(item.created_at)));box.append(row);});};

  const trustDecision=async(path,status,title,description)=>{
    const values=await window.siteFormModal({eyebrow:'DENETİMLİ YÖNETİM İŞLEMİ',title,description,confirmText:'Kararı uygula',fields:[{name:'note',label:'Yönetim notu',type:'textarea',minLength:5,placeholder:'Kararın dayanağını en az 5 karakterle yaz…'}],validate:(input)=>input.note.trim().length<5?'Yönetim notu en az 5 karakter olmalıdır.':''});
    if(!values)return;
    await adminApi(path,{method:'PUT',body:JSON.stringify({status,note:values.note.trim()})});
    showToast('Yönetim kararı kaydedildi.');
    await Promise.all([loadTrust(),loadOverview()]);
  };
  const trustRow=(leading,title,copy,meta,actions)=>{const row=el('article','admin-record');const icon=el('span','admin-record-leading trust',leading);const content=el('div','admin-record-content');content.append(el('strong','',title),el('p','',copy),el('small','',meta));const actionBox=el('div','admin-record-actions');actions.forEach(([label,run,tone])=>actionBox.append(actionButton(label,()=>run().catch(handleError),tone)));row.append(icon,content,actionBox);return row;};
  const loadTrust=async()=>{
    const boxes={engagements:root.querySelector('[data-admin-engagements]'),reviews:root.querySelector('[data-admin-review-queue]'),risks:root.querySelector('[data-admin-risks]'),beta:root.querySelector('[data-admin-beta-feedback]'),members:root.querySelector('[data-admin-beta-members]')};
    Object.values(boxes).forEach(loadingState);
    const data=await adminApi('/trust-operations');
    const engagements=data.engagements||[],reviews=data.reviews||[],risks=data.risk_signals||[],beta=data.beta_feedback||[],members=data.beta_members||[];
    const total=engagements.length+reviews.length+risks.length+beta.length;const nav=root.querySelector('[data-nav-count="trust"]');if(nav)nav.textContent=total?number.format(total):'';
    [['engagements',engagements],['reviews',reviews],['risks',risks],['beta',beta]].forEach(([key,items])=>setResultCount(key,items.length));
    setResultCount('beta-members',members.length,' kullanıcı');
    boxes.engagements.replaceChildren();if(!engagements.length)boxes.engagements.append(emptyState('Bekleyen iş kaydı yok','Yeni anlaşmazlıklar ve tamamlanma onayları burada görünür.'));engagements.forEach((item)=>boxes.engagements.append(trustRow('İ',item.service_name_snapshot,`${item.requester_name} → ${item.provider_name}`,`${statusLabels[item.status]||item.status} · ${formatDate(item.updated_at)}${item.dispute_reason?` · ${item.dispute_reason}`:''}`,[['Tamamlandı',()=>trustDecision(`/engagements/${item.id}`,'completed','İşi tamamlandı olarak kapat','Tarafların kayıtları ve kanıtları incelendikten sonra işi tamamla.'),'primary'],['İptal et',()=>trustDecision(`/engagements/${item.id}`,'canceled','İşi iptal et','İşi yönetici kararıyla iptal et ve gerekçeyi denetim kaydına yaz.'),'danger']])));
    boxes.reviews.replaceChildren();if(!reviews.length)boxes.reviews.append(emptyState('Bekleyen değerlendirme yok','İnceleme gereken değerlendirmeler burada görünür.'));reviews.forEach((item)=>boxes.reviews.append(trustRow('★',`${item.rating}/5 · ${item.service_name_snapshot}`,item.comment||'Yazılı yorum yok',`${item.author_name} → ${item.reviewed_name} · ${formatDate(item.submitted_at)}`,[['Yayınla',()=>trustDecision(`/reviews/${item.id}`,'published','Değerlendirmeyi yayınla','Değerlendirmenin tamamlanmış işe ait olduğunu ve kurallara uyduğunu onayla.'),'primary'],['Gizle',()=>trustDecision(`/reviews/${item.id}`,'hidden','Değerlendirmeyi gizle','İçeriği inceleme için görünmez yap.'),'danger']])));
    boxes.risks.replaceChildren();if(!risks.length)boxes.risks.append(emptyState('Açık risk sinyali yok','Otomatik güvenlik işaretleri burada görünür.'));risks.forEach((item)=>boxes.risks.append(trustRow('!',`${item.signal_type} · ${item.score}/100`,item.user_name||'Sistem sinyali',`${statusLabels[item.status]||item.status} · ${formatDate(item.created_at)}`,[['Doğrula',()=>trustDecision(`/risk-signals/${item.id}`,'confirmed','Risk sinyalini doğrula','Kanıtı inceleyip sinyali doğrulanmış olarak kapat.'),'danger'],['Yanlış alarm',()=>trustDecision(`/risk-signals/${item.id}`,'dismissed','Risk sinyalini kapat','Sinyalin neden yanlış alarm olduğunu kaydet.'),'primary']])));
    boxes.beta.replaceChildren();if(!beta.length)boxes.beta.append(emptyState('Açık beta geri bildirimi yok','Beta kullanıcılarının bildirimleri burada görünür.'));beta.forEach((item)=>boxes.beta.append(trustRow('β',item.title,item.details,`${item.user_name} · ${item.kind} · ${formatDate(item.created_at)}`,[['Planlandı',()=>trustDecision(`/beta-feedback/${item.id}`,'planned','Geri bildirimi planla','Ürün planına alınma notunu kaydet.'),'primary'],['Kapat',()=>trustDecision(`/beta-feedback/${item.id}`,'closed','Geri bildirimi kapat','Sonuç ve gerekçeyi kaydet.'),'secondary']])));
    boxes.members.replaceChildren();if(!members.length)boxes.members.append(emptyState('Beta kullanıcısı yok','Davet koduyla katılan kullanıcılar burada görünür.'));members.forEach((item)=>boxes.members.append(trustRow('B',item.display_name,item.enabled?'Beta erişimi açık':'Beta erişimi kapalı',`${item.email_hint}@… · Katılım ${formatDate(item.joined_at)}`,[])));
  };

  root.querySelector('[data-create-beta-invite]')?.addEventListener('click',async()=>{
    const values=await window.siteFormModal({eyebrow:'KAPALI BETA',title:'Yeni davet kodu oluştur',description:'Kod yalnız bu işlemden sonra bir kez gösterilir.',confirmText:'Davet oluştur',fields:[{name:'label',label:'Davet etiketi',type:'text',minLength:2,placeholder:'Örn. Ağustos test grubu'},{name:'max_uses',label:'Kullanım sınırı',type:'number',value:'1'},{name:'expires_in_days',label:'Geçerlilik (gün)',type:'number',value:'30'}]});
    if(!values)return;
    try{const invite=await adminApi('/beta-invites',{method:'POST',body:JSON.stringify({label:values.label,max_uses:Number(values.max_uses||1),expires_in_days:Number(values.expires_in_days||30)})});await window.siteConfirm(`Davet kodu: ${invite.code}\n\nBu kod daha sonra tekrar gösterilmez. Güvenli bir kanaldan paylaş.`,{title:'Beta daveti hazır',confirmText:'Kodu gördüm',danger:false,cancelText:''});}catch(error){handleError(error);}
  });

  const loaders={overview:loadOverview,reports:loadReports,listings:loadListings,trust:loadTrust,users:loadUsers,categories:loadCategories,banners:loadBanners,privacy:loadPrivacy,audit:loadAudit};
  const switchTab=(tab,{updateHash=true}={})=>{if(!pageMeta[tab])tab='overview';state.currentTab=tab;root.querySelectorAll('[data-admin-tab]').forEach((button)=>button.classList.toggle('active',button.dataset.adminTab===tab));root.querySelectorAll('[data-admin-panel]').forEach((panel)=>{panel.hidden=panel.dataset.adminPanel!==tab;});const [crumb,title,subtitle]=pageMeta[tab];setText('[data-admin-breadcrumb]',crumb);setText('[data-admin-title]',title);setText('[data-admin-subtitle]',subtitle);if(updateHash)history.replaceState(null,'',`#${tab}`);root.querySelector('[data-admin-sidebar]').classList.remove('open');document.body.classList.remove('admin-menu-open');loaders[tab]().catch(handleError);};
  root.querySelectorAll('[data-admin-tab]').forEach((button)=>button.addEventListener('click',()=>switchTab(button.dataset.adminTab)));
  root.querySelectorAll('[data-go-tab]').forEach((button)=>button.addEventListener('click',()=>switchTab(button.dataset.goTab)));
  root.querySelector('[data-admin-refresh]').addEventListener('click',()=>loaders[state.currentTab]().then(()=>showToast('Veriler yenilendi.')).catch(handleError));
  root.querySelector('[data-admin-menu]').addEventListener('click',()=>{root.querySelector('[data-admin-sidebar]').classList.add('open');document.body.classList.add('admin-menu-open');});
  root.querySelector('[data-admin-menu-close]').addEventListener('click',()=>{root.querySelector('[data-admin-sidebar]').classList.remove('open');document.body.classList.remove('admin-menu-open');});
  root.querySelector('[data-report-filters]').addEventListener('submit',(event)=>{event.preventDefault();loadReports().catch(handleError);});
  root.querySelector('[data-listing-filters]').addEventListener('submit',(event)=>{event.preventDefault();loadListings().catch(handleError);});
  root.querySelector('[data-open-pending-listings]')?.addEventListener('click',()=>{
    const form=root.querySelector('[data-listing-filters]');
    if(form?.elements?.status)form.elements.status.value='pending';
    loadListings().catch(handleError);
    root.querySelector('[data-admin-listings]')?.scrollIntoView({behavior:'smooth',block:'start'});
  });
  root.querySelector('[data-user-filters]').addEventListener('submit',(event)=>{event.preventDefault();loadUsers().catch(handleError);});
  root.querySelector('[data-category-create]').addEventListener('click',()=>openCategoryDialog());
  root.querySelector('[data-category-search]').addEventListener('input',(event)=>{state.categorySearch=event.target.value;renderCategories();});
  root.querySelector('[data-banner-create]').addEventListener('click',()=>openBannerDialog());
  root.querySelector('[data-admin-policy-form]').addEventListener('submit',async(event)=>{event.preventDefault();const form=event.currentTarget;try{const policy=await adminApi('/policies',{method:'POST',body:JSON.stringify(Object.fromEntries(new FormData(form).entries()))});if(await window.siteConfirm('Hukuk ekibi onayladıysa metni şimdi kullanıcılara yayımlayabilirsin.',{title:'Yasal metin yayımlansın mı?',confirmText:'Şimdi yayımla',danger:false}))await adminApi(`/policies/${policy.id}/publish`,{method:'POST'});form.reset();showToast('Yasal metin kaydedildi.');}catch(error){handleError(error);}});
  root.querySelector('[data-admin-logout]').addEventListener('click',async()=>{try{await adminApi('/auth/logout',{method:'POST'});}finally{window.location.assign('/admin/giris');}});
  window.addEventListener('hashchange',()=>switchTab(location.hash.slice(1)||'overview',{updateHash:false}));
  switchTab(location.hash.slice(1)||'overview',{updateHash:false});
})();
