<?php

declare(strict_types=1);

namespace App\Domain;

use App\Core\HttpException;

final class LocationCatalog
{
    /** @var array<string, list<string>>|null */
    private ?array $locations = null;

    /** @return array<string, list<string>> */
    public function all(): array
    {
        if ($this->locations !== null) {
            return $this->locations;
        }

        $path = APP_ROOT . '/database/data/turkey_locations.json';
        $contents = is_file($path) ? file_get_contents($path) : false;
        $decoded = is_string($contents) ? json_decode($contents, true) : null;
        if (!is_array($decoded)) {
            throw new HttpException(500, 'Türkiye il ve ilçe listesi yüklenemedi.', 'location_catalog_unavailable');
        }

        $locations = [];
        foreach ($decoded as $city => $districts) {
            if (!is_string($city) || !is_array($districts)) {
                continue;
            }
            $locations[$city] = array_values(array_filter(
                $districts,
                static fn (mixed $district): bool => is_string($district) && $district !== '',
            ));
        }
        $this->locations = $locations;
        return $this->locations;
    }

    public function contains(string $city, string $district): bool
    {
        return isset($this->all()[$city]) && in_array($district, $this->all()[$city], true);
    }
}
