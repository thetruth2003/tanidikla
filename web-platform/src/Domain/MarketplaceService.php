<?php

declare(strict_types=1);

namespace App\Domain;

use App\Core\Database;
use App\Core\HttpException;
use App\Support\Uuid;
use App\Security\ContentPolicy;
use PDO;
use PDOException;

final class MarketplaceService
{
    public function __construct(
        private readonly Database $database,
        private readonly ListingService $listings,
    ) {
    }

    /** @return array{items: list<array<string, mixed>>, pagination: array<string, int>} */
    public function favorites(string $userId, array $query = []): array
    {
        return $this->listings->favorites($userId, $query);
    }

    public function addFavorite(string $listingId, string $userId): void
    {
        $listing = $this->activeListing($listingId);
        if ((string) $listing['owner_id'] === $userId) {
            throw new HttpException(422, 'Kendi ilanını favorilere ekleyemezsin.', 'own_listing_favorite');
        }
        $this->database->statement(
            'insert into favorites (user_id, listing_id) values (:user_id, :listing_id)
             on conflict (user_id, listing_id) do nothing',
            ['user_id' => $userId, 'listing_id' => $listingId],
        );
    }

    public function removeFavorite(string $listingId, string $userId): void
    {
        if (!Uuid::isValid($listingId)) {
            throw new HttpException(404, 'İlan bulunamadı.', 'listing_not_found');
        }
        $this->database->statement(
            'delete from favorites where user_id = :user_id and listing_id = :listing_id',
            ['user_id' => $userId, 'listing_id' => $listingId],
        );
    }

    /** @return array{items: list<array<string, mixed>>, pagination: array<string, int>} */
    public function reviews(string $reviewedUserId, array $query = []): array
    {
        if (!Uuid::isValid($reviewedUserId)) {
            throw new HttpException(404, 'Profil bulunamadı.', 'profile_not_found');
        }
        $limit = max(1, min(50, (int) ($query['limit'] ?? 20)));
        $page = max(1, (int) ($query['page'] ?? 1));
        $offset = ($page - 1) * $limit;
        $this->database->statement(
            "update reviews r set status='published',published_at=now(),updated_at=now()
             where r.status='pending' and r.engagement_id is not null and r.publish_after<=now()"
        );
        $items = $this->database->fetchAll(
            "select r.id, r.listing_id, r.engagement_id, r.author_id, r.reviewed_user_id,
                    r.rating, r.comment, r.created_at, r.updated_at,
                    p.display_name as author_name, p.avatar_path as author_avatar,
                    e.service_name_snapshot as listing_title, true as verified_engagement
             from reviews r
             join profiles p on p.user_id = r.author_id
             join service_engagements e on e.id=r.engagement_id and e.status='completed'
             where r.reviewed_user_id = :reviewed_user_id and r.status = 'published'
             order by r.created_at desc limit :limit offset :offset",
            ['reviewed_user_id' => $reviewedUserId, 'limit' => $limit, 'offset' => $offset],
        );
        $count = $this->database->fetchOne(
            "select count(*)::int as total from reviews r join service_engagements e on e.id=r.engagement_id
             where r.reviewed_user_id = :reviewed_user_id and r.status = 'published' and e.status='completed'",
            ['reviewed_user_id' => $reviewedUserId],
        );
        $total = (int) ($count['total'] ?? 0);
        foreach ($items as &$item) {
            $item['rating'] = (float) $item['rating'];
        }
        unset($item);
        return [
            'items' => $items,
            'pagination' => [
                'page' => $page,
                'limit' => $limit,
                'returned' => count($items),
                'total' => $total,
                'pages' => $total === 0 ? 0 : (int) ceil($total / $limit),
            ],
        ];
    }

    /** @param array<string, mixed> $payload
     *  @return array<string, mixed>
     */
    public function createReview(array $payload, string $authorId): array
    {
        $engagementId = trim((string) ($payload['engagement_id'] ?? ''));
        if (!Uuid::isValid($engagementId)) throw new HttpException(422, 'Tamamlanan iş kaydı gerekli.', 'validation_failed');
        $rating = filter_var($payload['rating'] ?? null, FILTER_VALIDATE_FLOAT, FILTER_NULL_ON_FAILURE);
        $comment = trim((string) ($payload['comment'] ?? ''));
        if ($rating === null || $rating < 1 || $rating > 5 || floor($rating) !== $rating) {
            throw new HttpException(422, 'Puan 1–5 arasında tam sayı olmalı.', 'validation_failed');
        }
        if (mb_strlen($comment) > 1000) {
            throw new HttpException(422, 'Yorum en fazla 1000 karakter olmalı.', 'validation_failed');
        }
        if ($comment !== '') ContentPolicy::assertAcceptable($comment, 'Yorum');

        try {
            $row = $this->database->transaction(function (PDO $pdo) use ($engagementId,$authorId,$rating,$comment): array {
                $select=$pdo->prepare("select * from service_engagements where id=:id and status='completed' for update");
                $select->execute(['id'=>$engagementId]);
                $engagement=$select->fetch(PDO::FETCH_ASSOC);
                if ($engagement===false || !in_array($authorId,[(string)$engagement['requester_id'],(string)$engagement['provider_id']],true)) {
                    throw new HttpException(403,'Yalnızca tamamlanan işin tarafları değerlendirme yapabilir.','review_not_eligible');
                }
                $reviewedUserId=$authorId===(string)$engagement['requester_id']?(string)$engagement['provider_id']:(string)$engagement['requester_id'];
                if ($reviewedUserId===$authorId) throw new HttpException(422,'Kendini değerlendiremezsin.','self_review');
                $statement=$pdo->prepare(
                    "insert into reviews (id,listing_id,engagement_id,author_id,reviewed_user_id,rating,comment,status)
                     values (:id,:listing_id,:engagement_id,:author_id,:reviewed_user_id,:rating,:comment,'pending')
                     returning id,listing_id,engagement_id,author_id,reviewed_user_id,rating,comment,status,created_at,updated_at"
                );
                $statement->execute(['id'=>Uuid::v4(),'listing_id'=>$engagement['listing_id'],'engagement_id'=>$engagementId,'author_id'=>$authorId,'reviewed_user_id'=>$reviewedUserId,'rating'=>$rating,'comment'=>$comment===''?null:$comment]);
                $review=$statement->fetch(PDO::FETCH_ASSOC);
                if ($review===false) throw new HttpException(500,'Değerlendirme kaydedilemedi.','review_failed');
                $counterpart=$pdo->prepare("select id from reviews where engagement_id=:engagement and author_id<>:author and status in ('pending','published') for update");
                $counterpart->execute(['engagement'=>$engagementId,'author'=>$authorId]);
                if ($counterpart->fetchColumn()!==false) {
                    $pdo->prepare("update reviews set status='published',published_at=now(),updated_at=now() where engagement_id=:engagement and status='pending'")
                        ->execute(['engagement'=>$engagementId]);
                    $review['status']='published';
                }
                $notification=$pdo->prepare("insert into notifications (user_id,type,title,body,data) values (:user_id,'review','Yeni değerlendirme',:body,cast(:data as jsonb)) returning id");
                $data=['engagement_id'=>$engagementId,'listing_id'=>$engagement['listing_id'],'review_id'=>$review['id'],'author_id'=>$authorId,'rating'=>(float)$rating];
                $notification->execute(['user_id'=>$reviewedUserId,'body'=>$comment===''?'Tamamlanan iş için puan verildi.':mb_substr($comment,0,180),'data'=>json_encode($data,JSON_THROW_ON_ERROR|JSON_UNESCAPED_UNICODE)]);
                $notificationId=(int)$notification->fetchColumn();
                $pdo->prepare("insert into realtime_outbox (channel,event_type,payload) values (:channel,'notification.created',cast(:payload as jsonb))")
                    ->execute(['channel'=>'user:'.$reviewedUserId,'payload'=>json_encode(['notification_id'=>$notificationId,'type'=>'review',...$data],JSON_THROW_ON_ERROR|JSON_UNESCAPED_UNICODE)]);
                return $review;
            });
        } catch (PDOException $exception) {
            if ($exception->getCode() === '23505') {
                throw new HttpException(409, 'Bu iş için zaten değerlendirme yaptın.', 'review_already_exists');
            }
            throw $exception;
        }
        if ($row === null) {
            throw new HttpException(500, 'Değerlendirme kaydedilemedi.', 'review_failed');
        }
        $row['rating'] = (float) $row['rating'];
        return $row;
    }

    /** @param array<string, mixed> $payload
     *  @return array<string, mixed>
     */
    public function updateReview(string $reviewId, array $payload, string $authorId): array
    {
        if (!Uuid::isValid($reviewId)) {
            throw new HttpException(404, 'Değerlendirme bulunamadı.', 'review_not_found');
        }
        $rating = filter_var($payload['rating'] ?? null, FILTER_VALIDATE_FLOAT, FILTER_NULL_ON_FAILURE);
        $comment = trim((string) ($payload['comment'] ?? ''));
        if ($rating === null || $rating < 1 || $rating > 5 || floor($rating) !== $rating
            || mb_strlen($comment) > 1000) {
            throw new HttpException(422, 'Puan veya yorum geçersiz.', 'validation_failed');
        }
        if ($comment !== '') ContentPolicy::assertAcceptable($comment, 'Yorum');
        $row = $this->database->fetchOne(
            "update reviews set rating = :rating, comment = :comment, updated_at = now()
             where id = :id and author_id = :author_id and status in ('pending','published')
               and submitted_at > now() - interval '24 hours'
             returning id, listing_id, author_id, reviewed_user_id, rating, comment, status, created_at, updated_at",
            ['rating' => $rating, 'comment' => $comment === '' ? null : $comment, 'id' => $reviewId, 'author_id' => $authorId],
        );
        if ($row === null) {
            throw new HttpException(404, 'Düzenleyebileceğin değerlendirme bulunamadı.', 'review_not_found');
        }
        $row['rating'] = (float) $row['rating'];
        return $row;
    }

    public function removeReview(string $reviewId, string $authorId): void
    {
        if (!Uuid::isValid($reviewId)) {
            throw new HttpException(404, 'Değerlendirme bulunamadı.', 'review_not_found');
        }
        $statement = $this->database->statement(
            "update reviews set status = 'removed', updated_at = now()
             where id = :id and author_id = :author_id and status <> 'removed'",
            ['id' => $reviewId, 'author_id' => $authorId],
        );
        if ($statement->rowCount() === 0) {
            throw new HttpException(404, 'Kaldırabileceğin değerlendirme bulunamadı.', 'review_not_found');
        }
    }

    /** @param array<string, mixed> $payload
     *  @return array<string, mixed>
     */
    public function report(array $payload, string $reporterId): array
    {
        $targets = [
            'listing_id' => trim((string)($payload['listing_id'] ?? '')),
            'reported_user_id' => trim((string)($payload['reported_user_id'] ?? '')),
            'listing_item_id' => trim((string)($payload['listing_item_id'] ?? '')),
            'message_id' => trim((string)($payload['message_id'] ?? '')),
            'engagement_id' => trim((string)($payload['engagement_id'] ?? '')),
            'review_id' => trim((string)($payload['review_id'] ?? '')),
        ];
        $selected=array_filter($targets,static fn(string $value):bool=>$value!=='');
        if(count($selected)!==1) throw new HttpException(422,'Tek bir şikâyet hedefi seçmelisin.','validation_failed');
        $column=(string)array_key_first($selected);
        $target=(string)$selected[$column];
        if($column==='message_id') {
            if(!ctype_digit($target)) throw new HttpException(404,'Mesaj bulunamadı.','message_not_found');
            $row=$this->database->fetchOne('select m.sender_id from messages m join conversation_members cm on cm.conversation_id=m.conversation_id and cm.user_id=:reporter where m.id=:id and m.deleted_at is null',['reporter'=>$reporterId,'id'=>(int)$target]);
            if($row===null) throw new HttpException(404,'Mesaj bulunamadı.','message_not_found');
            if((string)$row['sender_id']===$reporterId) throw new HttpException(422,'Kendi mesajını bildiremezsin.','self_report');
        } else {
            if(!Uuid::isValid($target)) throw new HttpException(404,'Şikâyet hedefi bulunamadı.','report_target_not_found');
            $owner = match($column) {
                'listing_id' => $this->database->fetchOne('select owner_id from listings where id=:id',['id'=>$target]),
                'listing_item_id' => $this->database->fetchOne('select l.owner_id from listing_items i join listings l on l.id=i.listing_id where i.id=:id',['id'=>$target]),
                'review_id' => $this->database->fetchOne('select author_id as owner_id from reviews where id=:id and status<>\'removed\'',['id'=>$target]),
                'engagement_id' => $this->database->fetchOne('select case when requester_id=:reporter then provider_id else requester_id end as owner_id from service_engagements where id=:id and (requester_id=:reporter2 or provider_id=:reporter3)',['reporter'=>$reporterId,'reporter2'=>$reporterId,'reporter3'=>$reporterId,'id'=>$target]),
                'reported_user_id' => $this->database->fetchOne('select id as owner_id from users where id=:id',['id'=>$target]),
                default => null,
            };
            if($owner===null) throw new HttpException(404,'Şikâyet hedefi bulunamadı.','report_target_not_found');
            if((string)$owner['owner_id']===$reporterId) throw new HttpException(422,'Kendi içeriğini bildiremezsin.','self_report');
        }
        $reason = (string) ($payload['reason'] ?? '');
        $allowedReasons = ['spam', 'fraud', 'harassment', 'inappropriate', 'safety', 'other'];
        if (!in_array($reason, $allowedReasons, true)) {
            throw new HttpException(422, 'Bildirim nedeni geçersiz.', 'validation_failed');
        }
        $details = trim((string) ($payload['details'] ?? ''));
        if (mb_strlen($details) > 2000 || ($reason === 'other' && mb_strlen($details) < 10)) {
            throw new HttpException(422, 'Bildirim açıklaması uygun uzunlukta değil.', 'validation_failed');
        }
        try {
            $row = $this->database->fetchOne(
                "insert into reports (id,reporter_id,{$column},reason,details)
                 values (:id,:reporter_id,:target,:reason,:details)
                 returning id,listing_id,reported_user_id,listing_item_id,message_id,engagement_id,review_id,reason,details,status,created_at",
                ['id'=>Uuid::v4(),'reporter_id'=>$reporterId,'target'=>$target,'reason'=>$reason,'details'=>$details],
            );
        } catch (PDOException $exception) {
            if ($exception->getCode() === '23505') {
                throw new HttpException(409, 'Bu içerik için açık bir bildirimin zaten var.', 'report_already_open');
            }
            throw $exception;
        }
        if ($row === null) {
            throw new HttpException(500, 'Bildirim kaydedilemedi.', 'report_failed');
        }
        return $row;
    }

    /** @return list<array<string, mixed>> */
    public function blocks(string $userId): array
    {
        return $this->database->fetchAll(
            'select b.blocked_user_id as id, p.display_name, p.avatar_path, b.created_at
             from user_blocks b join profiles p on p.user_id = b.blocked_user_id
             where b.blocker_id = :user_id order by b.created_at desc',
            ['user_id' => $userId],
        );
    }

    public function block(string $blockedUserId, string $userId): void
    {
        if (!Uuid::isValid($blockedUserId)
            || $this->database->fetchOne('select id from users where id = :id', ['id' => $blockedUserId]) === null) {
            throw new HttpException(404, 'Kullanıcı bulunamadı.', 'profile_not_found');
        }
        if ($blockedUserId === $userId) {
            throw new HttpException(422, 'Kendini engelleyemezsin.', 'self_block');
        }
        $this->database->statement(
            'insert into user_blocks (blocker_id, blocked_user_id)
             values (:blocker_id, :blocked_user_id) on conflict do nothing',
            ['blocker_id' => $userId, 'blocked_user_id' => $blockedUserId],
        );
    }

    public function unblock(string $blockedUserId, string $userId): void
    {
        if (!Uuid::isValid($blockedUserId)) {
            throw new HttpException(404, 'Kullanıcı bulunamadı.', 'profile_not_found');
        }
        $this->database->statement(
            'delete from user_blocks where blocker_id = :blocker_id and blocked_user_id = :blocked_user_id',
            ['blocker_id' => $userId, 'blocked_user_id' => $blockedUserId],
        );
    }

    /** @return array<string, mixed> */
    private function activeListing(string $listingId): array
    {
        if (!Uuid::isValid($listingId)) {
            throw new HttpException(404, 'İlan bulunamadı.', 'listing_not_found');
        }
        $listing = $this->database->fetchOne(
            "select id, owner_id from listings where id = :id and status = 'active'
             and (expires_at is null or expires_at > now())",
            ['id' => $listingId],
        );
        if ($listing === null) {
            throw new HttpException(404, 'Aktif ilan bulunamadı.', 'listing_not_found');
        }
        return $listing;
    }

    /** @return array<string, mixed> */
    private function activeOrCompletedListing(string $listingId): array
    {
        if (!Uuid::isValid($listingId)) {
            throw new HttpException(404, 'İlan bulunamadı.', 'listing_not_found');
        }
        $listing = $this->database->fetchOne(
            "select id, owner_id from listings where id = :id and status in ('active', 'completed', 'expired', 'paused')",
            ['id' => $listingId],
        );
        if ($listing === null) {
            throw new HttpException(404, 'İlan bulunamadı.', 'listing_not_found');
        }
        return $listing;
    }
}
