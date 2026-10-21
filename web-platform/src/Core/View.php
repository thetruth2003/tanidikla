<?php

declare(strict_types=1);

namespace App\Core;

use RuntimeException;

final class View
{
    /** @param array<string, mixed> $data */
    public static function render(string $template, array $data = []): string
    {
        $templatePath = APP_ROOT . '/templates/' . $template . '.php';
        if (!is_file($templatePath)) {
            throw new RuntimeException('Görünüm bulunamadı: ' . $template);
        }

        extract($data, EXTR_SKIP);
        ob_start();
        require $templatePath;
        return (string) ob_get_clean();
    }

    public static function escape(mixed $value): string
    {
        return htmlspecialchars((string) $value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
    }

    public static function priceLabel(mixed $amount, mixed $pricingUnit): string
    {
        $unit = (string) $pricingUnit;
        if ($unit === 'negotiable') return 'Teklif üzerine';
        if ($unit === 'free') return 'Ücretsiz';

        $suffix = match ($unit) {
            'hourly' => ' / saat',
            'daily' => ' / gün',
            'per_session' => ' / seans',
            'starting_at' => ' başlangıç',
            'fixed' => ' · sabit',
            default => '',
        };

        return number_format((float) $amount, 0, ',', '.') . ' ₺' . $suffix;
    }
}
