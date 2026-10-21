<?php

declare(strict_types=1);

namespace App\Core;

use App\Security\SecurityHeaders;

final class Response
{
    /** @param array<string, mixed> $data */
    public static function json(array $data, int $status = 200): never
    {
        http_response_code($status);
        SecurityHeaders::apply();
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR);
        Logger::requestCompleted($status);
        exit;
    }

    /** @param array<string, mixed> $data */
    public static function success(array $data = [], int $status = 200): never
    {
        self::json([
            'success' => true,
            'data' => $data,
            'error' => null,
            'meta' => ['request_id' => RequestContext::requestId()],
        ], $status);
    }

    /** @param array<string, mixed> $details */
    public static function error(string $message, string $code, int $status, array $details = []): never
    {
        self::json([
            'success' => false,
            'error' => [
                'code' => $code,
                'message' => $message,
                'details' => $details,
            ],
            'meta' => ['request_id' => RequestContext::requestId()],
        ], $status);
    }

    public static function html(string $html, int $status = 200): never
    {
        http_response_code($status);
        SecurityHeaders::apply();
        header('Content-Type: text/html; charset=utf-8');
        echo $html;
        Logger::requestCompleted($status);
        exit;
    }

    public static function text(string $content, string $contentType = 'text/plain; charset=utf-8', int $status = 200): never
    {
        http_response_code($status);
        SecurityHeaders::apply();
        header('Content-Type: ' . $contentType);
        echo $content;
        Logger::requestCompleted($status);
        exit;
    }

    public static function redirect(string $location, int $status = 302): never
    {
        http_response_code($status);
        SecurityHeaders::apply();
        header('Location: ' . $location);
        Logger::requestCompleted($status);
        exit;
    }

    public static function file(
        string $path,
        string $contentType,
        int $byteSize,
        string $etag,
        string $cacheControl = 'public, max-age=31536000, immutable',
    ): never
    {
        if (!is_file($path) || !is_readable($path)) {
            throw new HttpException(404, 'Dosya bulunamadı.', 'media_not_found');
        }
        $quotedEtag = '"' . $etag . '"';
        $notModified = trim((string) ($_SERVER['HTTP_IF_NONE_MATCH'] ?? '')) === $quotedEtag;
        http_response_code($notModified ? 304 : 200);
        SecurityHeaders::apply();
        header('Content-Type: ' . $contentType);
        header('Cache-Control: ' . $cacheControl);
        header('ETag: ' . $quotedEtag);
        header('X-Content-Type-Options: nosniff');
        if (!$notModified) {
            header('Content-Length: ' . $byteSize);
            readfile($path);
        }
        Logger::requestCompleted($notModified ? 304 : 200);
        exit;
    }
}
