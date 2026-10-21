<?php

declare(strict_types=1);

use App\Core\Database;
use App\Core\Logger;
use App\Core\RequestContext;
use App\Mail\MailerService;

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

require dirname(__DIR__) . '/bootstrap.php';
RequestContext::initialize('cron-email-' . bin2hex(random_bytes(8)));

$lockPath = APP_ROOT . '/storage/temp/send-emails.lock';
if (!is_dir(dirname($lockPath))) {
    mkdir(dirname($lockPath), 0770, true);
}
$lock = fopen($lockPath, 'c+');
if ($lock === false || !flock($lock, LOCK_EX | LOCK_NB)) {
    fwrite(STDOUT, "E-posta worker zaten çalışıyor.\n");
    exit(0);
}

$database = new Database();
$mailer = new MailerService();
$processed = 0;

while ($processed < 50) {
    $job = $database->transaction(static function (PDO $pdo): ?array {
        $statement = $pdo->query(
            "select id, recipient, subject, html_body, text_body, attempts
             from email_queue
             where status in ('pending', 'failed') and next_attempt_at <= now()
             order by id
             for update skip locked
             limit 1"
        );
        $row = $statement->fetch(PDO::FETCH_ASSOC);
        if ($row === false) {
            return null;
        }
        $pdo->prepare(
            "update email_queue set status = 'processing', processing_started_at = now(), attempts = attempts + 1
             where id = :id"
        )->execute(['id' => $row['id']]);
        return $row;
    });

    if ($job === null) {
        break;
    }

    try {
        $mailer->send(
            (string) $job['recipient'],
            (string) $job['subject'],
            (string) $job['html_body'],
            (string) $job['text_body'],
        );
        $database->statement(
            "update email_queue set status = 'sent', sent_at = now(), processing_started_at = null, last_error = null
             where id = :id",
            ['id' => $job['id']],
        );
    } catch (Throwable $exception) {
        $attempt = (int) $job['attempts'] + 1;
        $delaySeconds = min(3600, 60 * (2 ** min(6, $attempt)));
        $database->statement(
            "update email_queue set status = 'failed', processing_started_at = null,
             next_attempt_at = now() + make_interval(secs => :delay_seconds), last_error = :last_error
             where id = :id",
            [
                'id' => $job['id'],
                'delay_seconds' => $delaySeconds,
                'last_error' => mb_substr($exception->getMessage(), 0, 1000),
            ],
        );
        Logger::error('Email delivery failed', [
            'email_queue_id' => (int) $job['id'],
            'exception_type' => $exception::class,
        ]);
    }
    $processed += 1;
}

flock($lock, LOCK_UN);
fclose($lock);
fwrite(STDOUT, "İşlenen e-posta: {$processed}\n");
