<?php

declare(strict_types=1);

use App\Core\Config;
use App\Core\Database;
use App\Core\Logger;
use App\Core\RequestContext;
use App\Notifications\RealtimePublisher;

if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require dirname(__DIR__) . '/bootstrap.php';
RequestContext::initialize('cron-realtime-' . bin2hex(random_bytes(8)));
if (!Config::bool('CENTRIFUGO_ENABLED')) {
    fwrite(STDOUT, "Centrifugo kapalı; polling yedeği etkin.\n");
    exit(0);
}

$lock = fopen(APP_ROOT . '/storage/temp/publish-realtime.lock', 'c+');
if ($lock === false || !flock($lock, LOCK_EX | LOCK_NB)) { fwrite(STDOUT, "Realtime worker zaten çalışıyor.\n"); exit(0); }
$database = new Database();
$publisher = new RealtimePublisher();
$processed = 0;
while ($processed < 100) {
    $job = $database->transaction(static function (PDO $pdo): ?array {
        $row = $pdo->query("select id, channel, event_type, payload, attempts from realtime_outbox where status in ('pending','failed') and next_attempt_at <= now() order by id for update skip locked limit 1")->fetch(PDO::FETCH_ASSOC);
        if ($row === false) return null;
        $pdo->prepare("update realtime_outbox set status='processing', processing_started_at=now(), attempts=attempts+1 where id=:id")->execute(['id' => $row['id']]);
        return $row;
    });
    if ($job === null) break;
    try {
        $publisher->publish((string) $job['channel'], (string) $job['event_type'], json_decode((string) $job['payload'], true, 512, JSON_THROW_ON_ERROR));
        $database->statement("update realtime_outbox set status='published', published_at=now(), processing_started_at=null, last_error=null where id=:id", ['id' => $job['id']]);
    } catch (Throwable $exception) {
        $delay = min(3600, 5 * (2 ** min(8, (int) $job['attempts'] + 1)));
        $database->statement("update realtime_outbox set status='failed', processing_started_at=null, next_attempt_at=now()+make_interval(secs=>:delay), last_error=:error where id=:id", ['id' => $job['id'], 'delay' => $delay, 'error' => mb_substr($exception->getMessage(), 0, 1000)]);
        Logger::error('Realtime publish failed', ['outbox_id' => (int) $job['id'], 'exception_type' => $exception::class]);
    }
    $processed++;
}
flock($lock, LOCK_UN); fclose($lock); fwrite(STDOUT, "İşlenen realtime olayı: {$processed}\n");
