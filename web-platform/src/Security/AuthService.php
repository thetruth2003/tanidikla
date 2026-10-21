<?php

declare(strict_types=1);

namespace App\Security;

use App\Core\Config;
use App\Core\Database;
use App\Core\HttpException;
use App\Core\Request;
use App\Core\RequestContext;
use App\Notifications\EmailQueueService;
use App\Support\Uuid;
use DateTimeImmutable;
use PDO;

final class AuthService
{
    public function __construct(
        private readonly Database $database,
        private readonly EmailQueueService $emailQueue,
    ) {
    }

    /** @return array{user: array<string, mixed>, session: array<string, mixed>} */
    public function register(
        string $email,
        string $password,
        string $passwordConfirmation,
        string $displayName,
        string $profileType,
        bool $messageEmailNotifications,
        string $betaInviteCode,
        Request $request,
    ): array
    {
        $email = $this->normalizeEmail($email);
        $displayName = trim($displayName);
        $profileType = trim($profileType);
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            throw new HttpException(422, 'Geçerli bir e-posta adresi yazmalısın.', 'validation_failed', ['email' => 'Geçersiz e-posta.']);
        }
        if (mb_strlen($displayName) < 2 || mb_strlen($displayName) > 80) {
            throw new HttpException(422, 'Görünen ad 2–80 karakter olmalı.', 'validation_failed', ['display_name' => 'Geçersiz uzunluk.']);
        }
        ContentPolicy::assertAcceptable($displayName, 'Görünen ad');
        if (!in_array($profileType, ['person', 'business'], true)) {
            throw new HttpException(422, 'Hesap türü geçersiz.', 'validation_failed');
        }
        if (!hash_equals($password, $passwordConfirmation)) {
            throw new HttpException(422, 'Şifreler aynı olmalı.', 'password_confirmation_mismatch');
        }
        $this->assertPassword($password);
        if ($this->database->fetchOne('select id from users where lower(email) = :email', ['email' => $email]) !== null) {
            throw new HttpException(409, 'Bu e-posta adresi zaten kayıtlı.', 'email_already_registered');
        }

        $userId = Uuid::v4();
        $passwordHash = password_hash($password, PASSWORD_ARGON2ID);
        $verificationToken = $this->randomToken();
        $verificationHash = $this->hashToken($verificationToken);
        $mailEnabled = Config::bool('MAIL_ENABLED');
        $betaMode = Config::bool('BETA_MODE');
        $betaCodeHash = hash('sha256', trim($betaInviteCode));
        if ($betaMode && trim($betaInviteCode) === '') {
            throw new HttpException(403, 'Kapalı beta için geçerli bir davet kodu gerekli.', 'beta_invite_required');
        }

        $this->database->transaction(function (PDO $pdo) use (
            $userId,
            $email,
            $passwordHash,
            $displayName,
            $profileType,
            $messageEmailNotifications,
            $verificationHash,
            $mailEnabled,
            $betaMode,
            $betaCodeHash,
        ): void {
            $betaInviteId = null;
            if ($betaMode) {
                $invite = $pdo->prepare("select id from beta_invites where code_hash=:hash and is_active and (expires_at is null or expires_at>now()) and use_count<max_uses for update");
                $invite->execute(['hash'=>$betaCodeHash]);
                $betaInviteId = $invite->fetchColumn();
                if (!$betaInviteId) throw new HttpException(403,'Davet kodu geçersiz, süresi dolmuş veya kullanım hakkı bitmiş.','beta_invite_invalid');
            }
            $pdo->prepare(
                'insert into users (id, email, password_hash, email_verified_at)
                 values (:id, :email, :password_hash, :verified_at)'
            )->execute([
                'id' => $userId,
                'email' => $email,
                'password_hash' => $passwordHash,
                'verified_at' => $mailEnabled ? null : gmdate('Y-m-d H:i:sP'),
            ]);
            $pdo->prepare(
                'insert into profiles (user_id, display_name, profile_type, message_email_notifications)
                 values (:user_id, :display_name, :profile_type, :message_email_notifications)'
            )->execute([
                'user_id' => $userId,
                'display_name' => $displayName,
                'profile_type' => $profileType,
                'message_email_notifications' => $messageEmailNotifications ? 'true' : 'false',
            ]);
            if ($mailEnabled) {
                $pdo->prepare(
                    "insert into email_verification_tokens (user_id, token_hash, expires_at)
                     values (:user_id, :token_hash, now() + interval '24 hours')"
                )->execute(['user_id' => $userId, 'token_hash' => $verificationHash]);
            }
            if ($betaMode && is_string($betaInviteId)) {
                $pdo->prepare('insert into beta_members(user_id,invite_id) values(:user,:invite)')->execute(['user'=>$userId,'invite'=>$betaInviteId]);
                $pdo->prepare('update beta_invites set use_count=use_count+1 where id=:id')->execute(['id'=>$betaInviteId]);
            }
        });

        if ($mailEnabled) {
            $this->queueVerificationEmail($email, $verificationToken);
        }

        return [
            'user' => $this->publicUser($userId),
            'session' => $this->issueClientSession($userId, $request),
        ];
    }

    /** @return array{user: array<string, mixed>, session: array<string, mixed>} */
    public function login(string $email, string $password, Request $request): array
    {
        $email = $this->normalizeEmail($email);
        $row = $this->database->fetchOne(
            'select id, password_hash, is_suspended from users where lower(email) = :email',
            ['email' => $email],
        );
        if ($row === null || !password_verify($password, (string) $row['password_hash'])) {
            throw new HttpException(401, 'E-posta veya şifre hatalı.', 'invalid_credentials');
        }
        if ((bool) $row['is_suspended']) {
            throw new HttpException(403, 'Bu hesap askıya alınmış.', 'account_suspended');
        }

        $userId = (string) $row['id'];
        if (password_needs_rehash((string) $row['password_hash'], PASSWORD_ARGON2ID)) {
            $this->database->statement(
                'update users set password_hash = :password_hash, updated_at = now() where id = :id',
                ['password_hash' => password_hash($password, PASSWORD_ARGON2ID), 'id' => $userId],
            );
        }

        return [
            'user' => $this->publicUser($userId),
            'session' => $this->issueClientSession($userId, $request),
        ];
    }

    public function requestPasswordReset(string $email): void
    {
        $email = $this->normalizeEmail($email);
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            throw new HttpException(422, 'Geçerli bir e-posta adresi yazmalısın.', 'validation_failed');
        }

        $user = $this->database->fetchOne(
            'select id, email from users where lower(email) = :email and is_suspended = false',
            ['email' => $email],
        );
        if ($user === null) {
            return;
        }

        $token = $this->randomToken();
        $this->database->transaction(function (PDO $pdo) use ($user, $token): void {
            $pdo->prepare(
                'update password_reset_tokens set used_at = now()
                 where user_id = :user_id and used_at is null'
            )->execute(['user_id' => $user['id']]);
            $pdo->prepare(
                "insert into password_reset_tokens (user_id, token_hash, expires_at)
                 values (:user_id, :token_hash, now() + interval '1 hour')"
            )->execute(['user_id' => $user['id'], 'token_hash' => $this->hashToken($token)]);
        });

        $url = rtrim(Config::string('APP_URL'), '/') . '/sifre-yenile?token=' . rawurlencode($token);
        $this->emailQueue->enqueue(
            (string) $user['email'],
            'Şifreni yenile',
            '<p>Şifreni yenilemek için <a href="' . htmlspecialchars($url, ENT_QUOTES) . '">bu bağlantıya tıkla</a>.</p>',
            'Şifreni yenilemek için bağlantıyı aç: ' . $url,
        );
    }

    public function resetPassword(string $token, string $password, string $passwordConfirmation): void
    {
        if (!hash_equals($password, $passwordConfirmation)) {
            throw new HttpException(422, 'Yeni şifreler aynı olmalı.', 'password_confirmation_mismatch');
        }
        $this->assertPassword($password);
        if ($token === '') {
            throw new HttpException(422, 'Şifre yenileme anahtarı gerekli.', 'validation_failed');
        }

        $result = $this->database->transaction(function (PDO $pdo) use ($token, $password): bool {
            $statement = $pdo->prepare(
                'select id, user_id from password_reset_tokens
                 where token_hash = :token_hash and used_at is null and expires_at > now()
                 for update'
            );
            $statement->execute(['token_hash' => $this->hashToken($token)]);
            $row = $statement->fetch(PDO::FETCH_ASSOC);
            if ($row === false) {
                return false;
            }

            $pdo->prepare(
                'update users set password_hash = :password_hash, updated_at = now() where id = :user_id'
            )->execute([
                'password_hash' => password_hash($password, PASSWORD_ARGON2ID),
                'user_id' => $row['user_id'],
            ]);
            $pdo->prepare('update password_reset_tokens set used_at = now() where id = :id')
                ->execute(['id' => $row['id']]);
            $pdo->prepare('update user_sessions set revoked_at = now() where user_id = :user_id and revoked_at is null')
                ->execute(['user_id' => $row['user_id']]);
            $pdo->prepare('update api_token_families set revoked_at = now() where user_id = :user_id and revoked_at is null')
                ->execute(['user_id' => $row['user_id']]);
            return true;
        });

        if (!$result) {
            throw new HttpException(400, 'Şifre yenileme bağlantısı geçersiz veya süresi dolmuş.', 'invalid_reset_token');
        }
    }

    public function verifyEmail(string $token): void
    {
        if ($token === '') {
            throw new HttpException(422, 'Doğrulama anahtarı gerekli.', 'validation_failed');
        }

        $verified = $this->database->transaction(function (PDO $pdo) use ($token): bool {
            $statement = $pdo->prepare(
                'select id, user_id from email_verification_tokens
                 where token_hash = :token_hash and used_at is null and expires_at > now()
                 for update'
            );
            $statement->execute(['token_hash' => $this->hashToken($token)]);
            $row = $statement->fetch(PDO::FETCH_ASSOC);
            if ($row === false) {
                return false;
            }
            $pdo->prepare('update users set email_verified_at = coalesce(email_verified_at, now()), updated_at = now() where id = :id')
                ->execute(['id' => $row['user_id']]);
            $pdo->prepare('update email_verification_tokens set used_at = now() where id = :id')
                ->execute(['id' => $row['id']]);
            return true;
        });

        if (!$verified) {
            throw new HttpException(400, 'Doğrulama bağlantısı geçersiz veya süresi dolmuş.', 'invalid_verification_token');
        }
    }

    /** @param array<string, mixed> $user */
    public function resendVerification(array $user): void
    {
        if ($user['email_verified_at'] !== null || !Config::bool('MAIL_ENABLED')) {
            return;
        }
        $token = $this->randomToken();
        $this->database->transaction(function (PDO $pdo) use ($user, $token): void {
            $pdo->prepare('update email_verification_tokens set used_at = now() where user_id = :user_id and used_at is null')
                ->execute(['user_id' => $user['id']]);
            $pdo->prepare(
                "insert into email_verification_tokens (user_id, token_hash, expires_at)
                 values (:user_id, :token_hash, now() + interval '24 hours')"
            )->execute(['user_id' => $user['id'], 'token_hash' => $this->hashToken($token)]);
        });
        $this->queueVerificationEmail((string) $user['email'], $token);
    }

    /** @return array<string, mixed> */
    public function refreshMobileSession(string $refreshToken, Request $request): array
    {
        if ($refreshToken === '') {
            throw new HttpException(401, 'Yenileme anahtarı gerekli.', 'invalid_refresh_token');
        }

        $newAccessToken = $this->randomToken();
        $newRefreshToken = $this->randomToken();
        $newAccessId = Uuid::v4();
        $newRefreshId = Uuid::v4();
        $accessExpires = (new DateTimeImmutable())->modify('+' . Config::int('ACCESS_TOKEN_TTL_MINUTES', 15) . ' minutes');
        $refreshExpires = (new DateTimeImmutable())->modify('+' . Config::int('REFRESH_TOKEN_TTL_DAYS', 30) . ' days');

        $result = $this->database->transaction(function (PDO $pdo) use (
            $refreshToken,
            $newAccessToken,
            $newRefreshToken,
            $newAccessId,
            $newRefreshId,
            $accessExpires,
            $refreshExpires,
        ): array {
            $statement = $pdo->prepare(
                'select r.id, r.family_id, r.expires_at, r.rotated_at, r.revoked_at,
                        f.user_id, f.revoked_at as family_revoked_at, f.compromised_at,
                        u.is_suspended
                 from api_refresh_tokens r
                 join api_token_families f on f.id = r.family_id
                 join users u on u.id = f.user_id
                 where r.token_hash = :token_hash
                 for update of r, f'
            );
            $statement->execute(['token_hash' => $this->hashToken($refreshToken)]);
            $row = $statement->fetch(PDO::FETCH_ASSOC);
            if ($row === false || $row['revoked_at'] !== null || strtotime((string) $row['expires_at']) <= time()) {
                return ['status' => 'invalid'];
            }
            if ($row['rotated_at'] !== null) {
                $pdo->prepare(
                    'update api_token_families set compromised_at = now(), revoked_at = coalesce(revoked_at, now())
                     where id = :id'
                )->execute(['id' => $row['family_id']]);
                $pdo->prepare('update api_access_tokens set revoked_at = coalesce(revoked_at, now()) where family_id = :id')
                    ->execute(['id' => $row['family_id']]);
                $pdo->prepare('update api_refresh_tokens set revoked_at = coalesce(revoked_at, now()) where family_id = :id')
                    ->execute(['id' => $row['family_id']]);
                return ['status' => 'reused'];
            }
            if ($row['family_revoked_at'] !== null || $row['compromised_at'] !== null || (bool) $row['is_suspended']) {
                return ['status' => 'invalid'];
            }

            $pdo->prepare('update api_access_tokens set revoked_at = coalesce(revoked_at, now()) where family_id = :family_id')
                ->execute(['family_id' => $row['family_id']]);
            $pdo->prepare(
                'insert into api_access_tokens (id, family_id, token_hash, expires_at)
                 values (:id, :family_id, :token_hash, :expires_at)'
            )->execute([
                'id' => $newAccessId,
                'family_id' => $row['family_id'],
                'token_hash' => $this->hashToken($newAccessToken),
                'expires_at' => $accessExpires->format('Y-m-d H:i:sP'),
            ]);
            $pdo->prepare(
                'insert into api_refresh_tokens (id, family_id, token_hash, expires_at)
                 values (:id, :family_id, :token_hash, :expires_at)'
            )->execute([
                'id' => $newRefreshId,
                'family_id' => $row['family_id'],
                'token_hash' => $this->hashToken($newRefreshToken),
                'expires_at' => $refreshExpires->format('Y-m-d H:i:sP'),
            ]);
            $pdo->prepare(
                'update api_refresh_tokens set rotated_at = now(), last_used_at = now(), replaced_by_id = :replacement
                 where id = :id'
            )->execute(['replacement' => $newRefreshId, 'id' => $row['id']]);
            $pdo->prepare('update api_token_families set last_used_at = now() where id = :id')
                ->execute(['id' => $row['family_id']]);
            return ['status' => 'ok', 'user_id' => (string) $row['user_id']];
        });

        if ($result['status'] === 'reused') {
            throw new HttpException(401, 'Oturum güvenlik nedeniyle kapatıldı. Yeniden giriş yapmalısın.', 'refresh_token_reused');
        }
        if ($result['status'] !== 'ok') {
            throw new HttpException(401, 'Yenileme anahtarı geçersiz veya süresi dolmuş.', 'invalid_refresh_token');
        }

        return [
            'user' => $this->publicUser((string) $result['user_id']),
            'session' => $this->mobileSessionPayload($newAccessToken, $newRefreshToken, $accessExpires, $refreshExpires),
        ];
    }

    /** @return array<string, mixed> */
    public function requireUser(Request $request, bool $enforceCsrf = true): array
    {
        $bearer = $request->bearerToken();
        if ($bearer !== null) {
            $mobile = $this->mobileUser($bearer);
            if ($mobile !== null) {
                return $mobile;
            }
        }

        $cookieName = Config::string('SESSION_COOKIE', 'ankara_session');
        $token = $bearer ?? ($request->cookies[$cookieName] ?? null);
        if (!is_string($token) || $token === '') {
            throw new HttpException(401, 'Bu işlem için giriş yapmalısın.', 'authentication_required');
        }

        $idleMinutes = max(5, Config::int('SESSION_IDLE_MINUTES', 120));
        $row = $this->database->fetchOne(
            "select s.id as session_id, 'web' as session_kind, s.csrf_hash, u.id, u.email, u.role, u.email_verified_at,
                    u.is_suspended, p.display_name, p.avatar_path, p.bio, p.city, p.district, p.is_provider,
                    p.phone_e164, p.phone_visible, p.phone_verified_at, p.message_email_notifications
             from user_sessions s
             join users u on u.id = s.user_id
             join profiles p on p.user_id = u.id
             where s.token_hash = :token_hash
               and s.revoked_at is null
               and s.expires_at > now()
               and s.last_seen_at > now() - make_interval(mins => :idle_minutes)",
            ['token_hash' => $this->hashToken($token), 'idle_minutes' => $idleMinutes],
        );
        if ($row === null) {
            throw new HttpException(401, 'Oturumun sona ermiş. Yeniden giriş yapmalısın.', 'invalid_session');
        }
        if ((bool) $row['is_suspended']) {
            throw new HttpException(403, 'Bu hesap askıya alınmış.', 'account_suspended');
        }

        if ($bearer === null && $enforceCsrf && !in_array($request->method, ['GET', 'HEAD', 'OPTIONS'], true)) {
            $csrf = $request->header('x-csrf-token');
            if ($csrf === null || !hash_equals((string) $row['csrf_hash'], $this->hashToken($csrf))) {
                throw new HttpException(419, 'Güvenlik doğrulaması başarısız.', 'csrf_failed');
            }
        }

        $this->database->statement('update user_sessions set last_seen_at = now() where id = :id', ['id' => $row['session_id']]);
        unset($row['csrf_hash'], $row['is_suspended']);
        RequestContext::setUserId((string) $row['id']);
        return $row;
    }

    /** @return array<string, mixed> */
    public function requireRole(Request $request, array $roles): array
    {
        $user = $this->requireUser($request);
        if (!in_array($user['role'], $roles, true)) {
            throw new HttpException(403, 'Bu işlem için yetkin yok.', 'forbidden');
        }
        return $user;
    }

    public function logout(Request $request): void
    {
        $bearer = $request->bearerToken();
        if ($bearer !== null) {
            $family = $this->database->fetchOne(
                'select family_id from api_access_tokens where token_hash = :token_hash',
                ['token_hash' => $this->hashToken($bearer)],
            );
            if ($family !== null) {
                $this->revokeTokenFamily((string) $family['family_id']);
                return;
            }
        }

        $cookieName = Config::string('SESSION_COOKIE', 'ankara_session');
        $token = $bearer ?? ($request->cookies[$cookieName] ?? null);
        if (is_string($token) && $token !== '') {
            $this->database->statement(
                'update user_sessions set revoked_at = now() where token_hash = :token_hash and revoked_at is null',
                ['token_hash' => $this->hashToken($token)],
            );
        }
    }

    public function ensurePreAuthCsrfCookie(Request $request): void
    {
        $name = Config::string('PRE_AUTH_CSRF_COOKIE', 'ankara_pre_auth_csrf');
        if (isset($request->cookies[$name]) && is_string($request->cookies[$name]) && $request->cookies[$name] !== '') {
            return;
        }
        $this->setCookie($name, $this->randomToken(), time() + 7200, false, 'Strict');
    }

    public function refreshPreAuthCsrfCookie(): string
    {
        $token = $this->randomToken();
        $this->setCookie(
            Config::string('PRE_AUTH_CSRF_COOKIE', 'ankara_pre_auth_csrf'),
            $token,
            time() + 7200,
            false,
            'Strict',
        );
        return $token;
    }

    public function assertPreAuthCsrf(Request $request): void
    {
        if ($this->isMobileClient($request)) {
            return;
        }
        $name = Config::string('PRE_AUTH_CSRF_COOKIE', 'ankara_pre_auth_csrf');
        $cookie = $request->cookies[$name] ?? null;
        $header = $request->header('x-csrf-token');
        if (!is_string($cookie) || !is_string($header) || $cookie === '' || !hash_equals($cookie, $header)) {
            throw new HttpException(419, 'Güvenlik doğrulaması başarısız. Sayfayı yenileyip tekrar dene.', 'csrf_failed');
        }
    }

    /** @param array<string, mixed> $session */
    public function setSessionCookies(array $session): void
    {
        if (($session['type'] ?? null) !== 'web') {
            return;
        }
        $expires = strtotime((string) $session['expires_at']) ?: time() + 86400;
        $this->setCookie(Config::string('SESSION_COOKIE', 'ankara_session'), (string) $session['token'], $expires, true, 'Lax');
        $this->setCookie(Config::string('CSRF_COOKIE', 'ankara_csrf'), (string) $session['csrf_token'], $expires, false, 'Lax');
        $this->clearCookie(Config::string('PRE_AUTH_CSRF_COOKIE', 'ankara_pre_auth_csrf'), false);
    }

    public function clearSessionCookies(): void
    {
        $this->clearCookie(Config::string('SESSION_COOKIE', 'ankara_session'), true);
        $this->clearCookie(Config::string('CSRF_COOKIE', 'ankara_csrf'), false);
        $this->clearCookie(Config::string('PRE_AUTH_CSRF_COOKIE', 'ankara_pre_auth_csrf'), false);
    }

    /** @return array<string, mixed>|null */
    private function mobileUser(string $token): ?array
    {
        $row = $this->database->fetchOne(
            "select a.id as access_token_id, f.id as family_id, f.id as session_id, 'mobile' as session_kind,
                    u.id, u.email, u.role, u.email_verified_at, u.is_suspended,
                    p.display_name, p.avatar_path, p.bio, p.city, p.district, p.is_provider,
                    p.phone_e164, p.phone_visible, p.phone_verified_at, p.message_email_notifications
             from api_access_tokens a
             join api_token_families f on f.id = a.family_id
             join users u on u.id = f.user_id
             join profiles p on p.user_id = u.id
             where a.token_hash = :token_hash and a.revoked_at is null and a.expires_at > now()
               and f.revoked_at is null and f.compromised_at is null",
            ['token_hash' => $this->hashToken($token)],
        );
        if ($row === null) {
            return null;
        }
        if ((bool) $row['is_suspended']) {
            throw new HttpException(403, 'Bu hesap askıya alınmış.', 'account_suspended');
        }
        $this->database->statement(
            'update api_access_tokens set last_used_at = now() where id = :access_id',
            ['access_id' => $row['access_token_id']],
        );
        $this->database->statement(
            'update api_token_families set last_used_at = now() where id = :family_id',
            ['family_id' => $row['family_id']],
        );
        unset($row['access_token_id'], $row['family_id'], $row['is_suspended']);
        RequestContext::setUserId((string) $row['id']);
        return $row;
    }

    /** @return array<string, mixed> */
    private function issueClientSession(string $userId, Request $request): array
    {
        return $this->isMobileClient($request)
            ? $this->issueMobileSession($userId, $request)
            : $this->issueWebSession($userId, $request);
    }

    /** @return array<string, mixed> */
    private function issueWebSession(string $userId, Request $request): array
    {
        $token = $this->randomToken();
        $csrf = $this->randomToken();
        $expiresAt = (new DateTimeImmutable())->modify('+' . Config::int('SESSION_TTL_DAYS', 30) . ' days');
        $this->database->statement(
            "insert into user_sessions
             (user_id, token_hash, csrf_hash, device_name, ip_address, user_agent, expires_at, session_type)
             values (:user_id, :token_hash, :csrf_hash, :device_name, :ip_address, :user_agent, :expires_at, 'web')",
            [
                'user_id' => $userId,
                'token_hash' => $this->hashToken($token),
                'csrf_hash' => $this->hashToken($csrf),
                'device_name' => mb_substr($request->header('x-device-name') ?? 'Web tarayıcısı', 0, 120),
                'ip_address' => $request->clientIp(),
                'user_agent' => mb_substr($request->header('user-agent') ?? '', 0, 500),
                'expires_at' => $expiresAt->format('Y-m-d H:i:sP'),
            ],
        );
        return [
            'type' => 'web',
            'token' => $token,
            'csrf_token' => $csrf,
            'expires_at' => $expiresAt->format(DATE_ATOM),
        ];
    }

    /** @return array<string, mixed> */
    private function issueMobileSession(string $userId, Request $request): array
    {
        $familyId = Uuid::v4();
        $accessId = Uuid::v4();
        $refreshId = Uuid::v4();
        $accessToken = $this->randomToken();
        $refreshToken = $this->randomToken();
        $accessExpires = (new DateTimeImmutable())->modify('+' . Config::int('ACCESS_TOKEN_TTL_MINUTES', 15) . ' minutes');
        $refreshExpires = (new DateTimeImmutable())->modify('+' . Config::int('REFRESH_TOKEN_TTL_DAYS', 30) . ' days');

        $this->database->transaction(function (PDO $pdo) use (
            $userId,
            $request,
            $familyId,
            $accessId,
            $refreshId,
            $accessToken,
            $refreshToken,
            $accessExpires,
            $refreshExpires,
        ): void {
            $pdo->prepare(
                'insert into api_token_families (id, user_id, device_name, ip_address, user_agent)
                 values (:id, :user_id, :device_name, :ip_address, :user_agent)'
            )->execute([
                'id' => $familyId,
                'user_id' => $userId,
                'device_name' => mb_substr($request->header('x-device-name') ?? 'Mobil uygulama', 0, 120),
                'ip_address' => $request->clientIp(),
                'user_agent' => mb_substr($request->header('user-agent') ?? '', 0, 500),
            ]);
            $pdo->prepare(
                'insert into api_access_tokens (id, family_id, token_hash, expires_at)
                 values (:id, :family_id, :token_hash, :expires_at)'
            )->execute([
                'id' => $accessId,
                'family_id' => $familyId,
                'token_hash' => $this->hashToken($accessToken),
                'expires_at' => $accessExpires->format('Y-m-d H:i:sP'),
            ]);
            $pdo->prepare(
                'insert into api_refresh_tokens (id, family_id, token_hash, expires_at)
                 values (:id, :family_id, :token_hash, :expires_at)'
            )->execute([
                'id' => $refreshId,
                'family_id' => $familyId,
                'token_hash' => $this->hashToken($refreshToken),
                'expires_at' => $refreshExpires->format('Y-m-d H:i:sP'),
            ]);
        });

        return $this->mobileSessionPayload($accessToken, $refreshToken, $accessExpires, $refreshExpires);
    }

    /** @return array<string, mixed> */
    private function mobileSessionPayload(
        string $accessToken,
        string $refreshToken,
        DateTimeImmutable $accessExpires,
        DateTimeImmutable $refreshExpires,
    ): array {
        return [
            'type' => 'mobile',
            'token_type' => 'Bearer',
            'access_token' => $accessToken,
            'refresh_token' => $refreshToken,
            'token' => $accessToken,
            'expires_at' => $accessExpires->format(DATE_ATOM),
            'refresh_expires_at' => $refreshExpires->format(DATE_ATOM),
        ];
    }

    private function revokeTokenFamily(string $familyId): void
    {
        $this->database->transaction(function (PDO $pdo) use ($familyId): void {
            $pdo->prepare('update api_token_families set revoked_at = coalesce(revoked_at, now()) where id = :id')
                ->execute(['id' => $familyId]);
            $pdo->prepare('update api_access_tokens set revoked_at = coalesce(revoked_at, now()) where family_id = :id')
                ->execute(['id' => $familyId]);
            $pdo->prepare('update api_refresh_tokens set revoked_at = coalesce(revoked_at, now()) where family_id = :id')
                ->execute(['id' => $familyId]);
        });
    }

    private function queueVerificationEmail(string $email, string $token): void
    {
        $url = rtrim(Config::string('APP_URL'), '/') . '/e-posta-dogrula?token=' . rawurlencode($token);
        $this->emailQueue->enqueue(
            $email,
            'E-posta adresini doğrula',
            '<p>' . htmlspecialchars(Config::string('APP_NAME', 'Tanıdıkla'), ENT_QUOTES) . ' hesabını doğrulamak için <a href="' . htmlspecialchars($url, ENT_QUOTES) . '">bu bağlantıya tıkla</a>.</p>',
            'Hesabını doğrulamak için bağlantıyı aç: ' . $url,
        );
    }

    /** @return array<string, mixed> */
    private function publicUser(string $userId): array
    {
        $row = $this->database->fetchOne(
            'select u.id, u.email, u.role, u.email_verified_at,
                    p.display_name, p.avatar_path, p.bio, p.city, p.district, p.is_provider,
                    p.phone_e164, p.phone_visible, p.phone_verified_at, p.message_email_notifications
             from users u join profiles p on p.user_id = u.id where u.id = :id',
            ['id' => $userId],
        );
        if ($row === null) {
            throw new HttpException(500, 'Kullanıcı profili oluşturulamadı.', 'profile_missing');
        }
        return $row;
    }

    private function setCookie(string $name, string $value, int $expires, bool $httpOnly, string $sameSite): void
    {
        setcookie($name, $value, [
            'expires' => $expires,
            'path' => '/',
            'secure' => str_starts_with(Config::string('APP_URL'), 'https://'),
            'httponly' => $httpOnly,
            'samesite' => $sameSite,
        ]);
    }

    private function clearCookie(string $name, bool $httpOnly): void
    {
        $this->setCookie($name, '', time() - 3600, $httpOnly, 'Lax');
    }

    private function assertPassword(string $password): void
    {
        PasswordPolicy::assert($password);
    }

    private function isMobileClient(Request $request): bool
    {
        return strtolower((string) $request->header('x-client-type')) === 'mobile';
    }

    private function normalizeEmail(string $email): string
    {
        return mb_strtolower(trim($email));
    }

    private function randomToken(): string
    {
        return rtrim(strtr(base64_encode(random_bytes(32)), '+/', '-_'), '=');
    }

    private function hashToken(string $token): string
    {
        return hash('sha256', $token);
    }
}
