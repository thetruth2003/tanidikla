<?php

declare(strict_types=1);

namespace App\Notifications;

use App\Core\Config;
use RuntimeException;

final class SmsSender
{
    public function send(string $recipient, string $message): string
    {
        if (!Config::bool('SMS_ENABLED')) {
            throw new RuntimeException('SMS gönderimi bu ortamda etkin değil.');
        }
        $recipient = preg_replace('/\D+/', '', $recipient) ?? '';
        if (!preg_match('/^(90)?5\d{9}$/', $recipient)) {
            throw new RuntimeException('SMS alıcı numarası geçersiz.');
        }
        if (str_starts_with($recipient, '90')) {
            $recipient = substr($recipient, 2);
        }
        $payload = json_encode([
            'msgheader' => Config::string('NETGSM_HEADER'),
            'encoding' => 'TR',
            'messages' => [['msg' => mb_substr($message, 0, 1000), 'no' => $recipient]],
        ], JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE);
        $handle = curl_init(Config::string('NETGSM_API_URL', 'https://api.netgsm.com.tr/sms/rest/v2/send'));
        if ($handle === false) {
            throw new RuntimeException('NetGSM bağlantısı hazırlanamadı.');
        }
        curl_setopt_array($handle, [
            CURLOPT_POST => true,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_CONNECTTIMEOUT => 5,
            CURLOPT_TIMEOUT => 15,
            CURLOPT_USERPWD => Config::string('NETGSM_USERNAME') . ':' . Config::string('NETGSM_PASSWORD'),
            CURLOPT_HTTPAUTH => CURLAUTH_BASIC,
            CURLOPT_HTTPHEADER => ['Content-Type: application/json', 'Accept: application/json'],
            CURLOPT_POSTFIELDS => $payload,
        ]);
        $response = curl_exec($handle);
        $status = (int) curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
        $error = curl_error($handle);
        curl_close($handle);
        if (!is_string($response) || $status < 200 || $status >= 300) {
            throw new RuntimeException('NetGSM gönderimi başarısız: ' . ($error !== '' ? $error : 'HTTP ' . $status));
        }
        $decoded = json_decode($response, true);
        if (!is_array($decoded) || !isset($decoded['jobid'])) {
            throw new RuntimeException('NetGSM beklenmeyen yanıt döndürdü.');
        }
        return (string) $decoded['jobid'];
    }
}
