# Tanıdıkla Mobil

Harita üzerinden yakındaki hizmet verenleri ve süreli hizmet taleplerini
buluşturan Flutter uygulaması.

## Harita

Uygulama, geliştirme aşamasında ücretsiz ve anahtarsız OpenStreetMap'in sade yol
haritasını `flutter_map` üzerinden kullanır. Trafik katmanı bulunmaz; yakınlaşma
seviyesi işletme ayrıntılarını azaltacak şekilde sınırlandırılmıştır. Kaynak
bilgisi haritanın üzerinde görünür tutulur ve mobil cihazlarda harita döşemeleri
otomatik önbelleğe alınır.

OpenStreetMap'in herkese açık döşeme sunucusu geliştirme ve normal, düşük
yoğunluklu etkileşimli kullanım içindir. Uygulama büyüyüp yayınlanmadan önce
üretim trafiğine uygun bir döşeme sağlayıcısı seçilmelidir.

## Çalıştırma

Yerel PHP sunucusunu açmak artık zorunlu değildir. Android emülatör ve gerçek
cihaz uygulaması varsayılan olarak `https://tanidikla.com/api/v1` adresindeki
canlı API'ye bağlanır.

```powershell
flutter pub get
flutter run
```

Farklı bir API adresi için:

```powershell
flutter run --dart-define=API_BASE_URL=https://tanidikla.com/api/v1
```

Sunucuya yüklemeden lokal web/API ile Android emülatörde test etmek için önce
`web-platform` klasöründe `./dev.ps1` çalıştır. Ardından Android Studio'da
`ankara_local_api` çalıştırma profilini seç veya şu komutu kullan:

```powershell
flutter run --dart-define-from-file=config/api.local.json
```

Android emülatöründeki `10.0.2.2`, bilgisayardaki `127.0.0.1` adresine ulaşır.

## Kalite kontrolleri

```powershell
flutter analyze
flutter test
```

Mimari kararlar ve güvenlik sınırları için
[docs/architecture.md](docs/architecture.md) dosyasına bakın.
