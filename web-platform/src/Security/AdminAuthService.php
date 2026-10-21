<?php

declare(strict_types=1);

namespace App\Security;

use App\Core\Config;
use App\Core\Database;
use App\Core\HttpException;
use App\Core\Request;
use App\Core\RequestContext;

final class AdminAuthService
{
    public function __construct(private readonly Database $database)
    {
    }

    public function ensurePreAuthCookie(Request $request): void
    {
        $name = Config::string('ADMIN_PRE_AUTH_CSRF_COOKIE', 'ankara_admin_pre_csrf');
        if (is_string($request->cookies[$name] ?? null) && $request->cookies[$name] !== '') return;
        $this->cookie($name, $this->token(), time() + 7200, false, 'Strict');
    }

    /** @return array<string, mixed> */
    public function login(string $email, string $password, Request $request): array
    {
        $preName = Config::string('ADMIN_PRE_AUTH_CSRF_COOKIE', 'ankara_admin_pre_csrf');
        $pre = $request->cookies[$preName] ?? null;
        $header = $request->header('x-csrf-token');
        if (!is_string($pre) || !is_string($header) || !hash_equals($pre, $header)) {
            throw new HttpException(419, 'Yönetim güvenlik doğrulaması başarısız.', 'csrf_failed');
        }
        $user = $this->database->fetchOne(
            "select u.id, u.email, u.password_hash, u.role, u.is_suspended, p.display_name
             from users u join profiles p on p.user_id = u.id where lower(u.email) = lower(:email)",
            ['email' => trim($email)],
        );
        if ($user === null || !password_verify($password, (string) $user['password_hash'])) {
            throw new HttpException(401, 'E-posta veya şifre hatalı.', 'invalid_credentials');
        }
        if (!in_array($user['role'], ['moderator', 'admin', 'super_admin'], true) || (bool) $user['is_suspended']) {
            throw new HttpException(403, 'Bu hesap yönetim alanına erişemez.', 'admin_forbidden');
        }
        $token = $this->token();
        $csrf = $this->token();
        $expires = new \DateTimeImmutable('+' . max(1, Config::int('ADMIN_SESSION_HOURS', 8)) . ' hours');
        $this->database->statement(
            'insert into admin_sessions (user_id, token_hash, csrf_hash, ip_address, user_agent, expires_at)
             values (:user_id, :token_hash, :csrf_hash, :ip_address, :user_agent, :expires_at)',
            [
                'user_id' => $user['id'],
                'token_hash' => $this->hash($token),
                'csrf_hash' => $this->hash($csrf),
                'ip_address' => $request->clientIp(),
                'user_agent' => mb_substr((string) ($request->header('user-agent') ?? ''), 0, 500),
                'expires_at' => $expires->format('c'),
            ],
        );
        $timestamp = $expires->getTimestamp();
        $this->cookie(Config::string('ADMIN_SESSION_COOKIE', 'ankara_admin_session'), $token, $timestamp, true, 'Strict');
        $this->cookie(Config::string('ADMIN_CSRF_COOKIE', 'ankara_admin_csrf'), $csrf, $timestamp, false, 'Strict');
        $this->clearCookie($preName, false);
        unset($user['password_hash'], $user['is_suspended']);
        return $user;
    }

    /** @return array<string, mixed> */
    public function requirePermission(Request $request, string $permission, bool $enforceCsrf = true): array
    {
        $cookie = $request->cookies[Config::string('ADMIN_SESSION_COOKIE', 'ankara_admin_session')] ?? null;
        if (!is_string($cookie) || $cookie === '') {
            throw new HttpException(401, 'Yönetim oturumu gerekli.', 'admin_authentication_required');
        }
        $idle = max(5, Config::int('ADMIN_SESSION_IDLE_MINUTES', 30));
        $user = $this->database->fetchOne(
            "select s.id as session_id, s.csrf_hash, u.id, u.email, u.role, u.is_suspended, p.display_name
             from admin_sessions s join users u on u.id = s.user_id join profiles p on p.user_id = u.id
             where s.token_hash = :token_hash and s.revoked_at is null and s.expires_at > now()
               and s.last_seen_at > now() - make_interval(mins => :idle_minutes)",
            ['token_hash' => $this->hash($cookie), 'idle_minutes' => $idle],
        );
        if ($user === null || (bool) $user['is_suspended']) {
            throw new HttpException(401, 'Yönetim oturumu sona ermiş.', 'invalid_admin_session');
        }
        if ($enforceCsrf && !in_array($request->method, ['GET', 'HEAD', 'OPTIONS'], true)) {
            $csrf = $request->header('x-csrf-token');
            if (!is_string($csrf) || !hash_equals((string) $user['csrf_hash'], $this->hash($csrf))) {
                throw new HttpException(419, 'Yönetim güvenlik doğrulaması başarısız.', 'csrf_failed');
            }
        }
        $hasPermission = $this->database->fetchOne(
            'select 1 from role_permissions where role = :role and permission_code = :permission',
            ['role' => $user['role'], 'permission' => $permission],
        ) !== null;
        if (!$hasPermission) throw new HttpException(403, 'Bu yönetim işlemi için yetkin yok.', 'admin_permission_denied');
        $this->database->statement('update admin_sessions set last_seen_at = now() where id = :id', ['id' => $user['session_id']]);
        unset($user['session_id'], $user['csrf_hash'], $user['is_suspended']);
        RequestContext::setUserId((string) $user['id']);
        return $user;
    }

    public function logout(Request $request): void
    {
        $cookie = $request->cookies[Config::string('ADMIN_SESSION_COOKIE', 'ankara_admin_session')] ?? null;
        if (is_string($cookie) && $cookie !== '') {
            $this->database->statement('update admin_sessions set revoked_at = now() where token_hash = :hash', ['hash' => $this->hash($cookie)]);
        }
        $this->clearCookie(Config::string('ADMIN_SESSION_COOKIE', 'ankara_admin_session'), true);
        $this->clearCookie(Config::string('ADMIN_CSRF_COOKIE', 'ankara_admin_csrf'), false);
    }

    private function token(): string { return rtrim(strtr(base64_encode(random_bytes(32)), '+/', '-_'), '='); }
    private function hash(string $token): string { return hash_hmac('sha256', $token, Config::string('APP_KEY')); }
    private function cookie(string $name, string $value, int $expires, bool $httpOnly, string $sameSite): void
    {
        setcookie($name, $value, ['expires' => $expires, 'path' => '/', 'secure' => Config::string('APP_ENV') === 'production', 'httponly' => $httpOnly, 'samesite' => $sameSite]);
    }
    private function clearCookie(string $name, bool $httpOnly): void { $this->cookie($name, '', time() - 3600, $httpOnly, 'Strict'); }
}
