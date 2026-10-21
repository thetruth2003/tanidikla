<?php

declare(strict_types=1);

namespace App\Core;

final class RequestContext
{
    private static ?string $requestId = null;
    private static ?string $cspNonce = null;
    private static ?string $method = null;
    private static ?string $path = null;
    private static ?string $userId = null;
    private static float $startedAt = 0.0;

    public static function initialize(?string $incomingRequestId = null): void
    {
        if (self::$requestId !== null) {
            return;
        }

        $incomingRequestId = trim((string) $incomingRequestId);
        self::$requestId = preg_match('/^[A-Za-z0-9][A-Za-z0-9._-]{7,63}$/', $incomingRequestId) === 1
            ? $incomingRequestId
            : bin2hex(random_bytes(16));
        self::$cspNonce = rtrim(strtr(base64_encode(random_bytes(18)), '+/', '-_'), '=');
        self::$method = strtoupper((string) ($_SERVER['REQUEST_METHOD'] ?? 'GET'));
        self::$path = parse_url((string) ($_SERVER['REQUEST_URI'] ?? '/'), PHP_URL_PATH) ?: '/';
        self::$startedAt = microtime(true);
    }

    public static function requestId(): string
    {
        self::initialize();
        return (string) self::$requestId;
    }

    public static function cspNonce(): string
    {
        self::initialize();
        return (string) self::$cspNonce;
    }

    public static function setUserId(string $userId): void
    {
        self::$userId = $userId;
    }

    /** @return array<string, int|string|null> */
    public static function requestLogContext(int $status): array
    {
        self::initialize();
        return [
            'request_id' => self::$requestId,
            'user_id' => self::$userId,
            'method' => self::$method,
            'path' => self::$path,
            'status' => $status,
            'duration_ms' => (int) round((microtime(true) - self::$startedAt) * 1000),
        ];
    }
}
