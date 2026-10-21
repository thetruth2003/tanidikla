<?php

declare(strict_types=1);

use App\Core\Database;
use App\Notifications\RealtimeTokenService;

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

putenv('CENTRIFUGO_ENABLED=true');
putenv('CENTRIFUGO_CLIENT_URL=ws://127.0.0.1:8000/connection/websocket');
putenv('CENTRIFUGO_TOKEN_SECRET=realtime-test-secret-not-for-production');
require dirname(__DIR__) . '/bootstrap.php';

$database = new Database();
$user = $database->fetchOne('select id from users order by created_at limit 1');
if ($user === null) {
    throw new RuntimeException('Realtime token testi için kullanıcı bulunamadı.');
}
$result = (new RealtimeTokenService($database))->connectionFor((string) $user['id']);
$parts = explode('.', (string) $result['token']);
if (count($parts) !== 3) {
    throw new RuntimeException('JWT üç parçalı değil.');
}
$claims = json_decode((string) base64_decode(strtr($parts[1], '-_', '+/'), true), true, 512, JSON_THROW_ON_ERROR);
$expectedSignature = rtrim(strtr(base64_encode(hash_hmac('sha256', $parts[0] . '.' . $parts[1], 'realtime-test-secret-not-for-production', true)), '+/', '-_'), '=');
$personalChannel = 'user:' . $user['id'];
if (!$result['enabled']
    || !hash_equals($expectedSignature, $parts[2])
    || ($claims['sub'] ?? null) !== (string) $user['id']
    || !in_array($personalChannel, $claims['channels'] ?? [], true)) {
    throw new RuntimeException('Realtime token imzası veya kanal kapsamı geçersiz.');
}

fwrite(STDOUT, json_encode([
    'enabled' => true,
    'algorithm' => 'HS256',
    'personal_channel' => true,
], JSON_THROW_ON_ERROR) . PHP_EOL);
