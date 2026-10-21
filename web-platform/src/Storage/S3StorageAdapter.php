<?php

declare(strict_types=1);

namespace App\Storage;

use App\Core\Config;
use RuntimeException;

final class S3StorageAdapter implements StorageAdapter
{
    private readonly string $endpoint;
    private readonly string $bucket;
    private readonly string $region;
    private readonly string $accessKey;
    private readonly string $secretKey;
    private readonly bool $pathStyle;

    public function __construct()
    {
        $this->endpoint = rtrim(Config::string('STORAGE_S3_ENDPOINT'), '/');
        $this->bucket = Config::string('STORAGE_S3_BUCKET');
        $this->region = Config::string('STORAGE_S3_REGION', 'eu-central-1');
        $this->accessKey = Config::string('STORAGE_S3_ACCESS_KEY');
        $this->secretKey = Config::string('STORAGE_S3_SECRET_KEY');
        $this->pathStyle = Config::bool('STORAGE_S3_PATH_STYLE', true);
        if ($this->endpoint === '' || $this->bucket === '' || $this->accessKey === '' || $this->secretKey === '') {
            throw new RuntimeException('S3 depolama ayarları eksik.');
        }
    }

    public function driver(): string
    {
        return 's3';
    }

    public function put(string $key, string $sourcePath, string $contentType): void
    {
        $payloadHash = hash_file('sha256', $sourcePath);
        if ($payloadHash === false) {
            throw new RuntimeException('Yüklenecek dosya okunamadı.');
        }
        $handle = fopen($sourcePath, 'rb');
        if ($handle === false) {
            throw new RuntimeException('Yüklenecek dosya açılamadı.');
        }
        try {
            $this->request('PUT', $key, $payloadHash, $contentType, $handle, filesize($sourcePath) ?: 0);
        } finally {
            fclose($handle);
        }
    }

    public function delete(string $key): void
    {
        $this->request('DELETE', $key, hash('sha256', ''), 'application/octet-stream');
    }

    public function localPath(string $key): ?string
    {
        return null;
    }

    public function temporaryUrl(string $key, int $expiresInSeconds = 300): ?string
    {
        $expires = max(60, min(3600, $expiresInSeconds));
        $now = new \DateTimeImmutable('now', new \DateTimeZone('UTC'));
        $date = $now->format('Ymd');
        $amzDate = $now->format('Ymd\\THis\\Z');
        [$url, $host, $uri] = $this->objectLocation($key);
        $credentialScope = $date . '/' . $this->region . '/s3/aws4_request';
        $query = [
            'X-Amz-Algorithm' => 'AWS4-HMAC-SHA256',
            'X-Amz-Credential' => $this->accessKey . '/' . $credentialScope,
            'X-Amz-Date' => $amzDate,
            'X-Amz-Expires' => (string) $expires,
            'X-Amz-SignedHeaders' => 'host',
        ];
        ksort($query);
        $canonicalQuery = http_build_query($query, '', '&', PHP_QUERY_RFC3986);
        $canonicalRequest = "GET\n{$uri}\n{$canonicalQuery}\nhost:{$host}\n\nhost\nUNSIGNED-PAYLOAD";
        $stringToSign = "AWS4-HMAC-SHA256\n{$amzDate}\n{$credentialScope}\n" . hash('sha256', $canonicalRequest);
        $query['X-Amz-Signature'] = hash_hmac('sha256', $stringToSign, $this->signingKey($date));
        ksort($query);
        return $url . '?' . http_build_query($query, '', '&', PHP_QUERY_RFC3986);
    }

    /** @param resource|null $body */
    private function request(
        string $method,
        string $key,
        string $payloadHash,
        string $contentType,
        mixed $body = null,
        int $size = 0,
    ): void {
        if (!function_exists('curl_init')) {
            throw new RuntimeException('S3 için PHP cURL eklentisi gerekli.');
        }
        $now = new \DateTimeImmutable('now', new \DateTimeZone('UTC'));
        $date = $now->format('Ymd');
        $amzDate = $now->format('Ymd\\THis\\Z');
        [$url, $host, $uri] = $this->objectLocation($key);
        $canonicalHeaders = "content-type:{$contentType}\nhost:{$host}\nx-amz-content-sha256:{$payloadHash}\nx-amz-date:{$amzDate}\n";
        $signedHeaders = 'content-type;host;x-amz-content-sha256;x-amz-date';
        $canonicalRequest = "{$method}\n{$uri}\n\n{$canonicalHeaders}\n{$signedHeaders}\n{$payloadHash}";
        $scope = $date . '/' . $this->region . '/s3/aws4_request';
        $stringToSign = "AWS4-HMAC-SHA256\n{$amzDate}\n{$scope}\n" . hash('sha256', $canonicalRequest);
        $signature = hash_hmac('sha256', $stringToSign, $this->signingKey($date));
        $headers = [
            'Content-Type: ' . $contentType,
            'Host: ' . $host,
            'x-amz-content-sha256: ' . $payloadHash,
            'x-amz-date: ' . $amzDate,
            'Authorization: AWS4-HMAC-SHA256 Credential=' . $this->accessKey . '/' . $scope
                . ', SignedHeaders=' . $signedHeaders . ', Signature=' . $signature,
        ];
        $curl = curl_init($url);
        curl_setopt_array($curl, [
            CURLOPT_CUSTOMREQUEST => $method,
            CURLOPT_HTTPHEADER => $headers,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => 30,
            CURLOPT_CONNECTTIMEOUT => 5,
            CURLOPT_FOLLOWLOCATION => false,
        ]);
        if (is_resource($body)) {
            curl_setopt($curl, CURLOPT_UPLOAD, true);
            curl_setopt($curl, CURLOPT_INFILE, $body);
            curl_setopt($curl, CURLOPT_INFILESIZE, $size);
        }
        $response = curl_exec($curl);
        $status = (int) curl_getinfo($curl, CURLINFO_RESPONSE_CODE);
        $error = curl_error($curl);
        curl_close($curl);
        if ($response === false || $status < 200 || $status >= 300) {
            throw new RuntimeException('S3 depolama isteği başarısız: ' . ($error !== '' ? $error : 'HTTP ' . $status));
        }
    }

    /** @return array{0: string, 1: string, 2: string} */
    private function objectLocation(string $key): array
    {
        $encodedKey = implode('/', array_map('rawurlencode', explode('/', ltrim($key, '/'))));
        $parts = parse_url($this->endpoint);
        if (!is_array($parts) || !isset($parts['scheme'], $parts['host'])) {
            throw new RuntimeException('S3 endpoint adresi geçersiz.');
        }
        $port = isset($parts['port']) ? ':' . $parts['port'] : '';
        $basePath = rtrim((string) ($parts['path'] ?? ''), '/');
        if ($this->pathStyle) {
            $host = $parts['host'] . $port;
            $uri = $basePath . '/' . rawurlencode($this->bucket) . '/' . $encodedKey;
        } else {
            $host = $this->bucket . '.' . $parts['host'] . $port;
            $uri = $basePath . '/' . $encodedKey;
        }
        return [$parts['scheme'] . '://' . $host . $uri, $host, $uri];
    }

    private function signingKey(string $date): string
    {
        $dateKey = hash_hmac('sha256', $date, 'AWS4' . $this->secretKey, true);
        $regionKey = hash_hmac('sha256', $this->region, $dateKey, true);
        $serviceKey = hash_hmac('sha256', 's3', $regionKey, true);
        return hash_hmac('sha256', 'aws4_request', $serviceKey, true);
    }
}
