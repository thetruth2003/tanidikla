# API v1 sözleşmesi

Canlı API kökü `https://tanidikla.com/api/v1` adresidir. Lokal geliştirmede
`http://127.0.0.1:8080/api/v1`, Android emülatörde ise
`http://10.0.2.2:8080/api/v1` kullanılabilir. Flutter uygulamasının varsayılanı
canlı HTTPS API'dir; gerekirse `--dart-define=API_BASE_URL=...` ile değiştirilir.

Başarılı cevap:

```json
{"success": true, "data": {}}
```

Hata cevabı:

```json
{
  "success": false,
  "error": {
    "code": "validation_failed",
    "message": "İstek doğrulanamadı.",
    "details": {}
  }
}
```

Mobil istemci `Authorization: Bearer TOKEN` kullanır. Web istemcisi HttpOnly
oturum cookie'si ve veri değiştiren isteklerde `X-CSRF-Token` başlığı kullanır.

## İlk endpoint'ler

- `GET /health`
- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/password/forgot`
- `GET /auth/me`
- `POST /auth/logout`
- `GET /categories`
- `GET /listings`
- `GET /listings/{id-or-slug}`
- `POST /listings`
- `PUT /listings/{id}`
- `DELETE /listings/{id}`
- `GET /profiles/{id}`
- `PUT /profile`
- `GET /conversations`
- `POST /conversations`
- `GET /conversations/{id}/messages?after_id=0`
- `POST /conversations/{id}/messages`
- `GET /admin/stats`
# Çoklu hizmet, iş ve beta endpointleri

- `POST /api/v1/listings` ve `PUT /api/v1/listings/{id}`: `items` alanında 1–20 hizmet kalemi kabul eder. Kalemler sıralı gönderilir; `pricing_unit` değerleri `fixed`, `hourly`, `daily`, `per_session`, `starting_at`, `negotiable`, `free` olabilir.
- `POST /api/v1/engagements`: `listing_id` ve `listing_item_id` ile doğrulanmış hizmet talebi başlatır.
- `GET /api/v1/engagements` ve `GET /api/v1/engagements/{id}`: kullanıcının hizmet alan veya veren taraf olduğu işleri döndürür.
- `POST /api/v1/engagements/{id}/actions/{action}`: rol ve mevcut duruma göre kabul, ret, başlatma, tamamlama, onay, iptal ve anlaşmazlık geçişlerini yapar.
- `POST /api/v1/reviews`, `PUT /api/v1/reviews/{id}` ve `DELETE /api/v1/reviews/{id}`: yalnız tamamlanmış işe bağlı, tekil ve süre sınırlı değerlendirme akışıdır.
- `POST /api/v1/me/push-devices`, `DELETE /api/v1/me/push-devices/{id}`: şifreli cihaz tokenı kaydı ve iptali.
- `GET /api/v1/beta/status`, `POST /api/v1/beta/feedback`: kapalı beta üyeliği ve geri bildirim.
- `GET /api/v1/admin/trust-operations`: iş/anlaşmazlık, değerlendirme, risk, beta kullanıcı ve geri bildirim kuyrukları.

İlan, hizmet kalemi, konuşma, iş ve değerlendirme kimlikleri sunucu tarafında oturum kullanıcısına göre yetkilendirilir. İstemci tarafından gönderilen sahip/kullanıcı kimliği güven kaynağı değildir.
