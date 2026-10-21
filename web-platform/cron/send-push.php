<?php

declare(strict_types=1);

use App\Core\Database;
use App\Core\Logger;
use App\Core\RequestContext;
use App\Notifications\PushSender;

if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require dirname(__DIR__) . '/bootstrap.php';
RequestContext::initialize('cron-push-' . bin2hex(random_bytes(8)));

$lock=fopen(APP_ROOT.'/storage/temp/send-push.lock','c+');
if($lock===false||!flock($lock,LOCK_EX|LOCK_NB)){fwrite(STDOUT,"Push worker zaten çalışıyor.\n");exit(0);}
$database=new Database();$sender=new PushSender();$processed=0;
while($processed<100){
    $job=$database->transaction(static function(PDO $pdo):?array{
        $row=$pdo->query("select q.id,q.platform,q.payload,q.attempts,d.encrypted_token from push_delivery_queue q join device_push_tokens d on d.id=q.device_token_id and d.revoked_at is null where q.status in ('pending','failed') and q.next_attempt_at<=now() order by q.id for update of q skip locked limit 1")->fetch(PDO::FETCH_ASSOC);
        if($row===false)return null;$pdo->prepare("update push_delivery_queue set status='processing',attempts=attempts+1 where id=:id")->execute(['id'=>$row['id']]);return $row;
    });
    if($job===null)break;
    if(!$sender->configured((string)$job['platform'])){$database->statement("update push_delivery_queue set status='unconfigured',last_error='Servis yapılandırılmamış.' where id=:id",['id'=>$job['id']]);$processed++;continue;}
    try{$payload=json_decode((string)$job['payload'],true,512,JSON_THROW_ON_ERROR);$reference=$sender->send((string)$job['platform'],(string)$job['encrypted_token'],is_array($payload)?$payload:[]);$database->statement("update push_delivery_queue set status='sent',sent_at=now(),last_error=null where id=:id",['id'=>$job['id']]);}
    catch(Throwable $exception){$delay=min(3600,60*(2**min(6,(int)$job['attempts']+1)));$database->statement("update push_delivery_queue set status='failed',next_attempt_at=now()+make_interval(secs=>:delay),last_error=:error where id=:id",['id'=>$job['id'],'delay'=>$delay,'error'=>mb_substr($exception->getMessage(),0,1000)]);Logger::error('Push delivery failed',['push_queue_id'=>(int)$job['id'],'exception_type'=>$exception::class]);}
    $processed++;
}
flock($lock,LOCK_UN);fclose($lock);fwrite(STDOUT,"İşlenen push: {$processed}\n");
