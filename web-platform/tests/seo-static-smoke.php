<?php

declare(strict_types=1);

use App\Domain\SeoService;

require dirname(__DIR__) . '/bootstrap.php';

$failures = [];
$assert = static function (bool $condition, string $message) use (&$failures): void {
    if (!$condition) $failures[] = $message;
};

$assert(SeoService::slugify('Elektrikçi') === 'elektrikci', 'Türkçe kategori slug dönüşümü hatalı.');
$assert(SeoService::slugify('Kurye ve Taşıma') === 'kurye-ve-tasima', 'Çok sözcüklü slug dönüşümü hatalı.');
$assert(SeoService::slugify('İstanbul Özel Ders') === 'istanbul-ozel-ders', 'Türkçe şehir slug dönüşümü hatalı.');

$index = file_get_contents(dirname(__DIR__) . '/public/index.php') ?: '';
$layout = file_get_contents(dirname(__DIR__) . '/templates/layout.php') ?: '';
$assert(str_contains($index, "'/hizmet/{category}/{city}'"), 'Kategori/şehir SEO rotası eksik.');
$assert(str_contains($index, "'/hizmet/{category}'"), 'Kategori SEO rotası eksik.');
$assert(str_contains($index, 'indexableLocationPages'), 'Şehir sayfaları sitemap içinde değil.');
$assert(str_contains($layout, 'name="robots"'), 'Robots meta etiketi eksik.');
$assert(str_contains($layout, 'google-site-verification'), 'Google doğrulama etiketi desteği eksik.');
$assert(str_contains($layout, 'og:site_name'), 'Open Graph site adı eksik.');
$assert(str_contains($layout, 'rel="icon"') && str_contains($layout, 'tanidikla-symbol.png'), 'Tanıdıkla favicon bağlantısı eksik.');
$assert(str_contains($layout, 'rel="apple-touch-icon"'), 'Apple ana ekran ikonu eksik.');
$assert(str_contains($layout, 'rel="manifest"'), 'Web uygulaması manifest bağlantısı eksik.');
$assert(str_contains($layout, 'twitter:image') && str_contains($layout, 'og:image:alt'), 'Sosyal paylaşım marka görseli eksik.');
$assert(str_contains($index, "'logo' =>") && str_contains($index, 'tanidikla-symbol.png'), 'Organization logo yapılandırılmış verisi eksik.');
$assert(is_file(dirname(__DIR__) . '/public/site.webmanifest'), 'Web uygulaması manifest dosyası bulunamadı.');
$assert(is_file(dirname(__DIR__) . '/public/assets/brand/tanidikla-logo-horizontal.png'), 'Yatay Tanıdıkla logosu bulunamadı.');
$assert(is_file(dirname(__DIR__) . '/public/assets/brand/tanidikla-symbol.png'), 'Tanıdıkla amblemi bulunamadı.');
$assert(is_file(dirname(__DIR__) . '/public/assets/brand/tanidikla-wordmark.png'), 'Tanıdıkla yazı logosu bulunamadı.');

if ($failures !== []) {
    fwrite(STDERR, json_encode(['ok' => false, 'failures' => $failures], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT) . PHP_EOL);
    exit(1);
}

echo json_encode(['ok' => true, 'checks' => 18], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT) . PHP_EOL;
