<section class="simple-shell inbox-shell" data-messages-page>
  <span class="eyebrow">Ortak gelen kutusu</span>
  <h1>Mesajların</h1>
  <p>Mobil ve web mesajların aynı konuşmalarda tutulur.</p>
  <div class="message-section-tabs" role="tablist" aria-label="Konuşma türü">
    <button class="active" type="button" role="tab" aria-selected="true" data-conversation-section="receive">Hizmet al</button>
    <button type="button" role="tab" aria-selected="false" data-conversation-section="provide">Hizmet ver</button>
  </div>
  <div class="inbox-grid">
    <aside data-conversation-list><div class="loading-line">Konuşmalar yükleniyor…</div></aside>
    <div class="chat-panel" data-chat-panel>
      <div class="chat-empty">Bir konuşma seç.</div>
      <a class="chat-person-header" data-chat-person href="#" hidden><span class="chat-person-avatar" data-chat-person-avatar>K</span><span><strong data-chat-person-name>Kullanıcı</strong><small>Profili ve aktif ilanları gör</small></span><b aria-hidden="true">→</b></a>
      <div class="chat-messages" data-chat-messages hidden></div>
      <form data-message-form hidden>
        <label class="chat-attachment-button" title="Fotoğraf ekle"><input name="images" type="file" accept="image/jpeg,image/png,image/webp" multiple><span aria-hidden="true">🖼</span><span class="sr-only">Fotoğraf ekle</span></label>
        <input name="body" maxlength="4000" placeholder="Mesajını yaz">
        <button class="primary-button" type="submit">Gönder</button>
        <div class="chat-upload-preview" data-chat-upload-preview hidden></div>
      </form>
    </div>
  </div>
</section>
