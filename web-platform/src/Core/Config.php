<?php

declare(strict_types=1);

namespace App\Core;

final class Config
{
    public static function string(string $key, string $default = ''): string
    {
        $value = getenv($key);
        return $value === false ? $default : (string) $value;
    }

    public static function int(string $key, int $default): int
    {
        $value = getenv($key);
        return $value === false || !is_numeric($value) ? $default : (int) $value;
    }

    public static function bool(string $key, bool $default = false): bool
    {
        $value = getenv($key);
        if ($value === false) {
            return $default;
        }

        return filter_var($value, FILTER_VALIDATE_BOOL, FILTER_NULL_ON_FAILURE) ?? $default;
    }
}

