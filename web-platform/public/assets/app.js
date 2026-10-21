const preAuthPaths = new Set([
  '/api/v1/auth/login',
  '/api/v1/auth/register',
  '/api/v1/auth/password/forgot',
  '/api/v1/auth/password/reset',
]);

const cookieValue = (name) => document.cookie
  .split('; ')
  .find((item) => item.startsWith(`${name}=`))
  ?.split('=')[1];

const api = async (path, options = {}, allowCsrfRecovery = true) => {
  const cookies = document.cookie.split('; ');
  const sessionCsrf = cookies.find((item) => item.startsWith('ankara_csrf='))?.split('=')[1];
  const preAuthCsrf = cookies.find((item) => item.startsWith('ankara_pre_auth_csrf='))?.split('=')[1];
  // Giriş/kayıt işlemleri daima yeni pre-auth tokenını kullanır. Eski veya
  // süresi dolmuş bir oturum çerezi doğru şifreyle girişi engellememelidir.
  const csrf = preAuthPaths.has(path)
    ? (options.csrfToken || preAuthCsrf)
    : (options.csrfToken || sessionCsrf || preAuthCsrf);
  const headers = { Accept: 'application/json', ...(options.headers || {}) };
  if (options.body && !(options.body instanceof FormData)) headers['Content-Type'] = 'application/json';
  if (csrf) headers['X-CSRF-Token'] = decodeURIComponent(csrf);
  const { csrfToken: _csrfToken, ...fetchOptions } = options;
  const response = await fetch(path, { credentials: 'same-origin', ...fetchOptions, headers });
  const payload = await response.json().catch(() => ({ success: false, error: { message: 'Sunucu cevabı okunamadı.' } }));
  if ((!response.ok || !payload.success)
    && response.status === 419
    && preAuthPaths.has(path)
    && allowCsrfRecovery) {
    const refreshResponse = await fetch('/api/v1/auth/csrf', {
      credentials: 'same-origin',
      headers: { Accept: 'application/json' },
      cache: 'no-store',
    });
    const refreshPayload = await refreshResponse.json().catch(() => null);
    const freshToken = refreshPayload?.data?.csrf_token
      || decodeURIComponent(cookieValue('ankara_pre_auth_csrf') || '');
    if (refreshResponse.ok && freshToken) {
      return api(path, { ...options, csrfToken: freshToken }, false);
    }
  }
  if (!response.ok || !payload.success) {
    const error = new Error(payload.error?.message || 'İşlem başarısız.');
    error.status = response.status;
    error.code = payload.error?.code;
    throw error;
  }
  return payload.data;
};

const toastRegion = (() => {
  const region = document.createElement('div');
  region.className = 'site-toast-region';
  region.setAttribute('aria-live', 'polite');
  region.setAttribute('aria-atomic', 'false');
  document.body.append(region);
  return region;
})();

const showToast = (message, type = 'info', timeout = 4200) => {
  const toast = document.createElement('div');
  toast.className = `site-toast ${type}`;
  toast.setAttribute('role', type === 'error' ? 'alert' : 'status');
  const icon = document.createElement('span');
  icon.className = 'site-toast-icon';
  icon.textContent = type === 'error' ? '!' : type === 'success' ? '✓' : 'i';
  const copy = document.createElement('span');
  copy.textContent = String(message || 'İşlem tamamlandı.');
  const close = document.createElement('button');
  close.type = 'button';
  close.setAttribute('aria-label', 'Bildirimi kapat');
  close.textContent = '×';
  const remove = () => { toast.classList.add('leaving'); window.setTimeout(() => toast.remove(), 180); };
  close.addEventListener('click', remove);
  toast.append(icon, copy, close);
  toastRegion.append(toast);
  window.setTimeout(remove, timeout);
  return toast;
};

let activeSiteConfirm;
const siteConfirm = (message, options = {}) => new Promise((resolve) => {
  activeSiteConfirm?.(false);

  const dialog = document.createElement('dialog');
  const isDanger = options.danger !== false;
  dialog.className = `site-confirm-dialog ${isDanger ? 'danger' : 'standard'}`;
  dialog.setAttribute('aria-labelledby', 'site-confirm-title');
  dialog.setAttribute('aria-describedby', 'site-confirm-message');

  const panel = document.createElement('div');
  panel.className = 'site-confirm-panel';

  const icon = document.createElement('span');
  icon.className = 'site-confirm-icon';
  icon.setAttribute('aria-hidden', 'true');
  icon.innerHTML = isDanger
    ? '<svg viewBox="0 0 24 24"><path d="M12 8v5m0 3.2v.1M10.3 4.8 3.2 17.1a2 2 0 0 0 1.7 3h14.2a2 2 0 0 0 1.7-3L13.7 4.8a2 2 0 0 0-3.4 0Z"/></svg>'
    : '<svg viewBox="0 0 24 24"><path d="M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20Zm0-10v5m0-9.2v.1"/></svg>';

  const copy = document.createElement('div');
  copy.className = 'site-confirm-copy';
  const eyebrow = document.createElement('span');
  eyebrow.className = 'site-confirm-eyebrow';
  eyebrow.textContent = options.eyebrow || 'ONAY GEREKİYOR';
  const title = document.createElement('h2');
  title.id = 'site-confirm-title';
  title.textContent = options.title || 'Bu işlemi onaylıyor musun?';
  const description = document.createElement('p');
  description.id = 'site-confirm-message';
  description.textContent = String(message || 'Devam etmek istediğine emin misin?');
  copy.append(eyebrow, title, description);

  const actions = document.createElement('div');
  actions.className = 'site-confirm-actions';
  const cancelButton = document.createElement('button');
  cancelButton.type = 'button';
  cancelButton.className = 'site-confirm-cancel';
  cancelButton.textContent = options.cancelText || 'Vazgeç';
  const confirmButton = document.createElement('button');
  confirmButton.type = 'button';
  confirmButton.className = 'site-confirm-approve';
  confirmButton.textContent = options.confirmText || 'Evet, devam et';
  actions.append(cancelButton, confirmButton);
  panel.append(icon, copy, actions);
  dialog.append(panel);
  document.body.append(dialog);

  let settled = false;
  const finish = (value) => {
    if (settled) return;
    settled = true;
    activeSiteConfirm = undefined;
    dialog.classList.add('closing');
    cancelButton.disabled = true;
    confirmButton.disabled = true;
    window.setTimeout(() => {
      if (dialog.open) dialog.close();
      dialog.remove();
    }, 160);
    resolve(value);
  };
  activeSiteConfirm = finish;
  cancelButton.addEventListener('click', () => finish(false));
  confirmButton.addEventListener('click', () => finish(true));
  dialog.addEventListener('cancel', (event) => { event.preventDefault(); finish(false); });
  dialog.addEventListener('click', (event) => { if (event.target === dialog) finish(false); });
  dialog.showModal();
  window.requestAnimationFrame(() => cancelButton.focus());
});

window.siteConfirm = siteConfirm;

const siteFormModal = (options = {}) => new Promise((resolve) => {
  const dialog = document.createElement('dialog');
  dialog.className = 'site-confirm-dialog site-form-dialog standard';
  const form = document.createElement('form');
  form.className = 'site-confirm-panel site-form-panel';
  form.method = 'dialog';

  const copy = document.createElement('div');
  copy.className = 'site-confirm-copy';
  const eyebrow = document.createElement('span');
  eyebrow.className = 'site-confirm-eyebrow';
  eyebrow.textContent = options.eyebrow || 'BİLGİLERİ TAMAMLA';
  const title = document.createElement('h2');
  title.textContent = options.title || 'İşleme devam et';
  const description = document.createElement('p');
  description.textContent = options.description || '';
  copy.append(eyebrow, title, description);

  const fields = document.createElement('div');
  fields.className = 'site-form-fields';
  (options.fields || []).forEach((field) => {
    const label = document.createElement('label');
    label.textContent = field.label || field.name;
    let input;
    if (field.type === 'select') {
      input = document.createElement('select');
      (field.options || []).forEach((choice) => {
        const option = document.createElement('option');
        option.value = choice.value;
        option.textContent = choice.label;
        option.selected = String(choice.value) === String(field.value ?? '');
        input.append(option);
      });
    } else if (field.type === 'textarea') {
      input = document.createElement('textarea');
      input.rows = field.rows || 4;
      input.value = field.value ?? '';
    } else {
      input = document.createElement('input');
      input.type = field.type || 'text';
      input.value = field.value ?? '';
      if (field.min !== undefined) input.min = String(field.min);
      if (field.max !== undefined) input.max = String(field.max);
    }
    input.name = field.name;
    input.required = field.required !== false;
    if (field.placeholder) input.placeholder = field.placeholder;
    if (field.minLength) input.minLength = field.minLength;
    label.append(input);
    fields.append(label);
  });

  const error = document.createElement('div');
  error.className = 'site-form-error';
  error.setAttribute('role', 'alert');
  const actions = document.createElement('div');
  actions.className = 'site-confirm-actions';
  const cancel = document.createElement('button');
  cancel.type = 'button';
  cancel.className = 'site-confirm-cancel';
  cancel.textContent = options.cancelText || 'Vazgeç';
  const submit = document.createElement('button');
  submit.type = 'submit';
  submit.className = 'site-confirm-approve';
  submit.textContent = options.confirmText || 'Kaydet';
  actions.append(cancel, submit);
  form.append(copy, fields, error, actions);
  dialog.append(form);
  document.body.append(dialog);

  let settled = false;
  const finish = (value) => {
    if (settled) return;
    settled = true;
    dialog.classList.add('closing');
    window.setTimeout(() => { if (dialog.open) dialog.close(); dialog.remove(); }, 160);
    resolve(value);
  };
  cancel.addEventListener('click', () => finish(null));
  dialog.addEventListener('cancel', (event) => { event.preventDefault(); finish(null); });
  dialog.addEventListener('click', (event) => { if (event.target === dialog) finish(null); });
  form.addEventListener('submit', (event) => {
    event.preventDefault();
    if (!form.reportValidity()) return;
    const values = Object.fromEntries(new FormData(form).entries());
    const validationMessage = options.validate?.(values);
    if (validationMessage) { error.textContent = validationMessage; return; }
    finish(values);
  });
  dialog.showModal();
  window.requestAnimationFrame(() => form.querySelector('input,select,textarea')?.focus());
});

window.siteFormModal = siteFormModal;

const cookieConsent = document.querySelector('[data-cookie-consent]');
if (cookieConsent) {
  const storageKey = 'cookie-consent-v1';
  const options = cookieConsent.querySelector('[data-cookie-options]');
  const analytics = cookieConsent.querySelector('[data-cookie-analytics]');
  const marketing = cookieConsent.querySelector('[data-cookie-marketing]');
  const saveButton = cookieConsent.querySelector('[data-cookie-save]');
  const manageButton = cookieConsent.querySelector('[data-cookie-manage]');
  const read = () => {
    try { return JSON.parse(localStorage.getItem(storageKey) || 'null'); } catch (_) { return null; }
  };
  const write = (preferences) => {
    const value = { essential: true, ...preferences, saved_at: new Date().toISOString() };
    localStorage.setItem(storageKey, JSON.stringify(value));
    cookieConsent.hidden = true;
    window.dispatchEvent(new CustomEvent('cookie-consent-changed', { detail: value }));
  };
  const open = (manage = false) => {
    const existing = read();
    analytics.checked = existing?.analytics === true;
    marketing.checked = existing?.marketing === true;
    cookieConsent.hidden = false;
    options.hidden = !manage;
    saveButton.hidden = !manage;
    manageButton.hidden = manage;
  };
  if (!read()) open(false);
  cookieConsent.querySelector('[data-cookie-accept]')?.addEventListener('click', () => write({ analytics: true, marketing: true }));
  cookieConsent.querySelector('[data-cookie-reject]')?.addEventListener('click', () => write({ analytics: false, marketing: false }));
  manageButton?.addEventListener('click', () => open(true));
  saveButton?.addEventListener('click', () => write({ analytics: analytics.checked, marketing: marketing.checked }));
  document.querySelector('[data-cookie-settings]')?.addEventListener('click', () => open(true));
}

const startRealtime = (onPublication) => {
  let socket;
  let reconnectTimer;
  let refreshTimer;
  let stopped = false;
  let retryMs = 1000;

  const scheduleReconnect = () => {
    if (stopped || reconnectTimer) return;
    reconnectTimer = window.setTimeout(() => {
      reconnectTimer = undefined;
      connect();
    }, retryMs);
    retryMs = Math.min(retryMs * 2, 30000);
  };

  const connect = async () => {
    try {
      const connection = await api('/api/v1/realtime/connection');
      if (!connection.enabled || !connection.url || !connection.token || stopped) return;
      socket = new WebSocket(connection.url);
      socket.addEventListener('open', () => {
        retryMs = 1000;
        socket.send(JSON.stringify({
          id: 1,
          connect: { token: connection.token, name: 'ankara-web', version: '1.0.0' },
        }));
        const expiresAt = Date.parse(connection.expires_at || '');
        if (Number.isFinite(expiresAt)) {
          clearTimeout(refreshTimer);
          refreshTimer = window.setTimeout(() => socket?.close(1000, 'token refresh'), Math.max(1000, expiresAt - Date.now() - 30000));
        }
      });
      socket.addEventListener('message', ({ data }) => {
        String(data).split('\n').filter(Boolean).forEach((line) => {
          let frame;
          try { frame = JSON.parse(line); } catch (_) { return; }
          if (frame && Object.keys(frame).length === 0) {
            if (socket?.readyState === WebSocket.OPEN) socket.send('{}');
            return;
          }
          if (frame?.id === 1 && frame.error) socket?.close(1008, 'connect rejected');
          const publication = frame?.push?.pub;
          if (publication?.data) {
            onPublication({ channel: frame.push.channel, ...publication.data });
          }
        });
      });
      socket.addEventListener('close', scheduleReconnect);
      socket.addEventListener('error', () => socket?.close());
    } catch (_) {
      // Authenticated pages keep their polling fallback when realtime is unavailable.
      scheduleReconnect();
    }
  };

  connect();
  window.addEventListener('pagehide', () => {
    stopped = true;
    clearTimeout(reconnectTimer);
    clearTimeout(refreshTimer);
    socket?.close(1000, 'page closed');
  }, { once: true });
};

const adminApi = async (path, options = {}) => {
  const cookies = document.cookie.split('; ');
  const sessionCsrf = cookies.find((item) => item.startsWith('ankara_admin_csrf='))?.split('=')[1];
  const preAuthCsrf = cookies.find((item) => item.startsWith('ankara_admin_pre_csrf='))?.split('=')[1];
  // Login must use its short-lived pre-auth token. A stale management-session
  // cookie can remain after a deployment or server-side session expiry.
  const csrf = path === '/auth/login' ? preAuthCsrf : (sessionCsrf || preAuthCsrf);
  const headers = { Accept: 'application/json', ...(options.headers || {}) };
  if (options.body && !(options.body instanceof FormData)) headers['Content-Type'] = 'application/json';
  if (csrf) headers['X-CSRF-Token'] = decodeURIComponent(csrf);
  const response = await fetch(`/api/v1/admin${path}`, { credentials: 'same-origin', ...options, headers });
  const payload = await response.json().catch(() => ({ success: false, error: { message: 'Sunucu cevabı okunamadı.' } }));
  if (!response.ok || !payload.success) {
    const error = new Error(payload.error?.message || 'İşlem başarısız.');
    error.status = response.status;
    throw error;
  }
  return payload.data;
};

document.querySelector('[data-admin-login-form]')?.addEventListener('submit', async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  const message = form.querySelector('[data-form-message]');
  const values = Object.fromEntries(new FormData(form).entries());
  message.textContent = '';
  try {
    await adminApi('/auth/login', { method: 'POST', body: JSON.stringify(values) });
    sessionStorage.removeItem('admin-csrf-recovery');
    window.location.assign('/admin');
  } catch (error) {
    if (error.status === 419 && sessionStorage.getItem('admin-csrf-recovery') !== '1') {
      sessionStorage.setItem('admin-csrf-recovery', '1');
      document.cookie = 'ankara_admin_csrf=; Max-Age=0; path=/; SameSite=Strict';
      document.cookie = 'ankara_admin_pre_csrf=; Max-Age=0; path=/; SameSite=Strict';
      window.location.reload();
      return;
    }
    sessionStorage.removeItem('admin-csrf-recovery');
    message.textContent = error.message;
  }
});

const TURKEY_CENTER = [39.0, 35.0];
const TURKEY_DEFAULT_ZOOM = 6;
const TURKEY_COORDINATE_BOUNDS = {
  south: 35.5,
  west: 25.0,
  north: 42.5,
  east: 45.0,
};
const TURKEY_MAP_BOUNDS = [[33.0, 21.0], [45.0, 49.0]];
const USER_AREA_RADIUS_METERS = 15000;

const locationErrorMessage = (error) => {
  if (!window.isSecureContext) return 'Konum yalnızca güvenli HTTPS bağlantısında çalışır.';
  if (error?.code === 1) return 'Konum izni kapalı. Adres çubuğundaki kilit/konum simgesinden izni açıp tekrar dene.';
  if (error?.code === 2) return 'Cihaz konumu belirlenemedi. Konum hizmetini açıp tekrar dene.';
  if (error?.code === 3) return 'Konum alınması zaman aşımına uğradı. Tekrar deneyebilirsin.';
  return 'Konum alınamadı. Tarayıcı iznini kontrol edip tekrar dene.';
};

const validCoordinates = (latitude, longitude) => Number.isFinite(latitude)
  && Number.isFinite(longitude)
  && latitude >= -90 && latitude <= 90
  && longitude >= -180 && longitude <= 180;
const validTurkeyCoordinates = (latitude, longitude) => validCoordinates(latitude, longitude)
  && latitude >= TURKEY_COORDINATE_BOUNDS.south
  && latitude <= TURKEY_COORDINATE_BOUNDS.north
  && longitude >= TURKEY_COORDINATE_BOUNDS.west
  && longitude <= TURKEY_COORDINATE_BOUNDS.east;

const requestBrowserLocation = () => new Promise((resolve, reject) => {
  if (!navigator.geolocation) {
    reject(new Error('Tarayıcın konum desteği yok. Haritadan bölgeni seçebilirsin.'));
    return;
  }
  const accept = (position) => {
    const latitude = Number(position?.coords?.latitude);
    const longitude = Number(position?.coords?.longitude);
    if (!validCoordinates(latitude, longitude)) {
      reject(new Error('Tarayıcı geçerli bir konum döndürmedi. Tekrar deneyebilirsin.'));
      return;
    }
    resolve(position);
  };
  navigator.geolocation.getCurrentPosition(accept, (firstError) => {
    if (firstError?.code === 1) {
      reject(new Error(locationErrorMessage(firstError)));
      return;
    }
    navigator.geolocation.getCurrentPosition(accept, (secondError) => {
      reject(new Error(locationErrorMessage(secondError || firstError)));
    }, { enableHighAccuracy: false, timeout: 10000, maximumAge: 600000 });
  }, { enableHighAccuracy: true, timeout: 12000, maximumAge: 120000 });
});

const openHomeAtLocation = async (button) => {
  const original = button?.textContent;
  if (button) { button.disabled = true; button.textContent = 'Konum alınıyor…'; }
  try {
    const { coords } = await requestBrowserLocation();
    localStorage.setItem('location-onboarding', 'allowed');
    const url = new URL(window.location.href);
    url.searchParams.set('lat', coords.latitude.toFixed(6));
    url.searchParams.set('lng', coords.longitude.toFixed(6));
    url.hash = 'kesfet-haritasi';
    window.location.assign(url);
  } catch (error) {
    showToast(error.message, 'error');
  } finally {
    if (button) { button.disabled = false; button.textContent = original; }
  }
};

document.querySelector('[data-nearby]')?.addEventListener('click', (event) => openHomeAtLocation(event.currentTarget));

const homeSearchForm = document.querySelector('.search-form');
const categorySelect = document.querySelector('[data-category-select]');
const categoryTrigger = categorySelect?.querySelector('.category-field');
const categoryMenu = categorySelect?.querySelector('.category-menu');
const categoryInput = categorySelect?.querySelector('input[name="category"]');
const categoryLabel = categorySelect?.querySelector('[data-category-label]');

const closeCategoryMenu = () => {
  if (!categorySelect || !categoryMenu || !categoryTrigger) return;
  categorySelect.classList.remove('open');
  categoryMenu.hidden = true;
  categoryTrigger.setAttribute('aria-expanded', 'false');
};

const chooseCategory = (value, label) => {
  if (!categorySelect || !categoryInput || !categoryLabel) return;
  categoryInput.value = value || '';
  categoryLabel.textContent = label || 'Tüm kategoriler';
  // The quick category selector is authoritative. Selecting "Tüm kategoriler"
  // must also clear stale choices left open in the detailed filter panel.
  homeSearchForm?.querySelectorAll('[name="categories[]"]').forEach((input) => {
    input.checked = Boolean(value) && String(input.value) === String(value);
  });
  categorySelect.querySelectorAll('[data-category-option]').forEach((option) => {
    const selected = option.dataset.value === categoryInput.value;
    option.classList.toggle('selected', selected);
    option.setAttribute('aria-selected', selected ? 'true' : 'false');
  });
  closeCategoryMenu();
  renderActiveFilters();
  scheduleVisibleMapSearch();
};

categoryTrigger?.addEventListener('click', () => {
  const opening = categoryMenu?.hidden ?? true;
  if (!categoryMenu) return;
  categoryMenu.hidden = !opening;
  categorySelect.classList.toggle('open', opening);
  categoryTrigger.setAttribute('aria-expanded', opening ? 'true' : 'false');
  if (opening) categoryMenu.querySelector('.selected,[data-category-option]')?.focus();
});
categorySelect?.querySelectorAll('[data-category-option]').forEach((option) => option.addEventListener('click', () => {
  chooseCategory(option.dataset.value || '', option.dataset.label || option.textContent.trim());
  categoryTrigger?.focus();
}));

const advancedFilters = document.querySelector('[data-advanced-filters]');
const filterToggle = document.querySelector('[data-filter-toggle]');
const filterCount = document.querySelector('[data-filter-count]');
const savedSearchList = document.querySelector('[data-saved-search-list]');
const activeFilterSummary = document.querySelector('[data-active-filter-summary]');
const activeFilterChips = document.querySelector('[data-active-filter-chips]');
const radiusFilter = document.querySelector('[data-radius-filter]');
const radiusUnlimited = document.querySelector('[data-radius-unlimited]');
const radiusFilterValue = document.querySelector('[data-radius-filter-value]');
const providerKindChoices = [...document.querySelectorAll('[data-provider-kind-choice]')];
const genderChoices = [...document.querySelectorAll('[data-gender-choice]')];

const setFiltersOpen = (open) => {
  if (!advancedFilters || !filterToggle) return;
  advancedFilters.hidden = !open;
  filterToggle.setAttribute('aria-expanded', open ? 'true' : 'false');
  if (open) advancedFilters.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
};
filterToggle?.addEventListener('click', () => setFiltersOpen(advancedFilters?.hidden === true));
document.querySelector('[data-filter-close]')?.addEventListener('click', () => setFiltersOpen(false));

const currentSearchFilters = () => {
  if (!homeSearchForm) return {};
  const data = new FormData(homeSearchForm);
  const filters = {};
  const textKeys = ['type', 'q', 'lat', 'lng', 'gender', 'provider_kind', 'pricing_unit', 'sort'];
  textKeys.forEach((key) => {
    const value = String(data.get(key) || '').trim();
    if (value) filters[key] = value;
  });
  const categories = data.getAll('categories[]').map(String).filter(Boolean);
  const quickCategory = String(data.get('category') || '');
  if (!categories.length && quickCategory) categories.push(quickCategory);
  if (categories.length) filters.categories = [...new Set(categories)];
  ['available_now', 'open_24_7', 'verified_only'].forEach((key) => {
    if (data.get(key)) filters[key] = true;
  });
  const radius = Number(data.get('radius_meters'));
  if (Number.isFinite(radius) && radius > 0) filters.radius_meters = radius;
  return filters;
};

const knownCategoryLabels = new Map();
const categoryLabelMap = () => {
  const labels = new Map(knownCategoryLabels);
  document.querySelectorAll('[data-filter-label]').forEach((input) => labels.set(String(input.value), input.dataset.filterLabel || input.value));
  document.querySelectorAll('[data-category-option]').forEach((option) => {
    if (option.dataset.value) labels.set(String(option.dataset.value), option.dataset.label || option.textContent.trim());
  });
  return labels;
};

const filterSummaryParts = (filters = currentSearchFilters(), includeVisibleChoices = true) => {
  const labels = categoryLabelMap();
  const parts = [];
  (filters.categories || []).forEach((category) => parts.push(labels.get(String(category)) || String(category)));
  if (filters.q) parts.push(`“${filters.q}”`);
  if (filters.available_now) parts.push('Şu an müsait');
  if (filters.open_24_7) parts.push('7/24 açık');
  if (filters.verified_only) parts.push('Doğrulanmış kullanıcı');
  const visibleProviderKinds = providerKindChoices.filter((input) => input.checked).map((input) => input.value);
  const visibleGenders = genderChoices.filter((input) => input.checked).map((input) => input.value);
  const providerKinds = includeVisibleChoices && visibleProviderKinds.length ? visibleProviderKinds : (filters.provider_kind ? [filters.provider_kind] : []);
  const genders = includeVisibleChoices && visibleGenders.length ? visibleGenders : (filters.gender ? [filters.gender] : []);
  providerKinds.forEach((value) => parts.push(value === 'business' ? 'Kurumsal' : 'Şahıs'));
  genders.forEach((value) => parts.push(value === 'female' ? 'Kadın' : 'Erkek'));
  if (filters.radius_meters) parts.push(`${Math.round(Number(filters.radius_meters) / 1000)} km`);
  return [...new Set(parts.filter(Boolean))];
};

const autoSavedSearchName = (filters) => {
  const parts = filterSummaryParts(filters, false);
  const text = (parts.length ? parts.join(' · ') : 'Tüm ilanlar').slice(0, 80);
  return text.length >= 2 ? text : 'Kayıtlı filtre';
};

const syncChoiceGroup = (choices, hiddenName) => {
  const hidden = homeSearchForm?.elements[hiddenName];
  if (!hidden) return;
  const selected = choices.filter((input) => input.checked);
  hidden.value = selected.length === 1 ? selected[0].value : '';
};

const renderActiveFilters = () => {
  syncChoiceGroup(providerKindChoices, 'provider_kind');
  syncChoiceGroup(genderChoices, 'gender');
  const filters = currentSearchFilters();
  const parts = filterSummaryParts(filters);
  if (radiusFilterValue) radiusFilterValue.textContent = radiusFilter?.disabled ? 'Mesafe sınırı yok' : `${Math.round(Number(radiusFilter.value) / 1000)} km`;
  if (activeFilterSummary && activeFilterChips) {
    activeFilterChips.replaceChildren(...parts.map((part) => createElement('span', '', part)));
    activeFilterSummary.hidden = parts.length === 0;
  }
  if (filterCount) {
    filterCount.textContent = parts.length ? String(parts.length) : '';
    filterCount.hidden = parts.length === 0;
  }
};

homeSearchForm?.addEventListener('submit', () => {
  syncChoiceGroup(providerKindChoices, 'provider_kind');
  syncChoiceGroup(genderChoices, 'gender');
  // Preserve the map anchor for both the quick search and advanced filters.
  // The server may render a fresh result set, but the user returns to the map.
  homeSearchForm.action = '/#kesfet-haritasi';
});

const updateFilterCount = () => {
  renderActiveFilters();
};
homeSearchForm?.addEventListener('change', updateFilterCount);
homeSearchForm?.addEventListener('input', updateFilterCount);
radiusUnlimited?.addEventListener('change', () => {
  if (!radiusFilter) return;
  radiusFilter.disabled = radiusUnlimited.checked;
  renderActiveFilters();
});
providerKindChoices.forEach((input) => input.addEventListener('change', renderActiveFilters));
genderChoices.forEach((input) => input.addEventListener('change', renderActiveFilters));
document.querySelector('[data-clear-active-filters]')?.addEventListener('click', () => {
  homeSearchForm?.querySelectorAll('[name="categories[]"], [name="available_now"], [name="open_24_7"], [name="verified_only"], [data-provider-kind-choice], [data-gender-choice]').forEach((input) => { input.checked = false; });
  if (homeSearchForm?.elements.category) homeSearchForm.elements.category.value = '';
  if (homeSearchForm?.elements.provider_kind) homeSearchForm.elements.provider_kind.value = '';
  if (homeSearchForm?.elements.gender) homeSearchForm.elements.gender.value = '';
  if (radiusFilter) radiusFilter.disabled = true;
  if (radiusUnlimited) radiusUnlimited.checked = true;
  renderActiveFilters();
});
updateFilterCount();

const applySavedSearch = (filters) => {
  const url = new URL('/', window.location.origin);
  Object.entries(filters || {}).forEach(([key, value]) => {
    if (key === 'categories' && Array.isArray(value)) {
      value.forEach((category) => url.searchParams.append('categories[]', category));
    } else if (typeof value === 'boolean') {
      if (value) url.searchParams.set(key, '1');
    } else if (value !== '' && value !== null && value !== undefined) {
      url.searchParams.set(key, String(value));
    }
  });
  if (!url.searchParams.has('type')) url.searchParams.set('type', 'service_offer');
  url.hash = 'kesfet-haritasi';
  window.location.assign(url);
};

const loadSavedSearches = async () => {
  if (!savedSearchList) return;
  try {
    const data = await api('/api/v1/saved-searches');
    savedSearchList.replaceChildren();
    const items = data.items || [];
    if (!items.length) {
      savedSearchList.append(createElement('span', '', 'Henüz kayıtlı araman yok. Filtrelerini seçip “Bu aramayı kaydet” diyebilirsin.'));
      return;
    }
    items.forEach((item) => {
      const row = createElement('div', 'saved-search-row');
      const applyButton = createElement('button', 'saved-search-apply');
      applyButton.type = 'button';
      applyButton.append(createElement('strong', '', item.name), createElement('small', '', item.notification_enabled ? 'Bildirim açık' : 'Kayıtlı filtre'));
      applyButton.addEventListener('click', () => applySavedSearch(item.filters));
      const removeButton = createElement('button', 'saved-search-remove', 'Sil');
      removeButton.type = 'button';
      removeButton.setAttribute('aria-label', `${item.name} aramasını sil`);
      removeButton.addEventListener('click', async () => {
        if (!(await siteConfirm(`“${item.name}” kayıtlı araması kalıcı olarak kaldırılacak.`, {
          title: 'Kayıtlı filtre silinsin mi?',
          confirmText: 'Filtreyi sil',
        }))) return;
        await api(`/api/v1/saved-searches/${encodeURIComponent(item.id)}`, { method: 'DELETE' });
        await loadSavedSearches();
        showToast('Kayıtlı filtre kaldırıldı.', 'success');
      });
      row.append(applyButton, removeButton);
      savedSearchList.append(row);
    });
  } catch (error) {
    savedSearchList.replaceChildren();
    const link = createElement('a', '', 'Aramalarını kaydetmek için giriş yap');
    link.href = '/giris';
    savedSearchList.append(link);
  }
};
loadSavedSearches();

document.querySelector('[data-save-search]')?.addEventListener('click', async (event) => {
  const filters = currentSearchFilters();
  event.currentTarget.disabled = true;
  try {
    await api('/api/v1/saved-searches', {
      method: 'POST',
      body: JSON.stringify({
        name: autoSavedSearchName(filters),
        filters,
        notification_enabled: false,
      }),
    });
    await loadSavedSearches();
    showToast('Filtre favorilerine kaydedildi.', 'success');
  } catch (error) {
    if (error.status === 401) goToLogin({
      type: 'saved_search',
      filters,
      return_to: currentLocalPath(),
    });
    else showToast(error.message, 'error');
  } finally {
    event.currentTarget.disabled = false;
  }
});

const searchSuggestRoot = document.querySelector('[data-search-suggest]');
const searchSuggestInput = searchSuggestRoot?.querySelector('input[name="q"]');
const searchSuggestMenu = searchSuggestRoot?.querySelector('.search-suggestions');
let suggestionTimer;
let suggestionController;
let suggestionItems = [];
let activeSuggestion = -1;

const closeSearchSuggestions = () => {
  if (!searchSuggestMenu || !searchSuggestInput) return;
  searchSuggestMenu.hidden = true;
  searchSuggestInput.setAttribute('aria-expanded', 'false');
  activeSuggestion = -1;
};

const updateSuggestionFocus = () => {
  searchSuggestMenu?.querySelectorAll('.search-suggestion').forEach((button, index) => {
    button.classList.toggle('active', index === activeSuggestion);
    button.setAttribute('aria-selected', index === activeSuggestion ? 'true' : 'false');
  });
};

const useSuggestion = (item) => {
  if (!item) return;
  closeSearchSuggestions();
  if (item.kind === 'category') {
    chooseCategory(item.category_id || item.value || '', item.label || 'Tüm kategoriler');
    if (searchSuggestInput) searchSuggestInput.value = '';
  } else if (searchSuggestInput) {
    searchSuggestInput.value = item.label || searchSuggestInput.value;
  }
  homeSearchForm?.requestSubmit();
};

const renderSearchSuggestions = (items, query) => {
  if (!searchSuggestMenu || !searchSuggestInput) return;
  const categoryItems = items.filter((item) => item.kind === 'category');
  const selectedType = homeSearchForm?.elements?.type?.value;
  suggestionItems = categoryItems.length > 0
    ? categoryItems
    : [{
      kind: 'query',
      label: query,
      subtitle: selectedType === 'service_request'
        ? 'Bu ifadeyle iş ilanlarında ara'
        : 'Bu ifadeyle hizmet verenlerde ara',
    }];
  searchSuggestMenu.replaceChildren();
  const heading = document.createElement('div');
  heading.className = 'search-suggestion-heading';
  heading.textContent = categoryItems.length ? 'Eşleşen kategoriler' : 'Kategori bulunamadı';
  searchSuggestMenu.append(heading);
  suggestionItems.forEach((item, index) => {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'search-suggestion';
    button.setAttribute('role', 'option');
    button.setAttribute('aria-selected', 'false');
    const icon = document.createElement('span');
    icon.className = 'search-suggestion-icon';
    icon.textContent = item.kind === 'category' ? 'K' : '⌕';
    const copy = document.createElement('span');
    copy.className = 'search-suggestion-copy';
    const title = document.createElement('strong');
    title.textContent = item.kind === 'query' ? `“${item.label}” ara` : item.label;
    const subtitle = document.createElement('small');
    subtitle.textContent = item.subtitle || (item.kind === 'category' ? 'Kategori' : 'Genel arama');
    copy.append(title, subtitle);
    const arrow = document.createElement('span');
    arrow.className = 'search-suggestion-arrow';
    arrow.textContent = '→';
    button.append(icon, copy, arrow);
    button.addEventListener('mousedown', (event) => event.preventDefault());
    button.addEventListener('click', () => useSuggestion(item));
    searchSuggestMenu.append(button);
  });
  activeSuggestion = -1;
  searchSuggestMenu.hidden = false;
  searchSuggestInput.setAttribute('aria-expanded', 'true');
};

const loadSearchSuggestions = async () => {
  const query = searchSuggestInput?.value.trim() || '';
  if (query.length < 2) { closeSearchSuggestions(); return; }
  suggestionController?.abort();
  suggestionController = new AbortController();
  try {
    const data = await api(`/api/v1/search/suggestions?q=${encodeURIComponent(query)}&limit=8`, { signal: suggestionController.signal });
    if ((searchSuggestInput?.value.trim() || '') !== query) return;
    renderSearchSuggestions(data.items || [], query);
  } catch (error) {
    if (error.name !== 'AbortError') renderSearchSuggestions([], query);
  }
};

searchSuggestInput?.addEventListener('input', () => {
  window.clearTimeout(suggestionTimer);
  suggestionTimer = window.setTimeout(loadSearchSuggestions, 180);
});
searchSuggestInput?.addEventListener('focus', () => {
  if (searchSuggestInput.value.trim().length >= 2) loadSearchSuggestions();
});
searchSuggestInput?.addEventListener('keydown', (event) => {
  if (searchSuggestMenu?.hidden) return;
  if (event.key === 'ArrowDown') {
    event.preventDefault();
    activeSuggestion = (activeSuggestion + 1) % suggestionItems.length;
    updateSuggestionFocus();
  } else if (event.key === 'ArrowUp') {
    event.preventDefault();
    activeSuggestion = (activeSuggestion - 1 + suggestionItems.length) % suggestionItems.length;
    updateSuggestionFocus();
  } else if (event.key === 'Enter' && activeSuggestion >= 0) {
    event.preventDefault();
    useSuggestion(suggestionItems[activeSuggestion]);
  } else if (event.key === 'Escape') {
    closeSearchSuggestions();
  }
});

document.addEventListener('click', (event) => {
  if (categorySelect && !categorySelect.contains(event.target)) closeCategoryMenu();
  if (searchSuggestRoot && !searchSuggestRoot.contains(event.target)) closeSearchSuggestions();
});
document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') closeCategoryMenu();
});

const addMapTiles = (map) => {
  const tileUrl = document.querySelector('meta[name="map-tile-url"]')?.content
    || 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  const attribution = document.querySelector('meta[name="map-tile-attribution"]')?.content
    || '&copy; OpenStreetMap katkıcıları';
  const configuredMaxZoom = Number(document.querySelector('meta[name="map-tile-max-zoom"]')?.content);
  const options = {
    maxZoom: Number.isInteger(configuredMaxZoom) ? configuredMaxZoom : 19,
    attribution,
  };
  let activeLayer = window.L.tileLayer(tileUrl, options).addTo(map);
  let switchedToFallback = tileUrl.includes('tile.openstreetmap.org');
  activeLayer.on('load', () => map.getContainer().classList.remove('map-tiles-failed'));
  activeLayer.on('tileerror', () => {
    if (switchedToFallback) {
      map.getContainer().classList.add('map-tiles-failed');
      return;
    }
    switchedToFallback = true;
    map.removeLayer(activeLayer);
    activeLayer = window.L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '&copy; OpenStreetMap katkıcıları',
    }).addTo(map);
    activeLayer.on('load', () => map.getContainer().classList.remove('map-tiles-failed'));
    activeLayer.on('tileerror', () => map.getContainer().classList.add('map-tiles-failed'));
  });
  return activeLayer;
};

const listingMapElement = document.querySelector('[data-listing-map]');
const mapViewElement = document.querySelector('[data-map-view]');
const mapDataElement = document.querySelector('[data-map-listings]');
const mapStatusElement = document.querySelector('[data-map-status]');
let listingMap;
let listingMarkerLayer;
let userLocationLayer;
let mapRequestController;
let mapRefreshTimer;
let currentUserPoint;
let mapReturningToTurkey = false;

const resetListingMapToTurkey = () => {
  if (!listingMap) return;
  currentUserPoint = undefined;
  userLocationLayer?.clearLayers();
  if (homeSearchForm) {
    homeSearchForm.elements.lat.value = '';
    homeSearchForm.elements.lng.value = '';
  }
  const center = listingMap.getCenter();
  const alreadyAtTurkey = listingMap.getZoom() === TURKEY_DEFAULT_ZOOM
    && Math.abs(center.lat - TURKEY_CENTER[0]) < 0.05
    && Math.abs(center.lng - TURKEY_CENTER[1]) < 0.05;
  if (!alreadyAtTurkey) {
    mapReturningToTurkey = true;
    listingMap.setView(TURKEY_CENTER, TURKEY_DEFAULT_ZOOM, { animate: false });
  }
};

const showUserArea = (latitude, longitude, fitArea = true) => {
  if (!validTurkeyCoordinates(latitude, longitude)) {
    resetListingMapToTurkey();
    return false;
  }
  currentUserPoint = [latitude, longitude];
  if (homeSearchForm) {
    homeSearchForm.elements.lat.value = latitude.toFixed(6);
    homeSearchForm.elements.lng.value = longitude.toFixed(6);
  }
  userLocationLayer?.clearLayers();
  const area = window.L.circle(currentUserPoint, {
    radius: USER_AREA_RADIUS_METERS,
    color: '#15968e',
    weight: 1,
    opacity: 0.32,
    fillColor: '#36b6ac',
    fillOpacity: 0.055,
    interactive: false,
  }).addTo(userLocationLayer);
  window.L.circleMarker(currentUserPoint, {
    radius: 8,
    color: '#10231d',
    weight: 3,
    fillColor: '#f2b45b',
    fillOpacity: 1,
  }).addTo(userLocationLayer).bindPopup('Senin konumun');
  if (fitArea) listingMap?.fitBounds(area.getBounds(), { padding: [18, 18], maxZoom: 13 });
  return true;
};

const formatListingPrice = (listing) => {
  if (listing.pricing_unit === 'negotiable') return 'Teklif alınır';
  const amount = Number(listing.price_amount);
  if (!Number.isFinite(amount)) return 'Fiyat belirtilmedi';
  const suffix = {
    fixed: ' · sabit',
    hourly: ' / saat',
    daily: ' / gün',
  }[listing.pricing_unit] || '';
  return `${amount.toLocaleString('tr-TR')} ₺${suffix}`;
};

const createMapListingCard = (listing) => {
  const card = createElement('div', 'map-popup');
  const services = Array.isArray(listing.services) ? listing.services : [];
  const grouped = listing.grouped === true && services.length > 1;
  card.classList.toggle('grouped-provider', grouped);
  card.append(createElement('strong', '', grouped ? `${listing.owner_name} · ${services.length} hizmet` : listing.title));
  card.append(createElement('span', '', `${listing.neighborhood || listing.public_neighborhood}, ${listing.district || listing.public_district}`));
  if (grouped) {
    const list = createElement('div', 'map-popup-services');
    services.slice(0, 5).forEach((service) => {
      const link = createElement('a', 'map-popup-service');
      link.href = `/ilan/${encodeURIComponent(service.slug)}`;
      link.append(createElement('span', '', service.title), createElement('small', '', formatListingPrice(service)));
      list.append(link);
    });
    card.append(list);
  } else {
    card.append(createElement('span', 'map-popup-price', formatListingPrice(listing)));
    const link = createElement('a', '', 'İlanı görüntüle →');
    link.href = `/ilan/${encodeURIComponent(listing.slug)}`;
    card.append(link);
  }
  return card;
};

const addListingMarker = (listing, layer, inlineDirection = null) => {
  const latitude = Number(listing.latitude);
  const longitude = Number(listing.longitude);
  if (!validTurkeyCoordinates(latitude, longitude)) return;
  const grouped = listing.grouped === true && Number(listing.service_count || 0) > 1;
  const marker = grouped
    ? window.L.marker([latitude, longitude], {
      icon: window.L.divIcon({
        className: 'provider-group-marker',
        html: `<span>${Number(listing.service_count)}</span>`,
        iconSize: [42, 42],
        iconAnchor: [21, 21],
      }),
    }).addTo(layer)
    : window.L.circleMarker([latitude, longitude], {
      radius: listing.urgent ? 11 : 9,
      color: '#ffffff',
      weight: 3,
      fillColor: listing.urgent ? '#0b9b91' : '#18775d',
      fillOpacity: 1,
    }).addTo(layer);
  marker.bindPopup(createMapListingCard(listing), { offset: [0, -5] });
  if (inlineDirection) {
    const tooltipOffset = {
      top: [0, -14],
      bottom: [0, 14],
      left: [-14, 0],
      right: [14, 0],
    }[inlineDirection];
    marker.bindTooltip(createMapListingCard(listing), {
      permanent: true,
      direction: inlineDirection,
      offset: tooltipOffset,
      className: 'listing-map-tooltip',
      interactive: true,
      opacity: 1,
    });
    marker.on('popupopen', () => marker.closeTooltip());
    marker.on('popupclose', () => marker.openTooltip());
  }
};

const renderListingMarkers = (listings) => {
  if (!listingMap || !listingMarkerLayer) return 0;
  listingMarkerLayer.clearLayers();
  const zoom = listingMap.getZoom();
  const cellSize = zoom <= 10 ? 76 : 58;
  const groups = new Map();
  const inlineCardRects = [];
  const compactMap = window.matchMedia('(max-width: 700px)').matches;
  const inlineDetailLimit = compactMap ? 1 : 6;
  const inlineDetailZoom = compactMap ? 16 : 14;
  const mapSize = listingMap.getSize();
  const reservedCardRects = [{
    left: Math.max(0, mapSize.x - (compactMap ? 250 : 330)),
    right: mapSize.x,
    top: 0,
    bottom: compactMap ? 62 : 72,
  }];
  let validCount = 0;
  listings.forEach((listing) => {
    const latitude = Number(listing.latitude);
    const longitude = Number(listing.longitude);
    if (!validTurkeyCoordinates(latitude, longitude)) return;
    const point = listingMap.project([latitude, longitude], zoom);
    const key = `${Math.floor(point.x / cellSize)}:${Math.floor(point.y / cellSize)}`;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(listing);
    validCount += 1;
  });
  const reserveInlineCard = (listing) => {
    if (zoom < inlineDetailZoom || inlineCardRects.length >= inlineDetailLimit) return false;
    const point = listingMap.latLngToContainerPoint([Number(listing.latitude), Number(listing.longitude)]);
    const cardWidth = compactMap ? 212 : 238;
    const cardHeight = 124;
    const candidates = [
      { direction: 'top', left: point.x - (cardWidth / 2), right: point.x + (cardWidth / 2), top: point.y - cardHeight - 16, bottom: point.y - 8 },
      { direction: 'left', left: point.x - cardWidth - 16, right: point.x - 8, top: point.y - (cardHeight / 2), bottom: point.y + (cardHeight / 2) },
      { direction: 'right', left: point.x + 8, right: point.x + cardWidth + 16, top: point.y - (cardHeight / 2), bottom: point.y + (cardHeight / 2) },
      { direction: 'bottom', left: point.x - (cardWidth / 2), right: point.x + (cardWidth / 2), top: point.y + 8, bottom: point.y + cardHeight + 16 },
    ];
    const rect = candidates.find((candidate) => {
      if (candidate.left < 4 || candidate.right > mapSize.x - 4 || candidate.top < 4 || candidate.bottom > mapSize.y - 4) return false;
      return ![...reservedCardRects, ...inlineCardRects].some((placed) => !(
        candidate.right + 10 < placed.left
        || candidate.left - 10 > placed.right
        || candidate.bottom + 10 < placed.top
        || candidate.top - 10 > placed.bottom
      ));
    });
    if (!rect) return null;
    inlineCardRects.push(rect);
    return rect.direction;
  };
  groups.forEach((group) => {
    if (group.length === 1) {
      addListingMarker(group[0], listingMarkerLayer, reserveInlineCard(group[0]));
      return;
    }
    const coordinates = group.map((item) => [Number(item.latitude), Number(item.longitude)]);
    const center = coordinates.reduce(
      (total, item) => [total[0] + item[0] / coordinates.length, total[1] + item[1] / coordinates.length],
      [0, 0],
    );
    if (zoom >= 17) {
      const centerPoint = listingMap.latLngToLayerPoint(center);
      const spreadRadius = group.length === 2 ? 34 : Math.min(58, 36 + (group.length * 3));
      group.forEach((listing, index) => {
        const angle = (-Math.PI / 2) + ((Math.PI * 2 * index) / group.length);
        const displayPoint = window.L.point(
          centerPoint.x + (Math.cos(angle) * spreadRadius),
          centerPoint.y + (Math.sin(angle) * spreadRadius),
        );
        const displayLocation = listingMap.layerPointToLatLng(displayPoint);
        const displayListing = {
          ...listing,
          latitude: displayLocation.lat,
          longitude: displayLocation.lng,
        };
        addListingMarker(displayListing, listingMarkerLayer, reserveInlineCard(displayListing));
      });
      return;
    }
    const icon = window.L.divIcon({
      className: 'map-cluster-wrapper',
      html: `<span class="map-cluster">${group.length}</span>`,
      iconSize: [48, 48],
      iconAnchor: [24, 24],
    });
    window.L.marker(center, { icon }).addTo(listingMarkerLayer).on('click', () => {
      listingMap.fitBounds(window.L.latLngBounds(coordinates), {
        padding: [70, 70],
        maxZoom: Math.min(17, zoom + 3),
      });
    });
  });
  return validCount;
};

const visibleMapSearch = async () => {
  if (!listingMap) return;
  const center = listingMap.getCenter();
  if (!validTurkeyCoordinates(center.lat, center.lng)) {
    resetListingMapToTurkey();
    scheduleVisibleMapSearch();
    return;
  }
  mapRequestController?.abort();
  mapRequestController = new AbortController();
  const bounds = listingMap.getBounds();
  const form = document.querySelector('.search-form');
  const formData = form ? new FormData(form) : new FormData();
  const parameters = new URLSearchParams();
  for (const [key, rawValue] of formData.entries()) {
    const value = String(rawValue).trim();
    if (value !== '') parameters.append(key, value);
  }
  if (!parameters.has('type')) parameters.set('type', 'service_offer');
  parameters.set('min_lat', bounds.getSouth().toFixed(6));
  parameters.set('max_lat', bounds.getNorth().toFixed(6));
  parameters.set('min_lng', bounds.getWest().toFixed(6));
  parameters.set('max_lng', bounds.getEast().toFixed(6));
  parameters.set('limit', '50');
  parameters.set('map_only', '1');
  if (currentUserPoint) {
    parameters.set('lat', currentUserPoint[0].toFixed(6));
    parameters.set('lng', currentUserPoint[1].toFixed(6));
  }
  if (mapStatusElement) {
    mapStatusElement.classList.add('loading');
    mapStatusElement.textContent = 'Bu alandaki ilanlar yükleniyor…';
  }
  try {
    const data = await api(`/api/v1/listings?${parameters}`, { signal: mapRequestController.signal });
    const items = data.items || [];
    const shown = renderListingMarkers(items);
    if (mapStatusElement) {
      mapStatusElement.classList.remove('loading');
      if (shown === 0) {
        const currentCenter = listingMap.getCenter();
        const nationwideView = listingMap.getZoom() === TURKEY_DEFAULT_ZOOM
          && Math.abs(currentCenter.lat - TURKEY_CENTER[0]) < 0.05
          && Math.abs(currentCenter.lng - TURKEY_CENTER[1]) < 0.05;
        if (!nationwideView) {
          mapStatusElement.textContent = 'Bu alanda sonuç yok · Türkiye genelinde aranıyor…';
          resetListingMapToTurkey();
          scheduleVisibleMapSearch();
          return;
        }
        mapReturningToTurkey = false;
        mapStatusElement.textContent = 'Bu filtrelerde Türkiye genelinde ilan bulunamadı';
      }
      else if (data.pagination?.has_more) mapStatusElement.textContent = `${shown}+ ilan bulundu · Daha fazlası için yakınlaştır`;
      else mapStatusElement.textContent = `${shown} ilan bu görünümde gösteriliyor`;
    }
  } catch (error) {
    if (error.name === 'AbortError') return;
    if (mapStatusElement) {
      mapStatusElement.classList.remove('loading');
      mapStatusElement.textContent = 'İlanlar yenilenemedi · Tekrar denemek için haritayı hareket ettir';
    }
  }
};

const scheduleVisibleMapSearch = () => {
  window.clearTimeout(mapRefreshTimer);
  mapRefreshTimer = window.setTimeout(visibleMapSearch, 280);
};

const initializeListingMap = () => {
  if (!listingMapElement || listingMap || !window.L) return listingMap;
  const listings = JSON.parse(mapDataElement?.textContent || '[]');
  listingMap = window.L.map(listingMapElement, {
    scrollWheelZoom: false,
    minZoom: 5,
    maxBounds: TURKEY_MAP_BOUNDS,
    maxBoundsViscosity: 1,
  }).setView(TURKEY_CENTER, TURKEY_DEFAULT_ZOOM);
  addMapTiles(listingMap);
  listingMarkerLayer = window.L.layerGroup().addTo(listingMap);
  userLocationLayer = window.L.layerGroup().addTo(listingMap);
  renderListingMarkers(listings);

  const search = new URL(window.location.href).searchParams;
  const userLatValue = search.get('lat');
  const userLngValue = search.get('lng');
  const userLat = Number(userLatValue);
  const userLng = Number(userLngValue);
  if (userLatValue !== null && userLngValue !== null && validTurkeyCoordinates(userLat, userLng)) {
    showUserArea(userLat, userLng);
  } else if (userLatValue !== null || userLngValue !== null) {
    resetListingMapToTurkey();
  }
  if (mapStatusElement) mapStatusElement.textContent = listings.length > 0 ? `${listings.length} ilan hazırlanıyor…` : 'Bu alandaki ilanlar aranıyor…';
  listingMap.on('moveend', scheduleVisibleMapSearch);
  scheduleVisibleMapSearch();
  return listingMap;
};

document.querySelector('[data-map-recenter]')?.addEventListener('click', async (event) => {
  const button = event.currentTarget;
  const original = button.textContent;
  button.disabled = true;
  button.textContent = 'Konum alınıyor…';
  try {
    const { coords } = await requestBrowserLocation();
    localStorage.setItem('location-onboarding', 'allowed');
    initializeListingMap();
    const centered = showUserArea(Number(coords.latitude), Number(coords.longitude));
    if (!centered) showToast('Konumun Türkiye dışında görünüyor. Harita Türkiye merkezinde açıldı.', 'info');
    scheduleVisibleMapSearch();
  } catch (error) {
    showToast(error.message, 'error');
  } finally {
    button.disabled = false;
    button.textContent = original;
  }
});

if (listingMapElement && mapViewElement) initializeListingMap();

const locationOnboarding = document.querySelector('[data-location-onboarding]');
if (locationOnboarding) {
  const search = new URL(window.location.href).searchParams;
  const locationChoice = localStorage.getItem('location-onboarding');
  if (!search.has('lat') && !locationChoice) locationOnboarding.hidden = false;
  if (!search.has('lat') && locationChoice === 'allowed') {
    requestBrowserLocation().then(({ coords }) => {
      showUserArea(Number(coords.latitude), Number(coords.longitude));
      scheduleVisibleMapSearch();
    }).catch(() => {
      localStorage.removeItem('location-onboarding');
      locationOnboarding.hidden = false;
    });
  }
  locationOnboarding.querySelector('[data-location-allow]')?.addEventListener('click', (event) => openHomeAtLocation(event.currentTarget));
  locationOnboarding.querySelector('[data-location-manual]')?.addEventListener('click', () => {
    localStorage.setItem('location-onboarding', 'manual');
    locationOnboarding.hidden = true;
    initializeListingMap()?.getContainer().focus();
  });
}

if (window.location.hash === '#kesfet-haritasi') {
  window.requestAnimationFrame(() => document.querySelector('#kesfet-haritasi')?.scrollIntoView({ behavior: 'smooth', block: 'start' }));
}

const detailMapElement = document.querySelector('[data-detail-map]');
if (detailMapElement && window.L) {
  const latitude = Number(detailMapElement.dataset.latitude);
  const longitude = Number(detailMapElement.dataset.longitude);
  if (Number.isFinite(latitude) && Number.isFinite(longitude)) {
    const detailMap = window.L.map(detailMapElement, { scrollWheelZoom: false }).setView([latitude, longitude], 14);
    addMapTiles(detailMap);
    if (detailMapElement.dataset.precision === 'neighborhood') {
      window.L.circle([latitude, longitude], {
        radius: 650,
        color: '#18775d',
        weight: 2,
        fillColor: '#a9ecd4',
        fillOpacity: 0.28,
      }).addTo(detailMap).bindPopup('Yaklaşık mahalle konumu');
    } else {
      window.L.circleMarker([latitude, longitude], {
        radius: 10,
        color: '#ffffff',
        weight: 3,
        fillColor: '#18775d',
        fillOpacity: 1,
      }).addTo(detailMap).bindPopup(detailMapElement.dataset.title || 'İlan konumu');
    }
  }
}

const pendingAuthActionKey = 'pending-auth-action-v1';
const safeLocalPath = (value, fallback = '/') => {
  try {
    const url = new URL(String(value || fallback), window.location.origin);
    if (url.origin !== window.location.origin || !url.pathname.startsWith('/')) return fallback;
    return `${url.pathname}${url.search}${url.hash}`;
  } catch (_) { return fallback; }
};
const currentLocalPath = () => `${window.location.pathname}${window.location.search}${window.location.hash}`;
const goToLogin = (pendingAction = null, returnTo = currentLocalPath()) => {
  if (pendingAction) localStorage.setItem(pendingAuthActionKey, JSON.stringify({ ...pendingAction, created_at: Date.now() }));
  window.location.assign(`/giris?return_to=${encodeURIComponent(safeLocalPath(returnTo))}`);
};
const resumePendingAuthAction = async (fallback) => {
  let pending;
  try { pending = JSON.parse(localStorage.getItem(pendingAuthActionKey) || 'null'); } catch (_) { pending = null; }
  localStorage.removeItem(pendingAuthActionKey);
  if (!pending || Date.now() - Number(pending.created_at || 0) > 30 * 60 * 1000) return fallback;
  if (pending.type === 'favorite_add' && pending.listing_id) {
    await api(`/api/v1/favorites/${encodeURIComponent(pending.listing_id)}`, { method: 'POST' });
    showToast('İlan favorilerine eklendi.', 'success');
    return safeLocalPath(pending.return_to, fallback);
  }
  if (pending.type === 'conversation_start' && pending.listing_id) {
    const result = await api('/api/v1/conversations', {
      method: 'POST',
      body: JSON.stringify({ listing_id: pending.listing_id, listing_item_id: pending.listing_item_id || null }),
    });
    return `/mesajlar?conversation=${encodeURIComponent(result.conversation_id)}`;
  }
  if (pending.type === 'engagement_create' && pending.listing_id && pending.listing_item_id) {
    const result = await api('/api/v1/engagements', {
      method: 'POST',
      body: JSON.stringify({ listing_id: pending.listing_id, listing_item_id: pending.listing_item_id }),
    });
    showToast('Hizmet talebin gönderildi.', 'success');
    return `/mesajlar?conversation=${encodeURIComponent(result.conversation_id)}`;
  }
  if (pending.type === 'saved_search' && pending.filters && typeof pending.filters === 'object') {
    await api('/api/v1/saved-searches', {
      method: 'POST',
      body: JSON.stringify({
        name: autoSavedSearchName(pending.filters),
        filters: pending.filters,
        notification_enabled: false,
      }),
    });
    showToast('Filtre favorilerine kaydedildi.', 'success');
    return safeLocalPath(pending.return_to, fallback);
  }
  return safeLocalPath(pending.return_to, fallback);
};

document.querySelector('[data-auth-form]')?.addEventListener('submit', async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  const message = form.querySelector('[data-form-message]');
  const button = form.querySelector('button[type="submit"]');
  const formData = new FormData(form);
  const data = Object.fromEntries(formData.entries());
  data.message_email_notifications = formData.get('message_email_notifications') === 'true';
  const policyIds = formData.getAll('policy_ids');
  delete data.policy_ids;
  button.disabled = true;
  message.textContent = '';
  if (form.dataset.mode === 'register' && data.password !== data.password_confirmation) {
    message.textContent = 'Şifreler aynı olmalı.';
    button.disabled = false;
    return;
  }
  try {
    await api(`/api/v1/auth/${form.dataset.mode}`, { method: 'POST', body: JSON.stringify(data) });
    if (form.dataset.mode === 'register' && policyIds.length > 0) {
      await api('/api/v1/privacy/consents', { method: 'POST', body: JSON.stringify({ policy_ids: policyIds }) });
    }
    const fallback = safeLocalPath(form.dataset.returnTo, form.dataset.mode === 'register' ? '/profili-duzenle' : '/');
    const target = await resumePendingAuthAction(fallback);
    window.location.assign(target);
  } catch (error) {
    message.textContent = error.message;
  } finally {
    button.disabled = false;
  }
});

document.querySelectorAll('[data-toggle-password]').forEach((button) => {
  button.addEventListener('click', () => {
    const input = button.closest('.password-input')?.querySelector('input');
    if (!input) return;
    const reveal = input.type === 'password';
    input.type = reveal ? 'text' : 'password';
    button.textContent = reveal ? 'Gizle' : 'Göster';
    button.setAttribute('aria-label', reveal ? 'Şifreyi gizle' : 'Şifreyi göster');
  });
});

document.querySelector('[data-forgot-password]')?.addEventListener('click', async (event) => {
  const form = event.currentTarget.closest('form');
  const email = form?.elements.email?.value.trim() || '';
  const message = form?.querySelector('[data-form-message]');
  if (!email || !email.includes('@')) {
    message.textContent = 'Önce e-posta adresini yaz.';
    form?.elements.email?.focus();
    return;
  }
  event.currentTarget.disabled = true;
  try {
    await api('/api/v1/auth/password/forgot', { method: 'POST', body: JSON.stringify({ email }) });
    message.textContent = 'Adres kayıtlıysa şifre yenileme bağlantısı gönderildi.';
    message.classList.add('success');
  } catch (error) {
    message.textContent = error.message;
  } finally {
    event.currentTarget.disabled = false;
  }
});

document.querySelector('[data-password-reset-form]')?.addEventListener('submit', async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  const message = form.querySelector('[data-form-message]');
  const button = form.querySelector('button[type="submit"]');
  const values = Object.fromEntries(new FormData(form).entries());
  if (values.password !== values.password_confirmation) {
    message.textContent = 'Şifreler aynı olmalı.';
    return;
  }
  button.disabled = true;
  message.textContent = '';
  try {
    await api('/api/v1/auth/password/reset', {
      method: 'POST',
      body: JSON.stringify({ token: values.token, password: values.password, password_confirmation: values.password_confirmation }),
    });
    message.textContent = 'Şifren yenilendi. Giriş sayfasına yönlendiriliyorsun.';
    message.classList.add('success');
    window.setTimeout(() => window.location.assign('/giris'), 1200);
  } catch (error) {
    message.textContent = error.message;
  } finally {
    button.disabled = false;
  }
});

const engagementsPage = document.querySelector('[data-engagements-page]');
if (engagementsPage) {
  const list = engagementsPage.querySelector('[data-engagement-list]');
  const statusButtons = [...engagementsPage.querySelectorAll('[data-engagement-status]')];
  let userId = '';
  let selectedStatus = '';
  const statusLabels = { requested: 'Yanıt bekliyor', accepted: 'Kabul edildi', rejected: 'Reddedildi', in_progress: 'Devam ediyor', provider_completed: 'Müşteri onayı bekliyor', completed: 'Tamamlandı', canceled: 'İptal edildi', disputed: 'İncelemede' };
  const priceText = (job) => {
    const value = job.agreed_price_amount ?? job.quoted_price_amount;
    if (value === null || value === undefined) return 'Fiyat görüşülecek';
    return new Intl.NumberFormat('tr-TR', { style: 'currency', currency: job.currency_snapshot || 'TRY' }).format(Number(value));
  };
  const makeButton = (label, action, tone = '') => {
    const element = document.createElement('button');
    element.type = 'button'; element.className = `engagement-action ${tone}`.trim();
    element.dataset.engagementAction = action; element.textContent = label;
    return element;
  };
  const actionButtons = (job) => {
    const actions = [];
    const provider = String(job.provider_id) === String(userId);
    const requester = String(job.requester_id) === String(userId);
    if (provider && job.status === 'requested') actions.push(makeButton('Kabul et', 'accept', 'primary'), makeButton('Reddet', 'reject', 'danger'));
    if (provider && job.status === 'accepted') actions.push(makeButton('İşi başlat', 'start', 'primary'));
    if (provider && job.status === 'in_progress') actions.push(makeButton('Tamamladım', 'mark_completed', 'primary'));
    if (requester && job.status === 'provider_completed') actions.push(makeButton('Tamamlandığını onayla', 'confirm_completed', 'primary'), makeButton('Sorun bildir', 'dispute', 'danger'));
    if (['requested', 'accepted', 'in_progress'].includes(job.status)) actions.push(makeButton('İptal et', 'cancel'));
    if (['accepted', 'in_progress'].includes(job.status)) actions.push(makeButton('Anlaşmazlık bildir', 'dispute', 'danger'));
    if (job.status === 'completed') actions.push(makeButton('Değerlendir', 'review', 'primary'));
    const message = document.createElement('a');
    message.className = 'engagement-action';
    message.href = `/mesajlar?conversation=${encodeURIComponent(job.conversation_id || '')}`;
    message.textContent = 'Mesajlara git'; actions.push(message);
    return actions;
  };
  const renderJob = (job) => {
    const article = document.createElement('article');
    article.className = 'engagement-card'; article.dataset.engagementId = job.id;
    const provider = String(job.provider_id) === String(userId);
    const copy = document.createElement('div');
    const role = document.createElement('span'); role.className = 'engagement-role'; role.textContent = provider ? 'HİZMET VERİYORUM' : 'HİZMET ALIYORUM';
    const title = document.createElement('h2'); title.textContent = job.service_name_snapshot || job.listing_headline_snapshot || 'Hizmet';
    const meta = document.createElement('p'); meta.textContent = `${provider ? job.requester_name : job.provider_name || 'Kullanıcı'} · ${priceText(job)}`;
    copy.append(role, title, meta);
    const state = document.createElement('span'); state.className = `engagement-status status-${job.status}`; state.textContent = statusLabels[job.status] || job.status;
    const header = document.createElement('header'); header.append(copy, state);
    const footer = document.createElement('footer'); actionButtons(job).forEach((entry) => footer.append(entry));
    article.append(header, footer); return article;
  };
  const loadEngagements = async () => {
    list.innerHTML = '<div class="loading-card">İş kayıtların yükleniyor…</div>';
    try {
      const data = await api(`/api/v1/engagements${selectedStatus ? `?status=${encodeURIComponent(selectedStatus)}` : ''}`);
      list.replaceChildren();
      if (!(data.items || []).length) {
        const empty = document.createElement('div'); empty.className = 'engagement-empty';
        empty.innerHTML = '<strong>Bu durumda iş kaydın yok</strong><p>Bir hizmet talebi gönderdiğinde süreç burada görünecek.</p>';
        list.append(empty); return;
      }
      data.items.forEach((job) => list.append(renderJob(job)));
    } catch (error) {
      if (error.status === 401) { goToLogin(null, '/islerim'); return; }
      list.textContent = error.message;
    }
  };
  api('/api/v1/auth/me').then((session) => { userId = session.user?.id || ''; return loadEngagements(); }).catch((error) => {
    if (error.status === 401) goToLogin(null, '/islerim'); else showToast(error.message, 'error');
  });
  statusButtons.forEach((entry) => entry.addEventListener('click', () => {
    selectedStatus = entry.dataset.engagementStatus || '';
    statusButtons.forEach((item) => item.classList.toggle('active', item === entry)); loadEngagements();
  }));
  list.addEventListener('click', async (event) => {
    const trigger = event.target.closest('[data-engagement-action]');
    if (!trigger) return;
    const id = trigger.closest('[data-engagement-id]')?.dataset.engagementId;
    const action = trigger.dataset.engagementAction;
    if (!id) return;
    if (action === 'review') {
      const values = await siteFormModal({ eyebrow: 'DOĞRULANMIŞ İŞ', title: 'Bu işi değerlendir', description: 'İki taraf da gönderene veya 14 gün geçene kadar puanlar gizli tutulur.', confirmText: 'Değerlendirmeyi gönder', fields: [
        { name: 'rating', label: 'Puan', type: 'select', value: '5', options: [5,4,3,2,1].map((value) => ({ value: String(value), label: `${value} yıldız` })) },
        { name: 'comment', label: 'Yorum (isteğe bağlı)', type: 'textarea', required: false, placeholder: 'Deneyimini saygılı bir dille paylaş…' },
      ] });
      if (!values) return;
      try { await api('/api/v1/reviews', { method: 'POST', body: JSON.stringify({ engagement_id: id, rating: Number(values.rating), comment: values.comment.trim() }) }); showToast('Değerlendirmen güvenle kaydedildi.', 'success'); }
      catch (error) { showToast(error.message, 'error'); }
      return;
    }
    let payload = {};
    if (['cancel', 'dispute'].includes(action)) {
      const values = await siteFormModal({ eyebrow: action === 'dispute' ? 'ANLAŞMAZLIK' : 'İŞLEM ONAYI', title: action === 'dispute' ? 'Sorunu incelemeye gönder' : 'İşi iptal et', description: 'Karşı taraf ve moderasyon ekibi için kısa bir neden yaz.', confirmText: action === 'dispute' ? 'İncelemeye gönder' : 'İptal et', fields: [{ name: 'reason', label: 'Neden', type: 'textarea', minLength: 3, placeholder: 'En az 3 karakter…' }], validate: (values) => values.reason.trim().length < 3 ? 'Neden en az 3 karakter olmalı.' : '' });
      if (!values) return; payload = { reason: values.reason.trim() };
    } else {
      const approved = await siteConfirm('Bu işlem iş kaydının durumunu değiştirecek.', { danger: false, title: trigger.textContent, confirmText: 'Devam et' });
      if (!approved) return;
    }
    trigger.disabled = true;
    try { await api(`/api/v1/engagements/${encodeURIComponent(id)}/actions/${encodeURIComponent(action)}`, { method: 'POST', body: JSON.stringify(payload) }); showToast('İş durumu güncellendi.', 'success'); await loadEngagements(); }
    catch (error) { showToast(error.message, 'error'); trigger.disabled = false; }
  });
}

document.querySelector('[data-start-conversation]')?.addEventListener('click', async (event) => {
  const selectedItem = document.querySelector('[name="selected_listing_item"]:checked')?.value || null;
  try {
    const data = await api('/api/v1/conversations', { method: 'POST', body: JSON.stringify({ listing_id: event.currentTarget.dataset.listingId, listing_item_id: selectedItem }) });
    window.location.assign(`/mesajlar?conversation=${encodeURIComponent(data.conversation_id)}`);
  } catch (error) {
    if (error.status === 401 || /giriş|Oturum/i.test(error.message)) goToLogin({
      type: 'conversation_start',
      listing_id: event.currentTarget.dataset.listingId,
      listing_item_id: selectedItem,
      return_to: currentLocalPath(),
    });
    else showToast(error.message, 'error');
  }
});

document.querySelector('[data-create-engagement]')?.addEventListener('click', async (event) => {
  const selectedItem = document.querySelector('[name="selected_listing_item"]:checked')?.value || '';
  if (!selectedItem) { showToast('Önce bir hizmet kalemi seç.', 'error'); return; }
  try {
    const engagement = await api('/api/v1/engagements', {
      method: 'POST',
      body: JSON.stringify({ listing_id: event.currentTarget.dataset.listingId, listing_item_id: selectedItem }),
    });
    showToast('Hizmet talebin gönderildi.', 'success');
    window.setTimeout(() => window.location.assign(`/mesajlar?conversation=${encodeURIComponent(engagement.conversation_id)}`), 700);
  } catch (error) {
    if (error.status === 401 || /giriş|oturum/i.test(error.message)) goToLogin({
      type: 'engagement_create', listing_id: event.currentTarget.dataset.listingId,
      listing_item_id: selectedItem, return_to: currentLocalPath(),
    });
    else showToast(error.message, 'error');
  }
});

document.querySelectorAll('[data-gallery-image]').forEach((button) => {
  button.addEventListener('click', () => {
    const image = document.querySelector('.detail-visual img');
    if (image) image.src = button.dataset.galleryImage;
  });
});

const listingActions = document.querySelector('[data-listing-actions]');
if (listingActions) {
  const listingId = listingActions.dataset.listingId;
  const ownerId = listingActions.dataset.ownerId;
  const favoriteButton = listingActions.querySelector('[data-favorite-listing]');
  let favorited = false;
  api('/api/v1/auth/me').then(({ user }) => {
    const ownListing = String(user?.id || '') === String(ownerId);
    document.querySelector('[data-owner-edit-listing]')?.toggleAttribute('hidden', !ownListing);
    if (ownListing) {
      favoriteButton.hidden = true;
      listingActions.querySelector('[data-review-listing]').hidden = true;
      listingActions.querySelector('[data-report-listing]').hidden = true;
      listingActions.querySelector('[data-block-owner]').hidden = true;
      document.querySelector('[data-start-conversation]')?.toggleAttribute('hidden', true);
      document.querySelector('[data-create-engagement]')?.toggleAttribute('hidden', true);
    }
  }).catch(() => {});
  api('/api/v1/favorites?limit=100').then((data) => {
    favorited = (data.items || []).some((item) => item.id === listingId);
    favoriteButton.textContent = favorited ? '♥ Favorilerde' : '♡ Favoriye ekle';
  }).catch(() => {});

  favoriteButton.addEventListener('click', async () => {
    try {
      await api(`/api/v1/favorites/${encodeURIComponent(listingId)}`, { method: favorited ? 'DELETE' : 'POST' });
      favorited = !favorited;
      favoriteButton.textContent = favorited ? '♥ Favorilerde' : '♡ Favoriye ekle';
    } catch (error) {
      if (error.status === 401 || /giriş|oturum/i.test(error.message)) goToLogin({
        type: 'favorite_add',
        listing_id: listingId,
        return_to: currentLocalPath(),
      });
      else showToast(error.message, 'error');
    }
  });

  listingActions.querySelector('[data-share-listing]').addEventListener('click', async () => {
    const share = { title: document.title, url: window.location.href };
    if (navigator.share) await navigator.share(share).catch(() => {});
    else {
      await navigator.clipboard.writeText(share.url);
      showToast('İlan bağlantısı kopyalandı.', 'success');
    }
  });

  const reviewButton = listingActions.querySelector('[data-review-listing]');
  // Reviews are created only from a completed, verified job in /islerim.
  if (reviewButton) reviewButton.hidden = true;
  /*
  let ownReview;
  Promise.all([
    api('/api/v1/auth/me'),
    api(`/api/v1/users/${encodeURIComponent(ownerId)}/reviews?limit=50`),
  ]).then(([session, reviews]) => {
    ownReview = (reviews.items || []).find((review) =>
      String(review.author_id) === String(session.user?.id)
      && String(review.listing_id) === String(listingId));
    if (ownReview) reviewButton.textContent = '★ Değerlendirmeni düzenle';
  }).catch(() => {});
  reviewButton.addEventListener('click', async () => {
    try { await api('/api/v1/auth/me'); }
    catch (error) {
      if (error.status === 401) goToLogin(null, currentLocalPath());
      else showToast(error.message, 'error');
      return;
    }
    const values = await siteFormModal({
      eyebrow: 'DENEYİMİNİ PAYLAŞ',
      title: ownReview ? 'Değerlendirmeni düzenle' : 'Hizmeti değerlendir',
      description: 'Puanın ve yorumun diğer kullanıcıların doğru karar vermesine yardımcı olur.',
      confirmText: ownReview ? 'Değişiklikleri kaydet' : 'Değerlendirmeyi yayınla',
      fields: [
        { name: 'rating', label: 'Puan', type: 'select', value: String(ownReview?.rating || '5'), options: [5,4,3,2,1].map((value) => ({ value: String(value), label: `${value} yıldız` })) },
        { name: 'comment', label: 'Yorumun', type: 'textarea', value: ownReview?.comment || '', minLength: 3, placeholder: 'Hizmet deneyimini kısaca anlat…' },
      ],
      validate: (input) => input.comment.trim().length < 3 ? 'Yorum en az 3 karakter olmalı.' : '',
    });
    if (!values) return;
    try {
      const payload = { listing_id: listingId, rating: Number(values.rating), comment: values.comment.trim() };
      ownReview = ownReview
        ? await api(`/api/v1/reviews/${encodeURIComponent(ownReview.id)}`, { method: 'PUT', body: JSON.stringify(payload) })
        : await api('/api/v1/reviews', { method: 'POST', body: JSON.stringify(payload) });
      reviewButton.textContent = '★ Değerlendirmeni düzenle';
      showToast('Değerlendirmen kaydedildi.', 'success');
    } catch (error) {
      if (error.status === 401) goToLogin(null, currentLocalPath());
      else showToast(error.message, 'error');
    }
  });
  */

  listingActions.querySelector('[data-report-listing]').addEventListener('click', async () => {
    try { await api('/api/v1/auth/me'); }
    catch (error) {
      if (error.status === 401) goToLogin(null, currentLocalPath());
      else showToast(error.message, 'error');
      return;
    }
    const values = await siteFormModal({
      eyebrow: 'GÜVENLİK BİLDİRİMİ',
      title: 'Bu ilanı bildir',
      description: 'Bildirim yalnızca moderasyon ekibi tarafından incelenir.',
      confirmText: 'Bildirimi gönder',
      fields: [
        { name: 'reason', label: 'Bildirim nedeni', type: 'select', value: 'spam', options: [
          { value: 'spam', label: 'Spam veya yanıltıcı içerik' }, { value: 'fraud', label: 'Dolandırıcılık şüphesi' },
          { value: 'harassment', label: 'Taciz veya kötü davranış' }, { value: 'inappropriate', label: 'Uygunsuz içerik' },
          { value: 'safety', label: 'Güvenlik riski' }, { value: 'other', label: 'Diğer' },
        ] },
        { name: 'details', label: 'Açıklama', type: 'textarea', required: false, placeholder: 'Ekibimizin incelemesine yardımcı olacak ayrıntıları yaz…' },
      ],
      validate: (input) => input.reason === 'other' && input.details.trim().length < 10 ? 'Diğer seçeneğinde en az 10 karakter açıklama yazmalısın.' : '',
    });
    if (!values) return;
    try {
      await api('/api/v1/reports', { method: 'POST', body: JSON.stringify({ listing_id: listingId, reason: values.reason, details: values.details.trim() }) });
      showToast('Bildirimin inceleme sırasına alındı.', 'success');
    } catch (error) {
      if (error.status === 401) goToLogin(null, currentLocalPath());
      else showToast(error.message, 'error');
    }
  });

  listingActions.querySelector('[data-block-owner]').addEventListener('click', async () => {
    try { await api('/api/v1/auth/me'); }
    catch (error) {
      if (error.status === 401) goToLogin(null, currentLocalPath());
      else showToast(error.message, 'error');
      return;
    }
    if (!(await siteConfirm('Bu kullanıcının ilanları ve mesajları artık sana gösterilmeyecek.', {
      title: 'Kullanıcı engellensin mi?',
      confirmText: 'Kullanıcıyı engelle',
    }))) return;
    try {
      await api(`/api/v1/blocks/${encodeURIComponent(ownerId)}`, { method: 'POST' });
      showToast('Kullanıcı engellendi. İlanları ve mesajları artık gösterilmeyecek.', 'success');
      window.location.assign('/');
    } catch (error) { showToast(error.message, 'error'); }
  });
}

const refreshHeaderNotificationCount = async () => {
  const badge = document.querySelector('[data-notification-count]');
  if (!badge) return;
  const data = await api('/api/v1/notifications?limit=100');
  const count = (data.items || []).filter((item) => !item.read_at).length;
  badge.textContent = count > 99 ? '99+' : String(count);
  badge.hidden = count === 0;
};

api('/api/v1/auth/me').then(({ user }) => {
  document.querySelectorAll('.guest-action').forEach((element) => { element.hidden = true; });
  document.querySelectorAll('.signed-action').forEach((element) => { element.hidden = false; });
  const avatarButton = document.querySelector('[data-account-menu]');
  const initial = user.display_name.slice(0, 1).toLocaleUpperCase('tr');
  if (avatarButton) avatarButton.textContent = initial;
  const menuAvatar = document.querySelector('[data-account-menu-avatar]');
  const menuName = document.querySelector('[data-account-menu-name]');
  if (menuAvatar) menuAvatar.textContent = initial;
  if (menuName) menuName.textContent = user.display_name;
  refreshHeaderNotificationCount().catch(() => {});
  startRealtime(({ event }) => {
    if (event === 'notification.created') refreshHeaderNotificationCount().catch(() => {});
  });
}).catch(() => {});

const accountMenuButton = document.querySelector('[data-account-menu]');
const accountMenuPopover = document.querySelector('[data-account-menu-popover]');
const closeAccountMenu = () => {
  if (!accountMenuButton || !accountMenuPopover) return;
  accountMenuPopover.hidden = true;
  accountMenuButton.setAttribute('aria-expanded', 'false');
};
accountMenuButton?.addEventListener('click', () => {
  const shouldOpen = accountMenuPopover?.hidden === true;
  closeAccountMenu();
  if (shouldOpen && accountMenuPopover) {
    accountMenuPopover.hidden = false;
    accountMenuButton.setAttribute('aria-expanded', 'true');
  }
});
document.addEventListener('click', (event) => {
  if (!event.target.closest('[data-account-menu-root]')) closeAccountMenu();
});
document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') closeAccountMenu();
});
document.querySelector('[data-account-logout]')?.addEventListener('click', async () => {
  try { await api('/api/v1/auth/logout', { method: 'POST' }); } catch (_) { /* Oturum zaten kapanmış olabilir. */ }
  window.location.assign('/');
});

const locationPickerElement = document.querySelector('[data-location-picker]');
if (locationPickerElement && window.L) {
  const mapElement = locationPickerElement.querySelector('[data-location-map]');
  const loadingElement = locationPickerElement.querySelector('[data-location-map-loading]');
  const latitudeInput = locationPickerElement.querySelector('input[name="latitude"]');
  const longitudeInput = locationPickerElement.querySelector('input[name="longitude"]');
  const confirmedInput = locationPickerElement.querySelector('input[name="location_confirmed"]');
  const cityInput = locationPickerElement.querySelector('input[name="city"]');
  const districtInput = locationPickerElement.querySelector('input[name="district"]');
  const neighborhoodInput = locationPickerElement.querySelector('input[name="neighborhood"]');
  const titleElement = locationPickerElement.querySelector('[data-location-title]');
  const statusElement = locationPickerElement.querySelector('[data-location-status]');
  const confirmButton = locationPickerElement.querySelector('[data-confirm-location]');
  const precisionInputs = [...locationPickerElement.querySelectorAll('[name="location_precision"]')];
  const exactAddressPanel = locationPickerElement.querySelector('[data-exact-address]');
  const exactAddressInputs = [...exactAddressPanel.querySelectorAll('input:not([type="checkbox"])')];
  const addressMatchInput = exactAddressPanel.querySelector('[name="address_matches_map"]');
  const geocodeAddressButton = exactAddressPanel.querySelector('[data-geocode-address]');
  const initialPoint = [Number(latitudeInput.value), Number(longitudeInput.value)];
  const locationMap = window.L.map(mapElement, {
    center: initialPoint,
    zoom: 13.5,
    minZoom: 5,
    maxZoom: 17,
    scrollWheelZoom: false,
    zoomControl: true,
  });
  addMapTiles(locationMap);
  loadingElement.hidden = true;

  let lookupTimer;
  let lookupController;

  const firstAddressValue = (address, keys) => {
    for (const key of keys) {
      const value = address?.[key];
      if (typeof value === 'string' && value.trim()) return value.trim();
    }
    return '';
  };

  const setUnconfirmed = (title, status) => {
    confirmedInput.value = '0';
    confirmButton.disabled = true;
    confirmButton.textContent = 'Bu konumu doğrula';
    locationPickerElement.classList.remove('confirmed');
    titleElement.textContent = title;
    statusElement.textContent = status;
  };

  const resolveAddress = async () => {
    const center = locationMap.getCenter();
    latitudeInput.value = center.lat.toFixed(6);
    longitudeInput.value = center.lng.toFixed(6);
    setUnconfirmed('Adres aranıyor…', 'İğnenin altındaki konumu kontrol ediyoruz.');
    lookupController?.abort();
    const controller = new AbortController();
    lookupController = controller;

    try {
      const query = new URLSearchParams({
        format: 'jsonv2',
        lat: latitudeInput.value,
        lon: longitudeInput.value,
        addressdetails: '1',
        'accept-language': 'tr',
        zoom: '18',
      });
      const response = await fetch(`https://nominatim.openstreetmap.org/reverse?${query}`, {
        headers: { Accept: 'application/json' },
        signal: controller.signal,
      });
      if (!response.ok) throw new Error(`Adres servisi ${response.status} yanıtını verdi.`);
      const data = await response.json();
      const city = firstAddressValue(data.address, ['city', 'town', 'municipality', 'province', 'state']);
      const district = firstAddressValue(data.address, ['town', 'city_district', 'county', 'city']);
      const neighborhood = firstAddressValue(data.address, ['neighbourhood', 'suburb', 'quarter', 'village']);
      const street = firstAddressValue(data.address, ['road', 'pedestrian', 'residential', 'street']);
      const buildingNumber = firstAddressValue(data.address, ['house_number']);
      if (city) cityInput.value = city;
      if (district) districtInput.value = district;
      if (neighborhood) neighborhoodInput.value = neighborhood;
      if (exactAddressPanel && !exactAddressPanel.hidden) {
        if (city && !locationPickerElement.querySelector('[name="address_city"]').value) locationPickerElement.querySelector('[name="address_city"]').value = city;
        if (district && !locationPickerElement.querySelector('[name="address_district"]').value) locationPickerElement.querySelector('[name="address_district"]').value = district;
        if (neighborhood && !locationPickerElement.querySelector('[name="address_neighborhood"]').value) locationPickerElement.querySelector('[name="address_neighborhood"]').value = neighborhood;
        if (street && !locationPickerElement.querySelector('[name="street"]').value) locationPickerElement.querySelector('[name="street"]').value = street;
        if (buildingNumber && !locationPickerElement.querySelector('[name="building_number"]').value) locationPickerElement.querySelector('[name="building_number"]').value = buildingNumber;
      }
      titleElement.textContent = data.display_name || `${latitudeInput.value}, ${longitudeInput.value}`;
      statusElement.textContent = 'Adresi kontrol edip bu konumu doğrula.';
    } catch (error) {
      if (error.name === 'AbortError') return;
      titleElement.textContent = 'Adres otomatik bulunamadı';
      statusElement.textContent = 'İlçe ve mahalleyi kontrol ederek konumu yine de doğrulayabilirsin.';
    } finally {
      if (!controller.signal.aborted && lookupController === controller) confirmButton.disabled = false;
    }
  };

  locationMap.on('movestart', () => {
    window.clearTimeout(lookupTimer);
    lookupController?.abort();
    setUnconfirmed('Harita hareket ediyor…', 'Sabit iğneyi istediğin adresin üzerine getir.');
  });
  locationMap.on('moveend', () => {
    window.clearTimeout(lookupTimer);
    lookupTimer = window.setTimeout(resolveAddress, 1000);
  });
  confirmButton.addEventListener('click', () => {
    confirmedInput.value = '1';
    locationPickerElement.classList.add('confirmed');
    statusElement.textContent = 'Konum doğrulandı.';
    confirmButton.textContent = 'Doğrulandı';
    confirmButton.disabled = true;
  });

  const setPrecisionMode = () => {
    const exact = locationPickerElement.querySelector('[name="location_precision"]:checked')?.value === 'exact';
    exactAddressPanel.hidden = !exact;
    exactAddressInputs.forEach((input) => { input.required = exact && input.name !== 'apartment_number'; });
    addressMatchInput.required = exact;
    if (!exact) addressMatchInput.checked = false;
    if (exact) {
      const pairs = [
        ['address_city', 'city'],
        ['address_district', 'district'],
        ['address_neighborhood', 'neighborhood'],
      ];
      pairs.forEach(([targetName, sourceName]) => {
        const target = locationPickerElement.querySelector(`[name="${targetName}"]`);
        const source = locationPickerElement.querySelector(`[name="${sourceName}"]`);
        if (!target.value && source.value) target.value = source.value;
      });
    }
    window.setTimeout(() => locationMap.invalidateSize(), 0);
  };
  precisionInputs.forEach((input) => input.addEventListener('change', setPrecisionMode));
  setPrecisionMode();

  exactAddressInputs.forEach((input) => input.addEventListener('input', () => { addressMatchInput.checked = false; }));
  geocodeAddressButton?.addEventListener('click', async () => {
    const address = [
      locationPickerElement.querySelector('[name="street"]').value,
      locationPickerElement.querySelector('[name="building_number"]').value,
      locationPickerElement.querySelector('[name="address_neighborhood"]').value,
      locationPickerElement.querySelector('[name="address_district"]').value,
      locationPickerElement.querySelector('[name="address_city"]').value,
      'Türkiye',
    ].filter(Boolean).join(', ');
    if (address.length < 8) { showToast('Haritada bulmak için net adres alanlarını doldur.', 'error'); return; }
    const original = geocodeAddressButton.textContent;
    geocodeAddressButton.disabled = true;
    geocodeAddressButton.textContent = 'Adres aranıyor…';
    try {
      const query = new URLSearchParams({ format: 'jsonv2', q: address, limit: '1', countrycodes: 'tr', addressdetails: '1', 'accept-language': 'tr' });
      const response = await fetch(`https://nominatim.openstreetmap.org/search?${query}`, { headers: { Accept: 'application/json' } });
      if (!response.ok) throw new Error('Adres servisine ulaşılamadı.');
      const [result] = await response.json();
      if (!result) throw new Error('Yazdığın adres haritada bulunamadı. Alanları kontrol et.');
      addressMatchInput.checked = false;
      locationMap.setView([Number(result.lat), Number(result.lon)], 17);
      showToast('Adres haritada bulundu. İğneyi kontrol edip konumu doğrula.', 'success');
    } catch (error) { showToast(error.message, 'error'); }
    finally { geocodeAddressButton.disabled = false; geocodeAddressButton.textContent = original; }
  });

  locationPickerElement.querySelector('[data-use-current-location]')?.addEventListener('click', async (event) => {
    const button = event.currentTarget;
    const original = button.textContent;
    button.disabled = true;
    button.textContent = 'Konum alınıyor…';
    try {
      const { coords } = await requestBrowserLocation();
      const previous = locationMap.getCenter();
      const distanceMeters = previous.distanceTo([coords.latitude, coords.longitude]);
      if (distanceMeters > 100000 && confirmedInput.value === '1'
        && !(await siteConfirm('Yeni konum, daha önce seçtiğin yerden 100 km’den uzak.', {
          title: 'Konum değiştirilsin mi?',
          confirmText: 'Yeni konumu kullan',
          danger: false,
        }))) return;
      locationMap.setView([coords.latitude, coords.longitude], 16);
    } catch (error) {
      showToast(error.message, 'error');
    } finally {
      button.disabled = false;
      button.textContent = original;
    }
  });

  document.querySelector('[data-listing-form]')?.addEventListener('listing-draft-restored', (event) => {
    const latitude = Number(event.detail?.latitude);
    const longitude = Number(event.detail?.longitude);
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return;
    locationMap.setView([latitude, longitude], 16);
    if (event.detail?.confirmed === true) {
      window.setTimeout(() => {
        confirmedInput.value = '1';
        locationPickerElement.classList.add('confirmed');
        statusElement.textContent = 'Taslağındaki doğrulanmış konum geri yüklendi.';
        confirmButton.textContent = 'Doğrulandı';
        confirmButton.disabled = true;
      }, 1350);
    }
  });

  window.setTimeout(resolveAddress, 250);

  const editingId = document.querySelector('[data-listing-form]')?.dataset.editingId || '';
  if (editingId) {
    api(`/api/v1/me/listings/${encodeURIComponent(editingId)}`).then((listing) => {
      const form = document.querySelector('[data-listing-form]');
      const item = listing.items?.[0] || {};
      const setValue = (name, value) => { if (form.elements[name]) form.elements[name].value = value ?? ''; };
      const type = form.querySelector(`[name="listing_type"][value="${CSS.escape(listing.listing_type)}"]`);
      if (type) type.checked = true;
      const category = form.querySelector(`[name="category_id"][value="${CSS.escape(item.category_id || '')}"]`);
      if (category) { category.checked = true; category.closest('details').open = true; }
      setValue('headline', listing.headline || item.title); setValue('summary', listing.summary || '');
      setValue('title', item.title); setValue('description', item.description); setValue('pricing_unit', item.pricing_unit);
      setValue('price_amount', item.price_amount); setValue('currency', item.currency || 'TRY');
      setValue('estimated_duration_minutes', item.estimated_duration_minutes); setValue('schedule_label', item.schedule_label);
      (listing.items || []).slice(1).forEach((serviceItem) => addServiceItemEditor(serviceItem));
      form.elements.urgent.checked = item.urgent === true; form.elements.open_24_7.checked = item.open_24_7 === true;
      const precision = form.querySelector(`[name="location_precision"][value="${CSS.escape(listing.location_precision || 'neighborhood')}"]`);
      if (precision) { precision.checked = true; precision.dispatchEvent(new Event('change', { bubbles: true })); }
      setValue('city', listing.public_city); setValue('district', listing.public_district); setValue('neighborhood', listing.public_neighborhood);
      if (listing.private_address) {
        setValue('address_city', listing.private_address.city); setValue('address_district', listing.private_address.district);
        setValue('address_neighborhood', listing.private_address.neighborhood); setValue('street', listing.private_address.street);
        setValue('building_number', listing.private_address.building_number); setValue('apartment_number', listing.private_address.apartment_number);
      }
      if (listing.preferred_provider_kind) {
        const preference = form.querySelector(`[name="preferred_provider_kind"][value="${CSS.escape(listing.preferred_provider_kind)}"]`);
        if (preference) preference.checked = true;
      }
      if (listing.preferred_provider_gender) {
        const preference = form.querySelector(`[name="preferred_provider_gender"][value="${CSS.escape(listing.preferred_provider_gender)}"]`);
        if (preference) preference.checked = true;
      }
      const editLat = Number(listing.private_address?.latitude ?? listing.latitude);
      const editLng = Number(listing.private_address?.longitude ?? listing.longitude);
      if (Number.isFinite(editLat) && Number.isFinite(editLng)) locationMap.setView([editLat, editLng], 16);
      if (listing.service_radius_km === null) {
        form.elements.service_radius_unlimited.checked = true;
      } else {
        setValue('service_radius_km', listing.service_radius_km);
      }
      document.querySelector('[data-listing-upload-preview]')?.replaceChildren(...(listing.images || []).map((image) => {
        const card = createElement('span', 'existing-upload-preview');
        const img = document.createElement('img'); img.src = image.storage_path; img.alt = 'Mevcut ilan görseli'; card.append(img); return card;
      }));
      form.dispatchEvent(new CustomEvent('listing-form-prefilled'));
    }).catch((error) => {
      if (error.status === 401) goToLogin(null, currentLocalPath());
      else showToast(error.message, 'error');
    });
  }
}

const serviceItemsList = document.querySelector('[data-service-items-list]');
const serviceItemTemplate = document.querySelector('[data-service-item-template]');
const addServiceItemEditor = (data = {}) => {
  if (!serviceItemsList || !serviceItemTemplate || serviceItemsList.children.length >= 19) return null;
  const fragment = serviceItemTemplate.content.cloneNode(true);
  const card = fragment.querySelector('[data-service-item]');
  card.querySelectorAll('[data-item-field]').forEach((field) => {
    const key = field.dataset.itemField;
    if (field.type === 'checkbox') field.checked = data[key] !== false;
    else field.value = data[key] ?? (key === 'currency' ? 'TRY' : '');
  });
  const move = (offset) => {
    const sibling = offset < 0 ? card.previousElementSibling : card.nextElementSibling;
    if (!sibling) return;
    if (offset < 0) serviceItemsList.insertBefore(card, sibling);
    else serviceItemsList.insertBefore(sibling, card);
  };
  card.querySelector('[data-move-service-up]')?.addEventListener('click', () => move(-1));
  card.querySelector('[data-move-service-down]')?.addEventListener('click', () => move(1));
  card.querySelector('[data-remove-service-item]')?.addEventListener('click', () => card.remove());
  card.querySelector('[data-item-field="pricing_unit"]')?.addEventListener('change', (event) => {
    const price = card.querySelector('[data-item-field="price_amount"]');
    const noPrice = ['negotiable', 'free'].includes(event.currentTarget.value);
    price.disabled = noPrice; if (noPrice) price.value = '';
  });
  serviceItemsList.append(fragment);
  card.querySelector('[data-item-field="pricing_unit"]')?.dispatchEvent(new Event('change'));
  return card;
};
document.querySelector('[data-add-service-item]')?.addEventListener('click', () => addServiceItemEditor());

const collectServiceItems = (form, values) => {
  const firstNoPrice = ['negotiable', 'free'].includes(values.pricing_unit);
  const items = [{
    category_id: values.category_id,
    title: values.title,
    description: values.description,
    pricing_unit: values.pricing_unit,
    price_amount: firstNoPrice ? null : Number(values.price_amount),
    currency: values.currency || 'TRY',
    estimated_duration_minutes: values.estimated_duration_minutes ? Number(values.estimated_duration_minutes) : null,
    is_active: true,
    price_includes_vat: false,
    urgent: values.listing_type === 'service_request' ? form.elements.request_urgent.checked : form.elements.urgent.checked,
    open_24_7: values.listing_type === 'service_offer' && form.elements.open_24_7.checked,
    schedule_label: values.listing_type === 'service_offer' && !form.elements.open_24_7.checked ? values.schedule_label : '',
  }];
  serviceItemsList?.querySelectorAll('[data-service-item]').forEach((card) => {
    const value = (key) => card.querySelector(`[data-item-field="${key}"]`)?.value ?? '';
    const unit = value('pricing_unit') || 'negotiable';
    items.push({
      category_id: value('category_id'), title: value('title').trim(), description: value('description').trim(),
      pricing_unit: unit, price_amount: ['negotiable', 'free'].includes(unit) ? null : Number(value('price_amount')),
      currency: value('currency') || 'TRY',
      estimated_duration_minutes: value('estimated_duration_minutes') ? Number(value('estimated_duration_minutes')) : null,
      is_active: card.querySelector('[data-item-field="is_active"]')?.checked !== false,
      price_includes_vat: false, urgent: false, open_24_7: false, schedule_label: '',
    });
  });
  return items;
};

const listingDraftStorageKey = (form) => `listing-draft-v2:${form?.dataset.editingId || 'new'}`;
const newSubmissionKey = () => (window.crypto?.randomUUID?.() || `${Date.now()}-${Math.random()}-${Math.random()}`);
const listingSubmissionKey = (form) => {
  const key = `${listingDraftStorageKey(form)}:submission-key`;
  let value = localStorage.getItem(key);
  if (!value) { value = newSubmissionKey(); localStorage.setItem(key, value); }
  return value;
};
const clearListingDraft = (form) => {
  localStorage.removeItem(listingDraftStorageKey(form));
  localStorage.removeItem(`${listingDraftStorageKey(form)}:submission-key`);
};

document.querySelector('[data-listing-form]')?.addEventListener('submit', async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  const values = Object.fromEntries(new FormData(form).entries());
  const message = form.querySelector('[data-form-message]');
  const button = form.querySelector('button[type="submit"]');
  if (!values.category_id) {
    message.textContent = 'Önce ilanına uygun bir kategori seç.';
    form.querySelector('[data-category-picker]')?.scrollIntoView({ behavior: 'smooth', block: 'center' });
    return;
  }
  if (values.location_confirmed !== '1') {
    message.textContent = 'Önce haritadan konumunu seçip doğrula.';
    locationPickerElement?.scrollIntoView({ behavior: 'smooth', block: 'center' });
    return;
  }
  const exactLocation = values.location_precision === 'exact';
  if (exactLocation && !form.elements.address_matches_map.checked) {
    message.textContent = 'Net adres ile haritadaki iğnenin eşleştiğini onayla.';
    form.elements.address_matches_map.scrollIntoView({ behavior: 'smooth', block: 'center' });
    return;
  }
  button.disabled = true;
  message.textContent = '';
  try {
    const editingId = form.dataset.editingId || '';
    const publicCity = exactLocation ? values.address_city : values.city;
    const publicDistrict = exactLocation ? values.address_district : values.district;
    const publicNeighborhood = exactLocation ? values.address_neighborhood : values.neighborhood;
    const listing = await api(editingId ? `/api/v1/listings/${encodeURIComponent(editingId)}` : '/api/v1/listings', {
      method: editingId ? 'PUT' : 'POST',
      headers: editingId ? {} : { 'Idempotency-Key': listingSubmissionKey(form) },
      body: JSON.stringify({
        listing_type: values.listing_type,
        headline: values.headline,
        summary: values.summary || '',
        location: {
          latitude: Number(values.latitude),
          longitude: Number(values.longitude),
          city: publicCity,
          district: publicDistrict,
          neighborhood: publicNeighborhood,
          precision: values.location_precision || 'neighborhood',
        },
        ...(values.location_precision === 'exact' ? {
          private_address: {
            latitude: Number(values.latitude),
            longitude: Number(values.longitude),
            city: values.address_city,
            district: values.address_district,
            neighborhood: values.address_neighborhood,
            street: values.street,
            building_number: values.building_number,
            apartment_number: values.apartment_number,
          },
        } : {}),
        service_radius_km: form.elements.service_radius_unlimited.checked ? null : Number(values.service_radius_km || 25),
        preferred_provider_kind: values.listing_type === 'service_request' ? (values.preferred_provider_kind || null) : null,
        preferred_provider_gender: values.listing_type === 'service_request' ? (values.preferred_provider_gender || null) : null,
        items: collectServiceItems(form, values),
      }),
    });
    const imageFiles = [...form.elements.images.files].slice(0, 8);
    for (const file of imageFiles) {
      const upload = new FormData();
      upload.append('purpose', 'listing');
      upload.append('listing_id', listing.id);
      upload.append('file', file);
      await api('/api/v1/uploads/images', { method: 'POST', body: upload });
    }
    clearListingDraft(form);
    window.location.assign('/ilanlarim?submitted=1');
  } catch (error) {
    if (error.status === 401 || /giriş|oturum/i.test(error.message)) goToLogin(null, '/ilan-ver');
    else message.textContent = error.message;
  } finally {
    button.disabled = false;
  }
});

document.querySelectorAll('[data-service-radius]').forEach((input) => {
  const card = input.closest('[data-service-radius-card]');
  const output = card?.querySelector('[data-service-radius-value]');
  const unlimited = card?.querySelector('[name="service_radius_unlimited"]');
  const render = () => {
    input.disabled = unlimited?.checked === true;
    card?.classList.toggle('unlimited', unlimited?.checked === true);
    if (output) output.textContent = unlimited?.checked ? 'Mesafe sınırı yok' : `${input.value} km`;
  };
  input.addEventListener('input', render);
  unlimited?.addEventListener('change', render);
  document.querySelector('[data-listing-form]')?.addEventListener('listing-form-prefilled', render);
  render();
});

const listingForm = document.querySelector('[data-listing-form]');
if (listingForm) {
  const offerAvailability = listingForm.querySelector('[data-offer-availability]');
  const requestUrgent = listingForm.querySelector('[data-request-urgent]');
  const requestPreferences = listingForm.querySelector('[data-request-preferences]');
  const open24 = listingForm.elements.open_24_7;
  const urgent = listingForm.elements.urgent;
  const scheduleField = listingForm.querySelector('[data-schedule-field]');
  const syncListingType = () => {
    const offer = listingForm.elements.listing_type.value === 'service_offer';
    offerAvailability.hidden = !offer;
    requestUrgent.hidden = offer;
    requestPreferences.hidden = offer;
    if (!offer) { open24.checked = false; urgent.checked = false; }
    syncOpen24();
  };
  const syncOpen24 = () => {
    const alwaysOpen = open24.checked && !offerAvailability.hidden;
    scheduleField.hidden = alwaysOpen;
    urgent.closest('label').hidden = alwaysOpen;
    if (alwaysOpen) { urgent.checked = false; listingForm.elements.schedule_label.value = ''; }
  };
  listingForm.querySelectorAll('[name="listing_type"]').forEach((input) => input.addEventListener('change', syncListingType));
  open24.addEventListener('change', syncOpen24);
  listingForm.addEventListener('listing-form-prefilled', () => { syncListingType(); syncOpen24(); });
  syncListingType();

  const uploadInput = listingForm.elements.images;
  const uploadPreview = listingForm.querySelector('[data-listing-upload-preview]');
  uploadInput.addEventListener('change', () => {
    uploadPreview.replaceChildren();
    const files = [...uploadInput.files].slice(0, 8);
    if (!files.length) { uploadPreview.append(createElement('span', '', 'Henüz görsel seçilmedi.')); return; }
    files.forEach((file) => {
      const card = createElement('span', 'listing-upload-preview-card');
      const image = document.createElement('img');
      image.src = URL.createObjectURL(file); image.alt = '';
      image.addEventListener('load', () => URL.revokeObjectURL(image.src), { once: true });
      card.append(image, createElement('small', '', file.name));
      uploadPreview.append(card);
    });
    if (uploadInput.files.length > 8) showToast('En fazla 8 görsel yüklenecek.', 'info');
  });

  if (!listingForm.dataset.editingId) {
    let draftTimer;
    let dirty = false;
    const saveDraft = () => {
      if (!dirty) return;
      const controls = [...listingForm.querySelectorAll('[name]')]
        .filter((control) => control.type !== 'file' && control.type !== 'submit')
        .map((control) => ({
          name: control.name,
          type: control.type,
          value: control.value,
          checked: 'checked' in control ? control.checked : undefined,
        }));
      localStorage.setItem(listingDraftStorageKey(listingForm), JSON.stringify({
        version: 2,
        saved_at: Date.now(),
        controls,
        image_names: [...uploadInput.files].slice(0, 8).map((file) => file.name),
      }));
      listingSubmissionKey(listingForm);
    };
    const scheduleDraft = () => {
      dirty = true;
      window.clearTimeout(draftTimer);
      draftTimer = window.setTimeout(saveDraft, 350);
    };
    listingForm.addEventListener('input', scheduleDraft);
    listingForm.addEventListener('change', scheduleDraft);
    window.addEventListener('pagehide', saveDraft);

    let savedDraft;
    try { savedDraft = JSON.parse(localStorage.getItem(listingDraftStorageKey(listingForm)) || 'null'); } catch (_) { savedDraft = null; }
    if (savedDraft?.version === 2 && Array.isArray(savedDraft.controls)) {
      siteConfirm('Başlık, açıklama, kategori ve konum bilgilerin kaldığın yerden geri yüklensin mi?', {
        eyebrow: 'KAYDEDİLMİŞ TASLAK',
        title: 'Yarım kalan ilanın bulundu',
        confirmText: 'Taslağı geri yükle',
        cancelText: 'Taslağı sil',
        danger: false,
      }).then((restore) => {
        if (!restore) { clearListingDraft(listingForm); return; }
        savedDraft.controls.forEach((saved) => {
          const matches = [...listingForm.querySelectorAll(`[name="${CSS.escape(saved.name)}"]`)];
          const control = ['checkbox', 'radio'].includes(saved.type)
            ? matches.find((item) => String(item.value) === String(saved.value))
            : matches[0];
          if (!control || control.type === 'file') return;
          if (['checkbox', 'radio'].includes(saved.type)) control.checked = saved.checked === true;
          else control.value = saved.value ?? '';
        });
        listingForm.querySelectorAll('[name="listing_type"], [name="location_precision"], [name="open_24_7"], [name="service_radius_unlimited"]')
          .forEach((control) => control.dispatchEvent(new Event('change', { bubbles: true })));
        listingForm.dispatchEvent(new CustomEvent('listing-form-prefilled'));
        listingForm.dispatchEvent(new CustomEvent('listing-draft-restored', { detail: {
          latitude: listingForm.elements.latitude.value,
          longitude: listingForm.elements.longitude.value,
          confirmed: listingForm.elements.location_confirmed.value === '1',
        } }));
        if ((savedDraft.image_names || []).length) {
          showToast('Taslak geri yüklendi. Güvenlik nedeniyle görselleri yeniden seçmelisin.', 'info', 6500);
        } else {
          showToast('İlan taslağın geri yüklendi.', 'success');
        }
        dirty = true;
      });
    }
  }
}

function createElement(tag, className, text) {
  const element = document.createElement(tag);
  if (className) element.className = className;
  if (text !== undefined) element.textContent = text;
  return element;
}

const ownProfileRedirect = document.querySelector('[data-own-profile-redirect]');
if (ownProfileRedirect) {
  api('/api/v1/auth/me')
    .then(({ user }) => window.location.replace(`/profil/${encodeURIComponent(user.id)}`))
    .catch(() => window.location.replace('/giris'));
}

const publicProfile = document.querySelector('[data-public-profile]');
if (publicProfile) {
  api('/api/v1/auth/me').then(({ user }) => {
    if (String(user.id) === String(publicProfile.dataset.profileId)) {
      publicProfile.querySelector('[data-owner-profile-actions]').hidden = false;
    }
  }).catch(() => {});
}

const profileEditor = document.querySelector('[data-profile-editor]');
if (profileEditor) {
  const form = profileEditor.querySelector('[data-profile-form]');
  const citySelect = form.elements.city;
  const districtSelect = form.elements.district;
  const profileTypeSelect = form.elements.profile_type;
  const businessFields = profileEditor.querySelector('[data-business-fields]');
  const avatarPreview = profileEditor.querySelector('[data-avatar-preview]');
  const avatarStatus = profileEditor.querySelector('[data-avatar-upload-status]');
  const removeAvatarButton = profileEditor.querySelector('[data-remove-avatar]');
  let currentUser;
  let currentAvatarId = '';
  let locations = {};

  const renderDistricts = (city, selected = '') => {
    districtSelect.replaceChildren(new Option(city ? 'İlçe seç' : 'Önce il seç', ''));
    (locations[city] || []).forEach((district) => districtSelect.add(new Option(district, district)));
    districtSelect.disabled = !city;
    districtSelect.value = selected;
  };
  const renderProfileType = () => {
    const business = profileTypeSelect.value === 'business';
    businessFields.hidden = !business;
    ['business_name', 'business_address'].forEach((name) => { form.elements[name].required = business; });
  };
  const renderAvatar = (path, name) => {
    avatarPreview.replaceChildren();
    if (path) {
      const image = document.createElement('img');
      image.src = path;
      image.alt = `${name || 'Profil'} fotoğrafı`;
      avatarPreview.append(image);
    } else {
      avatarPreview.textContent = (name || 'H').slice(0, 1).toLocaleUpperCase('tr');
    }
  };
  const checkPreferences = (name, ids) => {
    form.querySelectorAll(`input[name="${name}"]`).forEach((input) => {
      input.checked = (ids || []).map(String).includes(String(input.value));
    });
  };

  Promise.all([api('/api/v1/auth/me'), api('/api/v1/profile'), api('/api/v1/locations')]).then(([session, profile, locationData]) => {
    currentUser = session.user;
    locations = locationData.items || {};
    Object.keys(locations).forEach((city) => citySelect.add(new Option(city, city)));
    form.elements.display_name.value = profile.display_name || '';
    form.elements.profile_type.value = profile.profile_type || 'person';
    form.elements.gender.value = profile.gender || '';
    form.elements.phone_e164.value = profile.phone_e164 || '';
    form.elements.phone_visible.checked = profile.phone_visible === true;
    form.elements.bio.value = profile.bio || '';
    form.elements.business_name.value = profile.business_name || '';
    form.elements.business_address.value = profile.business_address || '';
    form.elements.business_services.value = profile.business_services || '';
    citySelect.value = profile.city || '';
    renderDistricts(citySelect.value, profile.district || '');
    renderProfileType();
    checkPreferences('receive_category_ids', profile.category_preferences?.receive);
    checkPreferences('provide_category_ids', profile.category_preferences?.provide);
    renderAvatar(profile.avatar_path, profile.display_name);
    if (profile.avatar_path) currentAvatarId = profile.avatar_path.split('/').filter(Boolean).pop() || '';
    removeAvatarButton.disabled = !currentAvatarId;
  }).catch(() => goToLogin(null, currentLocalPath()));

  citySelect.addEventListener('change', () => renderDistricts(citySelect.value));
  profileTypeSelect.addEventListener('change', renderProfileType);

  const previewAvatarFile = (file) => {
    if (!file) return;
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) {
      showToast('Yalnızca JPEG, PNG veya WebP fotoğraf seçebilirsin.', 'error');
      return;
    }
    const url = URL.createObjectURL(file);
    renderAvatar(url, form.elements.display_name.value);
    avatarPreview.querySelector('img')?.addEventListener('load', () => URL.revokeObjectURL(url), { once: true });
    avatarStatus.textContent = 'Kaydettiğinde fotoğraf yüklenecek.';
  };
  form.elements.avatar_gallery.addEventListener('change', () => previewAvatarFile(form.elements.avatar_gallery.files[0]));
  form.elements.avatar_camera.addEventListener('change', () => previewAvatarFile(form.elements.avatar_camera.files[0]));

  removeAvatarButton.addEventListener('click', async () => {
    if (!currentAvatarId || !(await siteConfirm('Mevcut profil fotoğrafın hesabından kaldırılacak.', {
      title: 'Profil fotoğrafı kaldırılsın mı?',
      confirmText: 'Fotoğrafı kaldır',
    }))) return;
    try {
      await api(`/api/v1/uploads/images/${encodeURIComponent(currentAvatarId)}`, { method: 'DELETE' });
      currentAvatarId = '';
      renderAvatar('', form.elements.display_name.value || currentUser?.display_name);
      removeAvatarButton.disabled = true;
      avatarStatus.textContent = 'Profil fotoğrafı kaldırıldı.';
    } catch (error) { showToast(error.message, 'error'); }
  });

  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    const data = new FormData(form);
    const values = Object.fromEntries(data.entries());
    values.phone_visible = form.elements.phone_visible.checked;
    values.receive_category_ids = data.getAll('receive_category_ids');
    values.provide_category_ids = data.getAll('provide_category_ids');
    delete values.avatar_gallery;
    delete values.avatar_camera;
    const message = form.querySelector('[data-form-message]');
    const submit = form.querySelector('button[type="submit"]');
    submit.disabled = true;
    message.textContent = '';
    message.classList.remove('success');
    try {
      await api('/api/v1/profile', { method: 'PUT', body: JSON.stringify(values) });
      const avatarFile = form.elements.avatar_gallery.files[0] || form.elements.avatar_camera.files[0];
      if (avatarFile) {
        avatarStatus.textContent = 'Fotoğraf güvenli biçimde işleniyor…';
        const upload = new FormData();
        upload.append('purpose', 'avatar');
        upload.append('file', avatarFile);
        const media = await api('/api/v1/uploads/images', { method: 'POST', body: upload });
        currentAvatarId = media.id;
        renderAvatar(media.url, values.display_name);
        form.elements.avatar_gallery.value = '';
        form.elements.avatar_camera.value = '';
        removeAvatarButton.disabled = false;
        avatarStatus.textContent = 'Profil fotoğrafı yüklendi.';
      }
      message.textContent = 'Profilin ve ilgi alanların kaydedildi.';
      message.classList.add('success');
      window.setTimeout(() => window.location.assign('/profil'), 700);
    } catch (error) {
      message.textContent = error.message;
    } finally {
      submit.disabled = false;
    }
  });
}

const settingsPage = document.querySelector('[data-settings-page]');
if (settingsPage) {
  let settingsUser;
  settingsPage.querySelector('[data-beta-feedback-form]')?.addEventListener('submit', async (event) => {
    event.preventDefault();
    const form = event.currentTarget;
    const message = form.querySelector('[data-form-message]');
    const submit = form.querySelector('[type="submit"]');
    submit.disabled = true;
    message.textContent = 'Gönderiliyor…';
    try {
      await api('/api/v1/beta/feedback', {
        method: 'POST',
        body: JSON.stringify(Object.fromEntries(new FormData(form).entries())),
      });
      form.reset();
      message.textContent = 'Geri bildirimin alındı. Teşekkür ederiz.';
    } catch (error) {
      message.textContent = error.message || 'Geri bildirim gönderilemedi.';
    } finally {
      submit.disabled = false;
    }
  });
  const emailStatus = settingsPage.querySelector('[data-email-status]');
  const phoneStatus = settingsPage.querySelector('[data-phone-status]');
  const resendButton = settingsPage.querySelector('[data-resend-verification]');
  const phoneForm = settingsPage.querySelector('[data-phone-verification-form]');
  const preferenceInput = settingsPage.querySelector('[name="message_email_notifications"]');

  const blockedUsersBox = settingsPage.querySelector('[data-blocked-users]');
  const loadBlockedUsers = async () => {
    if (!blockedUsersBox) return;
    const data = await api('/api/v1/blocks');
    const items = data.items || [];
    blockedUsersBox.replaceChildren();
    if (!items.length) {
      blockedUsersBox.append(createElement('div', 'blocked-user-empty', 'Şu anda engellediğin bir kullanıcı yok. Engellediğin kişiler burada görünür.'));
      return;
    }
    items.forEach((item) => {
      const row = createElement('article', 'blocked-user-row');
      const avatar = createElement('span', 'blocked-user-avatar');
      if (item.avatar_path) {
        const image = document.createElement('img');
        image.src = item.avatar_path;
        image.alt = '';
        image.loading = 'lazy';
        image.addEventListener('error', () => {
          avatar.replaceChildren();
          avatar.textContent = (item.display_name || 'K').slice(0, 1).toLocaleUpperCase('tr');
        }, { once: true });
        avatar.append(image);
      } else avatar.textContent = (item.display_name || 'K').slice(0, 1).toLocaleUpperCase('tr');
      const copy = createElement('div', 'blocked-user-copy');
      copy.append(
        createElement('strong', '', item.display_name || 'Kullanıcı'),
        createElement('small', '', item.created_at ? `${new Date(item.created_at).toLocaleDateString('tr-TR')} tarihinde engellendi` : 'Engellenen kullanıcı'),
      );
      const unblock = createElement('button', 'secondary-button unblock-user-button', 'Engeli kaldır');
      unblock.type = 'button';
      unblock.addEventListener('click', async () => {
        if (!(await siteConfirm(`${item.display_name || 'Bu kullanıcı'} üzerindeki engeli kaldırdığında yeniden mesajlaşabilir ve etkileşim kurabilirsin.`, {
          title: 'Engel kaldırılsın mı?',
          confirmText: 'Engeli kaldır',
        }))) return;
        unblock.disabled = true;
        try {
          await api(`/api/v1/blocks/${encodeURIComponent(item.id)}`, { method: 'DELETE' });
          showToast('Kullanıcının engeli kaldırıldı.', 'success');
          await loadBlockedUsers();
        } catch (error) {
          showToast(error.message || 'Engel kaldırılamadı.', 'error');
          unblock.disabled = false;
        }
      });
      row.append(avatar, copy, unblock);
      blockedUsersBox.append(row);
    });
  };

  const loadSessions = async () => {
    const box = settingsPage.querySelector('[data-session-list]');
    const data = await api('/api/v1/account/sessions');
    box.replaceChildren();
    (data.items || []).forEach((item) => {
      const row = createElement('div', 'session-row');
      const label = item.device_name || (item.session_kind === 'mobile' ? 'Mobil uygulama' : 'Web tarayıcısı');
      row.append(createElement('strong', '', `${label}${item.is_current ? ' · Bu cihaz' : ''}`));
      row.append(createElement('span', '', `${item.session_kind === 'mobile' ? 'Mobil' : 'Web'} · Son kullanım ${new Date(item.last_seen_at).toLocaleString('tr-TR')}`));
      box.append(row);
    });
    if (!box.children.length) box.textContent = 'Açık oturum bulunamadı.';
  };

  api('/api/v1/auth/me').then(({ user }) => {
    settingsUser = user;
    emailStatus.textContent = user.email_verified_at ? `✓ ${user.email} doğrulandı` : `! ${user.email} henüz doğrulanmadı`;
    phoneStatus.textContent = user.phone_verified_at ? `✓ ${user.phone_e164} doğrulandı` : 'Telefonun henüz doğrulanmadı.';
    phoneForm.elements.phone.value = user.phone_e164 || '';
    preferenceInput.checked = user.message_email_notifications === true;
    resendButton.hidden = Boolean(user.email_verified_at);
    loadSessions().catch(() => {});
    loadBlockedUsers().catch((error) => {
      if (blockedUsersBox) blockedUsersBox.replaceChildren(createElement('div', 'blocked-user-empty', error.message || 'Engellenen kullanıcılar yüklenemedi.'));
    });
  }).catch(() => goToLogin(null, currentLocalPath()));

  resendButton.addEventListener('click', async () => {
    resendButton.disabled = true;
    try {
      await api('/api/v1/auth/email/resend', { method: 'POST' });
      emailStatus.textContent = 'Doğrulama bağlantısı e-posta adresine yeniden gönderildi.';
    } catch (error) { emailStatus.textContent = error.message; }
    finally { resendButton.disabled = false; }
  });

  settingsPage.querySelector('[data-email-change-form]').addEventListener('submit', async (event) => {
    event.preventDefault();
    const emailForm = event.currentTarget;
    const message = emailForm.querySelector('[data-form-message]');
    try {
      await api('/api/v1/account/email/change', { method: 'POST', body: JSON.stringify(Object.fromEntries(new FormData(emailForm).entries())) });
      message.textContent = 'Yeni adresine doğrulama bağlantısı gönderildi.';
      message.classList.add('success');
      emailForm.reset();
    } catch (error) { message.textContent = error.message; }
  });

  phoneForm.querySelector('[data-request-phone-code]').addEventListener('click', async () => {
    const message = phoneForm.querySelector('[data-form-message]');
    try {
      const result = await api('/api/v1/account/phone/request', { method: 'POST', body: JSON.stringify({ phone: phoneForm.elements.phone.value }) });
      phoneForm.querySelector('[data-phone-code-area]').hidden = false;
      phoneForm.elements.code.required = true;
      message.textContent = `${result.phone_masked} numarasına kod gönderildi.`;
      message.classList.add('success');
      phoneForm.elements.code.focus();
    } catch (error) { message.textContent = error.message; }
  });
  phoneForm.addEventListener('submit', async (event) => {
    event.preventDefault();
    const message = phoneForm.querySelector('[data-form-message]');
    try {
      await api('/api/v1/account/phone/verify', { method: 'POST', body: JSON.stringify({ code: phoneForm.elements.code.value }) });
      message.textContent = 'Telefon numaran doğrulandı.';
      message.classList.add('success');
      phoneStatus.textContent = `✓ ${phoneForm.elements.phone.value} doğrulandı`;
    } catch (error) { message.textContent = error.message; }
  });

  settingsPage.querySelector('[data-password-change-form]').addEventListener('submit', async (event) => {
    event.preventDefault();
    const passwordForm = event.currentTarget;
    const values = Object.fromEntries(new FormData(passwordForm).entries());
    const message = passwordForm.querySelector('[data-form-message]');
    if (values.password !== values.password_confirmation) { message.textContent = 'Yeni şifreler aynı olmalı.'; return; }
    try {
      await api('/api/v1/account/password', { method: 'PUT', body: JSON.stringify(values) });
      message.textContent = 'Şifren güncellendi; diğer cihazlardaki oturumlar kapatıldı.';
      message.classList.add('success');
      passwordForm.reset();
      await loadSessions();
    } catch (error) { message.textContent = error.message; }
  });
  settingsPage.querySelector('[data-revoke-other-sessions]').addEventListener('click', async () => {
    if (!(await siteConfirm('Bu cihaz dışındaki bütün açık oturumların güvenli biçimde kapatılacak.', {
      title: 'Diğer oturumlar kapatılsın mı?',
      confirmText: 'Oturumları kapat',
    }))) return;
    await api('/api/v1/account/sessions/revoke-others', { method: 'POST' });
    await loadSessions();
  });
  settingsPage.querySelector('[data-save-preferences]').addEventListener('click', async (event) => {
    event.currentTarget.disabled = true;
    try {
      await api('/api/v1/account/preferences', { method: 'PUT', body: JSON.stringify({ message_email_notifications: preferenceInput.checked }) });
      showToast('Bildirim tercihin kaydedildi.', 'success');
    } catch (error) { showToast(error.message, 'error'); }
    finally { event.currentTarget.disabled = false; }
  });
  settingsPage.querySelector('[data-copy-data]').addEventListener('click', async () => {
    const data = await api('/api/v1/privacy/export');
    await navigator.clipboard.writeText(JSON.stringify(data, null, 2));
    showToast('Veri kopyan panoya kopyalandı.', 'success');
  });
  const privacyRequestList = settingsPage.querySelector('[data-privacy-request-list]');
  const privacyTypeLabels = { correction: 'Düzeltme', objection: 'İtiraz / inceleme', deletion: 'Silme', export: 'Veri erişimi' };
  const privacyStatusLabels = { pending: 'Alındı', processing: 'İnceleniyor', completed: 'Tamamlandı', rejected: 'Gerekçeli olarak reddedildi' };
  const loadPrivacyRequests = async () => {
    if (!privacyRequestList) return;
    try {
      const data = await api('/api/v1/privacy/requests');
      privacyRequestList.replaceChildren();
      const items = data.items || [];
      if (!items.length) {
        privacyRequestList.append(createElement('p', 'muted-copy', 'Henüz açık veya geçmiş bir KVKK başvurun yok.'));
        return;
      }
      items.forEach((item) => {
        const row = createElement('article', 'privacy-request-row');
        const copy = createElement('div');
        copy.append(
          createElement('strong', '', privacyTypeLabels[item.request_type] || item.request_type),
          createElement('small', '', item.details || 'Açıklama belirtilmedi.'),
        );
        row.append(copy, createElement('span', `status-badge ${item.status}`, privacyStatusLabels[item.status] || item.status));
        privacyRequestList.append(row);
      });
    } catch (error) {
      privacyRequestList.textContent = error.message;
    }
  };
  settingsPage.querySelectorAll('[data-privacy-request]').forEach((button) => button.addEventListener('click', async () => {
    const requestType = button.dataset.privacyRequest;
    const deletion = requestType === 'deletion';
    if (deletion && !(await siteConfirm('Talep kabul edilip tamamlandığında hesabın anonimleştirilir, ilanların kaldırılır ve açık oturumların kapatılır.', {
      title: 'Silme talebine devam edilsin mi?',
      confirmText: 'Devam et',
    }))) return;
    const values = await siteFormModal({
      eyebrow: 'KVKK BAŞVURUSU',
      title: `${privacyTypeLabels[requestType] || 'Hak'} talebini açıkla`,
      description: deletion
        ? 'Silinmesini istediğin kapsamı ve varsa korunması gereken bilgileri yaz.'
        : 'Talebini değerlendirebilmemiz için hangi veri veya işlemle ilgili olduğunu açıkça yaz.',
      fields: [{ name: 'details', label: 'Talep ayrıntısı', type: 'textarea', rows: 5, minLength: 10, placeholder: 'En az 10 karakterle talebini açıkla.' }],
      confirmText: 'Başvuruyu gönder',
      validate: (values) => values.details.trim().length < 10 ? 'Talebini en az 10 karakterle açıkla.' : '',
    });
    if (!values) return;
    button.disabled = true;
    try {
      await api('/api/v1/privacy/requests', { method: 'POST', body: JSON.stringify({ request_type: requestType, details: values.details.trim() }) });
      showToast('KVKK başvurun kayıt altına alındı.', 'success');
      await loadPrivacyRequests();
    } catch (error) { showToast(error.message, 'error'); }
    finally { button.disabled = false; }
  }));
  loadPrivacyRequests();
  settingsPage.querySelector('[data-logout]').addEventListener('click', async () => {
    await api('/api/v1/auth/logout', { method: 'POST' });
    window.location.assign('/');
  });
}

const myListingsPage = document.querySelector('[data-my-listings-page]');
if (myListingsPage) {
  const box = myListingsPage.querySelector('[data-my-listings]');
  if (new URL(window.location.href).searchParams.get('submitted') === '1') {
    showToast('İlanın alındı ve güvenlik kontrolü için onay sırasına eklendi.', 'success', 6500);
    window.history.replaceState({}, '', '/ilanlarim');
  }
  api('/api/v1/me/listings?limit=100').then((data) => {
    box.replaceChildren();
    const items = data.items || [];
    if (!items.length) {
      const empty = createElement('div', 'empty-state');
      empty.append(createElement('h3', '', 'Henüz ilanın yok.'), createElement('p', '', 'İlk ilanını ücretsiz yayınlayabilirsin.'));
      const link = createElement('a', 'primary-button', 'İlan ver');
      link.href = '/ilan-ver';
      empty.append(link);
      box.append(empty);
      return;
    }
    items.forEach((item) => {
      const row = createElement('article', 'managed-listing-row');
      const copy = createElement('div');
      const type = item.listing_type === 'service_request' ? 'Hizmet alıyor' : 'Hizmet veriyor';
      const statusLabel = { active: 'Yayında', pending: 'Onay bekliyor', rejected: 'Düzenleme gerekli', paused: 'Yayın durduruldu', draft: 'Taslak', completed: 'Tamamlandı', expired: 'Süresi doldu' }[item.status] || item.status;
      copy.append(createElement('span', `status-badge ${item.status}`, statusLabel), createElement('strong', '', item.title), createElement('small', '', `${type} · ${item.public_district || ''}`));
      const actions = createElement('div', 'managed-listing-actions');
      const edit = createElement('a', 'primary-button', 'Düzenle');
      edit.href = `/ilan/${encodeURIComponent(item.id)}/duzenle`;
      if (item.status === 'active') {
        const link = createElement('a', 'secondary-button', 'İlanı görüntüle');
        link.href = `/ilan/${encodeURIComponent(item.slug)}`;
        actions.append(link);
      }
      actions.append(edit);
      row.append(copy, actions);
      box.append(row);
    });
  }).catch(() => goToLogin(null, currentLocalPath()));
}

document.querySelectorAll('[data-reveal-phone]').forEach((button) => {
  button.addEventListener('click', async () => {
    try {
      if (!button.dataset.phone) {
        const result = await api(`/api/v1/profiles/${encodeURIComponent(button.dataset.profileId)}/phone-reveal`, { method: 'POST' });
        button.dataset.phone = result.phone_e164;
        button.textContent = `☎ ${result.phone_e164} · Kopyala`;
        return;
      }
      await navigator.clipboard.writeText(button.dataset.phone);
      button.textContent = `✓ ${button.dataset.phone} kopyalandı`;
    } catch (error) {
      if (/giriş|oturum/i.test(error.message)) goToLogin(null, currentLocalPath());
      else showToast(error.message, 'error');
    }
  });
});

const favoritesPage = document.querySelector('[data-favorites-page]');
if (favoritesPage) {
  const favoriteList = favoritesPage.querySelector('[data-favorite-list]');
  const savedFilterList = favoritesPage.querySelector('[data-favorite-search-list]');
  const favoriteTabs = [...favoritesPage.querySelectorAll('[data-favorites-tab]')];
  favoriteTabs.forEach((tab) => tab.addEventListener('click', () => {
    favoriteTabs.forEach((item) => {
      const active = item === tab;
      item.classList.toggle('active', active);
      item.setAttribute('aria-selected', active ? 'true' : 'false');
    });
    favoritesPage.querySelectorAll('[data-favorites-panel]').forEach((panel) => { panel.hidden = panel.dataset.favoritesPanel !== tab.dataset.favoritesTab; });
  }));
  const loadFavorites = async () => {
    const data = await api('/api/v1/favorites?limit=50');
    favoriteList.replaceChildren();
    if (!(data.items || []).length) {
      favoriteList.append(createElement('div', 'empty-state', 'Henüz favoriye eklediğin bir ilan yok.'));
      return;
    }
    data.items.forEach((item) => {
      const row = createElement('article', 'favorite-row');
      const link = createElement('a');
      link.href = `/ilan/${encodeURIComponent(item.slug)}`;
      link.append(createElement('strong', '', item.title));
      link.append(createElement('p', '', `${item.public_neighborhood}, ${item.public_district}`));
      const remove = createElement('button', '', 'Kaldır');
      remove.type = 'button';
      remove.addEventListener('click', async () => {
        await api(`/api/v1/favorites/${encodeURIComponent(item.id)}`, { method: 'DELETE' });
        row.remove();
        if (!favoriteList.children.length) loadFavorites();
      });
      row.append(link, remove);
      favoriteList.append(row);
    });
  };
  const loadFavoriteSearches = async () => {
    if (!knownCategoryLabels.size) {
      const categories = await api('/api/v1/categories');
      (categories.items || []).forEach((category) => knownCategoryLabels.set(String(category.id), category.label));
    }
    const data = await api('/api/v1/saved-searches');
    savedFilterList.replaceChildren();
    if (!(data.items || []).length) {
      savedFilterList.append(createElement('div', 'empty-state', 'Henüz kayıtlı filtren yok. Keşfet ekranındaki filtreleri seçip favorilere kaydedebilirsin.'));
      return;
    }
    data.items.forEach((item) => {
      const row = createElement('article', 'saved-filter-card');
      const head = createElement('div', 'saved-filter-card-head');
      head.append(createElement('span', 'status-pill', item.notification_enabled ? 'Bildirim açık' : 'Kayıtlı filtre'));
      const open = createElement('button', 'secondary-button', 'Sonuçları gör');
      open.type = 'button';
      open.addEventListener('click', () => applySavedSearch(item.filters));
      head.append(open);
      const title = createElement('h2', '', item.name || autoSavedSearchName(item.filters || {}));
      const details = createElement('div', 'saved-filter-details');
      const parts = filterSummaryParts(item.filters || {}, false);
      (parts.length ? parts : ['Tüm ilanlar']).forEach((part) => details.append(createElement('span', '', part)));
      const actions = createElement('div', 'saved-filter-actions');
      const remove = createElement('button', 'text-danger-button', 'Kayıtlı filtreyi sil');
      remove.type = 'button';
      remove.addEventListener('click', async () => {
        if (!(await siteConfirm('Bu filtre kayıtlı aramalarından kalıcı olarak kaldırılacak.', {
          title: 'Kayıtlı filtre silinsin mi?',
          confirmText: 'Filtreyi sil',
        }))) return;
        await api(`/api/v1/saved-searches/${encodeURIComponent(item.id)}`, { method: 'DELETE' });
        row.remove();
        showToast('Kayıtlı filtre kaldırıldı.', 'success');
        if (!savedFilterList.children.length) await loadFavoriteSearches();
      });
      actions.append(remove);
      row.append(head, title, details, actions);
      savedFilterList.append(row);
    });
  };
  Promise.all([loadFavorites(), loadFavoriteSearches()]).catch(() => goToLogin(null, currentLocalPath()));
}

const messagesPage = document.querySelector('[data-messages-page]');
if (messagesPage) {
  const list = messagesPage.querySelector('[data-conversation-list]');
  const messageBox = messagesPage.querySelector('[data-chat-messages]');
  const form = messagesPage.querySelector('[data-message-form]');
  const empty = messagesPage.querySelector('.chat-empty');
  const personHeader = messagesPage.querySelector('[data-chat-person]');
  const uploadPreview = messagesPage.querySelector('[data-chat-upload-preview]');
  let selectedConversation = new URL(window.location.href).searchParams.get('conversation');
  let currentUserId = '';
  let conversations = [];
  let activeConversationSection = 'receive';
  let pollTimer;
  let lastMessageId = 0;
  let loadGeneration = 0;

  const loadMessages = async (generation = loadGeneration) => {
    if (!selectedConversation) return;
    const wasNearBottom = messageBox.scrollHeight - messageBox.scrollTop - messageBox.clientHeight < 80;
    let hasMore = true;
    while (hasMore && generation === loadGeneration) {
      const query = new URLSearchParams({ after_id: String(lastMessageId) });
      const data = await api(`/api/v1/conversations/${encodeURIComponent(selectedConversation)}/messages?${query}`);
      const items = data.items || [];
      items.forEach((item) => {
        const id = Number(item.id);
        if (!Number.isFinite(id) || messageBox.querySelector(`[data-message-id="${id}"]`)) return;
        const mine = String(item.sender_id) === String(currentUserId);
        const bubble = createElement('article', `message-bubble ${mine ? 'mine' : 'theirs'}`);
        bubble.dataset.messageId = String(id);
        if (item.body) bubble.append(createElement('p', '', item.body));
        (item.attachments || []).forEach((attachment) => {
          const imageLink = createElement('a', 'message-image-link');
          imageLink.href = attachment.url;
          imageLink.target = '_blank';
          imageLink.rel = 'noopener';
          const image = document.createElement('img');
          image.src = attachment.url;
          image.alt = mine ? 'Gönderdiğin fotoğraf' : 'Gelen fotoğraf';
          image.loading = 'lazy';
          imageLink.append(image);
          bubble.append(imageLink);
        });
        bubble.append(createElement('small', '', new Date(item.created_at).toLocaleString('tr-TR')));
        messageBox.append(bubble);
        lastMessageId = Math.max(lastMessageId, id);
      });
      hasMore = data.has_more === true && items.length > 0;
    }
    if (wasNearBottom) messageBox.scrollTop = messageBox.scrollHeight;
    if (lastMessageId > 0) {
      await api(`/api/v1/conversations/${encodeURIComponent(selectedConversation)}/read`, {
        method: 'POST',
        body: JSON.stringify({ message_id: lastMessageId }),
      });
    }
  };

  const selectConversation = async (id) => {
    selectedConversation = id;
    clearInterval(pollTimer);
    loadGeneration += 1;
    const generation = loadGeneration;
    lastMessageId = 0;
    messageBox.replaceChildren();
    empty.hidden = true;
    messageBox.hidden = false;
    form.hidden = false;
    list.querySelectorAll('.conversation-row').forEach((row) => {
      row.classList.toggle('active', row.dataset.conversationId === String(id));
      row.setAttribute('aria-current', row.dataset.conversationId === String(id) ? 'true' : 'false');
    });
    const selected = conversations.find((item) => String(item.id) === String(id));
    if (selected) {
      activeConversationSection = selected.conversation_section || 'receive';
      messagesPage.querySelectorAll('[data-conversation-section]').forEach((button) => {
        const active = button.dataset.conversationSection === activeConversationSection;
        button.classList.toggle('active', active);
        button.setAttribute('aria-selected', active ? 'true' : 'false');
      });
      personHeader.hidden = false;
      personHeader.href = `/profil/${encodeURIComponent(selected.other_user_id)}`;
      personHeader.querySelector('[data-chat-person-name]').textContent = selected.other_user_name || 'Kullanıcı';
      const avatar = personHeader.querySelector('[data-chat-person-avatar]');
      avatar.replaceChildren();
      if (selected.other_user_avatar) {
        const image = document.createElement('img');
        image.src = selected.other_user_avatar;
        image.alt = '';
        avatar.append(image);
      } else avatar.textContent = (selected.other_user_name || 'K').slice(0, 1).toLocaleUpperCase('tr');
    }
    const url = new URL(window.location.href);
    url.searchParams.set('conversation', id);
    window.history.replaceState({}, '', url);
    await loadMessages(generation);
    pollTimer = setInterval(() => loadMessages(generation).catch(() => {}), 3000);
  };

  const renderConversations = () => {
    list.replaceChildren();
    const filtered = conversations.filter((item) => (item.conversation_section || 'receive') === activeConversationSection);
    if (!filtered.length) {
      list.append(createElement('div', 'chat-empty conversation-empty', activeConversationSection === 'receive'
        ? 'Hizmet aldığın bir konuşma henüz yok.'
        : 'Hizmet verdiğin bir konuşma henüz yok.'));
      return;
    }
    filtered.forEach((item) => {
      const button = createElement('button', 'conversation-row');
      button.type = 'button';
      button.dataset.conversationId = String(item.id);
      if (String(item.id) === String(selectedConversation)) button.classList.add('active');
      const avatar = createElement('span', 'conversation-row-avatar');
      if (item.other_user_avatar) {
        const image = document.createElement('img');
        image.src = item.other_user_avatar;
        image.alt = '';
        avatar.append(image);
      } else avatar.textContent = (item.other_user_name || 'K').slice(0, 1).toLocaleUpperCase('tr');
      const copy = createElement('span', 'conversation-row-copy');
      copy.append(createElement('strong', '', item.other_user_name || 'Kullanıcı'));
      copy.append(createElement('span', '', item.listing_title || 'İlan konuşması'));
      copy.append(createElement('small', '', item.last_message || 'Yeni konuşma'));
      button.append(avatar, copy);
      if (Number(item.unread_count) > 0) button.append(createElement('b', 'unread-badge', String(item.unread_count)));
      button.addEventListener('click', () => selectConversation(item.id));
      list.append(button);
    });
  };

  messagesPage.querySelectorAll('[data-conversation-section]').forEach((button) => {
    button.addEventListener('click', () => {
      activeConversationSection = button.dataset.conversationSection;
      messagesPage.querySelectorAll('[data-conversation-section]').forEach((item) => {
        const active = item === button;
        item.classList.toggle('active', active);
        item.setAttribute('aria-selected', active ? 'true' : 'false');
      });
      renderConversations();
    });
  });

  const loadConversations = async ({ activateSelected = false } = {}) => {
    if (!currentUserId) {
      const session = await api('/api/v1/auth/me');
      currentUserId = session.user?.id || '';
    }
    const data = await api('/api/v1/conversations');
    conversations = data.items || [];
    const selected = conversations.find((item) => String(item.id) === String(selectedConversation));
    if (selected) activeConversationSection = selected.conversation_section || 'receive';
    messagesPage.querySelectorAll('[data-conversation-section]').forEach((button) => {
      const active = button.dataset.conversationSection === activeConversationSection;
      button.classList.toggle('active', active);
      button.setAttribute('aria-selected', active ? 'true' : 'false');
    });
    renderConversations();
    if (activateSelected && selectedConversation) await selectConversation(selectedConversation);
  };

  loadConversations({ activateSelected: true }).catch(() => goToLogin(null, currentLocalPath()));
  startRealtime(({ event, payload }) => {
    if (event !== 'message.created' && event !== 'notification.created') return;
    loadConversations().catch(() => {});
    if (payload?.conversation_id === selectedConversation) loadMessages().catch(() => {});
  });

  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    const input = form.elements.body;
    const body = input.value.trim();
    const files = [...form.elements.images.files].slice(0, 5);
    if ((!body && !files.length) || !selectedConversation) return;
    const button = form.querySelector('button[type="submit"]');
    button.disabled = true;
    try {
      const attachmentIds = [];
      for (const file of files) {
        const upload = new FormData();
        upload.append('purpose', 'message');
        upload.append('conversation_id', selectedConversation);
        upload.append('file', file);
        const media = await api('/api/v1/uploads/images', { method: 'POST', body: upload });
        attachmentIds.push(media.id);
      }
      await api(`/api/v1/conversations/${encodeURIComponent(selectedConversation)}/messages`, {
        method: 'POST',
        body: JSON.stringify({ body, attachment_ids: attachmentIds }),
      });
      input.value = '';
      form.elements.images.value = '';
      uploadPreview.hidden = true;
      uploadPreview.replaceChildren();
      await loadMessages();
    } catch (error) {
      showToast(error.message, 'error');
    } finally {
      button.disabled = false;
    }
  });

  form.elements.images.addEventListener('change', () => {
    const files = [...form.elements.images.files].slice(0, 5);
    uploadPreview.replaceChildren();
    files.forEach((file) => {
      const item = createElement('span', '', file.name);
      uploadPreview.append(item);
    });
    uploadPreview.hidden = files.length === 0;
  });
}

const notificationsPage = document.querySelector('[data-notifications-page]');
if (notificationsPage) {
  const notificationList = notificationsPage.querySelector('[data-notification-list]');
  const loadNotifications = async () => {
    const data = await api('/api/v1/notifications?limit=100');
    notificationList.replaceChildren();
    if (!(data.items || []).length) {
      notificationList.append(createElement('div', 'empty-state', 'Henüz bildirimin yok.'));
      return;
    }
    data.items.forEach((item) => {
      const row = createElement('button', `notification-row${item.read_at ? '' : ' unread'}`);
      row.type = 'button';
      row.append(createElement('strong', '', item.title));
      row.append(createElement('span', '', item.body));
      row.addEventListener('click', async () => {
        await api(`/api/v1/notifications/${encodeURIComponent(item.id)}/read`, { method: 'POST' });
        const conversationId = item.data?.conversation_id;
        if (conversationId) window.location.assign(`/mesajlar?conversation=${encodeURIComponent(conversationId)}`);
        else row.classList.remove('unread');
      });
      notificationList.append(row);
    });
  };
  startRealtime(({ event }) => {
    if (event === 'notification.created') loadNotifications().catch(() => {});
  });
  notificationsPage.querySelector('[data-read-all-notifications]').addEventListener('click', async () => {
    await api('/api/v1/notifications/read-all', { method: 'POST' });
    loadNotifications();
  });
  loadNotifications().catch(() => goToLogin(null, currentLocalPath()));
}

// The production console is implemented in admin-console.js.
if (document.body.classList.contains('legacy-admin-page')) {
  const adminPage = document.querySelector('[data-admin-page]');
  const redirectOnAuth = (error) => {
    if (error.status === 401 || error.status === 419) window.location.assign('/admin/giris');
    else showToast(error.message, 'error');
  };
  const makeAdminRow = (title, details, actions = []) => {
    const row = createElement('article', 'admin-row');
    const copy = createElement('div');
    copy.append(createElement('strong', '', title), createElement('span', '', details));
    const actionBox = createElement('div', 'admin-row-actions');
    actions.forEach((action) => {
      const button = createElement('button', '', action.label);
      button.type = 'button';
      button.addEventListener('click', action.run);
      actionBox.append(button);
    });
    row.append(copy, actionBox);
    return row;
  };
  const loadOverview = async () => {
    const stats = await adminApi('/stats');
    Object.entries(stats).forEach(([key, value]) => {
      const element = document.querySelector(`[data-admin-stat="${key}"]`);
      if (element) element.textContent = new Intl.NumberFormat('tr-TR').format(Number(value));
    });
  };
  const loaders = {
    overview: loadOverview,
    reports: async () => {
      const box = adminPage.querySelector('[data-admin-reports]');
      const data = await adminApi('/reports'); box.replaceChildren();
      (data.items || []).forEach((item) => box.append(makeAdminRow(
        item.listing_title || item.reported_user_name || 'Bildirilen kayıt',
        `${item.reason} · ${item.status} · ${item.reporter_name}`,
        ['reviewing', 'resolved', 'rejected'].map((status) => ({ label: status, run: async () => { await adminApi(`/reports/${item.id}`, { method: 'PUT', body: JSON.stringify({ status }) }); loaders.reports(); } })),
      )));
    },
    listings: async () => {
      const box = adminPage.querySelector('[data-admin-listings]');
      const data = await adminApi('/listings'); box.replaceChildren();
      (data.items || []).forEach((item) => box.append(makeAdminRow(item.title || item.slug, `${item.owner_name} · ${item.status} · ${item.open_reports} açık şikâyet`, [{ label: 'Durumu değiştir', run: async () => {
        const values = await siteFormModal({
          eyebrow: 'İLAN MODERASYONU',
          title: 'İlan durumunu güncelle',
          description: 'Karar kullanıcıya bildirilir ve denetim kaydına yazılır.',
          confirmText: 'Kararı uygula',
          fields: [
            { name: 'status', label: 'Yeni durum', type: 'select', value: item.status, options: [
              { value: 'pending', label: 'Onay bekliyor' }, { value: 'active', label: 'Onayla ve yayınla' },
              { value: 'rejected', label: 'Reddet / düzenleme iste' }, { value: 'paused', label: 'Yayını durdur' },
              { value: 'removed', label: 'Yayından kaldır' },
            ] },
            { name: 'note', label: 'Moderasyon notu', type: 'textarea', required: false, value: item.moderation_note || '', placeholder: 'Kullanıcının göreceği kısa açıklama' },
          ],
        });
        if (!values) return;
        await adminApi(`/listings/${item.id}/moderation`, { method: 'PUT', body: JSON.stringify(values) });
        loaders.listings();
      } }])));
    },
    users: async () => {
      const box = adminPage.querySelector('[data-admin-users]');
      const data = await adminApi('/users'); box.replaceChildren();
      (data.items || []).forEach((item) => box.append(makeAdminRow(item.display_name, `${item.email} · ${item.role}${item.is_suspended ? ' · askıda' : ''}`, [{ label: item.is_suspended ? 'Askıyı kaldır' : 'Askıya al', run: async () => {
        let reason = '';
        if (!item.is_suspended) {
          const values = await siteFormModal({
            eyebrow: 'HESAP GÜVENLİĞİ', title: 'Kullanıcı askıya alınsın mı?',
            description: 'Açık oturumları kapatılır ve kullanıcı gerekçeyi görür.', confirmText: 'Hesabı askıya al',
            fields: [{ name: 'reason', label: 'Askıya alma nedeni', type: 'textarea', minLength: 5, placeholder: 'En az 5 karakterle gerekçeyi yaz' }],
          });
          if (!values) return;
          reason = values.reason;
        }
        await adminApi(`/users/${item.id}/suspension`, { method: 'PUT', body: JSON.stringify({ suspended: !item.is_suspended, reason }) });
        loaders.users();
      } }])));
    },
    categories: async () => {
      const box = adminPage.querySelector('[data-admin-categories]');
      const data = await adminApi('/categories'); box.replaceChildren();
      (data.items || []).forEach((item) => box.append(makeAdminRow(item.label, `${item.id} · ${item.is_active ? 'aktif' : 'pasif'}`, [{ label: 'Düzenle', run: async () => {
        const values = await siteFormModal({
          eyebrow: 'KATEGORİ YÖNETİMİ', title: 'Kategori adını düzenle', description: item.id,
          confirmText: 'Kategoriyi kaydet',
          fields: [{ name: 'label', label: 'Kategori adı', value: item.label, minLength: 2 }],
        });
        if (!values) return;
        await adminApi(`/categories/${encodeURIComponent(item.id)}`, { method: 'PUT', body: JSON.stringify({ label: values.label, is_active: item.is_active, is_selectable: item.is_selectable, sort_order: item.sort_order }) });
        loaders.categories();
      } }])));
    },
    banners: async () => {
      const box = adminPage.querySelector('[data-admin-banners]');
      const data = await adminApi('/banners'); box.replaceChildren();
      (data.items || []).forEach((item) => box.append(makeAdminRow(item.title, `${item.placement} · ${item.is_active ? 'aktif' : 'pasif'} · ${item.target_url || 'bağlantı yok'}`)));
    },
    privacy: async () => {
      const box = adminPage.querySelector('[data-admin-privacy]');
      const data = await adminApi('/privacy/requests'); box.replaceChildren();
      (data.items || []).forEach((item) => {
        const actions = ['processing', 'completed', 'rejected'].map((status) => ({
          label: status,
          run: async () => {
            await adminApi(`/privacy/requests/${item.id}`, {
              method: 'PUT',
              body: JSON.stringify({ status }),
            });
            loaders.privacy();
          },
        }));
        box.append(makeAdminRow(
          `${item.request_type} · ${item.display_name}`,
          `${item.email} · ${item.status} · ${item.details || 'Açıklama yok'}`,
          actions,
        ));
      });
    },
    audit: async () => {
      const box = adminPage.querySelector('[data-admin-audit]');
      const data = await adminApi('/audit'); box.replaceChildren();
      (data.items || []).forEach((item) => box.append(makeAdminRow(item.action, `${item.admin_name} · ${item.entity_type} ${item.entity_id || ''} · ${new Date(item.created_at).toLocaleString('tr-TR')}`)));
    },
  };
  adminPage.querySelectorAll('[data-admin-tab]').forEach((button) => button.addEventListener('click', () => {
    const tab = button.dataset.adminTab;
    adminPage.querySelectorAll('[data-admin-tab]').forEach((item) => item.classList.toggle('active', item === button));
    adminPage.querySelectorAll('[data-admin-panel]').forEach((panel) => { panel.hidden = panel.dataset.adminPanel !== tab; });
    loaders[tab]?.().catch(redirectOnAuth);
  }));
  adminPage.querySelector('[data-admin-banner-form]')?.addEventListener('submit', async (event) => {
    event.preventDefault();
    const form = event.currentTarget;
    const values = Object.fromEntries(new FormData(form).entries());
    await adminApi('/banners', { method: 'POST', body: JSON.stringify({ ...values, body: '', placement: 'home', is_active: true }) });
    form.reset(); loaders.banners();
  });
  adminPage.querySelector('[data-admin-policy-form]')?.addEventListener('submit', async (event) => {
    event.preventDefault();
    const form = event.currentTarget;
    const values = Object.fromEntries(new FormData(form).entries());
    const policy = await adminApi('/policies', { method: 'POST', body: JSON.stringify(values) });
    if (await siteConfirm('Bu metin hemen yayına alınacak ve kullanıcılara gösterilecek.', {
      title: 'Yasal metin yayımlansın mı?',
      confirmText: 'Şimdi yayımla',
      danger: false,
    })) {
      await adminApi(`/policies/${policy.id}/publish`, { method: 'POST' });
    }
    form.reset(); showToast('Yasal metin kaydedildi.', 'success');
  });
  adminPage.querySelector('[data-admin-logout]').addEventListener('click', async () => { await adminApi('/auth/logout', { method: 'POST' }); window.location.assign('/admin/giris'); });
  loadOverview().catch(redirectOnAuth);
}
