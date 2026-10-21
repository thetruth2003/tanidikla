<?php

declare(strict_types=1);

namespace App\Notifications;

use App\Core\Database;

final class EmailQueueService
{
    public function __construct(private readonly Database $database)
    {
    }

    public function enqueue(string $recipient, string $subject, string $html, string $plainText): void
    {
        $this->database->statement(
            'insert into email_queue (recipient, subject, html_body, text_body)
             values (:recipient, :subject, :html_body, :text_body)',
            [
                'recipient' => mb_strtolower(trim($recipient)),
                'subject' => mb_substr(trim($subject), 0, 250),
                'html_body' => $html,
                'text_body' => $plainText,
            ],
        );
    }
}
