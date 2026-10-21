<?php

declare(strict_types=1);

namespace App\Notifications;

use App\Core\Config;
use RuntimeException;

final class PushSender
{
    /** @param array<string,mixed> $payload */
    public function send(string $platform, string $encryptedToken, array $payload): string
    {
        $token = $this->decrypt($encryptedToken);
        return match ($platform) {
            'android' => $this->sendFcm($token, $payload),
            'ios' => $this->sendApns($token, $payload),
            default => throw new RuntimeException('Push servisi yapılandırılmamış.'),
        };
    }

    public function configured(string $platform): bool
    {
        return match ($platform) {
            'android' => Config::string('FCM_PROJECT_ID') !== '' && Config::string('FCM_SERVICE_ACCOUNT_JSON') !== '',
            'ios' => Config::string('APNS_TEAM_ID') !== '' && Config::string('APNS_KEY_ID') !== '' && Config::string('APNS_BUNDLE_ID') !== '' && Config::string('APNS_PRIVATE_KEY') !== '',
            default => false,
        };
    }

    /** @param array<string,mixed> $payload */
    private function sendFcm(string $deviceToken, array $payload): string
    {
        $accountValue = Config::string('FCM_SERVICE_ACCOUNT_JSON');
        $json = is_file($accountValue) ? file_get_contents($accountValue) : $accountValue;
        $account = json_decode((string) $json, true);
        if (!is_array($account) || empty($account['client_email']) || empty($account['private_key'])) {
            throw new RuntimeException('FCM servis hesabı geçersiz.');
        }
        $now = time();
        $jwt = $this->jwt(['alg'=>'RS256','typ'=>'JWT'], [
            'iss'=>$account['client_email'],'scope'=>'https://www.googleapis.com/auth/firebase.messaging',
            'aud'=>'https://oauth2.googleapis.com/token','iat'=>$now,'exp'=>$now+3600,
        ], (string) $account['private_key'], OPENSSL_ALGO_SHA256);
        $oauth = $this->request('https://oauth2.googleapis.com/token', [
            'Content-Type: application/x-www-form-urlencoded',
        ], http_build_query(['grant_type'=>'urn:ietf:params:oauth:grant-type:jwt-bearer','assertion'=>$jwt]), 10);
        $access = json_decode($oauth['body'], true)['access_token'] ?? null;
        if ($oauth['status'] >= 300 || !is_string($access)) throw new RuntimeException('FCM yetkilendirmesi başarısız.');
        $message = ['message'=>['token'=>$deviceToken,'notification'=>[
            'title'=>(string)($payload['title']??'Tanıdıkla'),'body'=>(string)($payload['body']??''),
        ],'data'=>array_map(static fn($value):string=>is_scalar($value)?(string)$value:json_encode($value,JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES), (array)($payload['data']??[]))]];
        $result = $this->request('https://fcm.googleapis.com/v1/projects/'.rawurlencode(Config::string('FCM_PROJECT_ID')).'/messages:send', [
            'Authorization: Bearer '.$access,'Content-Type: application/json',
        ], json_encode($message, JSON_THROW_ON_ERROR|JSON_UNESCAPED_UNICODE), 10);
        if ($result['status'] >= 300) throw new RuntimeException('FCM teslimatı başarısız (HTTP '.$result['status'].').');
        return (string)(json_decode($result['body'],true)['name']??'sent');
    }

    /** @param array<string,mixed> $payload */
    private function sendApns(string $deviceToken, array $payload): string
    {
        $keyValue = Config::string('APNS_PRIVATE_KEY');
        $key = is_file($keyValue) ? file_get_contents($keyValue) : str_replace('\\n', "\n", $keyValue);
        $jwt = $this->jwt(['alg'=>'ES256','kid'=>Config::string('APNS_KEY_ID')], ['iss'=>Config::string('APNS_TEAM_ID'),'iat'=>time()], (string)$key, OPENSSL_ALGO_SHA256, true);
        $host = Config::bool('APNS_USE_SANDBOX') ? 'https://api.sandbox.push.apple.com' : 'https://api.push.apple.com';
        $body = ['aps'=>['alert'=>['title'=>(string)($payload['title']??'Tanıdıkla'),'body'=>(string)($payload['body']??'')],'sound'=>'default'],'data'=>$payload['data']??[]];
        $result=$this->request($host.'/3/device/'.rawurlencode($deviceToken),['authorization: bearer '.$jwt,'apns-topic: '.Config::string('APNS_BUNDLE_ID'),'apns-push-type: alert','content-type: application/json'],json_encode($body,JSON_THROW_ON_ERROR|JSON_UNESCAPED_UNICODE),10,true);
        if($result['status']!==200) throw new RuntimeException('APNs teslimatı başarısız (HTTP '.$result['status'].').');
        return $result['headers']['apns-id']??'sent';
    }

    /** @param array<string,mixed> $header @param array<string,mixed> $claims */
    private function jwt(array $header,array $claims,string $key,int|string $algorithm,bool $ecdsa=false): string
    {
        $part=$this->base64Url(json_encode($header,JSON_THROW_ON_ERROR)).'.'.$this->base64Url(json_encode($claims,JSON_THROW_ON_ERROR));
        if(!openssl_sign($part,$signature,$key,$algorithm)) throw new RuntimeException('Push imzası üretilemedi.');
        if($ecdsa)$signature=$this->derToJose($signature,64);
        return $part.'.'.$this->base64Url($signature);
    }

    private function decrypt(string $value): string
    {
        $raw=base64_decode($value,true);if($raw===false||strlen($raw)<29)throw new RuntimeException('Push tokenı çözülemedi.');
        $plain=openssl_decrypt(substr($raw,28),'aes-256-gcm',hash('sha256',Config::string('APP_KEY'),true),OPENSSL_RAW_DATA,substr($raw,0,12),substr($raw,12,16));
        if($plain===false)throw new RuntimeException('Push tokenı çözülemedi.');return $plain;
    }

    /** @param list<string> $headers @return array{status:int,body:string,headers:array<string,string>} */
    private function request(string $url,array $headers,string $body,int $timeout,bool $http2=false): array
    {
        $responseHeaders=[];$handle=curl_init($url);if($handle===false)throw new RuntimeException('Push bağlantısı açılamadı.');
        curl_setopt_array($handle,[CURLOPT_POST=>true,CURLOPT_POSTFIELDS=>$body,CURLOPT_HTTPHEADER=>$headers,CURLOPT_RETURNTRANSFER=>true,CURLOPT_CONNECTTIMEOUT=>5,CURLOPT_TIMEOUT=>$timeout,CURLOPT_HEADERFUNCTION=>static function($curl,string $line)use(&$responseHeaders):int{$parts=explode(':',$line,2);if(count($parts)===2)$responseHeaders[strtolower(trim($parts[0]))]=trim($parts[1]);return strlen($line);}]);
        if($http2)curl_setopt($handle,CURLOPT_HTTP_VERSION,CURL_HTTP_VERSION_2_0);
        $response=curl_exec($handle);$status=(int)curl_getinfo($handle,CURLINFO_RESPONSE_CODE);$error=curl_error($handle);curl_close($handle);
        if($response===false)throw new RuntimeException('Push ağına bağlanılamadı: '.$error);
        return ['status'=>$status,'body'=>(string)$response,'headers'=>$responseHeaders];
    }

    private function base64Url(string $value): string{return rtrim(strtr(base64_encode($value),'+/','-_'),'=');}

    private function derToJose(string $der,int $length): string
    {
        $offset=3;if(ord($der[1])>0x80)$offset=2+(ord($der[1])&0x7f);if(ord($der[$offset])!==2)throw new RuntimeException('APNs imza biçimi geçersiz.');
        $rLength=ord($der[++$offset]);$r=substr($der,++$offset,$rLength);$offset+=$rLength;if(ord($der[$offset])!==2)throw new RuntimeException('APNs imza biçimi geçersiz.');$sLength=ord($der[++$offset]);$s=substr($der,++$offset,$sLength);
        $half=intdiv($length,2);return str_pad(ltrim($r,"\0"),$half,"\0",STR_PAD_LEFT).str_pad(ltrim($s,"\0"),$half,"\0",STR_PAD_LEFT);
    }
}
