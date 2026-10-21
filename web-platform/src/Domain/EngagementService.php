<?php

declare(strict_types=1);

namespace App\Domain;

use App\Core\Database;
use App\Core\HttpException;
use App\Support\Uuid;
use PDO;

final class EngagementService
{
    public function __construct(private readonly Database $database)
    {
    }

    /** @return list<array<string,mixed>> */
    public function all(string $userId, array $query = []): array
    {
        $status = trim((string) ($query['status'] ?? ''));
        $parameters = ['requester_user_id' => $userId, 'provider_user_id' => $userId];
        $statusSql = '';
        if ($status !== '') {
            $statusSql = 'and e.status = :status';
            $parameters['status'] = $status;
        }
        return array_map([$this, 'normalize'], $this->database->fetchAll(
            "select e.*, requester.display_name as requester_name, provider.display_name as provider_name,
                    requester.avatar_path as requester_avatar, provider.avatar_path as provider_avatar
             from service_engagements e
             join profiles requester on requester.user_id=e.requester_id
             join profiles provider on provider.user_id=e.provider_id
             where (e.requester_id=:requester_user_id or e.provider_id=:provider_user_id) {$statusSql}
             order by e.updated_at desc limit 200",
            $parameters,
        ));
    }

    /** @return array<string,mixed> */
    public function find(string $id, string $userId): array
    {
        if (!Uuid::isValid($id)) throw new HttpException(404, 'İş kaydı bulunamadı.', 'engagement_not_found');
        $row = $this->database->fetchOne(
            'select e.*, requester.display_name as requester_name, provider.display_name as provider_name,
                    requester.avatar_path as requester_avatar, provider.avatar_path as provider_avatar
             from service_engagements e
             join profiles requester on requester.user_id=e.requester_id
             join profiles provider on provider.user_id=e.provider_id
             where e.id=:id and (e.requester_id=:requester_user_id or e.provider_id=:provider_user_id)',
            ['id'=>$id,'requester_user_id'=>$userId,'provider_user_id'=>$userId],
        );
        if ($row === null) throw new HttpException(404, 'İş kaydı bulunamadı.', 'engagement_not_found');
        $row['events'] = $this->database->fetchAll(
            'select id,actor_id,from_status,to_status,metadata,created_at from service_engagement_events where engagement_id=:id order by id',
            ['id'=>$id],
        );
        return $this->normalize($row);
    }

    /** @param array<string,mixed> $payload @return array<string,mixed> */
    public function create(array $payload, string $requesterId): array
    {
        $listingId = trim((string) ($payload['listing_id'] ?? ''));
        $itemId = trim((string) ($payload['listing_item_id'] ?? ''));
        if (!Uuid::isValid($listingId) || !Uuid::isValid($itemId)) {
            throw new HttpException(422, 'İlan ve hizmet kalemi gerekli.', 'validation_failed');
        }
        $note = trim((string) ($payload['note'] ?? ''));
        if (mb_strlen($note) > 2000) throw new HttpException(422, 'Talep notu çok uzun.', 'validation_failed');

        $id = $this->database->transaction(function (PDO $pdo) use ($listingId,$itemId,$requesterId,$payload,$note): string {
            $itemQuery = $pdo->prepare(
                "select l.id as listing_id,l.owner_id,l.headline,l.listing_type,
                        li.id as item_id,li.title,li.description,li.category_id,li.price_amount,li.currency,li.pricing_unit
                 from listings l join listing_items li on li.listing_id=l.id
                 where l.id=:listing_id and li.id=:item_id and l.status='active'
                   and (l.expires_at is null or l.expires_at>now()) and li.is_active and li.deleted_at is null
                 for update of l,li"
            );
            $itemQuery->execute(['listing_id'=>$listingId,'item_id'=>$itemId]);
            $item = $itemQuery->fetch(PDO::FETCH_ASSOC);
            if ($item === false) throw new HttpException(404, 'Aktif hizmet kalemi bulunamadı.', 'listing_item_not_found');
            if ($item['listing_type'] !== 'service_offer') {
                throw new HttpException(422, 'İş talebi yalnız hizmet veren ilana gönderilebilir.', 'invalid_engagement_listing');
            }
            $providerId = (string) $item['owner_id'];
            if ($providerId === $requesterId) throw new HttpException(422, 'Kendi hizmetine talep gönderemezsin.', 'self_engagement');
            $blocked = $pdo->prepare('select 1 from user_blocks where (blocker_id=:requester and blocked_user_id=:provider) or (blocker_id=:provider2 and blocked_user_id=:requester2) limit 1');
            $blocked->execute(['requester'=>$requesterId,'provider'=>$providerId,'provider2'=>$providerId,'requester2'=>$requesterId]);
            if ($blocked->fetchColumn() !== false) throw new HttpException(403, 'Bu kullanıcıya talep gönderemezsin.', 'user_blocked');

            $lock = $pdo->prepare('select pg_advisory_xact_lock(hashtext(:key))');
            $lock->execute(['key'=>$requesterId.'|'.$providerId.'|'.$itemId]);
            $duplicate = $pdo->prepare("select id from service_engagements where requester_id=:requester and provider_id=:provider and listing_item_id=:item and status in ('requested','accepted','in_progress','provider_completed','disputed') limit 1");
            $duplicate->execute(['requester'=>$requesterId,'provider'=>$providerId,'item'=>$itemId]);
            if ($duplicate->fetchColumn() !== false) throw new HttpException(409, 'Bu hizmet için zaten açık bir talebin var.', 'engagement_already_open');

            $conversationId = Uuid::v4();
            $pdo->prepare('insert into conversations (id,listing_id,listing_item_id) values (:id,:listing,:item)')
                ->execute(['id'=>$conversationId,'listing'=>$listingId,'item'=>$itemId]);
            $member = $pdo->prepare('insert into conversation_members (conversation_id,user_id) values (:conversation,:user_id)');
            $member->execute(['conversation'=>$conversationId,'user_id'=>$requesterId]);
            $member->execute(['conversation'=>$conversationId,'user_id'=>$providerId]);

            $engagementId = Uuid::v4();
            $agreedRaw = $payload['agreed_price_amount'] ?? null;
            $agreed = $agreedRaw === null || $agreedRaw === '' ? null : filter_var($agreedRaw,FILTER_VALIDATE_FLOAT,FILTER_NULL_ON_FAILURE);
            if ($agreed !== null && $agreed < 0) throw new HttpException(422, 'Anlaşılan fiyat geçersiz.', 'validation_failed');
            $insert = $pdo->prepare(
                'insert into service_engagements
                 (id,requester_id,provider_id,listing_id,listing_item_id,conversation_id,listing_headline_snapshot,
                  service_name_snapshot,service_description_snapshot,category_id_snapshot,quoted_price_amount,
                  agreed_price_amount,currency_snapshot,pricing_unit_snapshot)
                 values (:id,:requester,:provider,:listing,:item,:conversation,:headline,:name,:description,:category,
                  :quoted,:agreed,:currency,:pricing)'
            );
            $insert->execute([
                'id'=>$engagementId,'requester'=>$requesterId,'provider'=>$providerId,'listing'=>$listingId,
                'item'=>$itemId,'conversation'=>$conversationId,'headline'=>$item['headline'],'name'=>$item['title'],
                'description'=>$item['description'],'category'=>$item['category_id'],'quoted'=>$item['price_amount'],
                'agreed'=>$agreed,'currency'=>$item['currency'],'pricing'=>$item['pricing_unit'],
            ]);
            $pdo->prepare('update conversations set engagement_id=:engagement where id=:conversation')
                ->execute(['engagement'=>$engagementId,'conversation'=>$conversationId]);
            $this->event($pdo,$engagementId,$requesterId,null,'requested',['note'=>$note]);
            $this->notify($pdo,$providerId,'service_request','Yeni hizmet talebi',(string)$item['title'],[
                'engagement_id'=>$engagementId,'conversation_id'=>$conversationId,'listing_id'=>$listingId,'listing_item_id'=>$itemId,
            ]);
            return $engagementId;
        });
        return $this->find($id,$requesterId);
    }

    /** @param array<string,mixed> $payload @return array<string,mixed> */
    public function transition(string $id, string $action, array $payload, string $actorId): array
    {
        $allowedActions = ['accept','reject','start','mark_completed','confirm_completed','cancel','dispute'];
        if (!Uuid::isValid($id) || !in_array($action,$allowedActions,true)) {
            throw new HttpException(422, 'İş durumu isteği geçersiz.', 'validation_failed');
        }
        $this->database->transaction(function (PDO $pdo) use ($id,$action,$payload,$actorId): void {
            $select=$pdo->prepare('select * from service_engagements where id=:id for update');
            $select->execute(['id'=>$id]);
            $row=$select->fetch(PDO::FETCH_ASSOC);
            if ($row===false || !in_array($actorId,[(string)$row['requester_id'],(string)$row['provider_id']],true)) {
                throw new HttpException(404,'İş kaydı bulunamadı.','engagement_not_found');
            }
            $isRequester=$actorId===(string)$row['requester_id'];
            $isProvider=$actorId===(string)$row['provider_id'];
            $from=(string)$row['status'];
            $to=match($action){
                'accept' => $isProvider && $from==='requested' ? 'accepted' : null,
                'reject' => $isProvider && $from==='requested' ? 'rejected' : null,
                'start' => $isProvider && $from==='accepted' ? 'in_progress' : null,
                'mark_completed' => $isProvider && $from==='in_progress' ? 'provider_completed' : null,
                'confirm_completed' => $isRequester && $from==='provider_completed' ? 'completed' : null,
                'cancel' => in_array($from,['requested','accepted','in_progress'],true) ? 'canceled' : null,
                'dispute' => in_array($from,['accepted','in_progress','provider_completed'],true) ? 'disputed' : null,
                default => null,
            };
            if ($to===null) throw new HttpException(409,'Bu durum geçişine izin verilmiyor.','invalid_engagement_transition');
            $reason=trim((string)($payload['reason']??''));
            if (in_array($action,['cancel','dispute'],true) && mb_strlen($reason)<3) {
                throw new HttpException(422,'İptal veya anlaşmazlık nedeni gerekli.','validation_failed');
            }
            $agreedRaw=$payload['agreed_price_amount']??null;
            $agreed=$agreedRaw===null||$agreedRaw===''?$row['agreed_price_amount']:filter_var($agreedRaw,FILTER_VALIDATE_FLOAT,FILTER_NULL_ON_FAILURE);
            if ($agreed!==null && (!is_numeric($agreed)||(float)$agreed<0)) throw new HttpException(422,'Anlaşılan fiyat geçersiz.','validation_failed');
            $timestamps=[
                'accepted'=>'accepted_at=now(),responded_at=now()', 'rejected'=>'responded_at=now()',
                'in_progress'=>'started_at=now()', 'provider_completed'=>'provider_completed_at=now()',
                'completed'=>'requester_confirmed_at=now(),completed_at=now()',
                'canceled'=>'canceled_at=now(),canceled_by=:actor', 'disputed'=>'dispute_reason=:reason',
            ];
            $extra=$timestamps[$to];
            $sql="update service_engagements set status=:status,agreed_price_amount=:agreed,{$extra},
                  cancellation_reason=:cancel_reason,version=version+1,updated_at=now() where id=:id";
            $params=['status'=>$to,'agreed'=>$agreed,'cancel_reason'=>$to==='canceled'?$reason:(string)$row['cancellation_reason'],'id'=>$id];
            if ($to==='canceled') $params['actor']=$actorId;
            if ($to==='disputed') $params['reason']=$reason;
            $pdo->prepare($sql)->execute($params);
            $this->event($pdo,$id,$actorId,$from,$to,['reason'=>$reason]);
            $recipient=$isRequester?(string)$row['provider_id']:(string)$row['requester_id'];
            $this->notify($pdo,$recipient,$to==='disputed'?'dispute':'engagement','İş durumu güncellendi',$this->statusLabel($to),[
                'engagement_id'=>$id,'status'=>$to,'conversation_id'=>$row['conversation_id'],
            ]);
            if ($to==='completed') {
                foreach ([(string)$row['requester_id'],(string)$row['provider_id']] as $party) {
                    $this->notify($pdo,$party,'review','Değerlendirme hakkın hazır','Tamamlanan işi değerlendirebilirsin.',['engagement_id'=>$id]);
                }
                $this->flagSuspiciousCompletion($pdo,$row);
            }
        });
        return $this->find($id,$actorId);
    }

    private function notify(PDO $pdo,string $userId,string $type,string $title,string $body,array $data): void
    {
        $insert=$pdo->prepare('insert into notifications(user_id,type,title,body,data) values (:user,:type,:title,:body,cast(:data as jsonb)) returning id');
        $insert->execute(['user'=>$userId,'type'=>$type,'title'=>$title,'body'=>mb_substr($body,0,500),'data'=>json_encode($data,JSON_THROW_ON_ERROR|JSON_UNESCAPED_UNICODE)]);
        $notificationId=(int)$insert->fetchColumn();
        $pdo->prepare("insert into realtime_outbox(channel,event_type,payload) values (:channel,'notification.created',cast(:payload as jsonb))")
            ->execute(['channel'=>'user:'.$userId,'payload'=>json_encode(['notification_id'=>$notificationId,'type'=>$type,...$data],JSON_THROW_ON_ERROR|JSON_UNESCAPED_UNICODE)]);
    }

    private function event(PDO $pdo,string $id,?string $actor,?string $from,string $to,array $metadata=[]): void
    {
        $pdo->prepare('insert into service_engagement_events(engagement_id,actor_id,from_status,to_status,metadata) values (:id,:actor,:from,:to,cast(:metadata as jsonb))')
            ->execute(['id'=>$id,'actor'=>$actor,'from'=>$from,'to'=>$to,'metadata'=>json_encode($metadata,JSON_THROW_ON_ERROR|JSON_UNESCAPED_UNICODE)]);
    }

    /** @param array<string,mixed> $row */
    private function flagSuspiciousCompletion(PDO $pdo,array $row): void
    {
        $query=$pdo->prepare("select count(*) from service_engagements where requester_id=:requester and provider_id=:provider and status='completed' and completed_at>now()-interval '24 hours'");
        $query->execute(['requester'=>$row['requester_id'],'provider'=>$row['provider_id']]);
        $count=(int)$query->fetchColumn();
        if ($count>=3) {
            $pdo->prepare("insert into risk_signals(user_id,related_user_id,engagement_id,signal_type,score,evidence) values (:user,:related,:engagement,'rapid_pair_completions',60,cast(:evidence as jsonb))")
                ->execute(['user'=>$row['provider_id'],'related'=>$row['requester_id'],'engagement'=>$row['id'],'evidence'=>json_encode(['completed_pair_24h'=>$count],JSON_THROW_ON_ERROR)]);
        }
    }

    /** @param array<string,mixed> $row @return array<string,mixed> */
    private function normalize(array $row): array
    {
        foreach(['quoted_price_amount','agreed_price_amount'] as $key) if(isset($row[$key])) $row[$key]=(float)$row[$key];
        if(isset($row['version'])) $row['version']=(int)$row['version'];
        return $row;
    }

    private function statusLabel(string $status): string
    {
        return ['requested'=>'Talep gönderildi','accepted'=>'Talep kabul edildi','rejected'=>'Talep reddedildi',
            'in_progress'=>'İş başladı','provider_completed'=>'Hizmet veren işi tamamladı','completed'=>'İş tamamlandı',
            'canceled'=>'İş iptal edildi','disputed'=>'İş anlaşmazlık incelemesinde'][$status]??$status;
    }
}
