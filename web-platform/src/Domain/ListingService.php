<?php

declare(strict_types=1);

namespace App\Domain;

use App\Core\Database;
use App\Core\HttpException;
use App\Security\ContentPolicy;
use App\Support\Uuid;
use PDO;

final class ListingService
{
    private ?bool $postgisAvailable = null;

    public function __construct(private readonly Database $database)
    {
    }

    /** @return list<array<string, mixed>> */
    public function categories(): array
    {
        $categories = $this->database->fetchAll(
            'select id, label, parent_id, sort_order, is_open_ended, is_selectable
             from categories where is_active = true order by sort_order'
        );
        return array_map(function (array $category): array {
            $category['seo_slug'] = $this->slugify((string) $category['label']);
            return $category;
        }, $categories);
    }

    /** @return list<array<string, mixed>> */
    public function suggestions(string $term, int $limit = 8): array
    {
        $term = mb_substr(trim($term), 0, 80);
        if (mb_strlen($term) < 2) return [];
        $limit = max(1, min(12, $limit));

        return $this->database->fetchAll(
            "select 'category'::text as kind,c.id as value,c.label,
                    coalesce(parent.label,'Kategori') as subtitle,null::text as slug,c.id as category_id,
                    round(greatest(
                      similarity(unaccent(lower(c.label)),unaccent(lower(:category_similarity))),
                      word_similarity(unaccent(lower(:category_word)),unaccent(lower(c.label))),
                      case when unaccent(lower(c.label))=unaccent(lower(:category_exact)) then 1 else 0 end,
                      case when unaccent(lower(c.label)) like unaccent(lower(:category_prefix))||'%' then 0.99 else 0 end,
                      case when unaccent(lower(c.label)) like '%'||unaccent(lower(:category_contains))||'%' then 0.98 else 0 end
                    )::numeric,3) as score
             from categories c left join categories parent on parent.id=c.parent_id
             where c.is_active and c.is_selectable
               and greatest(
                 similarity(unaccent(lower(c.label)),unaccent(lower(:category_similarity_filter))),
                 word_similarity(unaccent(lower(:category_word_filter)),unaccent(lower(c.label))),
                 case when unaccent(lower(c.label)) like '%'||unaccent(lower(:category_contains_filter))||'%' then 0.98 else 0 end
               )>=:minimum_score
             order by score desc,c.sort_order,c.label
             limit :limit",
            [
                'category_similarity'=>$term,
                'category_word'=>$term,
                'category_exact'=>$term,
                'category_prefix'=>$term,
                'category_contains'=>$term,
                'category_similarity_filter'=>$term,
                'category_word_filter'=>$term,
                'category_contains_filter'=>$term,
                'minimum_score'=>mb_strlen($term) < 4 ? 0.34 : 0.30,
                'limit'=>$limit,
            ],
        );
    }

    /** @param array<string, mixed> $query
     *  @param array{viewer_id?: string, owner_id?: string, favorite_user_id?: string, include_inactive?: bool, skip_count?: bool, group_nearby?: bool} $scope
     *  @return array{items: list<array<string, mixed>>, pagination: array<string, int|bool>}
     */
    public function search(array $query, array $scope = []): array
    {
        $limit = max(1, min(50, (int) ($query['limit'] ?? 24)));
        $page = max(1, (int) ($query['page'] ?? 1));
        $offset = ($page - 1) * $limit;
        $skipCount = ($scope['skip_count'] ?? false) === true;
        $parameters = ['limit' => $limit + ($skipCount ? 1 : 0), 'offset' => $offset];
        $conditions = [];

        if (($scope['include_inactive'] ?? false) === true) {
            $conditions[] = "l.status <> 'removed'";
        } else {
            $conditions[] = "l.status = 'active'";
            $conditions[] = '(l.expires_at is null or l.expires_at > now())';
        }

        $ownerId = (string) ($scope['owner_id'] ?? '');
        if (Uuid::isValid($ownerId)) {
            $conditions[] = 'l.owner_id = :scope_owner_id';
            $parameters['scope_owner_id'] = $ownerId;
        }

        $favoriteUserId = (string) ($scope['favorite_user_id'] ?? '');
        if (Uuid::isValid($favoriteUserId)) {
            $conditions[] = 'exists (select 1 from favorites f where f.listing_id = l.id and f.user_id = :favorite_user_id)';
            $parameters['favorite_user_id'] = $favoriteUserId;
        }

        $viewerId = (string) ($scope['viewer_id'] ?? '');
        if (Uuid::isValid($viewerId)) {
            $conditions[] = 'not exists (
                select 1 from user_blocks b
                where (b.blocker_id = :viewer_blocker and b.blocked_user_id = l.owner_id)
                   or (b.blocker_id = l.owner_id and b.blocked_user_id = :viewer_blocked)
            )';
            $parameters['viewer_blocker'] = $viewerId;
            $parameters['viewer_blocked'] = $viewerId;
        }

        $type = (string) ($query['type'] ?? '');
        if (in_array($type, ['service_offer', 'service_request'], true)) {
            $conditions[] = 'l.listing_type = :listing_type';
            $parameters['listing_type'] = $type;
        }
        $categoryValues = $query['categories'] ?? [];
        if (is_string($categoryValues)) {
            $categoryValues = explode(',', $categoryValues);
        }
        if (!is_array($categoryValues)) {
            $categoryValues = [];
        }
        $legacyCategory = trim((string) ($query['category'] ?? ''));
        if ($legacyCategory !== '') {
            $categoryValues[] = $legacyCategory;
        }
        $categoryValues = array_slice(array_values(array_unique(array_filter(array_map(
            static fn (mixed $value): string => trim((string) $value),
            $categoryValues,
        )))), 0, 30);
        if ($categoryValues !== []) {
            $categoryConditions = [];
            foreach ($categoryValues as $index => $category) {
                $key = 'category_id_' . $index;
                $categoryConditions[] = "exists (
                    select 1 from listing_items ci
                    where ci.listing_id = l.id and ci.is_active and ci.deleted_at is null
                      and ci.category_id in (
                        with recursive category_tree as (
                            select id from categories where id = :{$key}
                            union all
                            select c.id from categories c join category_tree ct on c.parent_id = ct.id
                        )
                        select id from category_tree
                    )
                )";
                $parameters[$key] = $category;
            }
            $conditions[] = '(' . implode(' or ', $categoryConditions) . ')';
        }
        $term = trim((string) ($query['q'] ?? ''));
        $displayItemOrder = 'li.page_index';
        if ($term !== '') {
            $termCondition = '(
                exists (
                    select 1 from listing_items si
                    where si.listing_id = l.id and si.is_active and si.deleted_at is null
                      and unaccent(lower(si.title || \' \' || si.description)) like unaccent(lower(:term))
                )
                or unaccent(lower(p.display_name)) like unaccent(lower(:term))
            ';
            $parameters['term'] = '%' . $term . '%';
            if (mb_strlen($term) >= 3) {
                $termCondition .= ' or exists (
                    select 1 from listing_items fi
                    where fi.listing_id=l.id and fi.is_active and fi.deleted_at is null
                      and word_similarity(unaccent(lower(:fuzzy_term)),unaccent(lower(fi.title||\' \'||fi.description))) >= 0.32
                )';
                $parameters['fuzzy_term'] = mb_substr($term, 0, 80);
            }
            $parameters['display_item_similarity'] = mb_substr($term, 0, 80);
            $parameters['display_item_word'] = mb_substr($term, 0, 80);
            $displayItemOrder = "greatest(
                similarity(unaccent(lower(li.title)),unaccent(lower(:display_item_similarity))),
                word_similarity(unaccent(lower(:display_item_word)),unaccent(lower(li.title||' '||li.description)))
              ) desc, li.page_index";
            $conditions[] = $termCondition . ')';
        }

        $city = trim((string) ($query['city'] ?? ''));
        if ($city !== '') {
            $conditions[] = 'unaccent(lower(l.public_city)) = unaccent(lower(:city))';
            $parameters['city'] = $city;
        }
        $district = trim((string) ($query['district'] ?? ''));
        if ($district !== '') {
            $conditions[] = 'unaccent(lower(l.public_district)) = unaccent(lower(:district))';
            $parameters['district'] = $district;
        }
        $precision = (string) ($query['location_precision'] ?? '');
        if (in_array($precision, ['exact', 'neighborhood'], true)) {
            $conditions[] = 'l.location_precision = :location_precision';
            $parameters['location_precision'] = $precision;
        }
        if (filter_var($query['available_now'] ?? $query['urgent'] ?? false, FILTER_VALIDATE_BOOL)) {
            $conditions[] = 'exists (select 1 from listing_items ui where ui.listing_id = l.id and ui.is_active and ui.deleted_at is null and ui.urgent = true)';
        }
        if (filter_var($query['open_24_7'] ?? false, FILTER_VALIDATE_BOOL)) {
            $conditions[] = 'exists (select 1 from listing_items oi where oi.listing_id = l.id and oi.is_active and oi.deleted_at is null and oi.open_24_7 = true)';
        }
        if (filter_var($query['verified_only'] ?? false, FILTER_VALIDATE_BOOL)) {
            $conditions[] = 'p.phone_verified_at is not null';
            $conditions[] = 'owner.email_verified_at is not null';
        }
        $gender = (string) ($query['gender'] ?? '');
        if (in_array($gender, ['female', 'male', 'other'], true)) {
            $conditions[] = 'p.gender = :provider_gender';
            $parameters['provider_gender'] = $gender;
        }
        $providerKind = (string) ($query['provider_kind'] ?? '');
        if (in_array($providerKind, ['person', 'business'], true)) {
            $conditions[] = 'p.profile_type = :provider_kind';
            $parameters['provider_kind'] = $providerKind;
        }
        if (filter_var($query['vat_included'] ?? false, FILTER_VALIDATE_BOOL)) {
            $conditions[] = 'exists (select 1 from listing_items vi where vi.listing_id = l.id and vi.is_active and vi.deleted_at is null and vi.price_includes_vat = true)';
        }
        if (filter_var($query['has_schedule'] ?? false, FILTER_VALIDATE_BOOL)) {
            $conditions[] = "exists (select 1 from listing_items hi where hi.listing_id = l.id and hi.is_active and hi.deleted_at is null and btrim(hi.schedule_label) <> '')";
        }
        $pricingUnit = (string) ($query['pricing_unit'] ?? '');
        if (in_array($pricingUnit, ['fixed', 'hourly', 'daily', 'per_session', 'starting_at', 'negotiable', 'free'], true)) {
            $conditions[] = 'exists (select 1 from listing_items pi where pi.listing_id = l.id and pi.is_active and pi.deleted_at is null and pi.pricing_unit = :pricing_unit)';
            $parameters['pricing_unit'] = $pricingUnit;
        }
        $minPrice = filter_var($query['min_price'] ?? null, FILTER_VALIDATE_FLOAT, FILTER_NULL_ON_FAILURE);
        if ($minPrice !== null && $minPrice >= 0) {
            $conditions[] = 'exists (select 1 from listing_items mi where mi.listing_id = l.id and mi.is_active and mi.deleted_at is null and mi.price_amount >= :min_price)';
            $parameters['min_price'] = $minPrice;
        }
        $maxPrice = filter_var($query['max_price'] ?? null, FILTER_VALIDATE_FLOAT, FILTER_NULL_ON_FAILURE);
        if ($maxPrice !== null && $maxPrice >= 0) {
            $conditions[] = 'exists (select 1 from listing_items ma where ma.listing_id = l.id and ma.is_active and ma.deleted_at is null and ma.price_amount <= :max_price)';
            $parameters['max_price'] = $maxPrice;
        }
        $minRating = filter_var($query['min_rating'] ?? null, FILTER_VALIDATE_FLOAT, FILTER_NULL_ON_FAILURE);
        if ($minRating !== null && $minRating >= 1 && $minRating <= 5) {
            $conditions[] = 'coalesce(review_stats.rating, 0) >= :min_rating';
            $parameters['min_rating'] = $minRating;
        }

        $minLat = filter_var($query['min_lat'] ?? null, FILTER_VALIDATE_FLOAT, FILTER_NULL_ON_FAILURE);
        $maxLat = filter_var($query['max_lat'] ?? null, FILTER_VALIDATE_FLOAT, FILTER_NULL_ON_FAILURE);
        $minLng = filter_var($query['min_lng'] ?? null, FILTER_VALIDATE_FLOAT, FILTER_NULL_ON_FAILURE);
        $maxLng = filter_var($query['max_lng'] ?? null, FILTER_VALIDATE_FLOAT, FILTER_NULL_ON_FAILURE);
        $hasBounds = $minLat !== null && $maxLat !== null && $minLng !== null && $maxLng !== null
            && $minLat >= -90 && $maxLat <= 90 && $minLng >= -180 && $maxLng <= 180
            && $minLat < $maxLat && $minLng < $maxLng;
        if ($hasBounds) {
            $parameters['min_lat'] = $minLat;
            $parameters['max_lat'] = $maxLat;
            $parameters['min_lng'] = $minLng;
            $parameters['max_lng'] = $maxLng;
            $conditions[] = $this->supportsPostgis()
                ? 'l.public_location && ST_MakeEnvelope(:min_lng, :min_lat, :max_lng, :max_lat, 4326)::geography'
                : 'l.public_latitude between :min_lat and :max_lat
                   and l.public_longitude between :min_lng and :max_lng';
        }

        $lat = filter_var($query['lat'] ?? null, FILTER_VALIDATE_FLOAT, FILTER_NULL_ON_FAILURE);
        $lng = filter_var($query['lng'] ?? null, FILTER_VALIDATE_FLOAT, FILTER_NULL_ON_FAILURE);
        $hasCoordinates = $lat !== null && $lng !== null && $lat >= -90 && $lat <= 90 && $lng >= -180 && $lng <= 180;
        if ($hasCoordinates) {
            $parameters['lat'] = $lat;
            $parameters['lng'] = $lng;
            $parameters['lat_cos'] = $lat;
            $originJoin = $this->supportsPostgis()
                ? 'cross join lateral (
                    select ST_Distance(
                        l.public_location,
                        ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography
                    ) as distance_meters
                ) origin'
                : 'cross join lateral (
                    select 6371000 * 2 * asin(sqrt(
                        power(sin(radians(l.public_latitude - :lat) / 2), 2) +
                        cos(radians(:lat_cos)) * cos(radians(l.public_latitude)) *
                        power(sin(radians(l.public_longitude - :lng) / 2), 2)
                    )) as distance_meters
                ) origin';
            $radiusInput = $query['radius_meters'] ?? null;
            $hasRadiusFilter = $radiusInput !== null && $radiusInput !== ''
                && filter_var($radiusInput, FILTER_VALIDATE_INT) !== false;
            if ($hasRadiusFilter) {
                $parameters['radius'] = max(1000, min(100000, (int) $radiusInput));
                $conditions[] = 'origin.distance_meters <= least(:radius, coalesce(l.service_radius_km * 1000, 100000000))';
            }
            $distanceSelect = 'origin.distance_meters';
        } else {
            $originJoin = '';
            $distanceSelect = 'null::double precision as distance_meters';
        }

        $sort = (string) ($query['sort'] ?? ($hasCoordinates ? 'distance' : 'newest'));
        $order = match ($sort) {
            'price_asc' => 'first_item.price_amount asc nulls last, l.created_at desc',
            'price_desc' => 'first_item.price_amount desc nulls last, l.created_at desc',
            'rating' => 'owner_rating desc, owner_review_count desc, l.created_at desc',
            'distance' => $hasCoordinates ? 'distance_meters asc, l.created_at desc' : 'l.created_at desc',
            default => 'l.created_at desc',
        };

        $baseSql = "from listings l
                {$originJoin}
                join profiles p on p.user_id = l.owner_id
                join users owner on owner.id = l.owner_id and owner.is_suspended = false
                join lateral (
                  select li.id, li.title, li.description, li.category_id, li.price_amount, li.pricing_unit,
                          li.currency, li.estimated_duration_minutes, li.is_active,
                          li.price_includes_vat, li.urgent, li.open_24_7, li.schedule_label,
                         count(*) over ()::int as item_count
                  from listing_items li where li.listing_id = l.id and li.is_active and li.deleted_at is null
                  order by {$displayItemOrder} limit 1
                ) first_item on true
                left join lateral (
                  select avg(r.rating)::numeric(2,1) as rating, count(*)::int as review_count
                  from reviews r join service_engagements e on e.id=r.engagement_id and e.status='completed'
                  where r.reviewed_user_id = l.owner_id and r.status = 'published'
                ) review_stats on true
                left join lateral (
                  select storage_path from listing_images where listing_id = l.id order by sort_order limit 1
                ) image on true
                where " . implode(' and ', $conditions);

        $sql = "select l.id, l.slug, l.headline, l.summary, l.owner_id, l.listing_type, l.status, l.public_city, l.public_district,
                       l.public_neighborhood, l.location_precision, l.created_at, {$distanceSelect},
                       l.service_radius_km, l.preferred_provider_kind, l.preferred_provider_gender,
                       l.public_latitude as latitude, l.public_longitude as longitude,
                       first_item.id as item_id, first_item.title, first_item.description, first_item.category_id,
                       first_item.price_amount, first_item.pricing_unit, first_item.currency,
                       first_item.estimated_duration_minutes, first_item.is_active, first_item.price_includes_vat,
                        first_item.urgent, first_item.open_24_7, first_item.schedule_label, first_item.item_count,
                        p.display_name as owner_name, p.avatar_path as owner_avatar,
                        p.profile_type as owner_profile_type, p.gender as owner_gender,
                        (p.phone_verified_at is not null and owner.email_verified_at is not null) as owner_verified,
                       coalesce(review_stats.rating, 0) as owner_rating,
                       coalesce(review_stats.review_count, 0) as owner_review_count,
                       image.storage_path as cover_image
                {$baseSql}
                order by {$order}
                limit :limit offset :offset";

        $items = $this->database->fetchAll($sql, $parameters);
        $hasMore = false;
        if ($skipCount) {
            $hasMore = count($items) > $limit;
            if ($hasMore) {
                array_pop($items);
            }
            $total = $offset + count($items) + ($hasMore ? 1 : 0);
        } else {
            $countParameters = $parameters;
            unset($countParameters['limit'], $countParameters['offset']);
            $count = $this->database->fetchOne("select count(*)::int as total {$baseSql}", $countParameters);
            $total = (int) ($count['total'] ?? 0);
            $hasMore = $offset + count($items) < $total;
        }
        $normalizedItems = array_map([$this, 'normalizeListing'], $items);
        // Gruplama her zaman yalnız sorgudan geçen ilanları birleştirir. Bu sayede
        // "tüm ilanlar" görünümünde sağlayıcının bütün yakın hizmetleri tek işarette,
        // gitar gibi dar bir aramada ise yalnız eşleşen hizmet(ler)i görünür.
        if (($scope['group_nearby'] ?? false) === true) {
            $normalizedItems = $this->groupNearbyListings($normalizedItems);
        }

        return [
            'items' => $normalizedItems,
            'pagination' => [
                'page' => $page,
                'limit' => $limit,
                'returned' => count($normalizedItems),
                'total' => $total,
                'pages' => $total === 0 ? 0 : (int) ceil($total / $limit),
                'has_more' => $hasMore,
            ],
        ];
    }

    /** @return array{items: list<array<string, mixed>>, pagination: array<string, int>} */
    public function byOwner(string $ownerId, array $query = [], bool $includeInactive = false, ?string $viewerId = null): array
    {
        if (!Uuid::isValid($ownerId)) {
            throw new HttpException(404, 'Kullanıcı bulunamadı.', 'profile_not_found');
        }
        return $this->search($query, array_filter([
            'owner_id' => $ownerId,
            'viewer_id' => $viewerId,
            'include_inactive' => $includeInactive,
        ], static fn (mixed $value): bool => $value !== null));
    }

    /** @return array{items: list<array<string, mixed>>, pagination: array<string, int>} */
    public function favorites(string $userId, array $query = []): array
    {
        return $this->search($query, ['viewer_id' => $userId, 'favorite_user_id' => $userId]);
    }

    /** @return array<string, mixed> */
    public function find(string $idOrSlug): array
    {
        $listing = $this->database->fetchOne(
            "select l.id, l.slug, l.headline, l.summary, l.owner_id, l.listing_type, l.status, l.public_city,
                    l.public_district, l.public_neighborhood, l.location_precision,
                    l.view_count, l.expires_at, l.created_at, l.updated_at, l.service_radius_km,
                    l.preferred_provider_kind, l.preferred_provider_gender,
                    l.public_latitude as latitude, l.public_longitude as longitude,
                    p.display_name as owner_name, p.avatar_path as owner_avatar, p.bio as owner_bio,
                    p.phone_visible as owner_phone_visible,
                    coalesce(rs.rating, 0) as owner_rating, coalesce(rs.review_count, 0) as owner_review_count
             from listings l
             join profiles p on p.user_id = l.owner_id
             left join lateral (
               select avg(r.rating)::numeric(2,1) as rating, count(*)::int as review_count
               from reviews r join service_engagements e on e.id=r.engagement_id and e.status='completed'
               where r.reviewed_user_id = l.owner_id and r.status = 'published'
             ) rs on true
             where (l.id::text = :lookup or l.slug = :lookup)
               and l.status = 'active' and (l.expires_at is null or l.expires_at > now())",
            ['lookup' => $idOrSlug],
        );
        if ($listing === null) {
            throw new HttpException(404, 'İlan bulunamadı.', 'listing_not_found');
        }

        $listing['items'] = $this->database->fetchAll(
            'select id, category_id, page_index, title, description, schedule_label, price_amount,
                    pricing_unit, currency, estimated_duration_minutes, is_active,
                    price_includes_vat, urgent, open_24_7
             from listing_items where listing_id = :listing_id and is_active and deleted_at is null order by page_index',
            ['listing_id' => $listing['id']],
        );
        $listing['images'] = $this->database->fetchAll(
            'select id, storage_path, mime_type, width, height, sort_order
             from listing_images where listing_id = :listing_id order by sort_order',
            ['listing_id' => $listing['id']],
        );
        $this->database->statement('update listings set view_count = view_count + 1 where id = :id', ['id' => $listing['id']]);
        return $this->normalizeListing($listing);
    }

    /** @return array<string, mixed> */
    public function findForOwner(string $idOrSlug, string $ownerId): array
    {
        $listing = $this->database->fetchOne(
            "select l.id, l.slug, l.headline, l.summary, l.owner_id, l.listing_type, l.status, l.public_city,
                    l.public_district, l.public_neighborhood, l.location_precision,
                    l.view_count, l.expires_at, l.created_at, l.updated_at, l.service_radius_km,
                    l.preferred_provider_kind, l.preferred_provider_gender,
                    l.public_latitude as latitude, l.public_longitude as longitude,
                    p.display_name as owner_name, p.avatar_path as owner_avatar, p.bio as owner_bio,
                    p.phone_visible as owner_phone_visible,
                    coalesce(rs.rating, 0) as owner_rating, coalesce(rs.review_count, 0) as owner_review_count
             from listings l
             join profiles p on p.user_id = l.owner_id
             left join lateral (
               select avg(r.rating)::numeric(2,1) as rating, count(*)::int as review_count
               from reviews r join service_engagements e on e.id=r.engagement_id and e.status='completed'
               where r.reviewed_user_id = l.owner_id and r.status = 'published'
             ) rs on true
             where (l.id::text = :lookup or l.slug = :lookup) and l.owner_id = :owner_id",
            ['lookup' => $idOrSlug, 'owner_id' => $ownerId],
        );
        if ($listing === null) {
            throw new HttpException(404, 'Düzenleyebileceğin ilan bulunamadı.', 'listing_not_found');
        }
        $listing['items'] = $this->database->fetchAll(
            'select id, category_id, page_index, title, description, schedule_label, price_amount,
                    pricing_unit, currency, estimated_duration_minutes, is_active,
                    price_includes_vat, urgent, open_24_7
             from listing_items where listing_id = :listing_id and deleted_at is null order by page_index',
            ['listing_id' => $listing['id']],
        );
        $listing['images'] = $this->database->fetchAll(
            'select id, storage_path, mime_type, width, height, sort_order
             from listing_images where listing_id = :listing_id order by sort_order',
            ['listing_id' => $listing['id']],
        );
        $listing['private_address'] = $this->database->fetchOne(
            'select city, district, neighborhood, street, building_number, apartment_number,
                    exact_latitude as latitude, exact_longitude as longitude
             from private_listing_addresses where listing_id = :listing_id and owner_id = :owner_id',
            ['listing_id' => $listing['id'], 'owner_id' => $ownerId],
        );
        return $this->normalizeListing($listing);
    }

    /** @param array<string, mixed> $payload
     *  @param array<string, mixed> $user
     *  @return array<string, mixed>
     */
    public function create(array $payload, array $user, ?string $idempotencyKey = null): array
    {
        $ownerId = (string) $user['id'];
        $idempotencyKey = trim((string) $idempotencyKey);
        if ($idempotencyKey !== '' && (mb_strlen($idempotencyKey) < 16 || mb_strlen($idempotencyKey) > 160)) {
            throw new HttpException(422, 'İstek anahtarı geçersiz.', 'invalid_idempotency_key');
        }
        if ($idempotencyKey !== '') {
            $existingSubmission = $this->database->fetchOne(
                'select listing_id from listing_submission_keys
                 where user_id = :user_id and idempotency_key = :idempotency_key and expires_at > now()',
                ['user_id' => $ownerId, 'idempotency_key' => $idempotencyKey],
            );
            if ($existingSubmission !== null && Uuid::isValid((string) ($existingSubmission['listing_id'] ?? ''))) {
                return $this->findForOwner((string) $existingSubmission['listing_id'], $ownerId);
            }
        }

        $type = (string) ($payload['listing_type'] ?? '');
        if (!in_array($type, ['service_offer', 'service_request'], true)) {
            throw new HttpException(422, 'İlan türü geçersiz.', 'validation_failed', ['listing_type' => 'Geçersiz tür.']);
        }
        $items = $payload['items'] ?? null;
        if (!is_array($items) || count($items) < 1 || count($items) > 20) {
            throw new HttpException(422, 'Bir ilan 1–20 hizmet kalemi içermeli.', 'validation_failed');
        }
        $location = $payload['location'] ?? null;
        if (!is_array($location)) {
            throw new HttpException(422, 'Konum bilgisi gerekli.', 'validation_failed');
        }
        $lat = filter_var($location['latitude'] ?? null, FILTER_VALIDATE_FLOAT, FILTER_NULL_ON_FAILURE);
        $lng = filter_var($location['longitude'] ?? null, FILTER_VALIDATE_FLOAT, FILTER_NULL_ON_FAILURE);
        if ($lat === null || $lng === null || $lat < -90 || $lat > 90 || $lng < -180 || $lng > 180) {
            throw new HttpException(422, 'Geçerli koordinat gerekli.', 'validation_failed');
        }
        $district = trim((string) ($location['district'] ?? ''));
        $neighborhood = trim((string) ($location['neighborhood'] ?? ''));
        if ($district === '' || $neighborhood === '') {
            throw new HttpException(422, 'İlçe ve mahalle gerekli.', 'validation_failed');
        }
        $precision = (string) ($location['precision'] ?? 'neighborhood');
        if (!in_array($precision, ['exact', 'neighborhood'], true)) {
            throw new HttpException(422, 'Konum hassasiyeti geçersiz.', 'validation_failed');
        }
        $serviceRadiusRaw = $payload['service_radius_km'] ?? null;
        $serviceRadiusKm = $serviceRadiusRaw === null || $serviceRadiusRaw === ''
            ? null
            : filter_var($serviceRadiusRaw, FILTER_VALIDATE_INT, FILTER_NULL_ON_FAILURE);
        if ($serviceRadiusRaw !== null && $serviceRadiusRaw !== ''
            && ($serviceRadiusKm === null || $serviceRadiusKm < 1 || $serviceRadiusKm > 100)) {
            throw new HttpException(422, 'Hizmet mesafesi 1–100 km arasında olmalı.', 'validation_failed');
        }
        $preferredProviderKind = trim((string) ($payload['preferred_provider_kind'] ?? '')) ?: null;
        $preferredProviderGender = trim((string) ($payload['preferred_provider_gender'] ?? '')) ?: null;
        if ($type !== 'service_request') {
            $preferredProviderKind = null;
            $preferredProviderGender = null;
        }
        if ($preferredProviderKind !== null && !in_array($preferredProviderKind, ['person', 'business'], true)) {
            throw new HttpException(422, 'Hizmet veren türü tercihi geçersiz.', 'validation_failed');
        }
        if ($preferredProviderGender !== null && !in_array($preferredProviderGender, ['female', 'male'], true)) {
            throw new HttpException(422, 'Cinsiyet tercihi geçersiz.', 'validation_failed');
        }

        $cleanItems = [];
        foreach (array_values($items) as $index => $item) {
            if (!is_array($item)) {
                throw new HttpException(422, 'İlan kalemi geçersiz.', 'validation_failed');
            }
            $title = trim((string) ($item['title'] ?? ''));
            $description = trim((string) ($item['description'] ?? ''));
            $categoryId = trim((string) ($item['category_id'] ?? ''));
            $pricingUnit = (string) ($item['pricing_unit'] ?? 'negotiable');
            if (mb_strlen($title) < 3 || mb_strlen($title) > 120 || mb_strlen($description) < 10 || mb_strlen($description) > 2000) {
                throw new HttpException(422, 'İlan başlığı veya açıklaması uygun uzunlukta değil.', 'validation_failed');
            }
            ContentPolicy::assertAcceptable($title, 'İlan başlığı');
            ContentPolicy::assertAcceptable($description, 'İlan açıklaması');
            if ($this->database->fetchOne('select id from categories where id = :id and is_active and is_selectable', ['id' => $categoryId]) === null) {
                throw new HttpException(422, 'Kategori geçersiz.', 'validation_failed');
            }
            if (!in_array($pricingUnit, ['fixed', 'hourly', 'daily', 'per_session', 'starting_at', 'negotiable', 'free'], true)) {
                throw new HttpException(422, 'Fiyatlandırma türü geçersiz.', 'validation_failed');
            }
            $amount = in_array($pricingUnit, ['negotiable', 'free'], true)
                ? null
                : filter_var($item['price_amount'] ?? null, FILTER_VALIDATE_FLOAT, FILTER_NULL_ON_FAILURE);
            if (!in_array($pricingUnit, ['negotiable', 'free'], true) && ($amount === null || $amount < 0)) {
                throw new HttpException(422, 'Geçerli bir fiyat yazmalısın.', 'validation_failed');
            }
            $currency = strtoupper(trim((string) ($item['currency'] ?? 'TRY')));
            if (!preg_match('/^[A-Z]{3}$/', $currency)) {
                throw new HttpException(422, 'Para birimi geçersiz.', 'validation_failed');
            }
            $durationRaw = $item['estimated_duration_minutes'] ?? null;
            $duration = $durationRaw === null || $durationRaw === '' ? null
                : filter_var($durationRaw, FILTER_VALIDATE_INT, FILTER_NULL_ON_FAILURE);
            if ($duration !== null && ($duration < 5 || $duration > 525600)) {
                throw new HttpException(422, 'Tahmini süre geçersiz.', 'validation_failed');
            }
            $cleanItems[] = [
                'page_index' => $index,
                'title' => $title,
                'description' => $description,
                'category_id' => $categoryId,
                'pricing_unit' => $pricingUnit,
                'price_amount' => $amount,
                'currency' => $currency,
                'estimated_duration_minutes' => $duration,
                'is_active' => (bool) ($item['is_active'] ?? true) ? 'true' : 'false',
                // Native PDO PostgreSQL binds PHP false as an empty string when
                // execute() receives an array. PostgreSQL boolean columns expect
                // an explicit boolean representation.
                'price_includes_vat' => (bool) ($item['price_includes_vat'] ?? false) ? 'true' : 'false',
                'urgent' => (bool) ($item['urgent'] ?? false) ? 'true' : 'false',
                'open_24_7' => (bool) ($item['open_24_7'] ?? false) ? 'true' : 'false',
                'schedule_label' => mb_substr(trim((string) ($item['schedule_label'] ?? '')), 0, 200),
            ];
        }

        if (!array_filter($cleanItems, static fn (array $item): bool => $item['is_active'] === 'true')) {
            throw new HttpException(422, 'En az bir hizmet kalemi aktif olmalı.', 'validation_failed');
        }
        $headline = trim((string) ($payload['headline'] ?? $cleanItems[0]['title']));
        $summary = trim((string) ($payload['summary'] ?? ''));
        if (mb_strlen($headline) < 3 || mb_strlen($headline) > 140 || mb_strlen($summary) > 1000) {
            throw new HttpException(422, 'Ana ilan başlığı veya özeti geçersiz.', 'validation_failed');
        }
        ContentPolicy::assertAcceptable($headline, 'Ana ilan başlığı');
        if ($summary !== '') ContentPolicy::assertAcceptable($summary, 'İlan özeti');

        $fingerprint = $this->submissionFingerprint($type, ['title' => $headline, 'description' => $summary . ' ' . implode(' ', array_column($cleanItems, 'title')), 'category_id' => $cleanItems[0]['category_id']], $lat, $lng);
        $moderation = $this->moderationAssessment($payload, $cleanItems, $user);
        $listingId = Uuid::v4();
        $slug = $this->slugify($headline) . '-' . substr(str_replace('-', '', $listingId), 0, 8);
        [$publicLat, $publicLng] = $this->publicCoordinates($listingId, $lat, $lng, $precision);

        $existingSubmissionId = null;

        $this->database->transaction(function (PDO $pdo) use (
            $listingId, $slug, $ownerId, $type, $lat, $lng, $publicLat, $publicLng,
            $precision, $district, $neighborhood, $serviceRadiusKm, $cleanItems, $payload, $headline, $summary,
            $preferredProviderKind, $preferredProviderGender, $fingerprint, $moderation,
            $idempotencyKey, &$existingSubmissionId
        ): void {
            $lockKey = $ownerId . '|' . ($idempotencyKey !== '' ? $idempotencyKey : $fingerprint);
            $lock = $pdo->prepare('select pg_advisory_xact_lock(hashtext(:lock_key))');
            $lock->execute(['lock_key' => $lockKey]);

            if ($idempotencyKey !== '') {
                $idempotent = $pdo->prepare(
                    'select listing_id from listing_submission_keys
                     where user_id = :user_id and idempotency_key = :idempotency_key and expires_at > now()'
                );
                $idempotent->execute(['user_id' => $ownerId, 'idempotency_key' => $idempotencyKey]);
                $existingSubmissionId = $idempotent->fetchColumn() ?: null;
                if (is_string($existingSubmissionId) && Uuid::isValid($existingSubmissionId)) {
                    return;
                }
            }

            $duplicate = $pdo->prepare(
                "select id from listings
                 where owner_id = :owner_id and submission_fingerprint = :fingerprint
                   and status <> 'removed' and created_at > now() - interval '24 hours'
                 order by created_at desc limit 1"
            );
            $duplicate->execute(['owner_id' => $ownerId, 'fingerprint' => $fingerprint]);
            if ($duplicate->fetchColumn() !== false) {
                throw new HttpException(
                    409,
                    'Aynı ilanı son 24 saat içinde zaten gönderdin. Mevcut ilanını düzenleyebilirsin.',
                    'duplicate_listing'
                );
            }

            $listing = $pdo->prepare(
                "insert into listings (id, owner_id, slug, headline, summary, listing_type, public_latitude, public_longitude, location_precision,
                 public_city, public_district, public_neighborhood, service_radius_km, expires_at,
                 preferred_provider_kind, preferred_provider_gender, status, submission_fingerprint,
                 moderation_score, moderation_flags, submitted_at)
                 values (:id, :owner_id, :slug, :headline, :summary, :listing_type, :lat, :lng,
                 :precision, :city, :district, :neighborhood, :service_radius_km, :expires_at,
                 :preferred_provider_kind, :preferred_provider_gender, 'pending', :submission_fingerprint,
                 :moderation_score, cast(:moderation_flags as jsonb), now())"
            );
            $listing->execute([
                'id' => $listingId,
                'owner_id' => $ownerId,
                'slug' => $slug,
                'headline' => $headline,
                'summary' => $summary,
                'listing_type' => $type,
                'lng' => $publicLng,
                'lat' => $publicLat,
                'precision' => $precision,
                'city' => trim((string) (($payload['location']['city'] ?? 'Belirtilmedi'))),
                'district' => $district,
                'neighborhood' => $neighborhood,
                'service_radius_km' => $serviceRadiusKm,
                'expires_at' => isset($payload['expires_at']) ? (string) $payload['expires_at'] : null,
                'preferred_provider_kind' => $preferredProviderKind,
                'preferred_provider_gender' => $preferredProviderGender,
                'submission_fingerprint' => $fingerprint,
                'moderation_score' => $moderation['score'],
                'moderation_flags' => json_encode($moderation['flags'], JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE),
            ]);

            if ($idempotencyKey !== '') {
                $pdo->prepare(
                    "insert into listing_submission_keys (user_id, idempotency_key, listing_id)
                     values (:user_id, :idempotency_key, :listing_id)
                     on conflict (user_id, idempotency_key) do update
                     set listing_id = excluded.listing_id, created_at = now(), expires_at = now() + interval '24 hours'"
                )->execute([
                    'user_id' => $ownerId,
                    'idempotency_key' => $idempotencyKey,
                    'listing_id' => $listingId,
                ]);
            }

            $itemStatement = $pdo->prepare(
                'insert into listing_items (id, listing_id, category_id, page_index, title, description,
                 schedule_label, price_amount, pricing_unit, currency, estimated_duration_minutes, is_active,
                 price_includes_vat, urgent, open_24_7)
                 values (:id, :listing_id, :category_id, :page_index, :title, :description,
                 :schedule_label, :price_amount, :pricing_unit, :currency, :estimated_duration_minutes, :is_active,
                 :price_includes_vat, :urgent, :open_24_7)'
            );
            foreach ($cleanItems as $item) {
                $itemStatement->execute(['id' => Uuid::v4(), 'listing_id' => $listingId, ...$item]);
            }

            if ($type === 'service_offer') {
                $pdo->prepare('update profiles set is_provider = true, district = :district, updated_at = now() where user_id = :user_id')
                    ->execute(['district' => $district, 'user_id' => $ownerId]);
            }

            $private = $payload['private_address'] ?? null;
            if ($precision === 'exact' && is_array($private)) {
                $address = $pdo->prepare(
                    "insert into private_listing_addresses
                     (listing_id, owner_id, exact_latitude, exact_longitude, city, district, neighborhood, street, building_number, apartment_number)
                     values (:listing_id, :owner_id, :lat, :lng,
                     :city, :district, :neighborhood, :street, :building_number, :apartment_number)"
                );
                $address->execute([
                    'listing_id' => $listingId,
                    'owner_id' => $ownerId,
                    'lng' => $lng,
                    'lat' => $lat,
                    'city' => trim((string) ($private['city'] ?? ($payload['location']['city'] ?? 'Belirtilmedi'))),
                    'district' => trim((string) ($private['district'] ?? $district)),
                    'neighborhood' => trim((string) ($private['neighborhood'] ?? $neighborhood)),
                    'street' => trim((string) ($private['street'] ?? '')),
                    'building_number' => trim((string) ($private['building_number'] ?? '')),
                    'apartment_number' => trim((string) ($private['apartment_number'] ?? '')),
                ]);
            }

        });

        if (is_string($existingSubmissionId) && Uuid::isValid($existingSubmissionId)) {
            return $this->findForOwner($existingSubmissionId, $ownerId);
        }
        return $this->findForOwner($listingId, $ownerId);
    }

    /** @param list<array<string, mixed>> $items */
    private function notifyMatchingUsers(
        PDO $pdo,
        string $listingId,
        string $ownerId,
        string $listingType,
        string $city,
        string $district,
        array $items,
    ): void {
        $preferenceType = $listingType === 'service_request' ? 'provide' : 'receive';
        $categoryIds = array_values(array_unique(array_map(
            static fn (array $item): string => (string) $item['category_id'],
            $items,
        )));
        if ($categoryIds === []) {
            return;
        }

        $placeholders = [];
        $parameters = [
            'preference_type' => $preferenceType,
            'owner_id' => $ownerId,
            'city' => $city,
        ];
        foreach ($categoryIds as $index => $categoryId) {
            $key = 'category_' . $index;
            $placeholders[] = ':' . $key;
            $parameters[$key] = $categoryId;
        }
        $recipients = $pdo->prepare(
            "with recursive category_ancestors as (
               select id, parent_id from categories where id in (" . implode(',', $placeholders) . ")
               union
               select parent.id, parent.parent_id
               from categories parent join category_ancestors child on child.parent_id = parent.id
             )
             select distinct preference.user_id
             from profile_category_preferences preference
             join category_ancestors matched on matched.id = preference.category_id
             join users recipient on recipient.id = preference.user_id and recipient.is_suspended = false
             join profiles profile on profile.user_id = preference.user_id
             where preference.preference_type = :preference_type
               and preference.user_id <> :owner_id
               and unaccent(lower(profile.city)) = unaccent(lower(:city))"
        );
        $recipients->execute($parameters);

        $notification = $pdo->prepare(
            "insert into notifications (user_id, type, title, body, data)
             values (:user_id, 'listing', :title, :body, cast(:data as jsonb)) returning id"
        );
        $outbox = $pdo->prepare(
            'insert into realtime_outbox (channel, event_type, payload)
             values (:channel, :event_type, cast(:payload as jsonb))'
        );
        $title = $listingType === 'service_request'
            ? 'Alanına uygun yeni hizmet talebi'
            : 'İlgilendiğin alanda yeni hizmet';
        $body = mb_substr((string) $items[0]['title'] . ' · ' . $district . ', ' . $city, 0, 180);
        while (($recipientId = $recipients->fetchColumn()) !== false) {
            $recipientId = (string) $recipientId;
            $data = [
                'listing_id' => $listingId,
                'listing_type' => $listingType,
                'matched_category_ids' => $categoryIds,
            ];
            $notification->execute([
                'user_id' => $recipientId,
                'title' => $title,
                'body' => $body,
                'data' => json_encode($data, JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE),
            ]);
            $notificationId = (int) $notification->fetchColumn();
            $outbox->execute([
                'channel' => 'user:' . $recipientId,
                'event_type' => 'notification.created',
                'payload' => json_encode([
                    'notification_id' => $notificationId,
                    'type' => 'listing',
                    ...$data,
                ], JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE),
            ]);
        }
    }

    public function notifyApproved(string $listingId): void
    {
        if (!Uuid::isValid($listingId)) {
            return;
        }
        $this->database->transaction(function (PDO $pdo) use ($listingId): void {
            $statement = $pdo->prepare(
                "select id, owner_id, listing_type, public_city, public_district, approval_notified_at
                 from listings where id = :id and status = 'active' for update"
            );
            $statement->execute(['id' => $listingId]);
            $listing = $statement->fetch(PDO::FETCH_ASSOC);
            if ($listing === false || $listing['approval_notified_at'] !== null) {
                return;
            }
            $items = $pdo->prepare(
                'select category_id, title from listing_items where listing_id = :listing_id order by page_index'
            );
            $items->execute(['listing_id' => $listingId]);
            $listingItems = $items->fetchAll(PDO::FETCH_ASSOC);
            if ($listingItems !== []) {
                $this->notifyMatchingUsers(
                    $pdo,
                    $listingId,
                    (string) $listing['owner_id'],
                    (string) $listing['listing_type'],
                    (string) $listing['public_city'],
                    (string) $listing['public_district'],
                    $listingItems,
                );
            }
            $pdo->prepare('update listings set approval_notified_at = now() where id = :id')
                ->execute(['id' => $listingId]);
        });
    }

    /** @param array<string, mixed> $payload
     *  @param array<string, mixed> $user
     *  @return array<string, mixed>
     */
    public function update(string $listingId, array $payload, array $user): array
    {
        if (!Uuid::isValid($listingId)) {
            throw new HttpException(404, 'İlan bulunamadı.', 'listing_not_found');
        }
        $existing = $this->database->fetchOne(
            'select id from listings where id = :id and owner_id = :owner_id and status <> :removed',
            ['id' => $listingId, 'owner_id' => $user['id'], 'removed' => 'removed'],
        );
        if ($existing === null) {
            throw new HttpException(404, 'Düzenleyebileceğin ilan bulunamadı.', 'listing_not_found');
        }

        $type = (string) ($payload['listing_type'] ?? '');
        if (!in_array($type, ['service_offer', 'service_request'], true)) {
            throw new HttpException(422, 'İlan türü geçersiz.', 'validation_failed');
        }
        $location = $payload['location'] ?? null;
        $items = $payload['items'] ?? null;
        if (!is_array($location) || !is_array($items) || count($items) < 1 || count($items) > 20) {
            throw new HttpException(422, 'Bir ilan 1–20 hizmet kalemi içermeli.', 'validation_failed');
        }
        $lat = filter_var($location['latitude'] ?? null, FILTER_VALIDATE_FLOAT, FILTER_NULL_ON_FAILURE);
        $lng = filter_var($location['longitude'] ?? null, FILTER_VALIDATE_FLOAT, FILTER_NULL_ON_FAILURE);
        $district = trim((string) ($location['district'] ?? ''));
        $neighborhood = trim((string) ($location['neighborhood'] ?? ''));
        $precision = (string) ($location['precision'] ?? 'neighborhood');
        if ($lat === null || $lng === null || $lat < -90 || $lat > 90 || $lng < -180 || $lng > 180
            || $district === '' || $neighborhood === '' || !in_array($precision, ['exact', 'neighborhood'], true)) {
            throw new HttpException(422, 'Geçerli konum bilgisi gerekli.', 'validation_failed');
        }
        $serviceRadiusRaw = $payload['service_radius_km'] ?? null;
        $serviceRadiusKm = $serviceRadiusRaw === null || $serviceRadiusRaw === ''
            ? null
            : filter_var($serviceRadiusRaw, FILTER_VALIDATE_INT, FILTER_NULL_ON_FAILURE);
        if ($serviceRadiusRaw !== null && $serviceRadiusRaw !== ''
            && ($serviceRadiusKm === null || $serviceRadiusKm < 1 || $serviceRadiusKm > 100)) {
            throw new HttpException(422, 'Hizmet mesafesi 1–100 km arasında olmalı.', 'validation_failed');
        }
        $preferredProviderKind = trim((string) ($payload['preferred_provider_kind'] ?? '')) ?: null;
        $preferredProviderGender = trim((string) ($payload['preferred_provider_gender'] ?? '')) ?: null;
        if ($type !== 'service_request') {
            $preferredProviderKind = null;
            $preferredProviderGender = null;
        }
        if ($preferredProviderKind !== null && !in_array($preferredProviderKind, ['person', 'business'], true)) {
            throw new HttpException(422, 'Hizmet veren türü tercihi geçersiz.', 'validation_failed');
        }
        if ($preferredProviderGender !== null && !in_array($preferredProviderGender, ['female', 'male'], true)) {
            throw new HttpException(422, 'Cinsiyet tercihi geçersiz.', 'validation_failed');
        }
        [$publicLat, $publicLng] = $this->publicCoordinates($listingId, $lat, $lng, $precision);

        $cleanItems = [];
        foreach (array_values($items) as $index => $item) {
            if (!is_array($item)) {
                throw new HttpException(422, 'İlan kalemi geçersiz.', 'validation_failed');
            }
            $title = trim((string) ($item['title'] ?? ''));
            $description = trim((string) ($item['description'] ?? ''));
            $categoryId = trim((string) ($item['category_id'] ?? ''));
            $pricingUnit = (string) ($item['pricing_unit'] ?? 'negotiable');
            if (mb_strlen($title) < 3 || mb_strlen($title) > 120
                || mb_strlen($description) < 10 || mb_strlen($description) > 2000) {
                throw new HttpException(422, 'İlan başlığı veya açıklaması uygun uzunlukta değil.', 'validation_failed');
            }
            ContentPolicy::assertAcceptable($title, 'İlan başlığı');
            ContentPolicy::assertAcceptable($description, 'İlan açıklaması');
            if ($this->database->fetchOne(
                'select id from categories where id = :id and is_active and is_selectable',
                ['id' => $categoryId],
            ) === null) {
                throw new HttpException(422, 'Kategori geçersiz.', 'validation_failed');
            }
            if (!in_array($pricingUnit, ['fixed', 'hourly', 'daily', 'per_session', 'starting_at', 'negotiable', 'free'], true)) {
                throw new HttpException(422, 'Fiyatlandırma türü geçersiz.', 'validation_failed');
            }
            $amount = in_array($pricingUnit, ['negotiable', 'free'], true)
                ? null
                : filter_var($item['price_amount'] ?? null, FILTER_VALIDATE_FLOAT, FILTER_NULL_ON_FAILURE);
            if (!in_array($pricingUnit, ['negotiable', 'free'], true) && ($amount === null || $amount < 0)) {
                throw new HttpException(422, 'Geçerli bir fiyat yazmalısın.', 'validation_failed');
            }
            $currency = strtoupper(trim((string) ($item['currency'] ?? 'TRY')));
            if (!preg_match('/^[A-Z]{3}$/', $currency)) {
                throw new HttpException(422, 'Para birimi geçersiz.', 'validation_failed');
            }
            $durationRaw = $item['estimated_duration_minutes'] ?? null;
            $duration = $durationRaw === null || $durationRaw === '' ? null
                : filter_var($durationRaw, FILTER_VALIDATE_INT, FILTER_NULL_ON_FAILURE);
            if ($duration !== null && ($duration < 5 || $duration > 525600)) {
                throw new HttpException(422, 'Tahmini süre geçersiz.', 'validation_failed');
            }
            $cleanItems[] = [
                'id' => Uuid::v4(),
                'listing_id' => $listingId,
                'category_id' => $categoryId,
                'page_index' => $index,
                'title' => $title,
                'description' => $description,
                'schedule_label' => mb_substr(trim((string) ($item['schedule_label'] ?? '')), 0, 200),
                'price_amount' => $amount,
                'pricing_unit' => $pricingUnit,
                'currency' => $currency,
                'estimated_duration_minutes' => $duration,
                'is_active' => (bool) ($item['is_active'] ?? true) ? 'true' : 'false',
                'price_includes_vat' => (bool) ($item['price_includes_vat'] ?? false) ? 'true' : 'false',
                'urgent' => (bool) ($item['urgent'] ?? false) ? 'true' : 'false',
                'open_24_7' => (bool) ($item['open_24_7'] ?? false) ? 'true' : 'false',
            ];
        }

        if (!array_filter($cleanItems, static fn (array $item): bool => $item['is_active'] === 'true')) {
            throw new HttpException(422, 'En az bir hizmet kalemi aktif olmalı.', 'validation_failed');
        }
        $headline = trim((string) ($payload['headline'] ?? $cleanItems[0]['title']));
        $summary = trim((string) ($payload['summary'] ?? ''));
        if (mb_strlen($headline) < 3 || mb_strlen($headline) > 140 || mb_strlen($summary) > 1000) {
            throw new HttpException(422, 'Ana ilan başlığı veya özeti geçersiz.', 'validation_failed');
        }
        ContentPolicy::assertAcceptable($headline, 'Ana ilan başlığı');
        if ($summary !== '') ContentPolicy::assertAcceptable($summary, 'İlan özeti');

        $fingerprint = $this->submissionFingerprint($type, ['title' => $headline, 'description' => $summary . ' ' . implode(' ', array_column($cleanItems, 'title')), 'category_id' => $cleanItems[0]['category_id']], $lat, $lng);
        $moderation = $this->moderationAssessment($payload, $cleanItems, $user);

        $this->database->transaction(function (PDO $pdo) use (
            $listingId, $payload, $location, $type, $lat, $lng, $publicLat, $publicLng,
            $district, $neighborhood, $precision, $serviceRadiusKm, $cleanItems, $user,
            $preferredProviderKind, $preferredProviderGender, $fingerprint, $moderation, $headline, $summary
        ): void {
            $duplicate = $pdo->prepare(
                "select id from listings
                 where owner_id = :owner_id and submission_fingerprint = :fingerprint
                   and id <> :id and status <> 'removed' and created_at > now() - interval '24 hours'
                 limit 1"
            );
            $duplicate->execute(['owner_id' => $user['id'], 'fingerprint' => $fingerprint, 'id' => $listingId]);
            if ($duplicate->fetchColumn() !== false) {
                throw new HttpException(409, 'Aynı içerikte başka bir ilanını son 24 saat içinde zaten gönderdin.', 'duplicate_listing');
            }

            $pdo->prepare(
                'update listings set headline = :headline, summary = :summary, listing_type = :listing_type, public_latitude = :lat,
                 public_longitude = :lng, location_precision = :precision, public_city = :city,
                 public_district = :district, public_neighborhood = :neighborhood,
                 service_radius_km = :service_radius_km,
                 preferred_provider_kind = :preferred_provider_kind,
                 preferred_provider_gender = :preferred_provider_gender,
                 expires_at = :expires_at, status = :status,
                 submission_fingerprint = :submission_fingerprint,
                 moderation_score = :moderation_score,
                 moderation_flags = cast(:moderation_flags as jsonb), submitted_at = now(),
                 reviewed_at = null, reviewed_by = null, approval_notified_at = null,
                 updated_at = now()
                 where id = :id and owner_id = :owner_id'
            )->execute([
                'listing_type' => $type,
                'headline' => $headline,
                'summary' => $summary,
                'lat' => $publicLat,
                'lng' => $publicLng,
                'precision' => $precision,
                'city' => trim((string) ($location['city'] ?? 'Belirtilmedi')),
                'district' => $district,
                'neighborhood' => $neighborhood,
                'service_radius_km' => $serviceRadiusKm,
                'preferred_provider_kind' => $preferredProviderKind,
                'preferred_provider_gender' => $preferredProviderGender,
                'expires_at' => isset($payload['expires_at']) ? (string) $payload['expires_at'] : null,
                'status' => 'pending',
                'submission_fingerprint' => $fingerprint,
                'moderation_score' => $moderation['score'],
                'moderation_flags' => json_encode($moderation['flags'], JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE),
                'id' => $listingId,
                'owner_id' => $user['id'],
            ]);
            $pdo->prepare('delete from listing_items where listing_id = :listing_id')
                ->execute(['listing_id' => $listingId]);
            $insert = $pdo->prepare(
                'insert into listing_items (id, listing_id, category_id, page_index, title, description,
                 schedule_label, price_amount, pricing_unit, currency, estimated_duration_minutes, is_active,
                 price_includes_vat, urgent, open_24_7)
                 values (:id, :listing_id, :category_id, :page_index, :title, :description,
                 :schedule_label, :price_amount, :pricing_unit, :currency, :estimated_duration_minutes, :is_active,
                 :price_includes_vat, :urgent, :open_24_7)'
            );
            foreach ($cleanItems as $item) {
                $insert->execute($item);
            }

            $pdo->prepare('delete from private_listing_addresses where listing_id = :listing_id')
                ->execute(['listing_id' => $listingId]);
            $private = $payload['private_address'] ?? null;
            if ($precision === 'exact' && is_array($private)) {
                $pdo->prepare(
                    'insert into private_listing_addresses
                     (listing_id, owner_id, exact_latitude, exact_longitude, city, district,
                       neighborhood, street, building_number, apartment_number)
                     values (:listing_id, :owner_id, :lat, :lng, :city, :district,
                       :neighborhood, :street, :building_number, :apartment_number)'
                )->execute([
                    'listing_id' => $listingId,
                    'owner_id' => $user['id'],
                    'lat' => $lat,
                    'lng' => $lng,
                    'city' => trim((string) ($private['city'] ?? ($location['city'] ?? 'Belirtilmedi'))),
                    'district' => trim((string) ($private['district'] ?? $district)),
                    'neighborhood' => trim((string) ($private['neighborhood'] ?? $neighborhood)),
                    'street' => trim((string) ($private['street'] ?? '')),
                    'building_number' => trim((string) ($private['building_number'] ?? '')),
                    'apartment_number' => trim((string) ($private['apartment_number'] ?? '')),
                ]);
            }
            if ($type === 'service_offer') {
                $pdo->prepare('update profiles set is_provider = true, district = :district, updated_at = now() where user_id = :user_id')
                    ->execute(['district' => $district, 'user_id' => $user['id']]);
            }
        });

        return $this->findForOwner($listingId, (string) $user['id']);
    }

    /** @param array<string, mixed> $user */
    public function remove(string $listingId, array $user): void
    {
        if (!Uuid::isValid($listingId)) {
            throw new HttpException(404, 'İlan bulunamadı.', 'listing_not_found');
        }
        $statement = $this->database->statement(
            "update listings set status = 'removed', updated_at = now()
             where id = :id and owner_id = :owner_id and status <> 'removed'",
            ['id' => $listingId, 'owner_id' => $user['id']],
        );
        if ($statement->rowCount() === 0) {
            throw new HttpException(404, 'Kaldırabileceğin ilan bulunamadı.', 'listing_not_found');
        }
    }

    /** @param array<string, mixed> $item */
    private function submissionFingerprint(string $type, array $item, float $latitude, float $longitude): string
    {
        $normalize = static function (string $value): string {
            $value = mb_strtolower(trim($value));
            $value = preg_replace('/\s+/u', ' ', $value) ?? $value;
            return mb_substr($value, 0, 2200);
        };
        return hash('sha256', implode('|', [
            $type,
            $normalize((string) ($item['category_id'] ?? '')),
            $normalize((string) ($item['title'] ?? '')),
            $normalize((string) ($item['description'] ?? '')),
            number_format($latitude, 3, '.', ''),
            number_format($longitude, 3, '.', ''),
        ]));
    }

    /** @param array<string, mixed> $payload
     *  @param list<array<string, mixed>> $items
     *  @param array<string, mixed> $user
     *  @return array{score: int, flags: list<string>}
     */
    private function moderationAssessment(array $payload, array $items, array $user): array
    {
        $account = $this->database->fetchOne(
            'select u.email_verified_at, u.created_at, p.phone_verified_at
             from users u join profiles p on p.user_id = u.id where u.id = :id',
            ['id' => (string) $user['id']],
        ) ?? [];
        $score = 0;
        $flags = [];
        if (($account['email_verified_at'] ?? null) === null) {
            $score += 20;
            $flags[] = 'email_unverified';
        }
        if (($account['phone_verified_at'] ?? null) === null) {
            $score += 15;
            $flags[] = 'phone_unverified';
        }
        $createdAt = strtotime((string) ($account['created_at'] ?? '')) ?: 0;
        if ($createdAt > time() - 86400) {
            $score += 10;
            $flags[] = 'new_account';
        }
        $content = implode(' ', array_map(
            static fn (array $item): string => (string) ($item['title'] ?? '') . ' ' . (string) ($item['description'] ?? ''),
            $items,
        ));
        if (preg_match('/(?:https?:\/\/|www\.|t\.me\/|wa\.me\/)/iu', $content)) {
            $score += 25;
            $flags[] = 'external_link';
        }
        if (preg_match('/(.)\1{7,}/u', $content)) {
            $score += 20;
            $flags[] = 'repeated_characters';
        }
        if (preg_match_all('/\b\d{10,}\b/u', preg_replace('/[\s()+-]/', '', $content) ?? $content) > 1) {
            $score += 15;
            $flags[] = 'repeated_phone_number';
        }
        if (mb_strlen($content) < 35) {
            $score += 10;
            $flags[] = 'low_detail';
        }
        if (($payload['listing_type'] ?? '') === 'service_offer'
            && filter_var($items[0]['urgent'] ?? false, FILTER_VALIDATE_BOOL)) {
            $score += 5;
            $flags[] = 'urgent_offer';
        }
        return ['score' => min(100, $score), 'flags' => array_values(array_unique($flags))];
    }

    /** @param list<array<string, mixed>> $items @return list<array<string, mixed>> */
    private function groupNearbyListings(array $items): array
    {
        $groups = [];
        foreach ($items as $item) {
            $lat = (float) ($item['latitude'] ?? 0);
            $lng = (float) ($item['longitude'] ?? 0);
            $groupIndex = null;
            foreach ($groups as $index => $group) {
                if (($group['owner_id'] ?? null) !== ($item['owner_id'] ?? null)
                    || ($group['listing_type'] ?? null) !== ($item['listing_type'] ?? null)) {
                    continue;
                }
                if ($this->distanceMeters(
                    $lat,
                    $lng,
                    (float) ($group['latitude'] ?? 0),
                    (float) ($group['longitude'] ?? 0),
                ) <= 150) {
                    $groupIndex = $index;
                    break;
                }
            }

            $service = [
                'id' => $item['id'] ?? null,
                'slug' => $item['slug'] ?? null,
                'title' => $item['title'] ?? '',
                'category_id' => $item['category_id'] ?? '',
                'price_amount' => $item['price_amount'] ?? null,
                'pricing_unit' => $item['pricing_unit'] ?? 'negotiable',
                'urgent' => (bool) ($item['urgent'] ?? false),
                'cover_image' => $item['cover_image'] ?? null,
            ];
            if ($groupIndex === null) {
                $item['grouped'] = false;
                $item['service_count'] = 1;
                $item['services'] = [$service];
                $groups[] = $item;
                continue;
            }
            $groups[$groupIndex]['services'][] = $service;
            $groups[$groupIndex]['service_count'] = count($groups[$groupIndex]['services']);
            $groups[$groupIndex]['grouped'] = true;
            $groups[$groupIndex]['urgent'] = (bool) ($groups[$groupIndex]['urgent'] ?? false) || (bool) ($item['urgent'] ?? false);
        }
        return array_values($groups);
    }

    private function distanceMeters(float $latA, float $lngA, float $latB, float $lngB): float
    {
        $latDelta = deg2rad($latB - $latA);
        $lngDelta = deg2rad($lngB - $lngA);
        $a = sin($latDelta / 2) ** 2
            + cos(deg2rad($latA)) * cos(deg2rad($latB)) * sin($lngDelta / 2) ** 2;
        return 6371000 * 2 * atan2(sqrt($a), sqrt(max(0, 1 - $a)));
    }

    /** @param array<string, mixed> $row
     *  @return array<string, mixed>
     */
    private function normalizeListing(array $row): array
    {
        foreach (['price_amount', 'owner_rating', 'distance_meters', 'latitude', 'longitude'] as $key) {
            if (array_key_exists($key, $row) && $row[$key] !== null) {
                $row[$key] = (float) $row[$key];
            }
        }
        foreach (['owner_review_count', 'item_count', 'view_count'] as $key) {
            if (array_key_exists($key, $row) && $row[$key] !== null) {
                $row[$key] = (int) $row[$key];
            }
        }
        if (array_key_exists('service_radius_km', $row) && $row['service_radius_km'] !== null) {
            $row['service_radius_km'] = (int) $row['service_radius_km'];
        }
        foreach (['urgent', 'open_24_7', 'price_includes_vat', 'owner_verified', 'is_active'] as $key) {
            if (array_key_exists($key, $row)) {
                $row[$key] = (bool) $row[$key];
            }
        }
        if (isset($row['items']) && is_array($row['items'])) {
            $row['items'] = array_map(function (array $item): array {
                foreach (['price_amount'] as $key) {
                    if (array_key_exists($key, $item) && $item[$key] !== null) $item[$key] = (float) $item[$key];
                }
                if (array_key_exists('estimated_duration_minutes', $item) && $item['estimated_duration_minutes'] !== null) {
                    $item['estimated_duration_minutes'] = (int) $item['estimated_duration_minutes'];
                }
                foreach (['urgent', 'open_24_7', 'price_includes_vat', 'is_active'] as $key) {
                    if (array_key_exists($key, $item)) $item[$key] = (bool) $item[$key];
                }
                return $item;
            }, $row['items']);
        }
        return $row;
    }

    private function slugify(string $value): string
    {
        $value = mb_strtolower($value);
        $value = strtr($value, ['ç' => 'c', 'ğ' => 'g', 'ı' => 'i', 'ö' => 'o', 'ş' => 's', 'ü' => 'u']);
        $value = preg_replace('/[^a-z0-9]+/', '-', $value) ?? 'ilan';
        return trim($value, '-') ?: 'ilan';
    }

    private function supportsPostgis(): bool
    {
        if ($this->postgisAvailable !== null) {
            return $this->postgisAvailable;
        }
        $row = $this->database->fetchOne(
            "select exists (
                select 1 from pg_extension where extname = 'postgis'
            ) and exists (
                select 1 from information_schema.columns
                where table_schema = current_schema()
                  and table_name = 'listings'
                  and column_name = 'public_location'
            ) as available"
        );
        return $this->postgisAvailable = (bool) ($row['available'] ?? false);
    }

    /** @return array{0: float, 1: float} */
    private function publicCoordinates(string $listingId, float $latitude, float $longitude, string $precision): array
    {
        // Kullanıcının ilan formunda doğruladığı iğne web ve mobil haritada aynı
        // noktayı göstermeli. Tam adres metni ise private_listing_addresses içinde
        // kalır ve ilan detayında yayımlanmaz.
        return [$latitude, $longitude];
    }
}
