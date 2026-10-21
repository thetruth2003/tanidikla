<?php

declare(strict_types=1);

namespace App\Core;

use Throwable;

final class Logger
{
    /** @param array<string, mixed> $context */
    public static function info(string $message, array $context = []): void
    {
        self::write('info', $message, $context);
    }

    /** @param array<string, mixed> $context */
    public static function error(string $message, array $context = []): void
    {
        self::write('error', $message, $context);
    }

    public static function exception(Throwable $exception): void
    {
        self::error('Unhandled application exception', [
            'exception_type' => $exception::class,
            'exception_message' => $exception->getMessage(),
            'exception_file' => Config::bool('APP_DEBUG') ? $exception->getFile() : null,
            'exception_line' => Config::bool('APP_DEBUG') ? $exception->getLine() : null,
        ]);
    }

    public static function requestCompleted(int $status): void
    {
        self::info('HTTP request completed', RequestContext::requestLogContext($status));
    }

    /** @param array<string, mixed> $context */
    private static function write(string $level, string $message, array $context): void
    {
        $directory = APP_ROOT . '/storage/logs';
        if (!is_dir($directory) && !mkdir($directory, 0770, true) && !is_dir($directory)) {
            return;
        }

        $entry = [
            'timestamp' => gmdate(DATE_ATOM),
            'level' => $level,
            'message' => $message,
            'request_id' => RequestContext::requestId(),
            ...self::sanitize($context),
        ];
        $json = json_encode($entry, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_INVALID_UTF8_SUBSTITUTE);
        if (is_string($json)) {
            file_put_contents($directory . '/app.jsonl', $json . "\n", FILE_APPEND | LOCK_EX);
        }
    }

    /** @param array<string, mixed> $context
     *  @return array<string, mixed>
     */
    private static function sanitize(array $context): array
    {
        $clean = [];
        foreach ($context as $key => $value) {
            if (preg_match('/password|token|secret|authorization|cookie|credential/i', (string) $key) === 1) {
                $clean[$key] = '[REDACTED]';
            } elseif (is_array($value)) {
                $clean[$key] = self::sanitize($value);
            } elseif (is_scalar($value) || $value === null) {
                $clean[$key] = is_string($value) ? mb_substr($value, 0, 2000) : $value;
            } else {
                $clean[$key] = get_debug_type($value);
            }
        }
        return $clean;
    }
}
