<?php

declare(strict_types=1);

namespace App\Domain;

use App\Core\Config;
use App\Core\Database;
use App\Core\HttpException;
use App\Core\Request;
use App\Support\Uuid;

final class BetaService
{
    public function __construct(private readonly Database $database) {}

    /** @return array<string,mixed> */
    public function status(string $userId): array
    {
        $member=$this->database->fetchOne('update beta_members set last_seen_at=now() where user_id=:id returning enabled,joined_at,last_seen_at',['id'=>$userId]);
        return ['beta_mode'=>Config::bool('BETA_MODE'),'member'=>$member!==null&&(bool)$member['enabled'],'joined_at'=>$member['joined_at']??null];
    }

    /** @param array<string,mixed> $payload @return array<string,mixed> */
    public function submitFeedback(string $userId,array $payload,Request $request): array
    {
        $kind=(string)($payload['kind']??'other');$title=trim((string)($payload['title']??''));$details=trim((string)($payload['details']??''));
        if(!in_array($kind,['bug','suggestion','usability','other'],true)||mb_strlen($title)<3||mb_strlen($title)>160||mb_strlen($details)<10||mb_strlen($details)>4000) throw new HttpException(422,'Geri bildirim alanlarını kontrol et.','validation_failed');
        $context=['platform'=>mb_substr((string)($payload['platform']??'web'),0,30),'app_version'=>mb_substr((string)($payload['app_version']??''),0,40),'request_id'=>$request->header('x-request-id')];
        $id=Uuid::v4();
        $this->database->statement('insert into beta_feedback(id,user_id,kind,title,details,client_context) values(:id,:user,:kind,:title,:details,cast(:context as jsonb))',['id'=>$id,'user'=>$userId,'kind'=>$kind,'title'=>$title,'details'=>$details,'context'=>json_encode($context,JSON_THROW_ON_ERROR|JSON_UNESCAPED_UNICODE)]);
        return ['id'=>$id,'status'=>'new'];
    }

    /** @param array<string,mixed> $actor @return array<string,mixed> */
    public function createInvite(array $payload,array $actor): array
    {
        $max=max(1,min(1000,(int)($payload['max_uses']??1)));$days=max(1,min(180,(int)($payload['expires_in_days']??30)));$label=mb_substr(trim((string)($payload['label']??'')),0,160);
        $code='TANIDIKLA-'.strtoupper(bin2hex(random_bytes(6)));$id=Uuid::v4();
        $this->database->statement("insert into beta_invites(id,code_hash,label,max_uses,expires_at,created_by) values(:id,:hash,:label,:max,now()+make_interval(days => cast(:days as integer)),:actor)",['id'=>$id,'hash'=>hash('sha256',$code),'label'=>$label,'max'=>$max,'days'=>$days,'actor'=>$actor['id']]);
        return ['id'=>$id,'code'=>$code,'max_uses'=>$max,'expires_in_days'=>$days];
    }
}
