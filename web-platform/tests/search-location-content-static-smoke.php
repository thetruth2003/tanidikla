<?php

declare(strict_types=1);

use App\Core\HttpException;
use App\Security\ContentPolicy;

require dirname(__DIR__) . '/bootstrap.php';

$root = dirname(__DIR__);
$listing = file_get_contents($root . '/src/Domain/ListingService.php') ?: '';
$app = file_get_contents($root . '/public/assets/app.js') ?: '';
$layout = file_get_contents($root . '/templates/layout.php') ?: '';
$home = file_get_contents($root . '/templates/home.php') ?: '';
$settings = file_get_contents($root . '/templates/settings.php') ?: '';
$styles = file_get_contents($root . '/public/assets/app.css') ?: '';

$checks = [
    'suggestions-only-categories' => !str_contains(substr($listing, 0, 7000), "select 'listing'::text as kind"),
    'all-categories-clears-detailed-selection' => str_contains($app, 'quick category selector is authoritative')
        && str_contains($app, "querySelectorAll('[name=\"categories[]\"]')"),
    'single-map-navigation-link' => str_contains($layout, '>Hizmet bul/al</a>')
        && !str_contains($layout, '<a href="/?type=service_offer#kesfet-haritasi">Hizmet bul</a>')
        && !str_contains($layout, '<a href="/?type=service_request#kesfet-haritasi">İş bul</a>'),
    'search-submit-keeps-map-anchor' => str_contains($home, 'action="/#kesfet-haritasi"')
        && str_contains($app, "homeSearchForm.action = '/#kesfet-haritasi'"),
    'category-exact-priority' => str_contains($listing, ':category_exact'),
    'turkey-map-fallback' => str_contains($app, 'TURKEY_CENTER') && str_contains($app, 'TURKEY_DEFAULT_ZOOM'),
    'turkey-coordinate-guard' => str_contains($app, 'validTurkeyCoordinates')
        && str_contains($app, 'TURKEY_COORDINATE_BOUNDS'),
    'empty-results-return-turkey' => str_contains($app, 'Türkiye genelinde aranıyor')
        && str_contains($app, 'resetListingMapToTurkey'),
    'map-cannot-drift-abroad' => str_contains($app, 'maxBounds: TURKEY_MAP_BOUNDS'),
    'location-retry' => str_contains($app, 'enableHighAccuracy: false'),
    'location-radius-15km' => str_contains($app, 'USER_AREA_RADIUS_METERS = 15000'),
    'tile-provider-fallback' => str_contains($app, "tile.openstreetmap.org/{z}/{x}/{y}.png"),
    'listing-content-policy' => substr_count($listing, 'ContentPolicy::assertAcceptable') >= 8,
    'distance-only-when-selected' => str_contains($listing, '$hasRadiusFilter')
        && !str_contains($listing, "query['radius_meters'] ?? 60000"),
    'settings-navigation-does-not-follow-scroll' => str_contains($styles, '.settings-shortcuts { position: static;'),
    'settings-feedback-controls-styled' => str_contains($settings, 'beta-feedback-section')
        && str_contains($styles, '.settings-field input,.settings-field select,.settings-field textarea'),
    'settings-blocked-users-management' => str_contains($settings, 'data-blocked-users')
        && str_contains($app, "api('/api/v1/blocks')")
        && str_contains($app, "method: 'DELETE'"),
    'beta-feedback-uses-versioned-api' => str_contains($app, "api('/api/v1/beta/feedback'")
        && str_contains($app, 'JSON.stringify(Object.fromEntries(new FormData(form).entries()))'),
];

foreach ([
    'punctuation-obfuscation' => 'Bu a.m.k şeklinde kötü bir mesajdır.',
    'spaced-obfuscation' => 'o r o s p u diye hakaret etti',
    'leetspeak-obfuscation' => 's1kt1r git',
    'turkish-suffix' => 'Bana orospuya der gibi konuştu',
    'repeated-letters' => 'siiiktiiir',
] as $name => $sample) {
    $blocked = false;
    try {
        ContentPolicy::assertAcceptable($sample, 'Mesaj');
    } catch (HttpException $exception) {
        $blocked = $exception->errorCode === 'inappropriate_content';
    }
    $checks['content-policy-blocks-' . $name] = $blocked;
}

foreach ([
    'normal-turkish' => 'Şikayetimi düzgün ve saygılı biçimde anlatıyorum.',
    'legitimate-goods' => 'Mal taşıma ve lojistik hizmeti veriyorum.',
    'legitimate-warehouse' => 'Ambar taşıma ve montaj hizmeti veriyorum.',
] as $name => $sample) {
    $allowed = true;
    try {
        ContentPolicy::assertAcceptable($sample, 'Mesaj');
    } catch (HttpException) {
        $allowed = false;
    }
    $checks['content-policy-allows-' . $name] = $allowed;
}

foreach ($checks as $name => $passed) {
    echo ($passed ? '[PASS] ' : '[FAIL] ') . $name . PHP_EOL;
}

if (in_array(false, $checks, true)) exit(1);
