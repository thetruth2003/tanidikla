<?php

declare(strict_types=1);

namespace App\Domain;

use App\Core\Database;
use App\Core\Config;
use App\Core\HttpException;
use App\Core\Request;
use App\Support\Uuid;
use App\Storage\StorageFactory;
use PDO;
use Throwable;

final class PrivacyService
{
    public function __construct(private readonly Database $database) {}

    /** @return list<array<string, mixed>> */
    public function publishedPolicies(): array
    {
        $documents = $this->database->fetchAll(
            "select id, document_type, version, title, content, published_at
             from policy_documents where status='published' order by document_type"
        );

        $controllerName = trim(Config::string('LEGAL_CONTROLLER_NAME'));
        $controllerAddress = trim(Config::string('LEGAL_CONTROLLER_ADDRESS'));
        $kvkkEmail = trim(Config::string('LEGAL_CONTROLLER_EMAIL', 'kvkk@tanidikla.com'));
        $missing = [];
        if ($controllerName === '') $missing[] = 'LEGAL_CONTROLLER_NAME';
        if ($controllerAddress === '') $missing[] = 'LEGAL_CONTROLLER_ADDRESS';
        if ($kvkkEmail === '') $missing[] = 'LEGAL_CONTROLLER_EMAIL';

        $replacements = [
            '{{APP_NAME}}' => Config::string('APP_NAME', 'Tanıdıkla'),
            '{{APP_URL}}' => rtrim(Config::string('APP_URL', 'https://tanidikla.com'), '/'),
            '{{DATA_CONTROLLER_NAME}}' => $controllerName !== '' ? $controllerName : '[VERİ SORUMLUSU ADI YAYIN ÖNCESİ DOLDURULMALI]',
            '{{DATA_CONTROLLER_ADDRESS}}' => $controllerAddress !== '' ? $controllerAddress : '[VERİ SORUMLUSU ADRESİ YAYIN ÖNCESİ DOLDURULMALI]',
            '{{KVKK_EMAIL}}' => $kvkkEmail !== '' ? $kvkkEmail : '[KVKK E-POSTA ADRESİ YAYIN ÖNCESİ DOLDURULMALI]',
            '{{DATA_CONTROLLER_KEP}}' => trim(Config::string('LEGAL_CONTROLLER_KEP')) ?: 'Belirtilmemiştir',
            '{{DATA_CONTROLLER_PHONE}}' => trim(Config::string('LEGAL_CONTROLLER_PHONE')) ?: 'Belirtilmemiştir',
            '{{EFFECTIVE_DATE}}' => Config::string('LEGAL_EFFECTIVE_DATE', '17.08.2026'),
        ];

        return array_map(static function (array $document) use ($replacements, $missing): array {
            $document['content'] = strtr((string) $document['content'], $replacements);
            $document['configuration_complete'] = $missing === [];
            $document['configuration_missing'] = $missing;
            return $document;
        }, $documents);
    }

    /** @param list<string> $policyIds */
    public function recordConsents(string $userId, array $policyIds, Request $request): int
    {
        $ids = array_values(array_unique(array_filter($policyIds, fn ($id): bool => is_string($id) && Uuid::isValid($id))));
        if ($ids === []) throw new HttpException(422, 'Onaylanacak metin seçilmedi.', 'validation_failed');
        return $this->database->transaction(function (PDO $pdo) use ($ids, $userId, $request): int {
            $check = $pdo->prepare("select id from policy_documents where id=:id and status='published' and document_type='terms'");
            $insert = $pdo->prepare("insert into user_consents (user_id, policy_document_id, action, ip_address, user_agent) values (:user_id,:policy_id,'accepted',:ip,:agent)");
            foreach ($ids as $id) {
                $check->execute(['id' => $id]);
                if ($check->fetchColumn() === false) throw new HttpException(422, 'Yalnız yayımlanmış kullanım koşulları sözleşme onayı olarak kaydedilebilir.', 'validation_failed');
                $insert->execute(['user_id'=>$userId,'policy_id'=>$id,'ip'=>$request->clientIp(),'agent'=>mb_substr((string)($request->header('user-agent') ?? ''),0,500)]);
            }
            return count($ids);
        });
    }

    /** @return array<string, mixed> */
    public function request(string $userId, string $type, string $details): array
    {
        if (!in_array($type, ['export','deletion','correction','objection'], true)) throw new HttpException(422, 'Talep türü geçersiz.', 'validation_failed');
        try {
            $row = $this->database->fetchOne(
                'insert into privacy_requests (user_id, request_type, details) values (:user_id,:type,:details) returning id, request_type, status, created_at',
                ['user_id'=>$userId,'type'=>$type,'details'=>mb_substr(trim($details),0,2000)],
            );
        } catch (Throwable $exception) {
            if (str_contains($exception->getMessage(), 'privacy_requests_open_unique')) throw new HttpException(409, 'Bu türde açık bir talebin zaten var.', 'privacy_request_exists');
            throw $exception;
        }
        return $row ?? [];
    }

    /** @return list<array<string, mixed>> */
    public function requests(string $userId): array
    {
        return $this->database->fetchAll('select id, request_type, details, status, created_at, updated_at from privacy_requests where user_id=:user_id order by created_at desc', ['user_id'=>$userId]);
    }

    /** @return array<string, mixed> */
    public function export(string $userId): array
    {
        return [
            'generated_at' => gmdate(DATE_ATOM),
            'account' => $this->database->fetchOne('select id,email,role,email_verified_at,created_at,updated_at from users where id=:id', ['id'=>$userId]),
            'profile' => $this->database->fetchOne('select display_name,bio,city,district,gender,profile_type,business_name,business_address,business_services,is_provider,phone_e164,phone_visible,created_at,updated_at from profiles where user_id=:id', ['id'=>$userId]),
            'category_preferences' => $this->database->fetchAll('select preference_type,category_id,created_at from profile_category_preferences where user_id=:id order by preference_type,category_id', ['id'=>$userId]),
            'saved_searches' => $this->database->fetchAll('select id,name,filters,notification_enabled,created_at,updated_at from saved_searches where user_id=:id order by created_at', ['id'=>$userId]),
            'listings' => $this->database->fetchAll('select id,slug,listing_type,status,public_city,public_district,public_neighborhood,created_at,updated_at from listings where owner_id=:id order by created_at', ['id'=>$userId]),
            'messages' => $this->database->fetchAll('select id,conversation_id,body,created_at,edited_at from messages where sender_id=:id and deleted_at is null order by id', ['id'=>$userId]),
            'reviews' => $this->database->fetchAll('select id,listing_id,reviewed_user_id,rating,comment,status,created_at from reviews where author_id=:id order by created_at', ['id'=>$userId]),
            'consents' => $this->database->fetchAll('select c.action,c.created_at,d.document_type,d.version,d.title from user_consents c join policy_documents d on d.id=c.policy_document_id where c.user_id=:id order by c.created_at', ['id'=>$userId]),
        ];
    }

    /** @return list<array<string, mixed>> */
    public function adminRequests(): array
    {
        return $this->database->fetchAll('select r.id,r.request_type,r.details,r.status,r.created_at,p.display_name,u.email from privacy_requests r join users u on u.id=r.user_id join profiles p on p.user_id=u.id order by case r.status when \'pending\' then 0 when \'processing\' then 1 else 2 end,r.created_at');
    }

    /** @param array<string, mixed> $actor */
    public function reviewRequest(string $id, string $status, array $actor, Request $httpRequest): void
    {
        if (!Uuid::isValid($id) || !in_array($status, ['processing','completed','rejected'], true)) throw new HttpException(422, 'Talep durumu geçersiz.', 'validation_failed');
        $media = [];
        $this->database->transaction(function (PDO $pdo) use ($id,$status,$actor,$httpRequest,&$media): void {
            $find=$pdo->prepare('select user_id,request_type from privacy_requests where id=:id for update'); $find->execute(['id'=>$id]); $request=$find->fetch(PDO::FETCH_ASSOC);
            if ($request===false) throw new HttpException(404,'Talep bulunamadı.','privacy_request_not_found');
            if ($status==='completed' && $request['request_type']==='deletion') {
                $mediaStatement=$pdo->prepare('select storage_driver,storage_key from media_objects where owner_id=:user_id'); $mediaStatement->execute(['user_id'=>$request['user_id']]); $media=$mediaStatement->fetchAll(PDO::FETCH_ASSOC);
                $anonymousEmail='deleted+'.str_replace('-','',(string)$request['user_id']).'@anonymized.invalid';
                $pdo->prepare('update users set email=:email,password_hash=:password,role=\'user\',email_verified_at=null,is_suspended=true,suspended_reason=\'Hesap silme talebi tamamlandı\',suspended_at=now(),anonymized_at=now(),updated_at=now() where id=:id')
                    ->execute(['email'=>$anonymousEmail,'password'=>password_hash(base64_encode(random_bytes(48)), PASSWORD_ARGON2ID),'id'=>$request['user_id']]);
                $pdo->prepare("update profiles set display_name='Silinmiş Kullanıcı',avatar_path=null,avatar_media_id=null,bio='',city='',district='',gender=null,profile_type='person',business_name=null,business_address=null,business_services=null,is_provider=false,phone_e164=null,phone_visible=false,updated_at=now() where user_id=:id")->execute(['id'=>$request['user_id']]);
                $pdo->prepare('delete from profile_category_preferences where user_id=:id')->execute(['id'=>$request['user_id']]);
                $pdo->prepare('delete from saved_searches where user_id=:id')->execute(['id'=>$request['user_id']]);
                $pdo->prepare("update listings set status='removed',moderation_note='Hesap silme talebi',updated_at=now() where owner_id=:id")->execute(['id'=>$request['user_id']]);
                $pdo->prepare('update private_listing_addresses set exact_latitude=null,exact_longitude=null,city=\'\',district=\'\',neighborhood=\'\',street=\'\',building_number=\'\',apartment_number=\'\',updated_at=now() where owner_id=:id')->execute(['id'=>$request['user_id']]);
                $pdo->prepare("update reviews set status='removed',comment='Kullanıcı hesabı silindi.',updated_at=now() where author_id=:id")->execute(['id'=>$request['user_id']]);
                $pdo->prepare('delete from favorites where user_id=:id')->execute(['id'=>$request['user_id']]);
                $pdo->prepare('delete from user_blocks where blocker_id=:id or blocked_user_id=:id_copy')->execute(['id'=>$request['user_id'],'id_copy'=>$request['user_id']]);
                $pdo->prepare("update analytics_events set user_id=null,subject_id=case when subject_id=:subject_id then '' else subject_id end,metadata='{}'::jsonb where user_id=:user_id or subject_id=:subject_id_copy")
                    ->execute(['user_id'=>$request['user_id'],'subject_id'=>$request['user_id'],'subject_id_copy'=>$request['user_id']]);
                $pdo->prepare('delete from media_objects where owner_id=:id')->execute(['id'=>$request['user_id']]);
                $pdo->prepare('update user_sessions set revoked_at=now() where user_id=:id and revoked_at is null')->execute(['id'=>$request['user_id']]);
                $pdo->prepare('update api_token_families set revoked_at=now() where user_id=:id and revoked_at is null')->execute(['id'=>$request['user_id']]);
                $pdo->prepare('update admin_sessions set revoked_at=now() where user_id=:id and revoked_at is null')->execute(['id'=>$request['user_id']]);
                $pdo->prepare('update device_push_tokens set revoked_at=now() where user_id=:id and revoked_at is null')->execute(['id'=>$request['user_id']]);
            }
            $pdo->prepare('update privacy_requests set status=:status,reviewed_by=:admin,reviewed_at=now(),updated_at=now() where id=:id')->execute(['status'=>$status,'admin'=>$actor['id'],'id'=>$id]);
            $pdo->prepare("insert into admin_audit_logs (admin_user_id,action,entity_type,entity_id,metadata,ip_address) values (:admin,'privacy_request.status','privacy_request',:id,cast(:metadata as jsonb),:ip)")
                ->execute(['admin'=>$actor['id'],'id'=>$id,'metadata'=>json_encode(['status'=>$status,'request_type'=>$request['request_type']],JSON_THROW_ON_ERROR|JSON_UNESCAPED_UNICODE),'ip'=>$httpRequest->clientIp()]);
        });
        foreach ($media as $object) {
            try { StorageFactory::make((string)$object['storage_driver'])->delete((string)$object['storage_key']); } catch (Throwable) { /* DB state remains private and inaccessible. */ }
        }
    }

    /** @param array<string, mixed> $payload @param array<string, mixed> $actor @return array<string, mixed> */
    public function savePolicy(array $payload, array $actor, Request $request): array
    {
        $type = (string)($payload['document_type'] ?? '');
        $version = trim((string)($payload['version'] ?? ''));
        $title = trim((string)($payload['title'] ?? ''));
        $content = trim((string)($payload['content'] ?? ''));
        if (!in_array($type,['kvkk_notice','privacy_policy','terms','cookie_policy'],true) || $version==='' || $title==='' || $content==='') throw new HttpException(422,'Metin bilgileri eksik.','validation_failed');
        return $this->database->transaction(function (PDO $pdo) use ($type,$version,$title,$content,$actor,$request): array {
            $statement=$pdo->prepare('insert into policy_documents (document_type,version,title,content,created_by) values (:type,:version,:title,:content,:admin) returning id,document_type,version,title,status,created_at');
            $statement->execute(['type'=>$type,'version'=>mb_substr($version,0,50),'title'=>mb_substr($title,0,200),'content'=>$content,'admin'=>$actor['id']]);
            $row=$statement->fetch(PDO::FETCH_ASSOC); if ($row===false) throw new HttpException(500,'Metin kaydedilemedi.','policy_save_failed');
            $pdo->prepare("insert into admin_audit_logs (admin_user_id,action,entity_type,entity_id,metadata,ip_address) values (:admin,'policy.create','policy',:id,cast(:metadata as jsonb),:ip)")
                ->execute(['admin'=>$actor['id'],'id'=>$row['id'],'metadata'=>json_encode(['document_type'=>$type,'version'=>$version],JSON_THROW_ON_ERROR|JSON_UNESCAPED_UNICODE),'ip'=>$request->clientIp()]);
            return $row;
        });
    }

    public function publishPolicy(string $id, array $actor, Request $request): void
    {
        if (!Uuid::isValid($id)) throw new HttpException(404,'Metin bulunamadı.','policy_not_found');
        $this->database->transaction(function (PDO $pdo) use ($id,$actor,$request): void {
            $find=$pdo->prepare('select document_type from policy_documents where id=:id for update'); $find->execute(['id'=>$id]); $type=$find->fetchColumn();
            if (!is_string($type)) throw new HttpException(404,'Metin bulunamadı.','policy_not_found');
            $pdo->prepare("update policy_documents set status='retired',updated_at=now() where document_type=:type and status='published'")->execute(['type'=>$type]);
            $pdo->prepare("update policy_documents set status='published',published_at=now(),updated_at=now() where id=:id")->execute(['id'=>$id]);
            $pdo->prepare("insert into admin_audit_logs (admin_user_id,action,entity_type,entity_id,metadata,ip_address) values (:admin,'policy.publish','policy',:id,cast(:metadata as jsonb),:ip)")
                ->execute(['admin'=>$actor['id'],'id'=>$id,'metadata'=>json_encode(['document_type'=>$type],JSON_THROW_ON_ERROR|JSON_UNESCAPED_UNICODE),'ip'=>$request->clientIp()]);
        });
    }
}
