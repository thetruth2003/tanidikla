<?php

declare(strict_types=1);

namespace App\Notifications;

use App\Core\Config;
use RuntimeException;

final class RealtimePublisher
{
    /** @param array<string, mixed> $payload */
    public function publish(string $channel, string $eventType, array $payload): void
    {
        if (!Config::bool('CENTRIFUGO_ENABLED')) {
            throw new RuntimeException('Centrifugo bu ortamda etkin değil. Polling yedeği kullanılabilir.');
        }
        $endpoint = rtrim(Config::string('CENTRIFUGO_API_URL', 'http://127.0.0.1:8000/api'), '/');
        $body = json_encode([
            'channel' => $channel,
            'data' => ['event' => $eventType, 'payload' => $payload],
        ], JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE);
        $handle = curl_init($endpoint . '/publish');
        if ($handle === false) {
            throw new RuntimeException('Centrifugo bağlantısı hazırlanamadı.');
        }
        curl_setopt_array($handle, [
            CURLOPT_POST => true,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_CONNECTTIMEOUT => 3,
            CURLOPT_TIMEOUT => 8,
            CURLOPT_HTTPHEADER => [
                'Content-Type: application/json',
                'X-API-Key: ' . Config::string('CENTRIFUGO_API_KEY'),
                'X-Centrifugo-Error-Mode: transport',
            ],
            CURLOPT_POSTFIELDS => $body,
        ]);
        $response = curl_exec($handle);
        $status = (int) curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
        $error = curl_error($handle);
        curl_close($handle);
        if (!is_string($response) || $status < 200 || $status >= 300) {
            throw new RuntimeException('Centrifugo yayını başarısız: ' . ($error !== '' ? $error : 'HTTP ' . $status));
        }
        $decoded = json_decode($response, true);
        if (!is_array($decoded) || isset($decoded['error'])) {
            throw new RuntimeException('Centrifugo yayını hata döndürdü.');
        }
    }
}
