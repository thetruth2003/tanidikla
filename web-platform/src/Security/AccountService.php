<?php

declare(strict_types=1);

namespace App\Security;

use App\Core\Config;
use App\Core\Database;
use App\Core\HttpException;
use App\Notifications\EmailQueueService;
use App\Support\Uuid;
use PDO;

final class AccountService
{
    public function __construct(
        private readonly Database $database,
        private readonly EmailQueueService $emailQueue,
    ) {
    }

    /** @param array<string, mixed> $user */
    public function changePassword(array $user, string $currentPassword, string $password, string $confirmation): void
    {
        if (!hash_equals($password, $confirmation)) {
            throw new HttpException(422, 'Yeni şifreler aynı olmalı.', 'password_confirmation_mismatch');
        }
        PasswordPolicy::assert($password);
        $row = $this->database->fetchOne('select password_hash from users where id=:id', ['id' => $user['id']]);
        if ($row === null || !password_verify($currentPassword, (string) $row['password_hash'])) {
            throw new HttpException(401, 'Mevcut şifre hatalı.', 'invalid_current_password');
        }
        $sessionId = (string) ($user['session_id'] ?? '');
        $sessionKind = (string) ($user['session_kind'] ?? '');
        $this->database->transaction(function (PDO $pdo) use ($user, $password, $sessionId, $sessionKind): void {
            $pdo->prepare('update users set password_hash=:hash,updated_at=now() where id=:id')
                ->execute(['hash' => password_hash($password, PASSWORD_ARGON2ID), 'id' => $user['id']]);
            $pdo->prepare('update password_reset_tokens set used_at=coalesce(used_at,now()) where user_id=:id')
                ->execute(['id' => $user['id']]);
            $webSql = $sessionKind === 'web'
                ? 'update user_sessions set revoked_at=now() where user_id=:id and id<>cast(:current as uuid) and revoked_at is null'
                : 'update user_sessions set revoked_at=now() where user_id=:id and revoked_at is null';
            $webParams = $sessionKind === 'web' ? ['id'=>$user['id'],'current'=>$sessionId] : ['id'=>$user['id']];
            $pdo->prepare($webSql)->execute($webParams);
            $mobileSql = $sessionKind === 'mobile'
                ? 'update api_token_families set revoked_at=now() where user_id=:id and id<>cast(:current as uuid) and revoked_at is null'
                : 'update api_token_families set revoked_at=now() where user_id=:id and revoked_at is null';
            $mobileParams = $sessionKind === 'mobile' ? ['id'=>$user['id'],'current'=>$sessionId] : ['id'=>$user['id']];
            $pdo->prepare($mobileSql)->execute($mobileParams);
        });
    }

    /** @param array<string, mixed> $user */
    public function requestEmailChange(array $user, string $newEmail, string $currentPassword): void
    {
        if (!Config::bool('MAIL_ENABLED')) {
            throw new HttpException(503, 'E-posta doğrulama servisi henüz etkin değil.', 'mail_provider_unavailable');
        }
        $newEmail = mb_strtolower(trim($newEmail));
        if (!filter_var($newEmail, FILTER_VALIDATE_EMAIL)) {
            throw new HttpException(422, 'Geçerli bir e-posta adresi yazmalısın.', 'validation_failed');
        }
        $row = $this->database->fetchOne('select password_hash,email from users where id=:id', ['id'=>$user['id']]);
        if ($row === null || !password_verify($currentPassword, (string)$row['password_hash'])) {
            throw new HttpException(401, 'Mevcut şifre hatalı.', 'invalid_current_password');
        }
        if (mb_strtolower((string)$row['email']) === $newEmail) {
            throw new HttpException(422, 'Yeni e-posta mevcut adresinden farklı olmalı.', 'validation_failed');
        }
        if ($this->database->fetchOne(
            'select id from users where id<>:id and (lower(email)=:email or lower(coalesce(pending_email,\'\'))=:email_copy)',
            ['id'=>$user['id'],'email'=>$newEmail,'email_copy'=>$newEmail],
        ) !== null) {
            throw new HttpException(409, 'Bu e-posta adresi kullanılamıyor.', 'email_unavailable');
        }
        $token = $this->token();
        $this->database->transaction(function (PDO $pdo) use ($user,$newEmail,$token): void {
            $pdo->prepare('update email_change_tokens set used_at=now() where user_id=:id and used_at is null')
                ->execute(['id'=>$user['id']]);
            $pdo->prepare('update users set pending_email=:email,updated_at=now() where id=:id')
                ->execute(['email'=>$newEmail,'id'=>$user['id']]);
            $pdo->prepare("insert into email_change_tokens(user_id,new_email,token_hash,expires_at) values(:id,:email,:hash,now()+interval '1 hour')")
                ->execute(['id'=>$user['id'],'email'=>$newEmail,'hash'=>$this->hash($token)]);
        });
        $url = rtrim(Config::string('APP_URL'), '/') . '/e-posta-degistir?token=' . rawurlencode($token);
        $this->emailQueue->enqueue(
            $newEmail,
            'Yeni e-posta adresini doğrula',
            '<p>E-posta değişikliğini tamamlamak için <a href="'.htmlspecialchars($url,ENT_QUOTES).'">bu bağlantıya tıkla</a>.</p>',
            'E-posta değişikliğini tamamla: '.$url,
        );
    }

    public function confirmEmailChange(string $token): void
    {
        $changed = $this->database->transaction(function (PDO $pdo) use ($token): bool {
            $statement=$pdo->prepare('select id,user_id,new_email from email_change_tokens where token_hash=:hash and used_at is null and expires_at>now() for update');
            $statement->execute(['hash'=>$this->hash($token)]);
            $row=$statement->fetch(PDO::FETCH_ASSOC);
            if ($row===false) return false;
            $duplicate=$pdo->prepare('select 1 from users where id<>:id and lower(email)=:email');
            $duplicate->execute(['id'=>$row['user_id'],'email'=>mb_strtolower((string)$row['new_email'])]);
            if ($duplicate->fetchColumn()!==false) return false;
            $pdo->prepare('update users set email=:email,pending_email=null,email_verified_at=now(),updated_at=now() where id=:id')
                ->execute(['email'=>$row['new_email'],'id'=>$row['user_id']]);
            $pdo->prepare('update email_change_tokens set used_at=now() where id=:id')->execute(['id'=>$row['id']]);
            $pdo->prepare('update user_sessions set revoked_at=now() where user_id=:id and revoked_at is null')->execute(['id'=>$row['user_id']]);
            $pdo->prepare('update api_token_families set revoked_at=now() where user_id=:id and revoked_at is null')->execute(['id'=>$row['user_id']]);
            return true;
        });
        if (!$changed) throw new HttpException(400,'E-posta değişikliği bağlantısı geçersiz veya süresi dolmuş.','invalid_email_change_token');
    }

    /** @param array<string, mixed> $user @return array<string, mixed> */
    public function requestPhoneVerification(array $user, string $phone): array
    {
        if (!Config::bool('SMS_ENABLED')) {
            throw new HttpException(503, 'SMS doğrulama servisi henüz etkin değil.', 'sms_provider_unavailable');
        }
        $phone=$this->normalizePhone($phone);
        $duplicate=$this->database->fetchOne(
            'select user_id from profiles where user_id<>:id and phone_e164=:phone and phone_verified_at is not null',
            ['id'=>$user['id'],'phone'=>$phone],
        );
        if ($duplicate!==null) throw new HttpException(409,'Bu telefon numarası kullanılamıyor.','phone_unavailable');
        $code=(string)random_int(100000,999999);
        $this->database->transaction(function (PDO $pdo) use ($user,$phone,$code): void {
            $pdo->prepare('update phone_verification_codes set used_at=now() where user_id=:id and used_at is null')->execute(['id'=>$user['id']]);
            $pdo->prepare('update profiles set phone_e164=:phone,phone_verified_at=null,updated_at=now() where user_id=:id')->execute(['phone'=>$phone,'id'=>$user['id']]);
            $pdo->prepare("insert into phone_verification_codes(user_id,phone_e164,code_hash,expires_at) values(:id,:phone,:hash,now()+interval '10 minutes')")
                ->execute(['id'=>$user['id'],'phone'=>$phone,'hash'=>$this->hashCode($user['id'],$code)]);
            $pdo->prepare('insert into sms_queue(recipient,message) values(:phone,:message)')
                ->execute(['phone'=>$phone,'message'=>Config::string('APP_NAME', 'Tanıdıkla').' doğrulama kodun: '.$code.'. Kod 10 dakika geçerlidir.']);
        });
        return ['accepted'=>true,'phone_masked'=>substr($phone,0,5).'***'.substr($phone,-3),'expires_in_seconds'=>600];
    }

    /** @param array<string, mixed> $user */
    public function verifyPhone(array $user, string $code): void
    {
        if (preg_match('/^\d{6}$/',$code)!==1) throw new HttpException(422,'Doğrulama kodu 6 rakam olmalı.','validation_failed');
        $status=$this->database->transaction(function (PDO $pdo) use ($user,$code): string {
            $statement=$pdo->prepare('select id,phone_e164,code_hash,attempts from phone_verification_codes where user_id=:id and used_at is null and expires_at>now() order by created_at desc limit 1 for update');
            $statement->execute(['id'=>$user['id']]);
            $row=$statement->fetch(PDO::FETCH_ASSOC);
            if ($row===false) return 'expired';
            if ((int)$row['attempts']>=5) return 'locked';
            $pdo->prepare('update phone_verification_codes set attempts=attempts+1 where id=:id')->execute(['id'=>$row['id']]);
            if (!hash_equals((string)$row['code_hash'],$this->hashCode($user['id'],$code))) return 'invalid';
            $pdo->prepare('update phone_verification_codes set used_at=now() where id=:id')->execute(['id'=>$row['id']]);
            $pdo->prepare('update profiles set phone_e164=:phone,phone_verified_at=now(),updated_at=now() where user_id=:id')->execute(['phone'=>$row['phone_e164'],'id'=>$user['id']]);
            return 'ok';
        });
        if ($status==='expired') throw new HttpException(400,'Kodun süresi dolmuş. Yeni kod iste.','phone_code_expired');
        if ($status==='locked') throw new HttpException(429,'Çok fazla hatalı deneme yapıldı. Yeni kod iste.','phone_code_locked');
        if ($status!=='ok') throw new HttpException(422,'Doğrulama kodu hatalı.','invalid_phone_code');
    }

    /** @param array<string, mixed> $user */
    public function updatePreferences(array $user, bool $messageEmailNotifications): void
    {
        $this->database->statement('update profiles set message_email_notifications=:value,updated_at=now() where user_id=:id',[
            'value'=>$messageEmailNotifications?'true':'false','id'=>$user['id'],
        ]);
    }

    /** @param array<string, mixed> $user @return list<array<string, mixed>> */
    public function sessions(array $user): array
    {
        $rows=$this->database->fetchAll(
            "select id,'web' as session_kind,device_name,ip_address::text,user_agent,last_seen_at,expires_at,created_at
             from user_sessions where user_id=:web_id and revoked_at is null and expires_at>now()
             union all
             select f.id,'mobile',f.device_name,f.ip_address::text,f.user_agent,f.last_used_at,
                    coalesce((select max(r.expires_at) from api_refresh_tokens r where r.family_id=f.id and r.revoked_at is null),f.created_at),f.created_at
             from api_token_families f where f.user_id=:mobile_id and f.revoked_at is null
             order by last_seen_at desc",
            ['web_id'=>$user['id'],'mobile_id'=>$user['id']],
        );
        foreach($rows as &$row) $row['is_current']=(string)$row['id']===(string)($user['session_id']??'');
        unset($row);
        return $rows;
    }

    /** @param array<string, mixed> $user */
    public function revokeOtherSessions(array $user): void
    {
        $id=(string)($user['session_id']??'');
        $kind=(string)($user['session_kind']??'');
        $this->database->transaction(function(PDO $pdo) use($user,$id,$kind): void {
            if($kind==='web') $pdo->prepare('update user_sessions set revoked_at=now() where user_id=:uid and id<>cast(:id as uuid) and revoked_at is null')->execute(['uid'=>$user['id'],'id'=>$id]);
            else $pdo->prepare('update user_sessions set revoked_at=now() where user_id=:uid and revoked_at is null')->execute(['uid'=>$user['id']]);
            if($kind==='mobile') $pdo->prepare('update api_token_families set revoked_at=now() where user_id=:uid and id<>cast(:id as uuid) and revoked_at is null')->execute(['uid'=>$user['id'],'id'=>$id]);
            else $pdo->prepare('update api_token_families set revoked_at=now() where user_id=:uid and revoked_at is null')->execute(['uid'=>$user['id']]);
        });
    }

    private function normalizePhone(string $phone): string
    {
        $digits=preg_replace('/\D+/','',$phone)??'';
        if(str_starts_with($digits,'0090')) $digits=substr($digits,2);
        if(str_starts_with($digits,'0')) $digits='90'.substr($digits,1);
        if(!str_starts_with($digits,'90') && strlen($digits)===10) $digits='90'.$digits;
        $normalized='+'.$digits;
        if(preg_match('/^\+905\d{9}$/',$normalized)!==1) throw new HttpException(422,'Geçerli bir Türkiye cep telefonu numarası yazmalısın.','validation_failed');
        return $normalized;
    }

    private function token(): string { return rtrim(strtr(base64_encode(random_bytes(32)),'+/','-_'),'='); }
    private function hash(string $value): string { return hash('sha256',$value); }
    private function hashCode(string $userId,string $code): string { return hash_hmac('sha256',$userId.':'.$code,Config::string('APP_KEY')); }
}
