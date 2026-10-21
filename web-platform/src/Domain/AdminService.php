<?php

declare(strict_types=1);

namespace App\Domain;

use App\Core\Database;
use App\Core\HttpException;
use App\Core\Request;
use App\Storage\StorageFactory;
use App\Support\Uuid;
use PDO;
use Throwable;

final class AdminService
{
    public function __construct(
        private readonly Database $database,
        private readonly ?ListingService $listingService = null,
    ) {}

    /** @return array<string, mixed> */
    public function dashboard(): array
    {
        $summary = $this->database->fetchOne(
            "select (select count(*) from users where anonymized_at is null) as users,
                    (select count(*) from listings where status = 'active') as active_listings,
                    (select count(*) from listings where status = 'pending') as pending_listings,
                    (select count(*) from listings where status in ('pending','paused')) as listings_waiting,
                    (select count(*) from messages where deleted_at is null) as messages,
                    (select count(*) from reports where status in ('open','reviewing')) as open_reports,
                    (select count(*) from reports where status = 'open' and created_at < now() - interval '24 hours') as overdue_reports,
                    (select count(*) from reports where priority in ('high','critical') and status in ('open','reviewing')) as urgent_reports,
                    (select count(*) from privacy_requests where status in ('pending','processing')) as privacy_requests"
        ) ?? [];

        $summary['reports_by_reason'] = $this->database->fetchAll(
            "select reason, count(*) filter (where status in ('open','reviewing')) as open_count,
                    count(*) as total_count
             from reports group by reason order by open_count desc, total_count desc, reason"
        );
        $summary['reports_by_status'] = $this->database->fetchAll(
            'select status, count(*) as count from reports group by status order by status'
        );
        $summary['recent_activity'] = $this->database->fetchAll(
            "select a.id, a.action, a.entity_type, a.entity_id, a.created_at,
                    coalesce(p.display_name, 'Sistem') as admin_name
             from admin_audit_logs a
             left join profiles p on p.user_id = a.admin_user_id
             order by a.id desc limit 8"
        );

        return $summary;
    }

    /** @return list<array<string, mixed>> */
    public function users(string $query = '', string $status = '', string $role = ''): array
    {
        return $this->database->fetchAll(
            "select u.id, u.email, u.role, u.email_verified_at, u.is_suspended, u.suspended_reason,
                    u.created_at, p.display_name, p.city, p.district,
                    (select count(*) from listings l where l.owner_id = u.id and l.status <> 'removed') as listing_count,
                    (select count(*) from reports r where r.reported_user_id = u.id and r.status in ('open','reviewing')) as open_report_count
             from users u join profiles p on p.user_id = u.id
             where (:query = '' or lower(u.email) like lower(:pattern) or lower(p.display_name) like lower(:pattern_copy))
               and (:status = '' or (:status = 'suspended' and u.is_suspended) or (:status = 'active' and not u.is_suspended))
               and (:role = '' or u.role = :role_copy)
             order by u.created_at desc limit 200",
            [
                'query' => trim($query),
                'pattern' => '%' . trim($query) . '%',
                'pattern_copy' => '%' . trim($query) . '%',
                'status' => $status,
                'role' => $role,
                'role_copy' => $role,
            ],
        );
    }

    /** @return list<array<string, mixed>> */
    public function listings(string $query = '', string $status = '', string $type = ''): array
    {
        return $this->database->fetchAll(
            "select l.id, l.slug, l.status, l.listing_type, l.moderation_note, l.created_at,
                    l.submitted_at, l.moderation_score, l.moderation_flags, l.reviewed_at,
                    l.public_city, l.public_district, l.public_neighborhood,
                    p.display_name as owner_name, li.title, li.category_id, li.price_amount, li.pricing_unit,
                    (select count(*) from reports r where r.listing_id = l.id and r.status in ('open','reviewing')) as open_reports
             from listings l join profiles p on p.user_id = l.owner_id
             left join lateral (select title,category_id,price_amount,pricing_unit from listing_items where listing_id=l.id order by page_index limit 1) li on true
             where (:query = '' or lower(l.slug) like lower(:pattern) or lower(p.display_name) like lower(:pattern_copy) or lower(coalesce(li.title,'')) like lower(:pattern_title))
               and (:status = '' or l.status = :status_copy)
               and (:type = '' or l.listing_type = :type_copy)
             order by case when l.status='pending' then 0 else 1 end,
                      case when l.status='pending' then l.moderation_score else 0 end desc,
                      (select count(*) from reports r where r.listing_id=l.id and r.status in ('open','reviewing')) desc,
                      case when l.status='pending' then l.submitted_at end asc nulls last,
                      l.created_at desc limit 300"
            , [
                'query' => trim($query),
                'pattern' => '%' . trim($query) . '%',
                'pattern_copy' => '%' . trim($query) . '%',
                'pattern_title' => '%' . trim($query) . '%',
                'status' => $status,
                'status_copy' => $status,
                'type' => $type,
                'type_copy' => $type,
            ]
        );
    }

    /** @return array<string, int> */
    public function listingSummary(): array
    {
        $row = $this->database->fetchOne(
            "select count(*) filter (where status = 'pending')::int as pending,
                    count(*) filter (where status = 'active')::int as active,
                    count(*) filter (where status = 'paused')::int as paused,
                    count(*) filter (where status = 'rejected')::int as rejected
             from listings"
        ) ?? [];
        return [
            'pending' => (int) ($row['pending'] ?? 0),
            'active' => (int) ($row['active'] ?? 0),
            'paused' => (int) ($row['paused'] ?? 0),
            'rejected' => (int) ($row['rejected'] ?? 0),
        ];
    }

    /** @return list<array<string, mixed>> */
    public function reports(string $query = '', string $status = '', string $reason = '', string $priority = ''): array
    {
        return $this->database->fetchAll(
            "select r.id, r.reason, r.details, r.status, r.priority, r.admin_note, r.created_at, r.updated_at,
                    r.resolved_at, r.listing_id, r.reported_user_id,
                    reporter.display_name as reporter_name, reporter_user.email as reporter_email,
                    target.display_name as reported_user_name, target_user.email as reported_user_email,
                    assignee.display_name as assigned_admin_name, resolver.display_name as resolved_admin_name,
                    li.title as listing_title, l.slug as listing_slug
             from reports r join profiles reporter on reporter.user_id=r.reporter_id
             join users reporter_user on reporter_user.id=r.reporter_id
             left join profiles target on target.user_id=r.reported_user_id
             left join users target_user on target_user.id=r.reported_user_id
             left join profiles assignee on assignee.user_id=r.assigned_to
             left join profiles resolver on resolver.user_id=r.resolved_by
             left join listings l on l.id=r.listing_id
             left join lateral (select title from listing_items where listing_id=r.listing_id order by page_index limit 1) li on true
             where (:query = '' or lower(r.details) like lower(:pattern) or lower(reporter.display_name) like lower(:pattern_reporter)
                    or lower(coalesce(target.display_name,'')) like lower(:pattern_target) or lower(coalesce(li.title,'')) like lower(:pattern_listing))
               and (:status = '' or r.status = :status_copy)
               and (:reason = '' or r.reason = :reason_copy)
               and (:priority = '' or r.priority = :priority_copy)
             order by case r.status when 'open' then 0 when 'reviewing' then 1 else 2 end,
                      case r.priority when 'critical' then 0 when 'high' then 1 when 'normal' then 2 else 3 end,
                      r.created_at desc limit 300",
            [
                'query' => trim($query),
                'pattern' => '%' . trim($query) . '%',
                'pattern_reporter' => '%' . trim($query) . '%',
                'pattern_target' => '%' . trim($query) . '%',
                'pattern_listing' => '%' . trim($query) . '%',
                'status' => $status,
                'status_copy' => $status,
                'reason' => $reason,
                'reason_copy' => $reason,
                'priority' => $priority,
                'priority_copy' => $priority,
            ]
        );
    }

    /** @return array<string, mixed> */
    public function reportSummary(): array
    {
        return [
            'by_reason' => $this->database->fetchAll(
                "select reason, count(*) filter (where status = 'open') as open_count,
                        count(*) filter (where status = 'reviewing') as reviewing_count,
                        count(*) filter (where status in ('resolved','rejected')) as closed_count,
                        count(*) as total_count
                 from reports group by reason order by total_count desc, reason"
            ),
            'by_status' => $this->database->fetchAll(
                'select status, count(*) as count from reports group by status order by status'
            ),
            'unassigned' => (int) (($this->database->fetchOne(
                "select count(*) as count from reports where assigned_to is null and status in ('open','reviewing')"
            )['count'] ?? 0)),
        ];
    }

    /** @return list<array<string, mixed>> */
    public function categories(): array
    {
        return $this->database->fetchAll(
            "select c.id,c.label,c.parent_id,c.sort_order,c.is_active,c.is_selectable,c.is_open_ended,c.created_at,c.updated_at,
                    (select count(*) from categories child where child.parent_id=c.id) as child_count,
                    (select count(*) from listing_items li where li.category_id=c.id) as listing_count
             from categories c order by c.parent_id nulls first,c.sort_order,c.label"
        );
    }

    /** @param array<string, mixed> $payload @param array<string, mixed> $actor @return array<string, mixed> */
    public function createCategory(array $payload, array $actor, Request $request): array
    {
        $label = trim((string) ($payload['label'] ?? ''));
        $id = trim((string) ($payload['id'] ?? ''));
        $parentId = trim((string) ($payload['parent_id'] ?? ''));
        if ($id === '') $id = $this->categoryIdFromLabel($label);
        $this->validateCategoryInput($id, $label, $parentId);
        if ($parentId !== '' && $this->database->fetchOne('select id from categories where id=:id', ['id'=>$parentId]) === null) {
            throw new HttpException(422, 'Seçilen ana kategori bulunamadı.', 'parent_category_not_found');
        }

        return $this->database->transaction(function (PDO $pdo) use ($payload,$actor,$request,$id,$label,$parentId): array {
            try {
                $statement = $pdo->prepare(
                    'insert into categories (id,label,parent_id,sort_order,is_open_ended,is_active,is_selectable,updated_at)
                     values (:id,:label,:parent,:sort,:open_ended,:active,:selectable,now()) returning *'
                );
                $statement->execute([
                    'id'=>$id,
                    'label'=>$label,
                    'parent'=>$parentId === '' ? null : $parentId,
                    'sort'=>max(0,(int)($payload['sort_order'] ?? 0)),
                    'open_ended'=>!empty($payload['is_open_ended'])?'true':'false',
                    'active'=>array_key_exists('is_active',$payload) && empty($payload['is_active'])?'false':'true',
                    'selectable'=>array_key_exists('is_selectable',$payload) && empty($payload['is_selectable'])?'false':'true',
                ]);
            } catch (\PDOException $exception) {
                if ($exception->getCode() === '23505') throw new HttpException(409,'Bu kategori kodu zaten kullanılıyor.','category_exists');
                throw $exception;
            }
            $row=$statement->fetch(PDO::FETCH_ASSOC);
            if ($row===false) throw new HttpException(500,'Kategori oluşturulamadı.','category_create_failed');
            $this->audit($pdo,$actor,'category.create','category',$id,$payload,$request);
            return $row;
        });
    }

    /** @param array<string, mixed> $payload @param array<string, mixed> $actor */
    public function updateCategory(string $id, array $payload, array $actor, Request $request): void
    {
        $label = trim((string)($payload['label'] ?? ''));
        $parentId = trim((string)($payload['parent_id'] ?? ''));
        $this->validateCategoryInput($id,$label,$parentId);
        if ($parentId === $id) throw new HttpException(422,'Kategori kendisinin altında olamaz.','category_cycle');
        if ($parentId !== '') {
            $cycle = $this->database->fetchOne(
                'with recursive descendants as (
                   select id from categories where parent_id=:id
                   union all select c.id from categories c join descendants d on c.parent_id=d.id
                 ) select id from descendants where id=:parent limit 1',
                ['id'=>$id,'parent'=>$parentId]
            );
            if ($cycle !== null) throw new HttpException(422,'Kategori ağacında döngü oluşturulamaz.','category_cycle');
            if ($this->database->fetchOne('select id from categories where id=:id', ['id'=>$parentId]) === null) {
                throw new HttpException(422,'Seçilen ana kategori bulunamadı.','parent_category_not_found');
            }
        }
        $this->database->transaction(function (PDO $pdo) use ($id,$payload,$label,$parentId,$actor,$request): void {
            $statement=$pdo->prepare('update categories set label=:label,parent_id=:parent,is_active=:active,is_selectable=:selectable,is_open_ended=:open_ended,sort_order=:sort,updated_at=now() where id=:id');
            $statement->execute([
                'label'=>$label,
                'parent'=>$parentId === '' ? null : $parentId,
                'active'=>!empty($payload['is_active'])?'true':'false',
                'selectable'=>!empty($payload['is_selectable'])?'true':'false',
                'open_ended'=>!empty($payload['is_open_ended'])?'true':'false',
                'sort'=>max(0,(int)($payload['sort_order'] ?? 0)),
                'id'=>$id,
            ]);
            if ($statement->rowCount() !== 1) throw new HttpException(404,'Kategori bulunamadı.','category_not_found');
            $this->audit($pdo,$actor,'category.update','category',$id,$payload,$request);
        });
    }

    /** @param array<string, mixed> $actor @return array<string, mixed> */
    public function deleteCategory(string $id, array $actor, Request $request): array
    {
        if (!preg_match('/^[a-z0-9_]{2,64}$/', $id)) throw new HttpException(422,'Kategori kodu geçersiz.','validation_failed');
        $usage=$this->database->fetchOne(
            'select (select count(*) from categories where parent_id=:id) as children,
                    (select count(*) from listing_items where category_id=:id_copy) as listings,
                    (select label from categories where id=:id_label) as label',
            ['id'=>$id,'id_copy'=>$id,'id_label'=>$id]
        );
        if ($usage===null || $usage['label']===null) throw new HttpException(404,'Kategori bulunamadı.','category_not_found');

        return $this->database->transaction(function (PDO $pdo) use ($id,$usage,$actor,$request): array {
            $inUse=(int)$usage['children']>0 || (int)$usage['listings']>0;
            if ($inUse) {
                $pdo->prepare('update categories set is_active=false,updated_at=now() where id=:id')->execute(['id'=>$id]);
                $result=['deleted'=>false,'archived'=>true,'message'=>'Kategori kullanımda olduğu için arşivlendi.'];
                $action='category.archive';
            } else {
                $pdo->prepare('delete from categories where id=:id')->execute(['id'=>$id]);
                $result=['deleted'=>true,'archived'=>false,'message'=>'Kategori kalıcı olarak silindi.'];
                $action='category.delete';
            }
            $this->audit($pdo,$actor,$action,'category',$id,['usage'=>$usage],$request);
            return $result;
        });
    }

    /** @return list<array<string, mixed>> */
    public function banners(): array
    {
        return $this->database->fetchAll('select id,title,body,image_path,target_url,placement,is_active,starts_at,ends_at,created_at,updated_at from banners order by created_at desc');
    }

    /** @param array<string, mixed> $payload @param array<string, mixed> $actor @return array<string, mixed> */
    public function saveBanner(array $payload, array $actor, Request $request, ?string $id = null): array
    {
        $title=trim((string)($payload['title'] ?? '')); if ($title==='' || mb_strlen($title)>160) throw new HttpException(422,'Banner başlığı geçersiz.','validation_failed');
        return $this->database->transaction(function (PDO $pdo) use ($payload,$actor,$request,$id,$title): array {
            $values=['title'=>$title,'body'=>mb_substr(trim((string)($payload['body'] ?? '')),0,500),'image'=>trim((string)($payload['image_path'] ?? '')) ?: null,'url'=>trim((string)($payload['target_url'] ?? '')) ?: null,'placement'=>mb_substr(trim((string)($payload['placement'] ?? 'home')),0,50),'active'=>!empty($payload['is_active'])?'true':'false','starts'=>($payload['starts_at'] ?? null) ?: null,'ends'=>($payload['ends_at'] ?? null) ?: null];
            if ($id !== null) {
                if (!Uuid::isValid($id)) throw new HttpException(404,'Banner bulunamadı.','banner_not_found');
                $statement=$pdo->prepare('update banners set title=:title,body=:body,image_path=:image,target_url=:url,placement=:placement,is_active=:active,starts_at=:starts,ends_at=:ends,updated_at=now() where id=:id returning *');
                $statement->execute([...$values,'id'=>$id]);
            } else {
                $statement=$pdo->prepare('insert into banners (title,body,image_path,target_url,placement,is_active,starts_at,ends_at) values (:title,:body,:image,:url,:placement,:active,:starts,:ends) returning *');
                $statement->execute($values);
            }
            $row=$statement->fetch(PDO::FETCH_ASSOC); if ($row===false) throw new HttpException(404,'Banner kaydedilemedi.','banner_not_found');
            $this->audit($pdo,$actor,'banner.save','banner',(string)$row['id'],$payload,$request); return $row;
        });
    }

    /** @param array<string, mixed> $actor */
    public function deleteBanner(string $id, array $actor, Request $request): void
    {
        if (!Uuid::isValid($id)) throw new HttpException(404,'Banner bulunamadı.','banner_not_found');
        $this->database->transaction(function (PDO $pdo) use ($id,$actor,$request): void {
            $statement=$pdo->prepare('delete from banners where id=:id');
            $statement->execute(['id'=>$id]);
            if ($statement->rowCount() !== 1) throw new HttpException(404,'Banner bulunamadı.','banner_not_found');
            $this->audit($pdo,$actor,'banner.delete','banner',$id,[],$request);
        });
    }

    /** @param array<string, mixed> $actor */
    public function suspendUser(string $userId, bool $suspend, string $reason, array $actor, Request $request): void
    {
        if (!Uuid::isValid($userId) || $userId === $actor['id']) throw new HttpException(422, 'Bu kullanıcı üzerinde işlem yapılamaz.', 'validation_failed');
        $target = $this->database->fetchOne('select role from users where id=:id', ['id' => $userId]);
        if ($target === null || ($target['role'] === 'super_admin' && $actor['role'] !== 'super_admin')) throw new HttpException(403, 'Bu kullanıcı üzerinde yetkin yok.', 'admin_permission_denied');
        $this->database->transaction(function (PDO $pdo) use ($userId, $suspend, $reason, $actor, $request): void {
            $pdo->prepare('update users set is_suspended=:suspended, suspended_reason=:reason, suspended_at=case when :suspended_copy then now() else null end, updated_at=now() where id=:id')
                ->execute(['suspended' => $suspend ? 'true' : 'false', 'reason' => $suspend ? mb_substr(trim($reason), 0, 500) : '', 'suspended_copy' => $suspend ? 'true' : 'false', 'id' => $userId]);
            if ($suspend) {
                $pdo->prepare('update user_sessions set revoked_at=now() where user_id=:id and revoked_at is null')->execute(['id' => $userId]);
                $pdo->prepare('update api_token_families set revoked_at=now() where user_id=:id and revoked_at is null')->execute(['id' => $userId]);
            }
            $this->audit($pdo, $actor, $suspend ? 'user.suspend' : 'user.unsuspend', 'user', $userId, ['reason' => $reason], $request);
        });
    }

    /** @param array<string, mixed> $actor */
    public function moderateListing(string $listingId, string $status, string $note, array $actor, Request $request): void
    {
        if (!Uuid::isValid($listingId) || !in_array($status, ['pending','active','paused','rejected','removed'], true)) throw new HttpException(422, 'İlan moderasyon bilgisi geçersiz.', 'validation_failed');
        $this->database->transaction(function (PDO $pdo) use ($listingId, $status, $note, $actor, $request): void {
            $target = $pdo->prepare(
                'select l.owner_id, l.status, coalesce(li.title, l.slug) as title
                 from listings l
                 left join lateral (select title from listing_items where listing_id=l.id order by page_index limit 1) li on true
                 where l.id=:id for update of l'
            );
            $target->execute(['id' => $listingId]);
            $listing = $target->fetch(PDO::FETCH_ASSOC);
            if ($listing === false) throw new HttpException(404, 'İlan bulunamadı.', 'listing_not_found');

            $statement = $pdo->prepare(
                'update listings set status=:status, moderation_note=:note, reviewed_at=now(),
                 reviewed_by=:reviewed_by, updated_at=now() where id=:id'
            );
            $statement->execute([
                'status' => $status,
                'note' => mb_substr(trim($note), 0, 1000),
                'reviewed_by' => $actor['id'],
                'id' => $listingId,
            ]);
            if ($statement->rowCount() !== 1) throw new HttpException(404, 'İlan bulunamadı.', 'listing_not_found');

            $title = match ($status) {
                'active' => 'İlanın onaylandı',
                'rejected' => 'İlanın için düzenleme gerekiyor',
                'paused' => 'İlanın yayını durduruldu',
                'removed' => 'İlanın yayından kaldırıldı',
                default => 'İlanın yeniden incelenecek',
            };
            $body = mb_substr((string) $listing['title'] . ($note !== '' ? ' · ' . trim($note) : ''), 0, 500);
            $notification = $pdo->prepare(
                "insert into notifications (user_id, type, title, body, data)
                 values (:user_id, 'listing', :title, :body, cast(:data as jsonb)) returning id"
            );
            $notification->execute([
                'user_id' => $listing['owner_id'],
                'title' => $title,
                'body' => $body,
                'data' => json_encode(['listing_id' => $listingId, 'status' => $status], JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE),
            ]);
            $notificationId = (int) $notification->fetchColumn();
            $pdo->prepare(
                'insert into realtime_outbox (channel, event_type, payload)
                 values (:channel, :event_type, cast(:payload as jsonb))'
            )->execute([
                'channel' => 'user:' . $listing['owner_id'],
                'event_type' => 'notification.created',
                'payload' => json_encode([
                    'notification_id' => $notificationId,
                    'type' => 'listing',
                    'listing_id' => $listingId,
                    'status' => $status,
                ], JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE),
            ]);
            $this->audit($pdo, $actor, 'listing.moderate', 'listing', $listingId, ['status'=>$status,'note'=>$note], $request);
        });
        if ($status === 'active') {
            $this->listingService?->notifyApproved($listingId);
        }
    }

    /** @param array<string, mixed> $actor @return array<string, mixed> */
    public function permanentlyDeleteListing(string $listingId, string $reason, string $confirmation, array $actor, Request $request): array
    {
        $this->assertPermanentDeletion($reason, $confirmation, $actor);
        if (!Uuid::isValid($listingId)) throw new HttpException(404, 'İlan bulunamadı.', 'listing_not_found');

        $media = [];
        $result = $this->database->transaction(function (PDO $pdo) use ($listingId, $reason, $actor, $request, &$media): array {
            $find = $pdo->prepare(
                'select l.id,l.owner_id,l.slug,coalesce(li.title,l.slug) as title
                 from listings l
                 left join lateral (select title from listing_items where listing_id=l.id order by page_index limit 1) li on true
                 where l.id=:id for update of l'
            );
            $find->execute(['id'=>$listingId]);
            $listing = $find->fetch(PDO::FETCH_ASSOC);
            if ($listing === false) throw new HttpException(404, 'İlan bulunamadı.', 'listing_not_found');

            $mediaStatement = $pdo->prepare(
                'select distinct m.id,m.storage_driver,m.storage_key
                 from listing_images i join media_objects m on m.id=i.media_id
                 where i.listing_id=:id'
            );
            $mediaStatement->execute(['id'=>$listingId]);
            $media = $mediaStatement->fetchAll(PDO::FETCH_ASSOC);

            $this->audit($pdo,$actor,'listing.delete_permanent','listing',$listingId,[
                'reason'=>mb_substr(trim($reason),0,500),
                'title'=>$listing['title'],
                'owner_id'=>$listing['owner_id'],
                'media_count'=>count($media),
            ],$request);
            if ($media !== []) {
                $deleteMedia = $pdo->prepare('delete from media_objects where id=:id');
                foreach ($media as $object) {
                    $deleteMedia->execute(['id'=>$object['id']]);
                }
            }
            $delete = $pdo->prepare('delete from listings where id=:id');
            $delete->execute(['id'=>$listingId]);
            if ($delete->rowCount() !== 1) throw new HttpException(409, 'İlan silinemedi.', 'listing_delete_failed');

            return ['deleted'=>true,'id'=>$listingId,'title'=>$listing['title'],'media_count'=>count($media)];
        });

        return [...$result, ...$this->deleteStorageObjects($media)];
    }

    /** @param array<string, mixed> $actor @return array<string, mixed> */
    public function permanentlyDeleteUser(string $userId, string $reason, string $confirmation, array $actor, Request $request): array
    {
        $this->assertPermanentDeletion($reason, $confirmation, $actor);
        if (!Uuid::isValid($userId) || $userId === (string)$actor['id']) {
            throw new HttpException(422, 'Bu kullanıcı üzerinde işlem yapılamaz.', 'validation_failed');
        }

        $media = [];
        $result = $this->database->transaction(function (PDO $pdo) use ($userId, $reason, $actor, $request, &$media): array {
            $find = $pdo->prepare(
                'select u.id,u.role,p.display_name,
                        (select count(*) from listings where owner_id=u.id) as listing_count,
                        (select count(*) from admin_audit_logs where admin_user_id=u.id) as audit_count
                 from users u join profiles p on p.user_id=u.id where u.id=:id for update of u'
            );
            $find->execute(['id'=>$userId]);
            $target = $find->fetch(PDO::FETCH_ASSOC);
            if ($target === false) throw new HttpException(404, 'Kullanıcı bulunamadı.', 'user_not_found');
            if ($target['role'] !== 'user' || (int)$target['audit_count'] > 0) {
                throw new HttpException(403, 'Yönetici hesapları kalıcı olarak silinemez.', 'protected_admin_account');
            }

            $mediaStatement = $pdo->prepare('select id,storage_driver,storage_key from media_objects where owner_id=:id');
            $mediaStatement->execute(['id'=>$userId]);
            $media = $mediaStatement->fetchAll(PDO::FETCH_ASSOC);

            $this->audit($pdo,$actor,'user.delete_permanent','user',$userId,[
                'reason'=>mb_substr(trim($reason),0,500),
                'display_name'=>$target['display_name'],
                'listing_count'=>(int)$target['listing_count'],
                'media_count'=>count($media),
            ],$request);
            $pdo->prepare('delete from privacy_requests where user_id=:id')->execute(['id'=>$userId]);
            $delete = $pdo->prepare('delete from users where id=:id');
            $delete->execute(['id'=>$userId]);
            if ($delete->rowCount() !== 1) throw new HttpException(409, 'Kullanıcı silinemedi.', 'user_delete_failed');

            return [
                'deleted'=>true,
                'id'=>$userId,
                'display_name'=>$target['display_name'],
                'listing_count'=>(int)$target['listing_count'],
                'media_count'=>count($media),
            ];
        });

        return [...$result, ...$this->deleteStorageObjects($media)];
    }

    /** @param array<string, mixed> $actor */
    public function updateReport(string $reportId, array $payload, array $actor, Request $request): void
    {
        $status=(string)($payload['status'] ?? '');
        $priority=(string)($payload['priority'] ?? 'normal');
        $adminNote=trim((string)($payload['admin_note'] ?? ''));
        if (!Uuid::isValid($reportId) || !in_array($status, ['open','reviewing','resolved','rejected'], true)) throw new HttpException(422, 'Şikâyet durumu geçersiz.', 'validation_failed');
        if (!in_array($priority,['low','normal','high','critical'],true) || mb_strlen($adminNote)>2000) throw new HttpException(422,'Şikâyet yönetim bilgisi geçersiz.','validation_failed');
        $this->database->transaction(function (PDO $pdo) use ($reportId,$status,$priority,$adminNote,$actor,$request): void {
            $statement = $pdo->prepare(
                "update reports set status=:status,priority=:priority,admin_note=:note,
                        assigned_to=case when :status_copy='open' then null::uuid else coalesce(assigned_to,cast(:admin as uuid)) end,
                        resolved_by=case when :status_resolved in ('resolved','rejected') then cast(:admin_resolved as uuid) else null::uuid end,
                        resolved_at=case when :status_at in ('resolved','rejected') then now() else null end,
                        updated_at=now()
                 where id=:id"
            );
            $statement->execute([
                'status'=>$status,
                'priority'=>$priority,
                'note'=>$adminNote,
                'status_copy'=>$status,
                'status_resolved'=>$status,
                'status_at'=>$status,
                'admin'=>$actor['id'],
                'admin_resolved'=>$actor['id'],
                'id'=>$reportId,
            ]);
            if ($statement->rowCount() !== 1) throw new HttpException(404, 'Şikâyet bulunamadı.', 'report_not_found');
            $this->audit($pdo,$actor,'report.update','report',$reportId,['status'=>$status,'priority'=>$priority,'admin_note'=>$adminNote],$request);
        });
    }

    /** @return array<string, mixed> */
    public function trustOperations(): array
    {
        return [
            'engagements' => $this->database->fetchAll(
                "select e.id,e.status,e.service_name_snapshot,e.agreed_price_amount,e.currency_snapshot,
                        e.dispute_reason,e.updated_at,requester.display_name requester_name,
                        provider.display_name provider_name,
                        (select count(*) from reports r where r.engagement_id=e.id and r.status in ('open','reviewing')) open_reports
                 from service_engagements e
                 join profiles requester on requester.user_id=e.requester_id
                 join profiles provider on provider.user_id=e.provider_id
                 where e.status in ('requested','provider_completed','disputed')
                 order by case e.status when 'disputed' then 0 when 'provider_completed' then 1 else 2 end,e.updated_at asc limit 150"
            ),
            'reviews' => $this->database->fetchAll(
                "select r.id,r.rating,r.comment,r.status,r.moderation_note,r.submitted_at,
                        author.display_name author_name,reviewed.display_name reviewed_name,e.service_name_snapshot
                 from reviews r join profiles author on author.user_id=r.author_id
                 join profiles reviewed on reviewed.user_id=r.reviewed_user_id
                 join service_engagements e on e.id=r.engagement_id
                 where r.status in ('pending','hidden')
                 order by r.submitted_at asc limit 150"
            ),
            'risk_signals' => $this->database->fetchAll(
                "select rs.id,rs.signal_type,rs.score,rs.evidence,rs.status,rs.created_at,
                        p.display_name user_name,rp.display_name related_user_name
                 from risk_signals rs left join profiles p on p.user_id=rs.user_id
                 left join profiles rp on rp.user_id=rs.related_user_id
                 where rs.status in ('open','reviewing') order by rs.score desc,rs.created_at asc limit 150"
            ),
            'beta_feedback' => $this->database->fetchAll(
                "select f.id,f.kind,f.title,f.details,f.status,f.admin_note,f.created_at,p.display_name user_name
                 from beta_feedback f join profiles p on p.user_id=f.user_id
                 where f.status not in ('resolved','closed') order by f.created_at desc limit 150"
            ),
            'beta_members' => $this->database->fetchAll(
                "select bm.user_id,bm.enabled,bm.joined_at,bm.last_seen_at,p.display_name,
                        coalesce(nullif(split_part(u.email,'@',1),''),'kullanici') email_hint
                 from beta_members bm join users u on u.id=bm.user_id
                 join profiles p on p.user_id=bm.user_id
                 order by bm.joined_at desc limit 150"
            ),
        ];
    }

    /** @param array<string, mixed> $actor */
    public function moderateEngagement(string $id, string $status, string $note, array $actor, Request $request): void
    {
        if (!Uuid::isValid($id) || !in_array($status, ['completed','canceled'], true) || mb_strlen($note) < 5 || mb_strlen($note) > 2000) {
            throw new HttpException(422, 'İş çözüm bilgisi geçersiz.', 'validation_failed');
        }
        $this->database->transaction(function (PDO $pdo) use ($id,$status,$note,$actor,$request): void {
            $row=$pdo->prepare('select status from service_engagements where id=:id for update');$row->execute(['id'=>$id]);$current=$row->fetch();
            if (!$current) throw new HttpException(404,'İş kaydı bulunamadı.','engagement_not_found');
            if (!in_array((string)$current['status'],['provider_completed','disputed'],true)) throw new HttpException(409,'Bu iş yönetici tarafından sonuçlandırılamaz.','invalid_transition');
            $pdo->prepare("update service_engagements set status=:status,completed_at=case when :completed='completed' then now() else completed_at end,canceled_at=case when :canceled='canceled' then now() else canceled_at end,cancellation_reason=case when :cancel_reason='canceled' then :note else cancellation_reason end,version=version+1,updated_at=now() where id=:id")
                ->execute(['status'=>$status,'completed'=>$status,'canceled'=>$status,'cancel_reason'=>$status,'note'=>$note,'id'=>$id]);
            $pdo->prepare('insert into service_engagement_events(engagement_id,actor_id,from_status,to_status,metadata) values(:id,:actor,:from,:to,cast(:metadata as jsonb))')
                ->execute(['id'=>$id,'actor'=>$actor['id'],'from'=>$current['status'],'to'=>$status,'metadata'=>json_encode(['admin_note'=>$note],JSON_THROW_ON_ERROR|JSON_UNESCAPED_UNICODE)]);
            $this->audit($pdo,$actor,'engagement.moderate','engagement',$id,['from'=>$current['status'],'to'=>$status,'note'=>$note],$request);
        });
    }

    /** @param array<string, mixed> $actor */
    public function moderateReview(string $id, string $status, string $note, array $actor, Request $request): void
    {
        if (!Uuid::isValid($id) || !in_array($status,['published','hidden','removed'],true) || mb_strlen($note)>2000) throw new HttpException(422,'Değerlendirme kararı geçersiz.','validation_failed');
        $this->database->transaction(function(PDO $pdo) use($id,$status,$note,$actor,$request):void{
            $row=$pdo->prepare('select status from reviews where id=:id for update');$row->execute(['id'=>$id]);$current=$row->fetch();
            if(!$current) throw new HttpException(404,'Değerlendirme bulunamadı.','review_not_found');
            $pdo->prepare("update reviews set status=:status,moderation_note=:note,published_at=case when :publish='published' then coalesce(published_at,now()) else published_at end,updated_at=now() where id=:id")
                ->execute(['status'=>$status,'note'=>$note,'publish'=>$status,'id'=>$id]);
            $pdo->prepare('insert into review_moderation_events(review_id,actor_id,from_status,to_status,note) values(:id,:actor,:from,:to,:note)')
                ->execute(['id'=>$id,'actor'=>$actor['id'],'from'=>$current['status'],'to'=>$status,'note'=>$note]);
            $this->audit($pdo,$actor,'review.moderate','review',$id,['from'=>$current['status'],'to'=>$status,'note'=>$note],$request);
        });
    }

    /** @param array<string, mixed> $actor */
    public function moderateRisk(string $id, string $status, string $note, array $actor, Request $request): void
    {
        if(!Uuid::isValid($id)||!in_array($status,['reviewing','dismissed','confirmed'],true)||mb_strlen($note)>1000) throw new HttpException(422,'Risk kararı geçersiz.','validation_failed');
        $this->database->transaction(function(PDO $pdo) use($id,$status,$note,$actor,$request):void{
            $statement=$pdo->prepare("update risk_signals set status=:status,reviewed_by=:actor,reviewed_at=case when :done in ('dismissed','confirmed') then now() else null end,evidence=evidence||jsonb_build_object('admin_note',:note) where id=:id");
            $statement->execute(['status'=>$status,'actor'=>$actor['id'],'done'=>$status,'note'=>$note,'id'=>$id]);
            if($statement->rowCount()!==1) throw new HttpException(404,'Risk sinyali bulunamadı.','risk_not_found');
            $this->audit($pdo,$actor,'risk.moderate','risk_signal',$id,['status'=>$status,'note'=>$note],$request);
        });
    }

    /** @param array<string, mixed> $actor */
    public function moderateBetaFeedback(string $id, string $status, string $note, array $actor, Request $request): void
    {
        if(!Uuid::isValid($id)||!in_array($status,['new','reviewing','planned','resolved','closed'],true)||mb_strlen($note)>2000) throw new HttpException(422,'Beta geri bildirim kararı geçersiz.','validation_failed');
        $this->database->transaction(function(PDO $pdo) use($id,$status,$note,$actor,$request):void{
            $statement=$pdo->prepare('update beta_feedback set status=:status,admin_note=:note,updated_at=now() where id=:id');$statement->execute(['status'=>$status,'note'=>$note,'id'=>$id]);
            if($statement->rowCount()!==1) throw new HttpException(404,'Beta geri bildirimi bulunamadı.','feedback_not_found');
            $this->audit($pdo,$actor,'beta_feedback.moderate','beta_feedback',$id,['status'=>$status,'note'=>$note],$request);
        });
    }

    /** @return list<array<string, mixed>> */
    public function auditLogs(): array { return $this->database->fetchAll('select a.*, p.display_name as admin_name from admin_audit_logs a join profiles p on p.user_id=a.admin_user_id order by a.id desc limit 500'); }

    private function categoryIdFromLabel(string $label): string
    {
        $normalized=mb_strtolower($label,'UTF-8');
        $normalized=strtr($normalized,['ç'=>'c','ğ'=>'g','ı'=>'i','ö'=>'o','ş'=>'s','ü'=>'u']);
        $normalized=preg_replace('/[^a-z0-9]+/','_',$normalized) ?? '';
        return trim(mb_substr($normalized,0,64),'_');
    }

    private function validateCategoryInput(string $id, string $label, string $parentId): void
    {
        if (!preg_match('/^[a-z0-9_]{2,64}$/',$id) || mb_strlen($label)<2 || mb_strlen($label)>120) {
            throw new HttpException(422,'Kategori bilgisi geçersiz.','validation_failed');
        }
        if ($parentId!=='' && !preg_match('/^[a-z0-9_]{2,64}$/',$parentId)) {
            throw new HttpException(422,'Ana kategori bilgisi geçersiz.','validation_failed');
        }
    }

    /** @param array<string, mixed> $actor */
    private function assertPermanentDeletion(string $reason, string $confirmation, array $actor): void
    {
        if (($actor['role'] ?? '') !== 'super_admin') {
            throw new HttpException(403, 'Kalıcı silme yalnızca süper yönetici tarafından yapılabilir.', 'admin_permission_denied');
        }
        $length = mb_strlen(trim($reason));
        if ($length < 5 || $length > 500 || $confirmation !== 'KALICI OLARAK SİL') {
            throw new HttpException(422, 'Kalıcı silme nedeni ve onayı geçersiz.', 'permanent_delete_confirmation_required');
        }
    }

    /** @param list<array<string, mixed>> $objects @return array{storage_deleted: int, storage_failed: int} */
    private function deleteStorageObjects(array $objects): array
    {
        $deleted = 0;
        $failed = 0;
        foreach ($objects as $object) {
            try {
                StorageFactory::make((string)$object['storage_driver'])->delete((string)$object['storage_key']);
                $deleted++;
            } catch (Throwable) {
                $failed++;
            }
        }
        return ['storage_deleted'=>$deleted,'storage_failed'=>$failed];
    }

    /** @param array<string, mixed> $actor @param array<string, mixed> $metadata */
    private function audit(PDO $pdo, array $actor, string $action, string $entityType, string $entityId, array $metadata, Request $request): void
    {
        $pdo->prepare('insert into admin_audit_logs (admin_user_id, action, entity_type, entity_id, metadata, ip_address) values (:admin,:action,:type,:entity,cast(:metadata as jsonb),:ip)')
            ->execute(['admin'=>$actor['id'],'action'=>$action,'type'=>$entityType,'entity'=>$entityId,'metadata'=>json_encode($metadata, JSON_THROW_ON_ERROR|JSON_UNESCAPED_UNICODE),'ip'=>$request->clientIp()]);
    }
}
