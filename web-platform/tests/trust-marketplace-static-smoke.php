<?php

declare(strict_types=1);

$root = dirname(__DIR__);
$checks = [];

$read = static function (string $relative) use ($root): string {
    $contents = file_get_contents($root . DIRECTORY_SEPARATOR . $relative);
    if ($contents === false) {
        throw new RuntimeException("Dosya okunamadı: {$relative}");
    }
    return $contents;
};

$expect = static function (bool $condition, string $message) use (&$checks): void {
    if (!$condition) {
        fwrite(STDERR, "[FAIL] {$message}\n");
        exit(1);
    }
    $checks[] = $message;
};

$routes = $read('public/index.php');
$listing = $read('src/Domain/ListingService.php');
$engagements = $read('src/Domain/EngagementService.php');
$marketplace = $read('src/Domain/MarketplaceService.php');
$push = $read('src/Notifications/PushSender.php');
$migrations = implode("\n", array_map($read, [
    'database/migrations/018_multi_service_listings.sql',
    'database/migrations/019_service_engagements_and_verified_reviews.sql',
    'database/migrations/020_reports_risk_and_closed_beta.sql',
    'database/migrations/021_trust_operations_and_push_devices.sql',
    'database/migrations/022_beta_member_activity.sql',
]));

$expect(str_contains($routes, "'/api/v1/engagements'"), 'İş listesi ve oluşturma rotaları kayıtlı');
$expect(str_contains($routes, "'/api/v1/engagements/{id}/actions/{action}'"), 'Rol kontrollü iş geçiş rotası kayıtlı');
$expect(str_contains($routes, "'/api/v1/reviews'"), 'Doğrulanmış değerlendirme rotası kayıtlı');
$expect(str_contains($routes, "'/api/v1/me/push-devices'"), 'Push cihaz kaydı rotası kayıtlı');
$expect(str_contains($routes, "'/api/v1/beta/feedback'"), 'Beta geri bildirim rotası kayıtlı');
$expect(str_contains($routes, "'/api/v1/admin/trust-operations'"), 'Yönetim güven kuyruğu rotası kayıtlı');
$expect(str_contains($listing, 'count($items) > 20'), 'İlan hizmet kalemi üst sınırı 20');
$expect(str_contains($listing, 'item_similarity'), 'Öneriler tüm aktif alt hizmetlerde en iyi eşleşmeyi seçiyor');
$expect(str_contains($engagements, 'pg_advisory_xact_lock'), 'İş oluşturma yarışı veritabanı kilidiyle korunuyor');
$expect(str_contains($engagements, "status in ('requested','accepted','in_progress','provider_completed','disputed')"), 'Yinelenen açık iş kontrolü mevcut');
$expect(str_contains($marketplace, "status='completed'"), 'Değerlendirme yalnız tamamlanmış işe bağlı');
$expect(str_contains($marketplace, "interval '24 hours'"), 'Değerlendirme düzenleme süresi sınırlı');
$expect(str_contains($migrations, 'reviews_engagement_author_uidx'), 'İş başına taraf başına tek değerlendirme DB düzeyinde korunuyor');
$expect(str_contains($migrations, 'reports_has_target_check'), 'Şikâyetin tam bir hedefi olması DB düzeyinde korunuyor');
$expect(str_contains($migrations, 'notifications_enqueue_push'), 'Bildirimler cihaz kuyruğuna otomatik aktarılıyor');
$expect(str_contains($push, 'oauth2.googleapis.com/token'), 'FCM OAuth göndericisi yapılandırılmış');
$expect(str_contains($push, 'api.push.apple.com'), 'APNs göndericisi yapılandırılmış');

foreach ($checks as $check) {
    echo "[OK] {$check}\n";
}
echo count($checks) . " statik güven/pazar yeri kontrolü geçti.\n";
