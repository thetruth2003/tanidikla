<p align="center">
  <img src="web-platform/public/assets/brand/tanidikla-logo-horizontal.png" alt="Tanıdıkla" width="310">
</p>

<p align="center">
  Yakındaki hizmet verenlerle hizmet arayanları harita üzerinde buluşturan<br>
  web ve mobil yerel hizmet platformu.
</p>

<p align="center">
  <strong>Flutter Mobil</strong> · <strong>Düz PHP Web/API</strong> · <strong>PostgreSQL</strong> · <strong>Yönetim Paneli</strong>
</p>

## Web sitesi

Web arayüzü; hizmet arama, gelişmiş filtreleme, harita/liste görünümü, ilan
oluşturma, favoriler, mesajlaşma ve profil yönetimini içerir. Aynı PHP uygulaması
`/api/v1` REST API'sini ve ayrı oturum kullanan yönetim panelini de sunar.

![Tanıdıkla web ana sayfası](docs/screenshots/web-home.png)

## Mobil uygulama

Flutter uygulaması web sitesiyle aynı API ve veritabanını kullanır. Yakındaki
hizmetleri keşfetme, hizmet verme/alma ilanı oluşturma, mesajlaşma, bildirim ve
profil işlemleri iki istemcide ortak çalışır.

<table>
  <tr>
    <td align="center"><img src="docs/screenshots/mobile-login.png" alt="Mobil giriş" width="260"></td>
    <td align="center"><img src="docs/screenshots/mobile-discovery.png" alt="Mobil keşif" width="260"></td>
    <td align="center"><img src="docs/screenshots/mobile-create-listing.png" alt="Mobil ilan oluşturma" width="260"></td>
  </tr>
  <tr>
    <td align="center"><strong>Giriş ve kayıt</strong></td>
    <td align="center"><strong>Yakındaki hizmetler</strong></td>
    <td align="center"><strong>İlan oluşturma</strong></td>
  </tr>
</table>

## Proje yapısı

```text
tanidikla/
├── mobile/        Flutter mobil uygulaması
├── web-platform/  PHP web sitesi, REST API ve admin paneli
└── docs/          Repo görselleri ve ortak dokümantasyon
```

```text
Flutter uygulaması ─┐
                    ├── /api/v1 (PHP) ── PostgreSQL
Web sitesi ─────────┘          │
                               └── Yönetim paneli
```

## Öne çıkan özellikler

- Konuma göre hizmet ve iş ilanı keşfi
- Harita/liste görünümü, kategori ve mesafe filtreleri
- Tek hesapla hizmet verme ve hizmet alma ilanları
- İlan görselleri, favoriler, kayıtlı aramalar ve bildirimler
- İlan bazlı kullanıcı mesajlaşması ve gerçek zamanlı güncelleme desteği
- Web oturumu, mobil access/refresh token akışı ve CSRF koruması
- Moderasyon, rol tabanlı yetki, rapor ve audit kayıtları
- KVKK/yasal metin, veri dışa aktarma ve hesap anonimleştirme akışları
- SEO uyumlu ilan/kategori sayfaları, sitemap ve yapılandırılmış veri

## Gereksinimler

### Web/API

- PHP 8.4 veya 8.5
- PostgreSQL (production için PostGIS önerilir)
- Composer
- PHP eklentileri: `curl`, `fileinfo`, `gd`, `mbstring`, `openssl`,
  `pdo_pgsql`, `pgsql`

### Mobil

- Flutter SDK ve Dart `^3.10.4`
- Android Studio veya Xcode

## Lokal çalıştırma

### 1. Web sitesi ve API

```powershell
cd web-platform
Copy-Item .env.example .env
composer install
php -c php.ini bin/migrate.php
php -c php.ini bin/seed.php
./dev.ps1
```

Lokal adresler:

- Web: `http://127.0.0.1:8080`
- API sağlık kontrolü: `http://127.0.0.1:8080/api/v1/health`
- Admin girişi: `http://127.0.0.1:8080/admin/giris`

### 2. Mobil uygulama

```powershell
cd mobile
flutter pub get
flutter run --dart-define-from-file=config/api.local.json
```

Android emülatörü lokal API'ye `http://10.0.2.2:8080/api/v1` üzerinden ulaşır.
Farklı bir sunucu için:

```powershell
flutter run --dart-define=API_BASE_URL=https://alan-adiniz.com/api/v1
```

## Kalite kontrolleri

```powershell
# Mobil
cd mobile
flutter analyze
flutter test

# Web
cd ../web-platform
node --check public/assets/app.js
php -c php.ini tests/seo-static-smoke.php
php -c php.ini tests/trust-marketplace-static-smoke.php
```

## Yapılandırma ve güvenlik

Gerçek parolalar, API anahtarları, yerel veritabanı, loglar ve kullanıcı
yüklemeleri Git'e eklenmez. Web yapılandırması için
`web-platform/.env.example`, mobil API adresi için `mobile/config/api.example.json`
kullanılır.

Production kurulumu öncesinde güçlü bir `APP_KEY`, ayrı veritabanı kullanıcısı,
HTTPS, SMTP ve üretim trafiğine uygun harita sağlayıcısı yapılandırılmalıdır.

## Ayrıntılı belgeler

- [Web/API kurulumu](web-platform/README.md)
- [Production dağıtımı](web-platform/docs/DEPLOYMENT.md)
- [API sözleşmesi](web-platform/docs/api-contract.md)
- [Mobil mimari](mobile/docs/architecture.md)
- [Mobil uygulama notları](mobile/README.md)

## Lisans

Bu proje özel geliştirmedir. İzinsiz kullanım, kopyalama ve dağıtım yapılamaz.
