<?php

declare(strict_types=1);

namespace App\Mail;

use App\Core\Config;
use PHPMailer\PHPMailer\PHPMailer;
use RuntimeException;

final class MailerService
{
    public function send(string $recipient, string $subject, string $html, string $plainText): void
    {
        if (!Config::bool('MAIL_ENABLED')) {
            throw new RuntimeException('E-posta gönderimi bu ortamda etkin değil.');
        }

        if (!class_exists(PHPMailer::class)) {
            throw new RuntimeException('PHPMailer kurulmamış. composer install çalıştırılmalı.');
        }

        $mailer = new PHPMailer(true);
        $mailer->isSMTP();
        $mailer->Host = Config::string('MAIL_HOST');
        $mailer->Port = Config::int('MAIL_PORT', 587);
        $username = Config::string('MAIL_USERNAME');
        if ($username !== '') {
            $mailer->SMTPAuth = true;
            $mailer->Username = $username;
            $mailer->Password = Config::string('MAIL_PASSWORD');
        }
        $encryption = Config::string('MAIL_ENCRYPTION');
        if ($encryption !== '') {
            $mailer->SMTPSecure = $encryption;
        }
        $mailer->CharSet = 'UTF-8';
        $mailer->setFrom(Config::string('MAIL_FROM_ADDRESS'), Config::string('MAIL_FROM_NAME'));
        $mailer->addAddress($recipient);
        $mailer->isHTML(true);
        $mailer->Subject = $subject;
        $mailer->Body = $html;
        $mailer->AltBody = $plainText;
        $mailer->send();
    }

}
