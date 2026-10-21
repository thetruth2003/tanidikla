<?php

declare(strict_types=1);

namespace App\Security;

use App\Core\HttpException;

final class PasswordPolicy
{
    /** @var list<string> */
    private const COMMON = [
        'password', 'password1', '12345678', '123456789', 'qwerty123',
        'admin123', 'ankara123', 'sifre123', 'yakindaki123',
    ];

    public static function assert(string $password): void
    {
        $errors = [];
        if (mb_strlen($password) < 10 || mb_strlen($password) > 200) {
            $errors[] = 'en az 10 karakter';
        }
        if (preg_match('/\p{L}/u', $password) !== 1) {
            $errors[] = 'en az bir harf';
        }
        if (preg_match('/\d/', $password) !== 1) {
            $errors[] = 'en az bir rakam';
        }
        if (preg_match('/[^\p{L}\d\s]/u', $password) !== 1) {
            $errors[] = 'en az bir özel karakter';
        }
        if (in_array(mb_strtolower(trim($password)), self::COMMON, true)) {
            $errors[] = 'yaygın olmayan bir parola';
        }
        if ($errors !== []) {
            throw new HttpException(
                422,
                'Şifre şu koşulları sağlamalı: ' . implode(', ', $errors) . '.',
                'weak_password',
                ['password' => $errors],
            );
        }
    }
}

