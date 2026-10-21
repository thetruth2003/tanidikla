<?php

declare(strict_types=1);

use App\Core\Database;
use App\Core\Logger;
use App\Core\RequestContext;
use App\Notifications\SmsSender;

if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require dirname(__DIR__) . '/bootstrap.php';
RequestContext::initialize('cron-sms-' . bin2hex(random_bytes(8)));

$lock = fopen(APP_ROOT . '/storage/temp/send-sms.lock', 'c+');
if ($lock === false || !flock($lock, LOCK_EX | LOCK_NB)) { fwrite(STDOUT, "SMS worker zaten çalışıyor.\n"); exit(0); }
$database = new Database();
$sender = new SmsSender();
$processed = 0;
while ($processed < 50) {
    $job = $database->transaction(static function (PDO $pdo): ?array {
        $row = $pdo->query("select id, recipient, message, attempts from sms_queue where status in ('pending','failed') and next_attempt_at <= now() order by id for update skip locked limit 1")->fetch(PDO::FETCH_ASSOC);
        if ($row === false) return null;
        $pdo->prepare("update sms_queue set status='processing', processing_started_at=now(), attempts=attempts+1 where id=:id")->execute(['id' => $row['id']]);
        return $row;
    });
    if ($job === null) break;
    try {
        $reference = $sender->send((string) $job['recipient'], (string) $job['message']);
        $database->statement("update sms_queue set status='sent', provider_reference=:reference, sent_at=now(), processing_started_at=null, last_error=null where id=:id", ['id' => $job['id'], 'reference' => $reference]);
    } catch (Throwable $exception) {
        $delay = min(3600, 60 * (2 ** min(6, (int) $job['attempts'] + 1)));
        $database->statement("update sms_queue set status='failed', processing_started_at=null, next_attempt_at=now()+make_interval(secs=>:delay), last_error=:error where id=:id", ['id' => $job['id'], 'delay' => $delay, 'error' => mb_substr($exception->getMessage(), 0, 1000)]);
        Logger::error('SMS delivery failed', ['sms_queue_id' => (int) $job['id'], 'exception_type' => $exception::class]);
    }
    $processed++;
}
flock($lock, LOCK_UN); fclose($lock); fwrite(STDOUT, "İşlenen SMS: {$processed}\n");
