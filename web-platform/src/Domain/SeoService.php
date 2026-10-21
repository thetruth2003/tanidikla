<?php

declare(strict_types=1);

namespace App\Domain;

use App\Core\Database;

final class SeoService
{
    public function __construct(
        private readonly Database $database,
        private readonly LocationCatalog $locations,
    ) {}

    /** @return list<array<string, mixed>> */
    public function categories(): array
    {
        $rows = $this->database->fetchAll(
            "select category.id, category.label, category.parent_id, category.updated_at,
                    parent.label as parent_label
             from categories category
             left join categories parent on parent.id = category.parent_id
             where category.is_active = true
             order by category.sort_order, category.label"
        );

        return array_map(function (array $row): array {
            $row['seo_slug'] = self::slugify((string) $row['label']);
            return $row;
        }, $rows);
    }

    /** @return array<string, mixed>|null */
    public function categoryBySlug(string $slug): ?array
    {
        $normalized = self::slugify($slug);
        foreach ($this->categories() as $category) {
            if ($category['seo_slug'] === $normalized) {
                return $category;
            }
        }
        return null;
    }

    public function cityBySlug(string $slug): ?string
    {
        $normalized = self::slugify($slug);
        foreach (array_keys($this->locations->all()) as $city) {
            if (self::slugify($city) === $normalized) {
                return $city;
            }
        }
        return null;
    }

    /** @return list<array{city: string, city_slug: string, listing_count: int, updated_at: string}> */
    public function activeCitiesForCategory(string $categoryId): array
    {
        $rows = $this->database->fetchAll(
            "with recursive category_tree as (
               select id from categories where id = :category_id and is_active = true
               union all
               select child.id from categories child join category_tree parent on child.parent_id = parent.id
               where child.is_active = true
             )
             select listing.public_city as city, count(distinct listing.id)::int as listing_count,
                    max(listing.updated_at)::text as updated_at
             from listings listing
             join users owner on owner.id = listing.owner_id and owner.is_suspended = false
             join listing_items item on item.listing_id = listing.id
             where listing.status = 'active'
               and (listing.expires_at is null or listing.expires_at > now())
               and item.category_id in (select id from category_tree)
               and btrim(listing.public_city) <> ''
             group by listing.public_city
             order by listing_count desc, listing.public_city",
            ['category_id' => $categoryId],
        );

        $cities = [];
        foreach ($rows as $row) {
            $city = $this->cityBySlug((string) $row['city']);
            if ($city === null) continue;
            $cities[self::slugify($city)] = [
                'city' => $city,
                'city_slug' => self::slugify($city),
                'listing_count' => (int) $row['listing_count'],
                'updated_at' => (string) $row['updated_at'],
            ];
        }
        return array_values($cities);
    }

    /** @return list<array{category_slug: string, city_slug: string, updated_at: string}> */
    public function indexableLocationPages(): array
    {
        $categories = [];
        foreach ($this->categories() as $category) {
            $categories[(string) $category['id']] = (string) $category['seo_slug'];
        }

        $rows = $this->database->fetchAll(
            "with recursive category_paths as (
               select id as descendant_id, id as ancestor_id from categories where is_active = true
               union all
               select path.descendant_id, parent.parent_id
               from category_paths path
               join categories parent on parent.id = path.ancestor_id
               where parent.parent_id is not null
             )
             select path.ancestor_id as category_id, listing.public_city as city,
                    max(listing.updated_at)::text as updated_at
             from listings listing
             join users owner on owner.id = listing.owner_id and owner.is_suspended = false
             join listing_items item on item.listing_id = listing.id
             join category_paths path on path.descendant_id = item.category_id
             where listing.status = 'active'
               and (listing.expires_at is null or listing.expires_at > now())
               and btrim(listing.public_city) <> ''
             group by path.ancestor_id, listing.public_city"
        );

        $pages = [];
        foreach ($rows as $row) {
            $categorySlug = $categories[(string) $row['category_id']] ?? null;
            if ($categorySlug === null) continue;
            $city = $this->cityBySlug((string) $row['city']);
            if ($city === null) continue;
            $citySlug = self::slugify($city);
            $pages[$categorySlug . '/' . $citySlug] = [
                'category_slug' => $categorySlug,
                'city_slug' => $citySlug,
                'updated_at' => (string) $row['updated_at'],
            ];
        }
        return array_values($pages);
    }

    public static function slugify(string $value): string
    {
        $value = strtr(trim($value), [
            'Ç'=>'c', 'Ğ'=>'g', 'İ'=>'i', 'I'=>'i', 'Ö'=>'o', 'Ş'=>'s', 'Ü'=>'u',
            'ç'=>'c', 'ğ'=>'g', 'ı'=>'i', 'ö'=>'o', 'ş'=>'s', 'ü'=>'u',
        ]);
        $value = strtolower($value);
        $value = preg_replace('/[^a-z0-9]+/', '-', $value) ?? '';
        return trim($value, '-');
    }
}
