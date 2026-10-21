<?php

declare(strict_types=1);

namespace App\Storage;

use App\Core\Config;
use RuntimeException;

final class StorageFactory
{
    public static function make(?string $driver = null): StorageAdapter
    {
        return match ($driver ?? Config::string('STORAGE_DRIVER', 'local')) {
            'local' => new LocalStorageAdapter(),
            's3' => new S3StorageAdapter(),
            default => throw new RuntimeException('Desteklenmeyen depolama sürücüsü.'),
        };
    }
}
