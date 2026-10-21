# Uygulama mimarisi

## Ürün modeli

Kullanıcıların kalıcı bir işveren veya çalışan rolü yoktur. Tek hesap iki tür
ilan oluşturabilir:

- `serviceOffer`: Kalıcı veya uzun süreli hizmet veren ilanı.
- `serviceRequest`: Belirli bir ihtiyaca ve zaman aralığına bağlı hizmet talebi.

Keşif ekranındaki "Hizmet Bul" ve "İş Bul" seçimi aynı harita üzerinde bu iki
ilan türü arasında geçiş yapar.

## Flutter katmanları

Kod özellik bazlı dizinlere ayrılır. Her özellik içinde aşağıdaki sınırlar
korunur:

- `domain`: Flutter ve backend ayrıntılarından bağımsız iş modelleri ve
  repository sözleşmeleri.
- `data`: Ortak PHP REST API'sine bağlanan repository uygulamaları.
- `application`: Riverpod controller ve provider'ları; filtreleme ve ekran
  durumları.
- `presentation`: Ekranlar ve tekrar kullanılabilir widget'lar.

Uygulama çapındaki yönlendirme ve tema `lib/app` altında bulunur. Bir ekran
doğrudan veritabanına erişmez; veriye repository ve sürümlendirilmiş API üzerinden ulaşır.

## Backend

Flutter uygulaması ve web sitesi aynı düz PHP `/api/v1` REST API'sini ve aynı
PostgreSQL veritabanını kullanır. Kimlik doğrulama, ilan işlemleri, profil ve
mesajlaşma PHP sunucusunda yürütülür. Mobil istemci Bearer oturum belirteci,
web istemcisi HttpOnly cookie ve CSRF koruması kullanır. Mesajlaşma ilk sürümde
üç saniyelik API sorgulamasıyla güncellenir; daha sonra aynı sözleşme WebSocket
ile genişletilebilir.

## Güvenlik sınırları

- Mobil uygulamada veritabanı parolası veya yönetici anahtarı bulunmaz.
- Kullanıcı kimliği istemci gövdesinden değil doğrulanmış oturumdan alınır.
- Bütün yetki kontrolleri PHP API içinde ve veritabanı sorgularında uygulanır.
- Profil e-postası ve tam konum genel ilan sorgusundan ayrı tutulur.
- Mesajları yalnızca konuşma üyeleri okuyabilir.
- Bildirme ve engelleme işlemleri sunucu tarafında uygulanır.
- Üretim sırları kaynak koduna veya Git geçmişine yazılmaz.
- Geliştirme, test ve üretim ortamları ayrı ayar ve veritabanları kullanır.

## Konum modeli

İlan, `exact` veya `neighborhood` görünürlüğünü seçer. İşletme konumu açık
olabilir; bireysel kullanıcı yaklaşık mahalle veya yakın sokak seçebilir. Cihazın
anlık konumu varsayılan olarak kalıcı şekilde saklanmaz.

`exact` seçildiğinde ilçe, mahalle, sokak ve bina bilgileri korumalı konum
alanında tutulur; genel ilan sorgusu yalnızca ilçe/mahalle etiketini döndürür.
`neighborhood` seçildiğinde kullanıcı haritada gerçek adresi dışında istediği
yakın bir noktaya iğne bırakır ve ayrıca adres bilgisi istenmez.

Bir hizmet talebi birden fazla kategori içerebilir. Veritabanında ortak bir
`bundle_id` altında kategori başına ayrı talep kalemi tutulur. Keşif ekranında
paket tek ilan/işaretçi olarak görünür; detay ekranında kalemler yatay sayfalar
halinde açılır. Böylece garson, tezgahtar ve kurye ihtiyacı tek ilanla
yayınlanabilirken her hizmetin açıklaması, zamanı ve bütçesi ayrı kalır.

## Sıradaki teknik adımlar

1. İlan görseli yükleme ve sunucu depolaması.
2. Bildirme, engelleme ve yönetici moderasyon akışları.
3. Üretim trafiğine uygun harita döşeme sağlayıcısı.
4. Server bilgileri geldiğinde HTTPS, SMTP, yedekleme ve cron ayarları.
