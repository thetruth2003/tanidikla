<?php

declare(strict_types=1);

namespace App\Core;

final class Request
{
    /** @param array<string, string> $routeParameters */
    private function __construct(
        public readonly string $method,
        public readonly string $path,
        public readonly array $query,
        public readonly array $body,
        public readonly array $headers,
        public readonly array $cookies,
        public readonly array $files,
        public readonly array $routeParameters = [],
    ) {
    }

    public static function capture(): self
    {
        $method = strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');
        $path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
        $contentLength = (int) ($_SERVER['CONTENT_LENGTH'] ?? 0);
        $rawContentType = strtolower((string) ($_SERVER['CONTENT_TYPE'] ?? ''));
        $maximumBytes = str_contains($rawContentType, 'multipart/form-data')
            ? (max(1, Config::int('UPLOAD_MAX_MB', 8)) * 1024 * 1024) + 262_144
            : Config::int('REQUEST_MAX_BYTES', 1_048_576);
        if ($contentLength > $maximumBytes) {
            throw new HttpException(413, 'İstek gövdesi izin verilen boyutu aşıyor.', 'request_too_large');
        }
        $headers = [];
        foreach ($_SERVER as $key => $value) {
            if (str_starts_with($key, 'HTTP_')) {
                $name = strtolower(str_replace('_', '-', substr($key, 5)));
                $headers[$name] = (string) $value;
            }
        }
        if (isset($_SERVER['CONTENT_TYPE'])) {
            $headers['content-type'] = (string) $_SERVER['CONTENT_TYPE'];
        }
        if (isset($_SERVER['HTTP_AUTHORIZATION'])) {
            $headers['authorization'] = (string) $_SERVER['HTTP_AUTHORIZATION'];
        }

        $body = $_POST;
        $contentType = strtolower($headers['content-type'] ?? '');
        if (str_contains($contentType, 'application/json')) {
            $raw = file_get_contents('php://input') ?: '';
            $decoded = json_decode($raw, true);
            if ($raw !== '' && !is_array($decoded)) {
                throw new HttpException(400, 'Geçersiz JSON gövdesi.', 'invalid_json');
            }
            $body = $decoded ?? [];
        }

        return new self($method, rtrim($path, '/') ?: '/', $_GET, $body, $headers, $_COOKIE, $_FILES);
    }

    /** @param array<string, string> $parameters */
    public function withRouteParameters(array $parameters): self
    {
        return new self(
            $this->method,
            $this->path,
            $this->query,
            $this->body,
            $this->headers,
            $this->cookies,
            $this->files,
            $parameters,
        );
    }

    public function header(string $name): ?string
    {
        return $this->headers[strtolower($name)] ?? null;
    }

    public function bearerToken(): ?string
    {
        $authorization = $this->header('authorization');
        if ($authorization === null || !preg_match('/^Bearer\s+(.+)$/i', $authorization, $matches)) {
            return null;
        }
        return trim($matches[1]);
    }

    public function clientIp(): string
    {
        $remote = (string) ($_SERVER['REMOTE_ADDR'] ?? '0.0.0.0');
        $trusted = array_filter(array_map('trim', explode(',', Config::string('TRUSTED_PROXY_IPS'))));
        if (!in_array($remote, $trusted, true)) {
            return filter_var($remote, FILTER_VALIDATE_IP) ? $remote : '0.0.0.0';
        }

        $candidate = trim((string) ($this->header('cf-connecting-ip') ?? ''));
        if ($candidate === '') {
            $candidate = trim(explode(',', (string) ($this->header('x-forwarded-for') ?? ''))[0]);
        }
        return filter_var($candidate, FILTER_VALIDATE_IP) ? $candidate : $remote;
    }

    public function route(string $key): ?string
    {
        return $this->routeParameters[$key] ?? null;
    }

    public function input(string $key, mixed $default = null): mixed
    {
        return $this->body[$key] ?? $default;
    }
}
