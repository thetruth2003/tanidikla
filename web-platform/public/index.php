<?php

declare(strict_types=1);

use App\Core\Config;
use App\Core\Database;
use App\Core\HttpException;
use App\Core\Logger;
use App\Core\Request;
use App\Core\RequestContext;
use App\Core\Response;
use App\Core\Router;
use App\Core\View;
use App\Domain\ListingService;
use App\Domain\AdminService;
use App\Domain\MarketplaceService;
use App\Domain\MessageService;
use App\Domain\EngagementService;
use App\Domain\PrivacyService;
use App\Domain\ProfileService;
use App\Domain\LocationCatalog;
use App\Domain\SavedSearchService;
use App\Domain\SeoService;
use App\Domain\BetaService;
use App\Notifications\EmailQueueService;
use App\Notifications\NotificationService;
use App\Notifications\RealtimeTokenService;
use App\Notifications\PushDeviceService;
use App\Security\AuthService;
use App\Security\AccountService;
use App\Security\AdminAuthService;
use App\Security\RateLimiter;
use App\Storage\MediaService;

require dirname(__DIR__) . '/bootstrap.php';

RequestContext::initialize($_SERVER['HTTP_X_REQUEST_ID'] ?? null);
try {
    $request = Request::capture();
} catch (HttpException $exception) {
    Response::error($exception->getMessage(), $exception->errorCode, $exception->status, $exception->details);
}
$primaryUrl = rtrim(Config::string('APP_URL'), '/');
$primaryHost = strtolower((string) parse_url($primaryUrl, PHP_URL_HOST));
$requestHost = strtolower(explode(':', (string) ($request->header('host') ?? ''))[0]);
$hostAliases = array_filter(array_map('trim', explode(',', strtolower(Config::string('APP_HOST_ALIASES')))));
if (Config::string('APP_ENV') === 'production' && $primaryHost !== '' && $requestHost !== '' && $requestHost !== $primaryHost && in_array($requestHost, $hostAliases, true)) {
    $target = $primaryUrl . $request->path;
    if ($request->query !== []) $target .= '?' . http_build_query($request->query);
    Response::redirect($target, 308);
}
$database = new Database();
$emailQueue = new EmailQueueService($database);
$auth = new AuthService($database, $emailQueue);
$account = new AccountService($database, $emailQueue);
$adminAuth = new AdminAuthService($database);
$privacy = new PrivacyService($database);
$listings = new ListingService($database);
$admin = new AdminService($database, $listings);
$marketplace = new MarketplaceService($database, $listings);
$media = new MediaService($database);
$profiles = new ProfileService($database);
$locations = new LocationCatalog();
$seo = new SeoService($database, $locations);
$savedSearches = new SavedSearchService($database);
$messages = new MessageService($database);
$engagements = new EngagementService($database);
$notifications = new NotificationService($database);
$realtimeTokens = new RealtimeTokenService($database);
$beta = new BetaService($database);
$pushDevices = new PushDeviceService($database);
$rateLimiter = new RateLimiter($database);
$router = new Router();

$renderPage = static function (string $template, array $data = [], int $status = 200): never {
    $content = View::render($template, $data);
    Response::html(View::render('layout', [
        'content' => $content,
        'title' => $data['title'] ?? Config::string('APP_NAME', 'Tanıdıkla'),
        'description' => $data['description'] ?? 'Yakınındaki hizmet verenleri ve hizmet taleplerini keşfet.',
        'canonical' => $data['canonical'] ?? null,
        'structuredData' => $data['structuredData'] ?? null,
        'openGraphType' => $data['openGraphType'] ?? 'website',
        'openGraphImage' => $data['openGraphImage'] ?? null,
        'robots' => $data['robots'] ?? 'index,follow,max-image-preview:large',
        'bodyClass' => $data['bodyClass'] ?? '',
    ]), $status);
};

$safeReturnPath = static function (mixed $value, string $fallback = '/'): string {
    $path = trim((string) $value);
    if ($path === '' || !str_starts_with($path, '/') || str_starts_with($path, '//')) {
        return $fallback;
    }
    $parts = parse_url($path);
    if ($parts === false || isset($parts['host']) || isset($parts['scheme'])) {
        return $fallback;
    }
    return mb_substr($path, 0, 1500);
};

$requirePageUser = static function (Request $request) use ($auth, $safeReturnPath): array {
    try {
        return $auth->requireUser($request, false);
    } catch (HttpException $exception) {
        if ($exception->status !== 401) throw $exception;
        $returnTo = $request->path;
        if ($request->query !== []) {
            $returnTo .= '?' . http_build_query($request->query);
        }
        Response::redirect('/giris?return_to=' . rawurlencode($safeReturnPath($returnTo)));
    }
};

$router->get('/', static function (Request $request) use ($database, $listings, $renderPage): never {
    $connectionError = null;
    $homeQuery = $request->query;
    if (!in_array((string) ($homeQuery['type'] ?? ''), ['service_offer', 'service_request'], true)) {
        $homeQuery['type'] = 'service_offer';
    }
    try {
        $categoryRows = $listings->categories();
        $result = $listings->search($homeQuery, ['skip_count' => true]);
        $mapQuery = $homeQuery;
        $mapQuery['limit'] = 50;
        $mapResult = $listings->search($mapQuery, ['skip_count' => true, 'group_nearby' => true]);
        $banners = $database->fetchAll("select title,body,image_path,target_url from banners where is_active and (starts_at is null or starts_at<=now()) and (ends_at is null or ends_at>now()) and placement='home' order by created_at desc limit 3");
    } catch (Throwable $exception) {
        Logger::exception($exception);
        $categoryRows = [];
        $result = ['items' => [], 'pagination' => ['page' => 1, 'limit' => 24, 'returned' => 0]];
        $mapResult = ['items' => [], 'pagination' => ['page' => 1, 'limit' => 50, 'returned' => 0]];
        $connectionError = Config::bool('APP_DEBUG')
            ? 'Geliştirme veritabanına bağlanılamadı.'
            : 'İlanlar şu anda yüklenemiyor. Lütfen biraz sonra tekrar dene.';
        $banners = [];
    }

    $renderPage('home', [
        'title' => 'Yakınındaki Hizmetleri Bul ve İş İlanlarını Keşfet | Tanıdıkla',
        'description' => 'Elektrikçi, kurye, temizlik, özel ders ve daha fazla hizmeti yakınında bul; ücretsiz hizmet veya iş ilanı yayınla.',
        'categories' => $categoryRows,
        'listings' => $result['items'],
        'mapListingRows' => $mapResult['items'],
        'query' => $homeQuery,
        'connectionError' => $connectionError,
        'banners' => $banners,
        'canonical' => rtrim(Config::string('APP_URL'), '/') . '/',
        'robots' => $request->query === [] ? 'index,follow,max-image-preview:large' : 'noindex,follow',
        'structuredData' => [
            '@context' => 'https://schema.org',
            '@graph' => [
                [
                    '@type' => 'Organization',
                    '@id' => rtrim(Config::string('APP_URL'), '/') . '/#organization',
                    'name' => Config::string('APP_NAME', 'Tanıdıkla'),
                    'url' => rtrim(Config::string('APP_URL'), '/') . '/',
                    'logo' => rtrim(Config::string('APP_URL'), '/') . '/assets/brand/tanidikla-symbol.png',
                    'image' => rtrim(Config::string('APP_URL'), '/') . '/assets/brand/tanidikla-logo-horizontal.png',
                ],
                [
                    '@type' => 'WebSite',
                    '@id' => rtrim(Config::string('APP_URL'), '/') . '/#website',
                    'name' => Config::string('APP_NAME', 'Tanıdıkla'),
                    'url' => rtrim(Config::string('APP_URL'), '/') . '/',
                    'publisher' => ['@id' => rtrim(Config::string('APP_URL'), '/') . '/#organization'],
                    'inLanguage' => 'tr-TR',
                ],
            ],
        ],
    ]);
});

$router->get('/robots.txt', static function (): never {
    $baseUrl = rtrim(Config::string('APP_URL'), '/');
    Response::text("User-agent: *\nAllow: /\nDisallow: /admin\nDisallow: /api/\nSitemap: {$baseUrl}/sitemap.xml\n");
});
$router->get('/sitemap.xml', static function () use ($database, $seo): never {
    $baseUrl = rtrim(Config::string('APP_URL'), '/');
    $rows = $database->fetchAll(
        "select slug, updated_at from listings where status = 'active'
         and (expires_at is null or expires_at > now()) order by updated_at desc limit 48000"
    );
    $urls = [
        ['location' => $baseUrl . '/', 'updated_at' => null],
        ['location' => $baseUrl . '/kullanim-kosullari', 'updated_at' => null],
        ['location' => $baseUrl . '/kvkk', 'updated_at' => null],
        ['location' => $baseUrl . '/gizlilik', 'updated_at' => null],
        ['location' => $baseUrl . '/cerez-politikasi', 'updated_at' => null],
        ...array_map(
            static fn (array $row): array => [
                'location' => $baseUrl . '/hizmet/' . rawurlencode((string) $row['seo_slug']),
                'updated_at' => (string) ($row['updated_at'] ?? ''),
            ],
            $seo->categories(),
        ),
        ...array_map(
            static fn (array $row): array => [
                'location' => $baseUrl . '/hizmet/' . rawurlencode((string) $row['category_slug']) . '/' . rawurlencode((string) $row['city_slug']),
                'updated_at' => (string) $row['updated_at'],
            ],
            $seo->indexableLocationPages(),
        ),
        ...array_map(
            static fn (array $row): array => [
                'location' => $baseUrl . '/ilan/' . rawurlencode((string) $row['slug']),
                'updated_at' => (string) $row['updated_at'],
            ],
            $rows,
        ),
    ];
    $xml = '<?xml version="1.0" encoding="UTF-8"?>' . "\n";
    $xml .= '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">' . "\n";
    foreach (array_slice($urls, 0, 50000) as $url) {
        $xml .= '  <url><loc>' . htmlspecialchars($url['location'], ENT_XML1 | ENT_QUOTES, 'UTF-8') . '</loc>';
        if ($url['updated_at'] !== null) {
            $timestamp = strtotime($url['updated_at']);
            if ($timestamp !== false) {
                $xml .= '<lastmod>' . gmdate('c', $timestamp) . '</lastmod>';
            }
        }
        $xml .= '</url>' . "\n";
    }
    $xml .= '</urlset>';
    Response::text($xml, 'application/xml; charset=utf-8');
});

$router->get('/media/{id}', static function (Request $request) use ($media, $auth): never {
    $private = false;
    try {
        $object = $media->resolvePublic((string) $request->route('id'));
    } catch (HttpException $exception) {
        if ($exception->status !== 404) throw $exception;
        $user = $auth->requireUser($request, false);
        $object = $media->resolveForUser((string) $request->route('id'), (string) $user['id']);
        $private = true;
    }
    if ($object['url'] !== null) {
        Response::redirect($object['url'], 302);
    }
    if ($object['path'] === null) {
        throw new HttpException(404, 'Görsel bulunamadı.', 'media_not_found');
    }
    Response::file(
        $object['path'],
        $object['mime_type'],
        $object['byte_size'],
        $object['sha256'],
        $private ? 'private, max-age=300' : 'public, max-age=31536000, immutable',
    );
});

$router->get('/giris', static function (Request $request) use ($auth, $renderPage, $safeReturnPath): never {
    $auth->ensurePreAuthCsrfCookie($request);
    $renderPage('auth', [
        'title' => 'Giriş yap',
        'mode' => 'login',
        'returnTo' => $safeReturnPath($request->query['return_to'] ?? '/'),
    ]);
});
$router->get('/kayit', static function (Request $request) use ($auth, $privacy, $renderPage, $safeReturnPath): never {
    $auth->ensurePreAuthCsrfCookie($request);
    $renderPage('auth', [
        'title' => 'Ücretsiz hesap oluştur',
        'mode' => 'register',
        'policies' => $privacy->publishedPolicies(),
        'returnTo' => $safeReturnPath($request->query['return_to'] ?? '/profili-duzenle', '/profili-duzenle'),
    ]);
});
$router->get('/sifre-yenile', static function (Request $request) use ($auth, $renderPage): never {
    $auth->ensurePreAuthCsrfCookie($request);
    $renderPage('password-reset', [
        'title' => 'Şifreni yenile',
        'token' => (string) ($request->query['token'] ?? ''),
    ]);
});
$router->get('/e-posta-dogrula', static function (Request $request) use ($auth, $renderPage): never {
    try {
        $auth->verifyEmail((string) ($request->query['token'] ?? ''));
        $renderPage('auth-result', [
            'title' => 'E-posta doğrulandı',
            'heading' => 'E-posta adresin doğrulandı',
            'message' => 'Hesabını artık doğrulanmış e-posta adresinle kullanabilirsin.',
        ]);
    } catch (HttpException $exception) {
        $renderPage('auth-result', [
            'title' => 'Doğrulama başarısız',
            'heading' => 'Bağlantı kullanılamadı',
            'message' => $exception->getMessage(),
        ], $exception->status);
    }
});
$router->get('/e-posta-degistir', static function (Request $request) use ($account, $renderPage): never {
    try {
        $account->confirmEmailChange((string) ($request->query['token'] ?? ''));
        $renderPage('auth-result', [
            'title' => 'E-posta değiştirildi',
            'heading' => 'Yeni e-posta adresin doğrulandı',
            'message' => 'Güvenliğin için oturumların kapatıldı. Yeni e-posta adresinle tekrar giriş yapabilirsin.',
        ]);
    } catch (HttpException $exception) {
        $renderPage('auth-result', [
            'title' => 'E-posta değişikliği başarısız',
            'heading' => 'Bağlantı kullanılamadı',
            'message' => $exception->getMessage(),
        ], $exception->status);
    }
});
$router->get('/ilan-ver', static function (Request $request) use ($listings, $renderPage, $requirePageUser): never {
    $requirePageUser($request);
    try {
        $categories = $listings->categories();
    } catch (Throwable) {
        $categories = [];
    }
    $renderPage('create-listing', [
        'title' => 'Ücretsiz ilan ver',
        'categories' => $categories,
        'selectedType' => (string) ($request->query['type'] ?? 'service_offer'),
        'editingId' => null,
    ]);
});
$router->get('/ilan/{id}/duzenle', static function (Request $request) use ($listings, $renderPage, $requirePageUser): never {
    try {
        $requirePageUser($request);
        $categories = $listings->categories();
        $renderPage('create-listing', [
            'title' => 'İlanı düzenle',
            'categories' => $categories,
            'selectedType' => 'service_offer',
            'editingId' => (string) $request->route('id'),
        ]);
    } catch (HttpException $exception) {
        $renderPage('not-found', ['title' => 'İlan bulunamadı'], $exception->status);
    }
});
$router->get('/mesajlar', static function (Request $request) use ($renderPage, $requirePageUser): never { $requirePageUser($request); $renderPage('messages', ['title' => 'Mesajlarım']); });
$router->get('/islerim', static function (Request $request) use ($renderPage, $requirePageUser): never { $requirePageUser($request); $renderPage('engagements', ['title' => 'İşlerim | Tanıdıkla']); });
$router->get('/favoriler', static function (Request $request) use ($renderPage, $requirePageUser): never { $requirePageUser($request); $renderPage('favorites', ['title' => 'Favorilerim']); });
$router->get('/bildirimler', static function (Request $request) use ($renderPage, $requirePageUser): never { $requirePageUser($request); $renderPage('notifications', ['title' => 'Bildirimlerim']); });
$router->get('/profil', static function (Request $request) use ($renderPage, $requirePageUser): never { $requirePageUser($request); $renderPage('profile', ['title' => 'Profilim']); });
$router->get('/profili-duzenle', static function (Request $request) use ($listings, $renderPage, $requirePageUser): never {
    $requirePageUser($request);
    try {
        $categories = $listings->categories();
    } catch (Throwable) {
        $categories = [];
    }
    $renderPage('profile-edit', [
        'title' => 'Profili düzenle',
        'categories' => $categories,
    ]);
});
$router->get('/ayarlar', static function (Request $request) use ($renderPage, $requirePageUser): never { $requirePageUser($request); $renderPage('settings', ['title' => 'Ayarlar']); });
$router->get('/ilanlarim', static function (Request $request) use ($renderPage, $requirePageUser): never { $requirePageUser($request); $renderPage('my-listings', ['title' => 'İlanlarım']); });
$router->get('/profil/{id}', static function (Request $request) use ($profiles, $renderPage): never {
    try {
        $profile = $profiles->find((string) $request->route('id'));
        $renderPage('provider-profile', [
            'title' => $profile['display_name'] . ' | Tanıdıkla',
            'description' => mb_substr((string) $profile['bio'], 0, 160),
            'profile' => $profile,
        ]);
    } catch (HttpException $exception) {
        $renderPage('not-found', ['title' => 'Profil bulunamadı'], $exception->status);
    }
});
$router->get('/admin/giris', static function (Request $request) use ($adminAuth, $renderPage): never {
    $adminAuth->ensurePreAuthCookie($request);
    $renderPage('admin-login', ['title' => 'Tanıdıkla Yönetim Girişi', 'bodyClass' => 'admin-auth-page', 'robots' => 'noindex,nofollow,noarchive']);
});
$router->get('/admin', static fn (Request $request) => $renderPage('admin', ['title' => 'Tanıdıkla Yönetim Paneli', 'bodyClass' => 'admin-console-page', 'robots' => 'noindex,nofollow,noarchive']));
$router->get('/gizlilik', static function () use ($privacy, $renderPage): never {
    $document = array_values(array_filter($privacy->publishedPolicies(), static fn (array $item): bool => $item['document_type'] === 'privacy_policy'))[0] ?? null;
    $renderPage('legal', ['title' => 'Gizlilik Politikası', 'document' => $document]);
});
$router->get('/kvkk', static function () use ($privacy, $renderPage): never {
    $document = array_values(array_filter($privacy->publishedPolicies(), static fn (array $item): bool => $item['document_type'] === 'kvkk_notice'))[0] ?? null;
    $renderPage('legal', ['title' => 'KVKK Aydınlatma Metni', 'document' => $document]);
});
$router->get('/cerez-politikasi', static function () use ($privacy, $renderPage): never {
    $document = array_values(array_filter($privacy->publishedPolicies(), static fn (array $item): bool => $item['document_type'] === 'cookie_policy'))[0] ?? null;
    $renderPage('legal', ['title' => 'Çerez Politikası', 'document' => $document]);
});
$router->get('/kullanim-kosullari', static function () use ($privacy, $renderPage): never {
    $document = array_values(array_filter($privacy->publishedPolicies(), static fn (array $item): bool => $item['document_type'] === 'terms'))[0] ?? null;
    $renderPage('legal', ['title' => 'Kullanım Koşulları', 'document' => $document]);
});
$renderServiceCategory = static function (Request $request, ?string $citySlug = null) use ($seo, $listings, $renderPage): never {
    try {
        $category = $seo->categoryBySlug((string) $request->route('category'));
        if ($category === null) {
            throw new HttpException(404, 'Hizmet kategorisi bulunamadı.', 'seo_category_not_found');
        }

        $city = $citySlug !== null ? $seo->cityBySlug($citySlug) : null;
        if ($citySlug !== null && $city === null) {
            throw new HttpException(404, 'Şehir bulunamadı.', 'seo_city_not_found');
        }

        $relatedCities = $seo->activeCitiesForCategory((string) $category['id']);
        if ($city !== null) {
            $hasActiveListings = array_filter(
                $relatedCities,
                static fn (array $row): bool => $row['city_slug'] === SeoService::slugify($city),
            ) !== [];
            if (!$hasActiveListings) {
                throw new HttpException(404, 'Bu şehir ve kategori için aktif ilan bulunamadı.', 'seo_location_empty');
            }
        }

        $page = max(1, (int) ($request->query['page'] ?? 1));
        $searchQuery = [
            'type' => 'service_offer',
            'category' => (string) $category['id'],
            'page' => $page,
            'limit' => 24,
        ];
        if ($city !== null) $searchQuery['city'] = $city;
        $result = $listings->search($searchQuery);

        $baseUrl = rtrim(Config::string('APP_URL'), '/');
        $categoryUrl = $baseUrl . '/hizmet/' . rawurlencode((string) $category['seo_slug']);
        $canonicalBase = $city === null
            ? $categoryUrl
            : $categoryUrl . '/' . rawurlencode(SeoService::slugify($city));
        $canonical = $page > 1 ? $canonicalBase . '?page=' . $page : $canonicalBase;
        $label = (string) $category['label'];
        $pageName = $city === null
            ? $label . ' Hizmetleri ve Güncel İlanlar'
            : $city . ' ' . $label . ' Hizmetleri ve İlanları';
        $title = $pageName . ($page > 1 ? ' - Sayfa ' . $page : '') . ' | Tanıdıkla';
        $description = $city === null
            ? $label . ' hizmeti veren güncel ilanları karşılaştır. Yakınındaki hizmet verenleri Tanıdıkla ile bul ve güvenle iletişime geç.'
            : $city . ' genelinde ' . mb_strtolower($label, 'UTF-8') . ' hizmeti veren güncel ilanları, profilleri ve fiyat bilgilerini Tanıdıkla ile karşılaştır.';
        $description = mb_substr($description, 0, 160);

        $breadcrumbItems = [
            ['@type' => 'ListItem', 'position' => 1, 'name' => 'Tanıdıkla', 'item' => $baseUrl . '/'],
            ['@type' => 'ListItem', 'position' => 2, 'name' => $label, 'item' => $categoryUrl],
        ];
        if ($city !== null) {
            $breadcrumbItems[] = ['@type' => 'ListItem', 'position' => 3, 'name' => $city, 'item' => $canonicalBase];
        }
        $itemElements = [];
        foreach ($result['items'] as $index => $item) {
            $itemElements[] = [
                '@type' => 'ListItem',
                'position' => (($page - 1) * 24) + $index + 1,
                'name' => (string) $item['title'],
                'url' => $baseUrl . '/ilan/' . rawurlencode((string) $item['slug']),
            ];
        }

        $renderPage('service-category', [
            'title' => $title,
            'description' => $description,
            'canonical' => $canonical,
            'robots' => 'index,follow,max-image-preview:large',
            'category' => $category,
            'city' => $city,
            'listings' => $result['items'],
            'pagination' => $result['pagination'],
            'relatedCities' => $relatedCities,
            'categoryUrl' => $categoryUrl,
            'canonicalBase' => $canonicalBase,
            'structuredData' => [
                '@context' => 'https://schema.org',
                '@graph' => [
                    [
                        '@type' => 'CollectionPage',
                        '@id' => $canonicalBase . '#page',
                        'url' => $canonicalBase,
                        'name' => $pageName,
                        'description' => $description,
                        'inLanguage' => 'tr-TR',
                        'about' => [
                            '@type' => 'Service',
                            'name' => $label,
                            'serviceType' => $label,
                            'areaServed' => ['@type' => 'AdministrativeArea', 'name' => $city ?? 'Türkiye'],
                        ],
                    ],
                    ['@type' => 'BreadcrumbList', 'itemListElement' => $breadcrumbItems],
                    ['@type' => 'ItemList', 'numberOfItems' => count($itemElements), 'itemListElement' => $itemElements],
                ],
            ],
        ]);
    } catch (HttpException $exception) {
        $renderPage('not-found', [
            'title' => 'Hizmet sayfası bulunamadı | Tanıdıkla',
            'robots' => 'noindex,follow',
        ], $exception->status);
    } catch (Throwable $exception) {
        Logger::exception($exception);
        $renderPage('not-found', [
            'title' => 'Hizmetler şu anda görüntülenemiyor | Tanıdıkla',
            'robots' => 'noindex,follow',
        ], 503);
    }
};
$router->get('/hizmet/{category}/{city}', static fn (Request $request) => $renderServiceCategory($request, (string) $request->route('city')));
$router->get('/hizmet/{category}', static fn (Request $request) => $renderServiceCategory($request));
$router->get('/ilan/{lookup}', static function (Request $request) use ($listings, $renderPage): never {
    try {
        $listing = $listings->find((string) $request->route('lookup'));
        $first = $listing['items'][0] ?? [];
        $renderPage('listing-detail', [
            'title' => ($first['title'] ?? 'İlan') . ' | Tanıdıkla',
            'description' => mb_substr((string) ($first['description'] ?? ''), 0, 160),
            'listing' => $listing,
            'canonical' => rtrim(Config::string('APP_URL'), '/') . '/ilan/' . $listing['slug'],
            'openGraphType' => 'article',
            'openGraphImage' => isset($listing['images'][0]['storage_path'])
                ? rtrim(Config::string('APP_URL'), '/') . $listing['images'][0]['storage_path']
                : null,
            'structuredData' => [
                '@context' => 'https://schema.org',
                '@type' => 'Service',
                'name' => (string) ($first['title'] ?? 'Hizmet ilanı'),
                'description' => (string) ($first['description'] ?? ''),
                'areaServed' => [
                    '@type' => 'AdministrativeArea',
                    'name' => implode(', ', array_filter([
                        (string) ($listing['public_district'] ?? ''),
                        (string) ($listing['public_city'] ?? ''),
                    ])),
                ],
                'provider' => [
                    '@type' => 'Person',
                    'name' => (string) $listing['owner_name'],
                ],
                'url' => rtrim(Config::string('APP_URL'), '/') . '/ilan/' . $listing['slug'],
            ],
        ]);
    } catch (HttpException $exception) {
        $renderPage('not-found', ['title' => 'İlan bulunamadı'], $exception->status);
    } catch (Throwable) {
        $renderPage('not-found', ['title' => 'İlan şu anda görüntülenemiyor'], 503);
    }
});

$router->get('/api/v1/health', static function () use ($database): never {
    $databaseStatus = false;
    try {
        $databaseStatus = (int) ($database->fetchOne('select 1 as ok')['ok'] ?? 0) === 1;
    } catch (Throwable) {
        // Health endpoint remains reachable while local PostgreSQL is being prepared.
    }
    Response::success([
        'service' => 'tanidikla-api',
        'version' => '1.0.0',
        'database' => $databaseStatus ? 'ready' : 'not_ready',
        'integrations' => [
            'smtp' => Config::bool('MAIL_ENABLED') && Config::string('MAIL_HOST') !== '' ? 'configured' : 'unconfigured',
            'sms' => Config::bool('SMS_ENABLED') && Config::string('NETGSM_USERNAME') !== '' ? 'configured' : 'unconfigured',
            'realtime' => Config::bool('CENTRIFUGO_ENABLED') && Config::string('CENTRIFUGO_TOKEN_SECRET') !== '' ? 'configured' : 'unconfigured',
            'fcm' => Config::bool('PUSH_ENABLED') && Config::string('FCM_SERVICE_ACCOUNT_JSON') !== '' ? 'configured' : 'unconfigured',
            'apns' => Config::bool('PUSH_ENABLED') && Config::string('APNS_PRIVATE_KEY') !== '' ? 'configured' : 'unconfigured',
        ],
        'beta_mode' => Config::bool('BETA_MODE'),
        'time' => gmdate(DATE_ATOM),
    ], $databaseStatus ? 200 : 503);
});
$router->get('/api/v1/beta/status', static function (Request $request) use ($auth,$beta): never {
    $user=$auth->requireUser($request,false);Response::success($beta->status((string)$user['id']));
});
$router->post('/api/v1/beta/feedback', static function (Request $request) use ($auth,$beta,$rateLimiter): never {
    $user=$auth->requireUser($request);$rateLimiter->enforce($request,'beta.feedback',(string)$user['id'],10,3600,3600);
    Response::success($beta->submitFeedback((string)$user['id'],$request->body,$request),201);
});
$router->post('/api/v1/me/push-devices', static function (Request $request) use ($auth,$pushDevices,$rateLimiter): never {
    $user=$auth->requireUser($request);$rateLimiter->enforce($request,'push.device.register',(string)$user['id'],20,3600,3600);
    Response::success($pushDevices->register((string)$user['id'],(string)$request->input('platform',''),(string)$request->input('token','')),201);
});
$router->delete('/api/v1/me/push-devices/{id}', static function (Request $request) use ($auth,$pushDevices): never {
    $user=$auth->requireUser($request);$pushDevices->revoke((string)$user['id'],(string)$request->route('id'));Response::success(['revoked'=>true]);
});

$router->get('/api/v1/categories', static fn () => Response::success(['items' => $listings->categories()]));
$router->get('/api/v1/search/suggestions', static function (Request $request) use ($listings): never {
    Response::success(['items'=>$listings->suggestions(
        (string)($request->query['q'] ?? ''),
        (int)($request->query['limit'] ?? 8),
    )]);
});
$router->get('/api/v1/policies', static fn () => Response::success(['items' => $privacy->publishedPolicies()]));
$router->get('/api/v1/listings', static function (Request $request) use ($listings): never {
    $mapOnly = filter_var($request->query['map_only'] ?? false, FILTER_VALIDATE_BOOL);
    Response::success($listings->search($request->query, $mapOnly ? ['skip_count' => true, 'group_nearby' => true] : []));
});
$router->get('/api/v1/listings/{lookup}', static fn (Request $request) => Response::success($listings->find((string) $request->route('lookup'))));
$router->get('/api/v1/users/{id}/listings', static fn (Request $request) => Response::success(
    $listings->byOwner((string) $request->route('id'), $request->query),
));
$router->get('/api/v1/me/listings', static function (Request $request) use ($auth, $listings): never {
    $user = $auth->requireUser($request, false);
    Response::success($listings->byOwner((string) $user['id'], $request->query, true, (string) $user['id']));
});
$router->get('/api/v1/me/listings/{id}', static function (Request $request) use ($auth, $listings): never {
    $user = $auth->requireUser($request, false);
    Response::success($listings->findForOwner((string) $request->route('id'), (string) $user['id']));
});
$router->post('/api/v1/listings', static function (Request $request) use ($auth, $listings, $rateLimiter): never {
    $user = $auth->requireUser($request);
    // Bu sınırlar toplam ilan kotası değildir; yalnızca otomatik/Postman tipi kısa süreli spamı keser.
    $rateLimiter->enforce($request, 'listing.create.user_burst', (string) $user['id'], 20, 300, 900);
    $rateLimiter->enforce($request, 'listing.create.ip_burst', $request->clientIp(), 60, 300, 900);
    Response::success($listings->create($request->body, $user, $request->header('idempotency-key')), 202);
});
$router->put('/api/v1/listings/{id}', static function (Request $request) use ($auth, $listings, $rateLimiter): never {
    $user = $auth->requireUser($request);
    $rateLimiter->enforce($request, 'listing.update.user_burst', (string) $user['id'], 30, 300, 900);
    Response::success($listings->update((string) $request->route('id'), $request->body, $user));
});
$router->delete('/api/v1/listings/{id}', static function (Request $request) use ($auth, $listings): never {
    $user = $auth->requireUser($request);
    $listings->remove((string) $request->route('id'), $user);
    Response::success(['removed' => true]);
});

$router->post('/api/v1/auth/register', static function (Request $request) use ($auth, $rateLimiter): never {
    $auth->assertPreAuthCsrf($request);
    $email = (string) $request->input('email', '');
    $rateLimiter->enforce($request, 'auth.register', $email, 5, 3600, 3600);
    $result = $auth->register(
        $email,
        (string) $request->input('password', ''),
        (string) $request->input('password_confirmation', ''),
        (string) $request->input('display_name', ''),
        (string) $request->input('profile_type', 'person'),
        (bool) $request->input('message_email_notifications', false),
        (string) $request->input('beta_invite_code', ''),
        $request,
    );
    $auth->setSessionCookies($result['session']);
    Response::success($result, 201);
});
$router->get('/api/v1/auth/csrf', static function () use ($auth): never {
    Response::success(['csrf_token' => $auth->refreshPreAuthCsrfCookie()]);
});
$router->post('/api/v1/auth/login', static function (Request $request) use ($auth, $rateLimiter): never {
    $auth->assertPreAuthCsrf($request);
    $email = (string) $request->input('email', '');
    $rateLimiter->enforce($request, 'auth.login', $email, 10, 900, 900);
    $result = $auth->login(
        $email,
        (string) $request->input('password', ''),
        $request,
    );
    $rateLimiter->clear($request, 'auth.login', $email);
    $auth->setSessionCookies($result['session']);
    Response::success($result);
});
$router->post('/api/v1/auth/password/forgot', static function (Request $request) use ($auth, $rateLimiter): never {
    $auth->assertPreAuthCsrf($request);
    $email = (string) $request->input('email', '');
    $rateLimiter->enforce($request, 'auth.password_forgot', $email, 5, 3600, 3600);
    $auth->requestPasswordReset($email);
    Response::success(['accepted' => true]);
});
$router->post('/api/v1/auth/password/reset', static function (Request $request) use ($auth, $rateLimiter): never {
    $auth->assertPreAuthCsrf($request);
    $rateLimiter->enforce($request, 'auth.password_reset', (string) $request->input('token', ''), 5, 3600, 3600);
    $auth->resetPassword(
        (string) $request->input('token', ''),
        (string) $request->input('password', ''),
        (string) $request->input('password_confirmation', ''),
    );
    Response::success(['reset' => true]);
});
$router->get('/api/v1/auth/email/verify', static function (Request $request) use ($auth): never {
    $auth->verifyEmail((string) ($request->query['token'] ?? ''));
    Response::success(['verified' => true]);
});
$router->post('/api/v1/auth/email/resend', static function (Request $request) use ($auth, $rateLimiter): never {
    $user = $auth->requireUser($request);
    $rateLimiter->enforce($request, 'auth.email_resend', (string) $user['id'], 3, 3600, 3600);
    $auth->resendVerification($user);
    Response::success(['accepted' => true]);
});
$router->post('/api/v1/auth/refresh', static function (Request $request) use ($auth, $rateLimiter): never {
    if (strtolower((string) $request->header('x-client-type')) !== 'mobile') {
        throw new HttpException(400, 'Bu endpoint mobil istemci içindir.', 'invalid_client_type');
    }
    $rateLimiter->enforce($request, 'auth.refresh', (string) $request->input('refresh_token', ''), 30, 3600, 900);
    Response::success($auth->refreshMobileSession((string) $request->input('refresh_token', ''), $request));
});
$router->get('/api/v1/auth/me', static fn (Request $request) => Response::success(['user' => $auth->requireUser($request, false)]));
$router->post('/api/v1/auth/logout', static function (Request $request) use ($auth): never {
    $auth->requireUser($request);
    $auth->logout($request);
    $auth->clearSessionCookies();
    Response::success(['logged_out' => true]);
});

$router->put('/api/v1/account/password', static function (Request $request) use ($auth, $account, $rateLimiter): never {
    $user = $auth->requireUser($request);
    $rateLimiter->enforce($request, 'account.password', (string) $user['id'], 5, 3600, 3600);
    $account->changePassword(
        $user,
        (string) $request->input('current_password', ''),
        (string) $request->input('password', ''),
        (string) $request->input('password_confirmation', ''),
    );
    Response::success(['changed' => true]);
});
$router->post('/api/v1/account/email/change', static function (Request $request) use ($auth, $account, $rateLimiter): never {
    $user = $auth->requireUser($request);
    $rateLimiter->enforce($request, 'account.email_change', (string) $user['id'], 3, 3600, 3600);
    $account->requestEmailChange(
        $user,
        (string) $request->input('new_email', ''),
        (string) $request->input('current_password', ''),
    );
    Response::success(['accepted' => true]);
});
$router->post('/api/v1/account/phone/request', static function (Request $request) use ($auth, $account, $rateLimiter): never {
    $user = $auth->requireUser($request);
    $rateLimiter->enforce($request, 'account.phone_request', (string) $user['id'], 3, 3600, 3600);
    Response::success($account->requestPhoneVerification($user, (string) $request->input('phone', '')));
});
$router->post('/api/v1/account/phone/verify', static function (Request $request) use ($auth, $account, $rateLimiter): never {
    $user = $auth->requireUser($request);
    $rateLimiter->enforce($request, 'account.phone_verify', (string) $user['id'], 10, 3600, 900);
    $account->verifyPhone($user, (string) $request->input('code', ''));
    Response::success(['verified' => true]);
});
$router->put('/api/v1/account/preferences', static function (Request $request) use ($auth, $account): never {
    $user = $auth->requireUser($request);
    $account->updatePreferences($user, (bool) $request->input('message_email_notifications', false));
    Response::success(['updated' => true]);
});
$router->get('/api/v1/account/sessions', static function (Request $request) use ($auth, $account): never {
    $user = $auth->requireUser($request, false);
    Response::success(['items' => $account->sessions($user)]);
});
$router->post('/api/v1/account/sessions/revoke-others', static function (Request $request) use ($auth, $account): never {
    $user = $auth->requireUser($request);
    $account->revokeOtherSessions($user);
    Response::success(['revoked' => true]);
});

$router->get('/api/v1/profiles/{id}', static fn (Request $request) => Response::success($profiles->find((string) $request->route('id'))));
$router->get('/api/v1/profile', static function (Request $request) use ($auth, $profiles): never {
    $user = $auth->requireUser($request, false);
    Response::success($profiles->findOwn((string) $user['id']));
});
$router->put('/api/v1/profile', static function (Request $request) use ($auth, $profiles): never {
    $user = $auth->requireUser($request);
    Response::success($profiles->update($request->body, $user));
});
$router->post('/api/v1/profiles/{id}/phone-reveal', static function (Request $request) use ($auth, $profiles, $rateLimiter): never {
    $user = $auth->requireUser($request);
    $rateLimiter->enforce($request, 'profile.phone_reveal', (string) $user['id'], 30, 86400, 3600);
    Response::success($profiles->revealPhone((string) $request->route('id'), (string) $user['id'], $request));
});
$router->get('/api/v1/locations', static fn (Request $request) => Response::success(['items' => $locations->all()]));
$router->get('/api/v1/saved-searches', static function (Request $request) use ($auth, $savedSearches): never {
    $user = $auth->requireUser($request, false);
    Response::success(['items' => $savedSearches->all((string) $user['id'])]);
});
$router->post('/api/v1/saved-searches', static function (Request $request) use ($auth, $savedSearches, $rateLimiter): never {
    $user = $auth->requireUser($request);
    $rateLimiter->enforce($request, 'saved_search.create', (string) $user['id'], 20, 86400, 3600);
    Response::success($savedSearches->create((string) $user['id'], $request->body), 201);
});
$router->delete('/api/v1/saved-searches/{id}', static function (Request $request) use ($auth, $savedSearches): never {
    $user = $auth->requireUser($request);
    $savedSearches->remove((string) $user['id'], (string) $request->route('id'));
    Response::success(['removed' => true]);
});

$router->post('/api/v1/uploads/images', static function (Request $request) use ($auth, $media, $rateLimiter): never {
    $user = $auth->requireUser($request);
    $rateLimiter->enforce($request, 'image.upload', (string) $user['id'], 30, 86400, 3600);
    $file = $request->files['file'] ?? null;
    if (!is_array($file)) {
        throw new HttpException(422, 'Yüklenecek görsel gerekli.', 'validation_failed');
    }
    Response::success($media->uploadImage(
        $file,
        (string) $request->input('purpose', ''),
        $user,
        is_string($request->input('listing_id')) ? $request->input('listing_id') : null,
        is_string($request->input('conversation_id')) ? $request->input('conversation_id') : null,
    ), 201);
});
$router->delete('/api/v1/uploads/images/{id}', static function (Request $request) use ($auth, $media): never {
    $user = $auth->requireUser($request);
    $media->remove((string) $request->route('id'), $user);
    Response::success(['removed' => true]);
});

$router->get('/api/v1/favorites', static function (Request $request) use ($auth, $marketplace): never {
    $user = $auth->requireUser($request, false);
    Response::success($marketplace->favorites((string) $user['id'], $request->query));
});
$router->post('/api/v1/favorites/{listing_id}', static function (Request $request) use ($auth, $marketplace): never {
    $user = $auth->requireUser($request);
    $marketplace->addFavorite((string) $request->route('listing_id'), (string) $user['id']);
    Response::success(['favorited' => true], 201);
});
$router->delete('/api/v1/favorites/{listing_id}', static function (Request $request) use ($auth, $marketplace): never {
    $user = $auth->requireUser($request);
    $marketplace->removeFavorite((string) $request->route('listing_id'), (string) $user['id']);
    Response::success(['favorited' => false]);
});

$router->get('/api/v1/users/{id}/reviews', static fn (Request $request) => Response::success(
    $marketplace->reviews((string) $request->route('id'), $request->query),
));
$router->post('/api/v1/reviews', static function (Request $request) use ($auth, $marketplace, $rateLimiter): never {
    $user = $auth->requireUser($request);
    $rateLimiter->enforce($request, 'review.create', (string) $user['id'], 10, 3600, 1800);
    Response::success($marketplace->createReview($request->body, (string) $user['id']), 201);
});
$router->put('/api/v1/reviews/{id}', static function (Request $request) use ($auth, $marketplace): never {
    $user = $auth->requireUser($request);
    Response::success($marketplace->updateReview((string) $request->route('id'), $request->body, (string) $user['id']));
});
$router->delete('/api/v1/reviews/{id}', static function (Request $request) use ($auth, $marketplace): never {
    $user = $auth->requireUser($request);
    $marketplace->removeReview((string) $request->route('id'), (string) $user['id']);
    Response::success(['removed' => true]);
});

$router->post('/api/v1/reports', static function (Request $request) use ($auth, $marketplace, $rateLimiter): never {
    $user = $auth->requireUser($request);
    $rateLimiter->enforce($request, 'report.create', (string) $user['id'], 10, 86400, 86400);
    Response::success($marketplace->report($request->body, (string) $user['id']), 201);
});
$router->get('/api/v1/blocks', static function (Request $request) use ($auth, $marketplace): never {
    $user = $auth->requireUser($request, false);
    Response::success(['items' => $marketplace->blocks((string) $user['id'])]);
});
$router->post('/api/v1/blocks/{user_id}', static function (Request $request) use ($auth, $marketplace): never {
    $user = $auth->requireUser($request);
    $marketplace->block((string) $request->route('user_id'), (string) $user['id']);
    Response::success(['blocked' => true], 201);
});
$router->delete('/api/v1/blocks/{user_id}', static function (Request $request) use ($auth, $marketplace): never {
    $user = $auth->requireUser($request);
    $marketplace->unblock((string) $request->route('user_id'), (string) $user['id']);
    Response::success(['blocked' => false]);
});

$router->get('/api/v1/engagements', static function (Request $request) use ($auth, $engagements): never {
    $user = $auth->requireUser($request, false);
    Response::success(['items' => $engagements->all((string)$user['id'], $request->query)]);
});
$router->post('/api/v1/engagements', static function (Request $request) use ($auth, $engagements, $rateLimiter): never {
    $user = $auth->requireUser($request);
    $rateLimiter->enforce($request, 'engagement.create', (string)$user['id'], 15, 3600, 3600);
    Response::success($engagements->create($request->body, (string)$user['id']), 201);
});
$router->get('/api/v1/engagements/{id}', static function (Request $request) use ($auth, $engagements): never {
    $user = $auth->requireUser($request, false);
    Response::success($engagements->find((string)$request->route('id'), (string)$user['id']));
});
$router->post('/api/v1/engagements/{id}/actions/{action}', static function (Request $request) use ($auth, $engagements, $rateLimiter): never {
    $user = $auth->requireUser($request);
    $rateLimiter->enforce($request, 'engagement.transition', (string)$user['id'], 40, 3600, 1800);
    Response::success($engagements->transition(
        (string)$request->route('id'),
        (string)$request->route('action'),
        $request->body,
        (string)$user['id'],
    ));
});

$router->get('/api/v1/conversations', static function (Request $request) use ($auth, $messages): never {
    $user = $auth->requireUser($request, false);
    Response::success(['items' => $messages->conversations((string) $user['id'])]);
});
$router->post('/api/v1/conversations', static function (Request $request) use ($auth, $messages, $rateLimiter): never {
    $user = $auth->requireUser($request);
    $rateLimiter->enforce($request, 'conversation.start', (string) $user['id'], 30, 3600, 1800);
    $itemId = trim((string)$request->input('listing_item_id', ''));
    $conversationId = $messages->startConversation(
        (string) $request->input('listing_id', ''),
        (string) $user['id'],
        $itemId === '' ? null : $itemId,
    );
    Response::success(['conversation_id' => $conversationId], 201);
});
$router->get('/api/v1/conversations/{id}/messages', static function (Request $request) use ($auth, $messages): never {
    $user = $auth->requireUser($request, false);
    $items = $messages->messages(
        (string) $request->route('id'),
        (string) $user['id'],
        (int) ($request->query['after_id'] ?? 0),
    );
    Response::success([
        'items' => $items,
        'has_more' => count($items) === 200,
        'next_after_id' => $items === [] ? null : (int) $items[array_key_last($items)]['id'],
        'poll_after_ms' => 3000,
    ]);
});
$router->post('/api/v1/conversations/{id}/messages', static function (Request $request) use ($auth, $messages, $rateLimiter): never {
    $user = $auth->requireUser($request);
    $rateLimiter->enforce($request, 'message.send', (string) $user['id'], 60, 60, 60);
    $attachmentIds = $request->input('attachment_ids', []);
    $message = $messages->send(
        (string) $request->route('id'),
        (string) $user['id'],
        (string) $request->input('body', ''),
        is_array($attachmentIds) ? $attachmentIds : [],
    );
    Response::success($message, 201);
});
$router->post('/api/v1/conversations/{id}/read', static function (Request $request) use ($auth, $messages): never {
    $user = $auth->requireUser($request);
    $messageId = $request->input('message_id');
    Response::success([
        'last_read_message_id' => $messages->markRead(
            (string) $request->route('id'),
            (string) $user['id'],
            is_numeric($messageId) ? (int) $messageId : null,
        ),
    ]);
});

$router->get('/api/v1/notifications', static function (Request $request) use ($auth, $notifications): never {
    $user = $auth->requireUser($request, false);
    Response::success($notifications->list(
        (string) $user['id'],
        (int) ($request->query['limit'] ?? 50),
        (int) ($request->query['before_id'] ?? 0),
    ));
});
$router->get('/api/v1/realtime/connection', static function (Request $request) use ($auth, $realtimeTokens): never {
    $user = $auth->requireUser($request, false);
    Response::success($realtimeTokens->connectionFor((string) $user['id']));
});
$router->post('/api/v1/notifications/read-all', static function (Request $request) use ($auth, $notifications): never {
    $user = $auth->requireUser($request);
    Response::success(['updated' => $notifications->markRead((string) $user['id'])]);
});
$router->post('/api/v1/notifications/{id}/read', static function (Request $request) use ($auth, $notifications): never {
    $user = $auth->requireUser($request);
    Response::success(['updated' => $notifications->markRead((string) $user['id'], (int) $request->route('id'))]);
});

$router->post('/api/v1/privacy/consents', static function (Request $request) use ($auth, $privacy): never {
    $user = $auth->requireUser($request);
    $ids = $request->input('policy_ids', []);
    Response::success(['recorded' => $privacy->recordConsents((string)$user['id'], is_array($ids) ? $ids : [], $request)], 201);
});
$router->get('/api/v1/privacy/requests', static function (Request $request) use ($auth, $privacy): never {
    $user = $auth->requireUser($request, false);
    Response::success(['items' => $privacy->requests((string)$user['id'])]);
});
$router->post('/api/v1/privacy/requests', static function (Request $request) use ($auth, $privacy, $rateLimiter): never {
    $user = $auth->requireUser($request);
    $rateLimiter->enforce($request, 'privacy.request', (string)$user['id'], 5, 86400, 86400);
    Response::success($privacy->request((string)$user['id'], (string)$request->input('request_type',''), (string)$request->input('details','')), 201);
});
$router->get('/api/v1/privacy/export', static function (Request $request) use ($auth, $privacy): never {
    $user = $auth->requireUser($request, false);
    Response::success($privacy->export((string)$user['id']));
});

$router->post('/api/v1/admin/auth/login', static function (Request $request) use ($adminAuth, $rateLimiter): never {
    $email = (string)$request->input('email','');
    $rateLimiter->enforce($request, 'admin.login', $email, 5, 900, 1800);
    Response::success(['user' => $adminAuth->login($email, (string)$request->input('password',''), $request)]);
});
$router->post('/api/v1/admin/auth/logout', static function (Request $request) use ($adminAuth): never {
    $adminAuth->requirePermission($request, 'dashboard.view');
    $adminAuth->logout($request);
    Response::success(['logged_out'=>true]);
});
$router->get('/api/v1/admin/stats', static function (Request $request) use ($adminAuth, $admin): never {
    $adminAuth->requirePermission($request, 'dashboard.view', false);
    Response::success($admin->dashboard());
});
$router->get('/api/v1/admin/users', static function (Request $request) use ($adminAuth, $admin): never {
    $actor=$adminAuth->requirePermission($request, 'users.view', false);
    Response::success(['items'=>$admin->users(
        (string)($request->query['q'] ?? ''),
        (string)($request->query['status'] ?? ''),
        (string)($request->query['role'] ?? ''),
    ),'capabilities'=>['permanent_delete'=>$actor['role']==='super_admin']]);
});
$router->put('/api/v1/admin/users/{id}/suspension', static function (Request $request) use ($adminAuth, $admin): never {
    $actor=$adminAuth->requirePermission($request, 'users.suspend');
    $admin->suspendUser((string)$request->route('id'), (bool)$request->input('suspended',true), (string)$request->input('reason',''), $actor, $request);
    Response::success(['updated'=>true]);
});
$router->delete('/api/v1/admin/users/{id}', static function (Request $request) use ($adminAuth, $admin): never {
    $actor=$adminAuth->requirePermission($request, 'users.delete');
    Response::success($admin->permanentlyDeleteUser(
        (string)$request->route('id'),
        (string)$request->input('reason',''),
        (string)$request->input('confirmation',''),
        $actor,
        $request,
    ));
});
$router->get('/api/v1/admin/listings', static function (Request $request) use ($adminAuth, $admin): never {
    $actor=$adminAuth->requirePermission($request, 'listings.view', false);
    Response::success(['items'=>$admin->listings(
        (string)($request->query['q'] ?? ''),
        (string)($request->query['status'] ?? ''),
        (string)($request->query['type'] ?? ''),
    ),'summary'=>$admin->listingSummary(),'capabilities'=>['permanent_delete'=>$actor['role']==='super_admin']]);
});
$router->put('/api/v1/admin/listings/{id}/moderation', static function (Request $request) use ($adminAuth, $admin): never {
    $actor=$adminAuth->requirePermission($request, 'listings.moderate');
    $admin->moderateListing((string)$request->route('id'),(string)$request->input('status',''),(string)$request->input('note',''),$actor,$request); Response::success(['updated'=>true]);
});
$router->delete('/api/v1/admin/listings/{id}', static function (Request $request) use ($adminAuth, $admin): never {
    $actor=$adminAuth->requirePermission($request, 'listings.delete');
    Response::success($admin->permanentlyDeleteListing(
        (string)$request->route('id'),
        (string)$request->input('reason',''),
        (string)$request->input('confirmation',''),
        $actor,
        $request,
    ));
});
$router->get('/api/v1/admin/reports', static function (Request $request) use ($adminAuth, $admin): never {
    $adminAuth->requirePermission($request, 'reports.view', false);
    Response::success([
        'items'=>$admin->reports(
            (string)($request->query['q'] ?? ''),
            (string)($request->query['status'] ?? ''),
            (string)($request->query['reason'] ?? ''),
            (string)($request->query['priority'] ?? ''),
        ),
        'summary'=>$admin->reportSummary(),
    ]);
});
$router->put('/api/v1/admin/reports/{id}', static function (Request $request) use ($adminAuth, $admin): never {
    $actor=$adminAuth->requirePermission($request, 'reports.resolve');
    $admin->updateReport((string)$request->route('id'),$request->body,$actor,$request);
    Response::success(['updated'=>true]);
});
$router->get('/api/v1/admin/trust-operations', static function (Request $request) use ($adminAuth, $admin): never {
    $adminAuth->requirePermission($request, 'engagements.view', false);
    Response::success($admin->trustOperations());
});
$router->put('/api/v1/admin/engagements/{id}', static function (Request $request) use ($adminAuth, $admin): never {
    $actor=$adminAuth->requirePermission($request, 'engagements.moderate');
    $admin->moderateEngagement((string)$request->route('id'),(string)$request->input('status',''),(string)$request->input('note',''),$actor,$request);
    Response::success(['updated'=>true]);
});
$router->put('/api/v1/admin/reviews/{id}', static function (Request $request) use ($adminAuth, $admin): never {
    $actor=$adminAuth->requirePermission($request, 'reviews.moderate');
    $admin->moderateReview((string)$request->route('id'),(string)$request->input('status',''),(string)$request->input('note',''),$actor,$request);
    Response::success(['updated'=>true]);
});
$router->put('/api/v1/admin/risk-signals/{id}', static function (Request $request) use ($adminAuth, $admin): never {
    $actor=$adminAuth->requirePermission($request, 'risk.moderate');
    $admin->moderateRisk((string)$request->route('id'),(string)$request->input('status',''),(string)$request->input('note',''),$actor,$request);
    Response::success(['updated'=>true]);
});
$router->put('/api/v1/admin/beta-feedback/{id}', static function (Request $request) use ($adminAuth, $admin): never {
    $actor=$adminAuth->requirePermission($request, 'beta.manage');
    $admin->moderateBetaFeedback((string)$request->route('id'),(string)$request->input('status',''),(string)$request->input('note',''),$actor,$request);
    Response::success(['updated'=>true]);
});
$router->post('/api/v1/admin/beta-invites', static function (Request $request) use ($adminAuth, $beta): never {
    $actor=$adminAuth->requirePermission($request,'beta.manage');
    Response::success($beta->createInvite($request->body,$actor),201);
});
$router->get('/api/v1/admin/categories', static function (Request $request) use ($adminAuth, $admin): never {
    $adminAuth->requirePermission($request, 'categories.manage', false); Response::success(['items'=>$admin->categories()]);
});
$router->post('/api/v1/admin/categories', static function (Request $request) use ($adminAuth, $admin): never {
    $actor=$adminAuth->requirePermission($request, 'categories.create');
    Response::success($admin->createCategory($request->body,$actor,$request),201);
});
$router->put('/api/v1/admin/categories/{id}', static function (Request $request) use ($adminAuth, $admin): never {
    $actor=$adminAuth->requirePermission($request, 'categories.manage'); $admin->updateCategory((string)$request->route('id'),$request->body,$actor,$request); Response::success(['updated'=>true]);
});
$router->delete('/api/v1/admin/categories/{id}', static function (Request $request) use ($adminAuth, $admin): never {
    $actor=$adminAuth->requirePermission($request, 'categories.delete');
    Response::success($admin->deleteCategory((string)$request->route('id'),$actor,$request));
});
$router->get('/api/v1/admin/banners', static function (Request $request) use ($adminAuth, $admin): never {
    $adminAuth->requirePermission($request, 'banners.manage', false); Response::success(['items'=>$admin->banners()]);
});
$router->post('/api/v1/admin/banners', static function (Request $request) use ($adminAuth, $admin): never {
    $actor=$adminAuth->requirePermission($request, 'banners.manage'); Response::success($admin->saveBanner($request->body,$actor,$request),201);
});
$router->put('/api/v1/admin/banners/{id}', static function (Request $request) use ($adminAuth, $admin): never {
    $actor=$adminAuth->requirePermission($request, 'banners.manage'); Response::success($admin->saveBanner($request->body,$actor,$request,(string)$request->route('id')));
});
$router->delete('/api/v1/admin/banners/{id}', static function (Request $request) use ($adminAuth, $admin): never {
    $actor=$adminAuth->requirePermission($request, 'banners.manage');
    $admin->deleteBanner((string)$request->route('id'),$actor,$request);
    Response::success(['deleted'=>true]);
});
$router->get('/api/v1/admin/audit', static function (Request $request) use ($adminAuth, $admin): never {
    $adminAuth->requirePermission($request, 'audit.view', false); Response::success(['items'=>$admin->auditLogs()]);
});
$router->get('/api/v1/admin/privacy/requests', static function (Request $request) use ($adminAuth, $privacy): never {
    $adminAuth->requirePermission($request, 'privacy.manage', false); Response::success(['items'=>$privacy->adminRequests()]);
});
$router->put('/api/v1/admin/privacy/requests/{id}', static function (Request $request) use ($adminAuth, $privacy): never {
    $actor=$adminAuth->requirePermission($request, 'privacy.manage'); $privacy->reviewRequest((string)$request->route('id'),(string)$request->input('status',''),$actor,$request); Response::success(['updated'=>true]);
});
$router->post('/api/v1/admin/policies', static function (Request $request) use ($adminAuth, $privacy): never {
    $actor=$adminAuth->requirePermission($request, 'privacy.manage'); Response::success($privacy->savePolicy($request->body,$actor,$request),201);
});
$router->post('/api/v1/admin/policies/{id}/publish', static function (Request $request) use ($adminAuth, $privacy): never {
    $actor=$adminAuth->requirePermission($request, 'privacy.manage'); $privacy->publishPolicy((string)$request->route('id'),$actor,$request); Response::success(['published'=>true]);
});

try {
    $router->dispatch($request);
} catch (HttpException $exception) {
    if (str_starts_with($request->path, '/api/')) {
        Response::error($exception->getMessage(), $exception->errorCode, $exception->status, $exception->details);
    }
    $renderPage('not-found', ['title' => $exception->getMessage()], $exception->status);
} catch (Throwable $exception) {
    Logger::exception($exception);
    if (str_starts_with($request->path, '/api/')) {
        $details = Config::bool('APP_DEBUG') ? ['exception' => $exception->getMessage()] : [];
        Response::error('Beklenmeyen bir sunucu hatası oluştu.', 'server_error', 500, $details);
    }
    $renderPage('not-found', ['title' => 'Bir sorun oluştu'], 500);
}
