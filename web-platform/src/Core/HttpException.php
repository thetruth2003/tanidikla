<?php

declare(strict_types=1);

namespace App\Core;

use RuntimeException;

final class HttpException extends RuntimeException
{
    /** @param array<string, mixed> $details */
    public function __construct(
        public readonly int $status,
        string $message,
        public readonly string $errorCode = 'request_failed',
        public readonly array $details = [],
    ) {
        parent::__construct($message);
    }
}

