<?php

declare(strict_types=1);

namespace App\Notifications;

use App\Core\Config;
use App\Core\Database;
use RuntimeException;

final class RealtimeTokenService
{
    public function __construct(private readonly Database $database)
    {
    }

    /** @return array{enabled: bool, url: ?string, token: ?string, expires_at: ?string, poll_after_ms: int} */
    public function connectionFor(string $userId): array
    {
        $url = trim(Config::string('CENTRIFUGO_CLIENT_URL'));
        $secret = Config::string('CENTRIFUGO_TOKEN_SECRET');
        if (!Config::bool('CENTRIFUGO_ENABLED') || $url === '' || $secret === '') {
            return [
                'enabled' => false,
                'url' => null,
                'token' => null,
                'expires_at' => null,
                'poll_after_ms' => 3000,
            ];
        }
        if (!preg_match('#^wss?://#i', $url)) {
            throw new RuntimeException('CENTRIFUGO_CLIENT_URL ws:// veya wss:// ile başlamalıdır.');
        }

        $rows = $this->database->fetchAll(
            'select conversation_id from conversation_members where user_id = :user_id order by conversation_id',
            ['user_id' => $userId],
        );
        $channels = ['user:' . $userId];
        foreach ($rows as $row) {
            $channels[] = 'conversation:' . (string) $row['conversation_id'];
        }

        $expiresAt = time() + max(60, min(Config::int('CENTRIFUGO_TOKEN_TTL_SECONDS', 300), 3600));
        $header = ['alg' => 'HS256', 'typ' => 'JWT'];
        $claims = [
            'sub' => $userId,
            'exp' => $expiresAt,
            'channels' => array_values(array_unique($channels)),
        ];
        $unsigned = $this->base64Url(json_encode($header, JSON_THROW_ON_ERROR))
            . '.' . $this->base64Url(json_encode($claims, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES));
        $signature = hash_hmac('sha256', $unsigned, $secret, true);

        return [
            'enabled' => true,
            'url' => $url,
            'token' => $unsigned . '.' . $this->base64Url($signature),
            'expires_at' => gmdate(DATE_ATOM, $expiresAt),
            'poll_after_ms' => 3000,
        ];
    }

    private function base64Url(string $value): string
    {
        return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
    }
}
