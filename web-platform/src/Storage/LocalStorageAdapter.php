<?php

declare(strict_types=1);

namespace App\Storage;

use App\Core\Config;
use RuntimeException;

final class LocalStorageAdapter implements StorageAdapter
{
    private readonly string $root;

    public function __construct()
    {
        $configured = Config::string('UPLOAD_PATH', 'storage/uploads');
        $this->root = str_starts_with($configured, '/') || preg_match('/^[A-Za-z]:[\\\\\/]/', $configured)
            ? rtrim($configured, '/\\')
            : APP_ROOT . '/' . trim($configured, '/\\');
    }

    public function driver(): string
    {
        return 'local';
    }

    public function put(string $key, string $sourcePath, string $contentType): void
    {
        $target = $this->path($key);
        $directory = dirname($target);
        if (!is_dir($directory) && !mkdir($directory, 0750, true) && !is_dir($directory)) {
            throw new RuntimeException('Yükleme klasörü oluşturulamadı.');
        }
        $source = fopen($sourcePath, 'rb');
        $destination = fopen($target, 'xb');
        if ($source === false || $destination === false) {
            if (is_resource($source)) {
                fclose($source);
            }
            throw new RuntimeException('Dosya güvenli depolamaya yazılamadı.');
        }
        try {
            if (stream_copy_to_stream($source, $destination) === false) {
                throw new RuntimeException('Dosya güvenli depolamaya kopyalanamadı.');
            }
        } finally {
            fclose($source);
            fclose($destination);
        }
        @chmod($target, 0640);
    }

    public function delete(string $key): void
    {
        $path = $this->path($key);
        if (is_file($path)) {
            @unlink($path);
        }
    }

    public function localPath(string $key): ?string
    {
        $path = $this->path($key);
        return is_file($path) ? $path : null;
    }

    public function temporaryUrl(string $key, int $expiresInSeconds = 300): ?string
    {
        return null;
    }

    private function path(string $key): string
    {
        if ($key === '' || str_contains($key, '..') || str_contains($key, '\\')
            || !preg_match('#^[A-Za-z0-9][A-Za-z0-9._/-]*$#', $key)) {
            throw new RuntimeException('Geçersiz depolama anahtarı.');
        }
        return $this->root . '/' . $key;
    }
}
