<?php

declare(strict_types=1);

namespace App\Security;

use App\Core\Config;
use App\Core\RequestContext;

final class SecurityHeaders
{
    public static function apply(): void
    {
        header('X-Request-ID: ' . RequestContext::requestId());
        header('X-Content-Type-Options: nosniff');
        header('Referrer-Policy: strict-origin-when-cross-origin');
        header('Permissions-Policy: geolocation=(self), camera=(), microphone=(), payment=()');
        header('Cross-Origin-Opener-Policy: same-origin');
        header('Cross-Origin-Resource-Policy: same-origin');

        $nonce = RequestContext::cspNonce();
        $connectSources = ["'self'", 'https://nominatim.openstreetmap.org'];
        $imageSources = ["'self'", 'data:', 'blob:', 'https://tile.openstreetmap.org', 'https://*.tile.openstreetmap.org'];
        $tileUrl = parse_url(Config::string('MAP_TILE_URL', 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'));
        $tileScheme = strtolower((string) ($tileUrl['scheme'] ?? ''));
        $tileHost = (string) ($tileUrl['host'] ?? '');
        $tilePort = isset($tileUrl['port']) ? (int) $tileUrl['port'] : null;
        if (in_array($tileScheme, ['http', 'https'], true)
            && preg_match('/^[a-z0-9.-]+$/i', $tileHost) === 1
            && ($tilePort === null || ($tilePort >= 1 && $tilePort <= 65535))) {
            $tileSource = $tileScheme . '://' . $tileHost . ($tilePort === null ? '' : ':' . $tilePort);
            if (!in_array($tileSource, $imageSources, true)) {
                $imageSources[] = $tileSource;
            }
        }
        if (Config::bool('CENTRIFUGO_ENABLED')) {
            $realtimeUrl = parse_url(Config::string('CENTRIFUGO_CLIENT_URL'));
            $scheme = strtolower((string) ($realtimeUrl['scheme'] ?? ''));
            $host = (string) ($realtimeUrl['host'] ?? '');
            $port = isset($realtimeUrl['port']) ? (int) $realtimeUrl['port'] : null;
            $validHost = preg_match('/^[a-z0-9.-]+$/i', $host) === 1
                || preg_match('/^[0-9a-f:]+$/i', $host) === 1;
            if (in_array($scheme, ['ws', 'wss'], true) && $validHost && ($port === null || ($port >= 1 && $port <= 65535))) {
                $displayHost = str_contains($host, ':') ? '[' . $host . ']' : $host;
                $connectSources[] = $scheme . '://' . $displayHost . ($port === null ? '' : ':' . $port);
            }
        }
        $directives = [
            "default-src 'self'",
            "base-uri 'self'",
            "object-src 'none'",
            "frame-ancestors 'none'",
            "form-action 'self'",
            "script-src 'self' 'nonce-{$nonce}' https://unpkg.com",
            "style-src 'self' 'unsafe-inline' https://unpkg.com",
            'img-src ' . implode(' ', $imageSources),
            "font-src 'self'",
            'connect-src ' . implode(' ', $connectSources),
            "manifest-src 'self'",
            "worker-src 'self' blob:",
        ];
        if (Config::string('APP_ENV') === 'production') {
            $directives[] = 'upgrade-insecure-requests';
        }
        header('Content-Security-Policy: ' . implode('; ', $directives));

        if (Config::string('APP_ENV') === 'production' && str_starts_with(Config::string('APP_URL'), 'https://')) {
            header('Strict-Transport-Security: max-age=31536000; includeSubDomains');
        }
    }
}
