<?php

declare(strict_types=1);

namespace App\Domain;

use App\Core\Database;
use App\Core\HttpException;
use App\Core\Request;
use App\Core\RequestContext;
use App\Security\ContentPolicy;
use App\Support\Uuid;
use PDO;

final class ProfileService
{
    private readonly LocationCatalog $locations;

    public function __construct(private readonly Database $database)
    {
        $this->locations = new LocationCatalog();
    }

    /** @return array<string, mixed> */
    public function find(string $userId): array
    {
        if (!Uuid::isValid($userId)) {
            throw new HttpException(404, 'Profil bulunamadı.', 'profile_not_found');
        }
        $profile = $this->database->fetchOne(
            "select p.user_id as id, p.display_name, p.avatar_path, p.bio, p.city, p.district,
                    p.gender, p.profile_type, p.business_name, p.business_services,
                    p.is_provider, p.phone_visible, p.phone_verified_at is not null as phone_verified,
                    u.email_verified_at is not null as email_verified, u.created_at,
                    coalesce(rs.rating, 0) as rating, coalesce(rs.review_count, 0) as review_count
             from profiles p join users u on u.id = p.user_id
             left join lateral (
               select avg(r.rating)::numeric(2,1) as rating, count(*)::int as review_count
               from reviews r join service_engagements e on e.id=r.engagement_id and e.status='completed'
               where r.reviewed_user_id = p.user_id and r.status = 'published'
             ) rs on true
             where p.user_id = :user_id and u.is_suspended = false",
            ['user_id' => $userId],
        );
        if ($profile === null) {
            throw new HttpException(404, 'Profil bulunamadı.', 'profile_not_found');
        }
        $profile['rating'] = (float) $profile['rating'];
        $profile['review_count'] = (int) $profile['review_count'];
        $profile['is_provider'] = (bool) $profile['is_provider'];
        $profile['phone_visible'] = (bool) $profile['phone_visible'];
        $profile['phone_verified'] = (bool) $profile['phone_verified'];
        $profile['email_verified'] = (bool) $profile['email_verified'];
        $completed = $this->database->fetchOne(
            "select count(*)::int as total from service_engagements
             where status='completed' and (requester_id=:user_id_requester or provider_id=:user_id_provider)",
            ['user_id_requester'=>$userId,'user_id_provider'=>$userId],
        );
        $profile['completed_jobs'] = (int)($completed['total'] ?? 0);
        $profile['is_verified'] = $profile['email_verified'] && $profile['phone_verified'];
        $profile['profile_type'] = (string) ($profile['profile_type'] ?? 'person');
        $profile['category_preferences'] = $this->categoryPreferences($userId);
        $profile['services'] = $this->database->fetchAll(
            "select li.category_id, li.title, li.description, li.price_amount, li.pricing_unit,
                    li.price_includes_vat, li.schedule_label as availability_label, li.urgent as available_now
             from listings l join listing_items li on li.listing_id = l.id
             where l.owner_id = :user_id and l.listing_type = 'service_offer' and l.status = 'active'
               and li.is_active and li.deleted_at is null
               and (l.expires_at is null or l.expires_at > now())
             order by l.created_at desc, li.page_index",
            ['user_id' => $userId],
        );
        $profile['reviews'] = $this->database->fetchAll(
            "select r.id,r.engagement_id,r.rating,r.comment,r.published_at as created_at,
                    p.user_id as author_id,p.display_name as author_name,p.avatar_path as author_avatar,
                    e.service_name_snapshot,true as verified_engagement
             from reviews r join profiles p on p.user_id = r.author_id
             join service_engagements e on e.id=r.engagement_id and e.status='completed'
             where r.reviewed_user_id = :user_id and r.status = 'published'
             order by r.created_at desc limit 100",
            ['user_id' => $userId],
        );
        $distribution=$this->database->fetchAll(
            "select r.rating::int as rating,count(*)::int as count
             from reviews r join service_engagements e on e.id=r.engagement_id and e.status='completed'
             where r.reviewed_user_id=:user_id and r.status='published' group by r.rating order by r.rating desc",
            ['user_id'=>$userId],
        );
        $profile['rating_distribution']=array_fill_keys(['1','2','3','4','5'],0);
        foreach($distribution as $bucket) $profile['rating_distribution'][(string)$bucket['rating']] = (int)$bucket['count'];
        $profile['recent_completed_jobs']=$this->database->fetchAll(
            "select id,service_name_snapshot,pricing_unit_snapshot,currency_snapshot,completed_at,
                    case when provider_id=:viewer then 'provided' else 'received' end as role,
                    true as verified_engagement
             from service_engagements where status='completed' and (requester_id=:viewer2 or provider_id=:viewer3)
             order by completed_at desc limit 20",
            ['viewer'=>$userId,'viewer2'=>$userId,'viewer3'=>$userId],
        );
        return $profile;
    }

    /** @return array<string, mixed> */
    public function findOwn(string $userId): array
    {
        $profile = $this->find($userId);
        $private = $this->database->fetchOne(
            'select gender, phone_e164, profile_type, business_name, business_address, business_services
             from profiles where user_id = :user_id',
            ['user_id' => $userId],
        );
        $profile['gender'] = $private['gender'] ?? null;
        $profile['phone_e164'] = $private['phone_e164'] ?? null;
        $profile['profile_type'] = (string) ($private['profile_type'] ?? 'person');
        $profile['business_name'] = $private['business_name'] ?? null;
        $profile['business_address'] = $private['business_address'] ?? null;
        $profile['business_services'] = $private['business_services'] ?? null;
        return $profile;
    }

    /** @param array<string, mixed> $payload
     *  @param array<string, mixed> $user
     *  @return array<string, mixed>
     */
    public function update(array $payload, array $user): array
    {
        $name = trim((string) ($payload['display_name'] ?? $user['display_name']));
        $bio = trim((string) ($payload['bio'] ?? $user['bio']));
        $city = trim((string) ($payload['city'] ?? $user['city']));
        $district = trim((string) ($payload['district'] ?? $user['district']));
        $phone = $this->normalizePhone((string) ($payload['phone_e164'] ?? $user['phone_e164'] ?? ''));
        $phoneVisible = filter_var(
            $payload['phone_visible'] ?? $user['phone_visible'] ?? false,
            FILTER_VALIDATE_BOOL,
        );
        $currentPrivate = $this->database->fetchOne(
            'select gender, profile_type, business_name, business_address, business_services
             from profiles where user_id = :user_id',
            ['user_id' => $user['id']],
        );
        $gender = array_key_exists('gender', $payload)
            ? ($payload['gender'] === null ? null : trim((string) $payload['gender']))
            : ($currentPrivate['gender'] ?? null);
        $profileType = array_key_exists('profile_type', $payload)
            ? trim((string) $payload['profile_type'])
            : (string) ($currentPrivate['profile_type'] ?? 'person');
        $businessName = trim((string) ($payload['business_name'] ?? $currentPrivate['business_name'] ?? ''));
        $businessAddress = trim((string) ($payload['business_address'] ?? $currentPrivate['business_address'] ?? ''));
        $businessServices = trim((string) ($payload['business_services'] ?? $currentPrivate['business_services'] ?? ''));
        if (mb_strlen($name) < 2 || mb_strlen($name) > 80 || mb_strlen($bio) > 500) {
            throw new HttpException(422, 'Profil bilgileri uygun uzunlukta değil.', 'validation_failed');
        }
        ContentPolicy::assertAcceptable($name, 'Görünen ad');
        if ($bio !== '') ContentPolicy::assertAcceptable($bio, 'Profil açıklaması');
        if (preg_match('/[\\p{Cc}\\p{Cf}]/u', $name) === 1) {
            throw new HttpException(422, 'Görünen ad geçersiz kontrol karakterleri içeriyor.', 'validation_failed');
        }
        if (!$this->locations->contains($city, $district)) {
            throw new HttpException(422, 'Geçerli il ve ilçe seçmelisin.', 'validation_failed');
        }
        if ($gender !== null && !in_array($gender, ['female', 'male', 'other', 'prefer_not_to_say'], true)) {
            throw new HttpException(422, 'Cinsiyet seçimi geçersiz.', 'validation_failed');
        }
        if (!in_array($profileType, ['person', 'business'], true)) {
            throw new HttpException(422, 'Profil türü geçersiz.', 'validation_failed');
        }
        if ($profileType === 'business' && (mb_strlen($businessName) < 2 || mb_strlen($businessAddress) < 5)) {
            throw new HttpException(422, 'İşletme adı ve açık adresi zorunludur.', 'validation_failed');
        }
        if (mb_strlen($businessName) > 120 || mb_strlen($businessAddress) > 300 || mb_strlen($businessServices) > 1000) {
            throw new HttpException(422, 'İşletme bilgileri izin verilen uzunluğu aşıyor.', 'validation_failed');
        }
        if ($businessName !== '') ContentPolicy::assertAcceptable($businessName, 'İşletme adı');
        if ($businessServices !== '') ContentPolicy::assertAcceptable($businessServices, 'İşletme hizmetleri');
        $receiveCategories = array_key_exists('receive_category_ids', $payload)
            ? $this->validateCategoryPreferences($payload['receive_category_ids'])
            : null;
        $provideCategories = array_key_exists('provide_category_ids', $payload)
            ? $this->validateCategoryPreferences($payload['provide_category_ids'])
            : null;
        if ($phoneVisible && $phone === null) {
            throw new HttpException(422, 'Telefonu görünür yapmak için geçerli bir numara girmelisin.', 'validation_failed');
        }
        $currentPhone = $this->normalizePhone((string) ($user['phone_e164'] ?? ''));
        $phoneChanged = $phone !== $currentPhone;
        if ($phoneVisible && ($phoneChanged || empty($user['phone_verified_at']))) {
            throw new HttpException(422, 'Telefonu paylaşmak için önce SMS ile doğrulamalısın.', 'phone_verification_required');
        }
        $this->database->transaction(function (PDO $pdo) use (
            $name, $bio, $city, $district, $phone, $phoneChanged, $phoneVisible,
            $gender, $profileType, $businessName, $businessAddress, $businessServices,
            $receiveCategories, $provideCategories, $user
        ): void {
            $statement = $pdo->prepare(
                'update profiles set display_name = :display_name, bio = :bio, city = :city,
                 district = :district, gender = :gender, profile_type = :profile_type,
                 business_name = :business_name, business_address = :business_address,
                 business_services = :business_services, phone_e164 = :phone_e164,
                 phone_verified_at = case when :phone_changed then null else phone_verified_at end,
                 phone_visible = case when :phone_changed_visible then false else :phone_visible end,
                 updated_at = now() where user_id = :user_id'
            );
            $statement->execute([
                'display_name' => $name,
                'bio' => $bio,
                'city' => $city,
                'district' => $district,
                'gender' => $gender,
                'profile_type' => $profileType,
                'business_name' => $profileType === 'business' ? $businessName : null,
                'business_address' => $profileType === 'business' ? $businessAddress : null,
                'business_services' => $profileType === 'business' ? $businessServices : null,
                'phone_e164' => $phone,
                'phone_changed' => $phoneChanged ? 'true' : 'false',
                'phone_changed_visible' => $phoneChanged ? 'true' : 'false',
                'phone_visible' => $phoneVisible ? 'true' : 'false',
                'user_id' => $user['id'],
            ]);
            if ($receiveCategories !== null) {
                $this->replaceCategoryPreferences($pdo, (string) $user['id'], 'receive', $receiveCategories);
            }
            if ($provideCategories !== null) {
                $this->replaceCategoryPreferences($pdo, (string) $user['id'], 'provide', $provideCategories);
            }
        });
        return $this->findOwn((string) $user['id']);
    }

    /** @return array{receive: list<string>, provide: list<string>, details: array{receive: list<array<string, string>>, provide: list<array<string, string>>}} */
    private function categoryPreferences(string $userId): array
    {
        $preferences = $this->database->fetchAll(
            'select preference.category_id, preference.preference_type, category.label
             from profile_category_preferences preference
             join categories category on category.id = preference.category_id
             where preference.user_id = :user_id
             order by preference.preference_type, category.sort_order, category.label',
            ['user_id' => $userId],
        );
        $result = [
            'receive' => [],
            'provide' => [],
            'details' => ['receive' => [], 'provide' => []],
        ];
        foreach ($preferences as $preference) {
            $type = (string) $preference['preference_type'];
            if (!isset($result[$type])) {
                continue;
            }
            $id = (string) $preference['category_id'];
            $result[$type][] = $id;
            $result['details'][$type][] = ['id' => $id, 'label' => (string) $preference['label']];
        }
        return $result;
    }

    /** @return list<string> */
    private function validateCategoryPreferences(mixed $value): array
    {
        if (!is_array($value) || count($value) > 30) {
            throw new HttpException(422, 'Kategori tercihleri geçersiz.', 'validation_failed');
        }
        $ids = [];
        foreach ($value as $categoryId) {
            $id = trim((string) $categoryId);
            if ($id === '' || isset($ids[$id])) {
                continue;
            }
            if ($this->database->fetchOne(
                'select id from categories where id = :id and is_active = true',
                ['id' => $id],
            ) === null) {
                throw new HttpException(422, 'Seçilen kategorilerden biri artık kullanılamıyor.', 'validation_failed');
            }
            $ids[$id] = true;
        }
        return array_keys($ids);
    }

    /** @param list<string> $categoryIds */
    private function replaceCategoryPreferences(PDO $pdo, string $userId, string $type, array $categoryIds): void
    {
        $pdo->prepare(
            'delete from profile_category_preferences where user_id = :user_id and preference_type = :type'
        )->execute(['user_id' => $userId, 'type' => $type]);
        $insert = $pdo->prepare(
            'insert into profile_category_preferences (user_id, category_id, preference_type)
             values (:user_id, :category_id, :type)'
        );
        foreach ($categoryIds as $categoryId) {
            $insert->execute(['user_id' => $userId, 'category_id' => $categoryId, 'type' => $type]);
        }
    }

    /** @return array{phone_e164: string} */
    public function revealPhone(string $profileId, string $viewerId, Request $request): array
    {
        if (!Uuid::isValid($profileId)) {
            throw new HttpException(404, 'Telefon paylaşımı bulunamadı.', 'phone_not_available');
        }
        $profile = $this->database->fetchOne(
            "select p.phone_e164 from profiles p join users u on u.id = p.user_id
             where p.user_id = :profile_id and p.phone_visible = true and p.phone_e164 is not null
               and p.phone_verified_at is not null
               and u.is_suspended = false
               and not exists (
                 select 1 from user_blocks b
                 where (b.blocker_id = :viewer_id and b.blocked_user_id = :profile_id_blocked)
                    or (b.blocker_id = :profile_id_blocker and b.blocked_user_id = :viewer_id_blocked)
               )",
            [
                'profile_id' => $profileId,
                'viewer_id' => $viewerId,
                'profile_id_blocked' => $profileId,
                'profile_id_blocker' => $profileId,
                'viewer_id_blocked' => $viewerId,
            ],
        );
        if ($profile === null) {
            throw new HttpException(404, 'Bu kullanıcı telefon numarasını paylaşmıyor.', 'phone_not_available');
        }
        $this->database->statement(
            "insert into analytics_events (user_id,event_type,subject_type,subject_id,request_id,ip_address)
             values (:user_id,'phone_reveal','profile',:subject_id,:request_id,cast(:ip_address as inet))",
            [
                'user_id' => $viewerId,
                'subject_id' => $profileId,
                'request_id' => RequestContext::requestId(),
                'ip_address' => $request->clientIp(),
            ],
        );
        return ['phone_e164' => (string) $profile['phone_e164']];
    }

    private function normalizePhone(string $value): ?string
    {
        $phone = preg_replace('/[\s().-]+/', '', trim($value)) ?? '';
        if ($phone === '') {
            return null;
        }
        if (preg_match('/^0[1-9][0-9]{9}$/', $phone) === 1) {
            $phone = '+90' . substr($phone, 1);
        } elseif (preg_match('/^5[0-9]{9}$/', $phone) === 1) {
            $phone = '+90' . $phone;
        }
        if (preg_match('/^\+[1-9][0-9]{7,14}$/', $phone) !== 1) {
            throw new HttpException(422, 'Telefon numarasını +905xxxxxxxxx biçiminde yazmalısın.', 'validation_failed');
        }
        return $phone;
    }
}
