<?php

declare(strict_types=1);

namespace App\Domain;

use App\Core\Database;
use App\Core\HttpException;
use App\Support\Uuid;

final class SavedSearchService
{
    private const ALLOWED_FILTERS = [
        'type', 'q', 'categories', 'lat', 'lng', 'radius_meters', 'available_now',
        'open_24_7', 'verified_only', 'gender', 'provider_kind', 'pricing_unit',
        'min_price', 'max_price', 'min_rating', 'sort',
    ];

    public function __construct(private readonly Database $database)
    {
    }

    /** @return list<array<string, mixed>> */
    public function all(string $userId): array
    {
        $rows = $this->database->fetchAll(
            'select id, name, filters, notification_enabled, created_at, updated_at
             from saved_searches where user_id = :user_id order by updated_at desc',
            ['user_id' => $userId],
        );
        foreach ($rows as &$row) {
            $row['filters'] = is_string($row['filters'])
                ? (json_decode($row['filters'], true) ?: [])
                : $row['filters'];
            $row['notification_enabled'] = (bool) $row['notification_enabled'];
        }
        return $rows;
    }

    /** @param array<string, mixed> $payload
     *  @return array<string, mixed>
     */
    public function create(string $userId, array $payload): array
    {
        $name = trim((string) ($payload['name'] ?? ''));
        if (mb_strlen($name) < 2 || mb_strlen($name) > 80) {
            throw new HttpException(422, 'Kayıtlı arama adı 2–80 karakter olmalı.', 'validation_failed');
        }
        $filters = $this->normalizeFilters($payload['filters'] ?? null);
        if ($filters === []) {
            throw new HttpException(422, 'Kaydetmek için en az bir arama ölçütü seçmelisin.', 'validation_failed');
        }
        $id = Uuid::v4();
        $this->database->statement(
            'insert into saved_searches (id, user_id, name, filters, notification_enabled)
             values (:id, :user_id, :name, cast(:filters as jsonb), :notification_enabled)',
            [
                'id' => $id,
                'user_id' => $userId,
                'name' => $name,
                'filters' => json_encode($filters, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
                'notification_enabled' => filter_var($payload['notification_enabled'] ?? false, FILTER_VALIDATE_BOOL) ? 'true' : 'false',
            ],
        );
        return array_values(array_filter($this->all($userId), static fn (array $row): bool => $row['id'] === $id))[0];
    }

    public function remove(string $userId, string $id): void
    {
        if (!Uuid::isValid($id)) {
            throw new HttpException(404, 'Kayıtlı arama bulunamadı.', 'saved_search_not_found');
        }
        $removed = $this->database->statement(
            'delete from saved_searches where id = :id and user_id = :user_id',
            ['id' => $id, 'user_id' => $userId],
        )->rowCount();
        if ($removed === 0) {
            throw new HttpException(404, 'Kayıtlı arama bulunamadı.', 'saved_search_not_found');
        }
    }

    /** @return array<string, mixed> */
    private function normalizeFilters(mixed $value): array
    {
        if (!is_array($value)) {
            throw new HttpException(422, 'Arama filtreleri geçersiz.', 'validation_failed');
        }
        $filters = [];
        foreach (self::ALLOWED_FILTERS as $key) {
            if (!array_key_exists($key, $value)) {
                continue;
            }
            $filterValue = $value[$key];
            if ($key === 'categories') {
                if (!is_array($filterValue) || count($filterValue) > 30) {
                    throw new HttpException(422, 'Kategori filtreleri geçersiz.', 'validation_failed');
                }
                $categories = array_values(array_unique(array_filter(
                    array_map(static fn (mixed $item): string => trim((string) $item), $filterValue),
                )));
                if ($categories !== []) {
                    $filters[$key] = $categories;
                }
                continue;
            }
            if (is_bool($filterValue) || is_numeric($filterValue)) {
                $filters[$key] = $filterValue;
                continue;
            }
            $text = mb_substr(trim((string) $filterValue), 0, 160);
            if ($text !== '') {
                $filters[$key] = $text;
            }
        }
        return $filters;
    }
}
