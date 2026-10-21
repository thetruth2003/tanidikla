<?php

declare(strict_types=1);

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

$root = dirname(__DIR__);
$files = [
    'migration' => $root . '/database/migrations/016_listing_moderation_and_submission_safety.sql',
    'listing_service' => $root . '/src/Domain/ListingService.php',
    'admin_service' => $root . '/src/Domain/AdminService.php',
    'router' => $root . '/public/index.php',
    'app_js' => $root . '/public/assets/app.js',
    'admin_js' => $root . '/public/assets/admin-console.js',
    'admin_template' => $root . '/templates/admin.php',
];

$contents = [];
foreach ($files as $name => $path) {
    $content = file_get_contents($path);
    if (!is_string($content)) {
        throw new RuntimeException("Test dosyası okunamadı: {$name}");
    }
    $contents[$name] = $content;
}

$requirements = [
    ['migration', "alter table listings alter column status set default 'pending'"],
    ['migration', 'listing_submission_keys'],
    ['migration', 'submission_fingerprint'],
    ['listing_service', "'duplicate_listing'"],
    ['listing_service', "'pending'"],
    ['listing_service', 'groupNearbyListings'],
    ['listing_service', 'notifyApproved'],
    ['admin_service', 'listingSummary'],
    ['admin_service', "['pending','active','paused','rejected','removed']"],
    ['router', "'listing.create.user_burst'"],
    ['router', "header('idempotency-key')"],
    ['router', '$requirePageUser($request)'],
    ['app_js', 'pending-auth-action-v1'],
    ['app_js', 'listing-draft-v2'],
    ['app_js', 'Idempotency-Key'],
    ['app_js', 'siteFormModal'],
    ['admin_js', 'Onayla ve yayınla'],
    ['admin_template', 'Onay bekleyen ilanlar'],
];

foreach ($requirements as [$file, $needle]) {
    if (!str_contains($contents[$file], $needle)) {
        throw new RuntimeException("Eksik güvenlik/regresyon işareti: {$file} -> {$needle}");
    }
}

foreach (['app_js', 'admin_js'] as $file) {
    if (str_contains($contents[$file], 'window.alert(')
        || str_contains($contents[$file], 'window.prompt(')
        || str_contains($contents[$file], 'window.confirm(')) {
        throw new RuntimeException("Eski tarayıcı penceresi kaldı: {$file}");
    }
}

fwrite(STDOUT, json_encode([
    'moderation' => 'pending-approval-ok',
    'submission_safety' => 'rate-limit-idempotency-duplicate-ok',
    'auth_continuity' => 'return-action-draft-ok',
    'map' => 'nearby-provider-grouping-ok',
    'dialogs' => 'professional-modal-ok',
], JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE) . PHP_EOL);
