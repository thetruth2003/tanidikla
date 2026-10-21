<?php

declare(strict_types=1);

namespace App\Security;

use App\Core\Database;
use App\Core\HttpException;
use App\Core\Request;

final class RateLimiter
{
    public function __construct(private readonly Database $database)
    {
    }

    public function enforce(
        Request $request,
        string $scope,
        string $identity,
        int $limit,
        int $windowSeconds,
        int $blockSeconds,
    ): void {
        $bucketKey = $this->bucketKey($request, $scope, $identity);
        $row = $this->database->fetchOne(
            'insert into rate_limits (bucket_key, attempts, window_started_at, blocked_until)
             values (:bucket_key, 1, now(), null)
             on conflict (bucket_key) do update set
               attempts = case
                 when rate_limits.window_started_at <= now() - make_interval(secs => :window_seconds)
                 then 1 else rate_limits.attempts + 1 end,
               window_started_at = case
                 when rate_limits.window_started_at <= now() - make_interval(secs => :window_seconds_reset)
                 then now() else rate_limits.window_started_at end,
               blocked_until = case
                 when rate_limits.blocked_until is not null and rate_limits.blocked_until > now()
                 then rate_limits.blocked_until
                 when rate_limits.window_started_at <= now() - make_interval(secs => :window_seconds_block)
                 then null
                 when rate_limits.attempts + 1 > :attempt_limit
                 then now() + make_interval(secs => :block_seconds)
                 else null end
             returning attempts, blocked_until, greatest(0, extract(epoch from (coalesce(blocked_until, now()) - now())))::int as retry_after',
            [
                'bucket_key' => $bucketKey,
                'window_seconds' => $windowSeconds,
                'window_seconds_reset' => $windowSeconds,
                'window_seconds_block' => $windowSeconds,
                'attempt_limit' => $limit,
                'block_seconds' => $blockSeconds,
            ],
        );

        if ($row !== null && $row['blocked_until'] !== null) {
            $retryAfter = max(1, (int) $row['retry_after']);
            header('Retry-After: ' . $retryAfter);
            throw new HttpException(
                429,
                'Çok fazla istek gönderildi. Lütfen biraz sonra tekrar dene.',
                'rate_limited',
                ['retry_after_seconds' => $retryAfter],
            );
        }
    }

    public function clear(Request $request, string $scope, string $identity): void
    {
        $this->database->statement(
            'delete from rate_limits where bucket_key = :bucket_key',
            ['bucket_key' => $this->bucketKey($request, $scope, $identity)],
        );
    }

    private function bucketKey(Request $request, string $scope, string $identity): string
    {
        return hash('sha256', $scope . '|' . $request->clientIp() . '|' . mb_strtolower(trim($identity)));
    }
}
