<?php

declare(strict_types=1);

namespace App\Storage;

interface StorageAdapter
{
    public function driver(): string;

    public function put(string $key, string $sourcePath, string $contentType): void;

    public function delete(string $key): void;

    public function localPath(string $key): ?string;

    public function temporaryUrl(string $key, int $expiresInSeconds = 300): ?string;
}
