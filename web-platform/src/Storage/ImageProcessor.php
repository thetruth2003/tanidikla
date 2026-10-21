<?php

declare(strict_types=1);

namespace App\Storage;

use App\Core\Config;
use App\Core\HttpException;

final class ImageProcessor
{
    /** @return array{path: string, mime_type: string, byte_size: int, width: int, height: int, sha256: string} */
    public function process(string $sourcePath): array
    {
        if (!function_exists('imagecreatefromstring') || !function_exists('imagewebp')) {
            throw new HttpException(503, 'Görsel işleme bileşeni hazır değil.', 'image_processing_unavailable');
        }
        $finfo = new \finfo(FILEINFO_MIME_TYPE);
        $mime = (string) $finfo->file($sourcePath);
        if (!in_array($mime, ['image/jpeg', 'image/png', 'image/webp'], true)) {
            throw new HttpException(422, 'Yalnızca JPEG, PNG veya WebP görsel yükleyebilirsin.', 'invalid_image_type');
        }
        $size = @getimagesize($sourcePath);
        if (!is_array($size) || $size[0] < 1 || $size[1] < 1 || ($size[0] * $size[1]) > 25_000_000) {
            throw new HttpException(422, 'Görsel bozuk veya çözünürlüğü çok yüksek.', 'invalid_image_dimensions');
        }
        $bytes = file_get_contents($sourcePath);
        if ($bytes === false) {
            throw new HttpException(422, 'Görsel okunamadı.', 'invalid_image');
        }
        $source = @imagecreatefromstring($bytes);
        unset($bytes);
        if ($source === false) {
            throw new HttpException(422, 'Görsel çözümlenemedi.', 'invalid_image');
        }
        if ($mime === 'image/jpeg' && function_exists('exif_read_data')) {
            $orientation = (int) ((@exif_read_data($sourcePath)['Orientation'] ?? 1));
            $rotated = match ($orientation) {
                3 => imagerotate($source, 180, 0),
                6 => imagerotate($source, -90, 0),
                8 => imagerotate($source, 90, 0),
                default => false,
            };
            if ($rotated !== false) {
                $source = $rotated;
            }
        }
        $width = imagesx($source);
        $height = imagesy($source);
        $maxDimension = max(640, min(4096, Config::int('UPLOAD_IMAGE_MAX_DIMENSION', 2400)));
        $scale = min(1.0, $maxDimension / max($width, $height));
        $targetWidth = max(1, (int) round($width * $scale));
        $targetHeight = max(1, (int) round($height * $scale));
        $target = imagecreatetruecolor($targetWidth, $targetHeight);
        if ($target === false) {
            throw new HttpException(500, 'Görsel işlenemedi.', 'image_processing_failed');
        }
        imagealphablending($target, false);
        imagesavealpha($target, true);
        $transparent = imagecolorallocatealpha($target, 0, 0, 0, 127);
        imagefilledrectangle($target, 0, 0, $targetWidth, $targetHeight, $transparent);
        imagecopyresampled($target, $source, 0, 0, 0, 0, $targetWidth, $targetHeight, $width, $height);

        $cache = APP_ROOT . '/storage/cache';
        if (!is_dir($cache) && !mkdir($cache, 0750, true) && !is_dir($cache)) {
            throw new HttpException(500, 'Görsel çalışma klasörü oluşturulamadı.', 'image_processing_failed');
        }
        $output = tempnam($cache, 'image-');
        if ($output === false || !imagewebp($target, $output, 82)) {
            throw new HttpException(500, 'Görsel WebP biçimine dönüştürülemedi.', 'image_processing_failed');
        }
        $byteSize = filesize($output);
        $sha256 = hash_file('sha256', $output);
        if ($byteSize === false || $byteSize < 1 || $sha256 === false) {
            @unlink($output);
            throw new HttpException(500, 'İşlenen görsel doğrulanamadı.', 'image_processing_failed');
        }
        return [
            'path' => $output,
            'mime_type' => 'image/webp',
            'byte_size' => $byteSize,
            'width' => $targetWidth,
            'height' => $targetHeight,
            'sha256' => $sha256,
        ];
    }
}
