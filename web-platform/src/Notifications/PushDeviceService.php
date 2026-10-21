<?php

declare(strict_types=1);

namespace App\Notifications;

use App\Core\Config;
use App\Core\Database;
use App\Core\HttpException;
use App\Support\Uuid;

final class PushDeviceService
{
    public function __construct(private readonly Database $database) {}

    /** @return array<string,mixed> */
    public function register(string $userId,string $platform,string $token): array
    {
        $token=trim($token);
        if(!in_array($platform,['android','ios','web'],true)||mb_strlen($token)<20||mb_strlen($token)>4096) throw new HttpException(422,'Push cihaz bilgisi geçersiz.','validation_failed');
        $hash=hash('sha256',$token);$encrypted=$this->encrypt($token);$id=Uuid::v4();
        $row=$this->database->fetchOne("insert into device_push_tokens(id,user_id,platform,token_hash,encrypted_token) values(:id,:user,:platform,:hash,:token) on conflict(token_hash) do update set user_id=excluded.user_id,platform=excluded.platform,encrypted_token=excluded.encrypted_token,last_seen_at=now(),revoked_at=null returning id,platform,last_seen_at",['id'=>$id,'user'=>$userId,'platform'=>$platform,'hash'=>$hash,'token'=>$encrypted]);
        return $row??['id'=>$id,'platform'=>$platform];
    }

    public function revoke(string $userId,string $id): void
    {
        if(!Uuid::isValid($id)) throw new HttpException(422,'Cihaz kimliği geçersiz.','validation_failed');
        $count=$this->database->statement('update device_push_tokens set revoked_at=now() where id=:id and user_id=:user and revoked_at is null',['id'=>$id,'user'=>$userId])->rowCount();
        if($count!==1) throw new HttpException(404,'Cihaz kaydı bulunamadı.','push_device_not_found');
    }

    private function encrypt(string $value): string
    {
        $key=hash('sha256',Config::string('APP_KEY'),true);$iv=random_bytes(12);$tag='';
        $cipher=openssl_encrypt($value,'aes-256-gcm',$key,OPENSSL_RAW_DATA,$iv,$tag);
        if($cipher===false) throw new HttpException(503,'Push kaydı güvenli biçimde saklanamadı.','push_storage_failed');
        return base64_encode($iv.$tag.$cipher);
    }
}
