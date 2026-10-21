<?php

declare(strict_types=1);

namespace App\Storage;

use App\Core\Config;
use App\Core\Database;
use App\Core\HttpException;
use App\Support\Uuid;
use PDO;
use Throwable;

final class MediaService
{
    public function __construct(
        private readonly Database $database,
        private readonly ImageProcessor $processor = new ImageProcessor(),
    ) {
    }

    /** @param array<string, mixed> $file
     *  @param array<string, mixed> $user
     *  @return array<string, mixed>
     */
    public function uploadImage(
        array $file,
        string $purpose,
        array $user,
        ?string $listingId = null,
        ?string $conversationId = null,
    ): array
    {
        $this->assertUpload($file);
        if (!in_array($purpose, ['listing', 'avatar', 'message'], true)) {
            throw new HttpException(422, 'Yükleme amacı geçersiz.', 'validation_failed');
        }
        $ownerId = (string) $user['id'];
        $listing = null;
        if ($purpose === 'listing') {
            if (!is_string($listingId) || !Uuid::isValid($listingId)) {
                throw new HttpException(422, 'İlan kimliği gerekli.', 'validation_failed');
            }
            $listing = $this->database->fetchOne(
                "select id from listings where id = :id and owner_id = :owner_id and status <> 'removed'",
                ['id' => $listingId, 'owner_id' => $ownerId],
            );
            if ($listing === null) {
                throw new HttpException(404, 'Görsel ekleyebileceğin ilan bulunamadı.', 'listing_not_found');
            }
            $count = $this->database->fetchOne(
                'select count(*)::int as total from listing_images where listing_id = :listing_id',
                ['listing_id' => $listingId],
            );
            if ((int) ($count['total'] ?? 0) >= 8) {
                throw new HttpException(422, 'Bir ilana en fazla 8 görsel ekleyebilirsin.', 'image_limit_reached');
            }
        }
        if ($purpose === 'message') {
            if (!is_string($conversationId) || !Uuid::isValid($conversationId)) {
                throw new HttpException(422, 'Konuşma kimliği gerekli.', 'validation_failed');
            }
            if ($this->database->fetchOne(
                'select 1 from conversation_members where conversation_id=:conversation_id and user_id=:user_id',
                ['conversation_id' => $conversationId, 'user_id' => $ownerId],
            ) === null) {
                throw new HttpException(403, 'Bu konuşmaya görsel ekleyemezsin.', 'conversation_forbidden');
            }
            $pending = $this->database->fetchOne(
                "select count(*)::int as total from media_objects m
                 where m.owner_id=:owner_id and m.purpose='message_attachment'
                   and m.created_at>now()-interval '1 hour'
                   and not exists(select 1 from message_attachments a where a.media_id=m.id)",
                ['owner_id' => $ownerId],
            );
            if ((int) ($pending['total'] ?? 0) >= 10) {
                throw new HttpException(429, 'Bekleyen çok fazla görsel var. Biraz sonra tekrar dene.', 'upload_rate_limited');
            }
        }

        $processed = $this->processor->process((string) $file['tmp_name']);
        $mediaId = Uuid::v4();
        $mediaPurpose = match ($purpose) {
            'avatar' => 'avatar',
            'message' => 'message_attachment',
            default => 'listing_image',
        };
        $storage = StorageFactory::make();
        $visibility = $purpose === 'message' ? 'private' : 'public';
        $key = $visibility . '/' . $mediaPurpose . '/' . gmdate('Y/m') . '/' . $mediaId . '.webp';
        try {
            $storage->put($key, $processed['path'], $processed['mime_type']);
            $oldMedia = $this->database->transaction(function (PDO $pdo) use (
                $mediaId,
                $ownerId,
                $mediaPurpose,
                $storage,
                $key,
                $processed,
                $purpose,
                $visibility,
                $listingId,
            ): ?array {
                $pdo->prepare(
                    'insert into media_objects
                     (id, owner_id, storage_driver, storage_key, purpose, visibility,
                      mime_type, byte_size, width, height, sha256)
                     values (:id, :owner_id, :storage_driver, :storage_key, :purpose, :visibility,
                      :mime_type, :byte_size, :width, :height, :sha256)'
                )->execute([
                    'id' => $mediaId,
                    'owner_id' => $ownerId,
                    'storage_driver' => $storage->driver(),
                    'storage_key' => $key,
                    'purpose' => $mediaPurpose,
                    'visibility' => $visibility,
                    'mime_type' => $processed['mime_type'],
                    'byte_size' => $processed['byte_size'],
                    'width' => $processed['width'],
                    'height' => $processed['height'],
                    'sha256' => $processed['sha256'],
                ]);
                if ($purpose === 'listing') {
                    $sort = $pdo->prepare('select coalesce(max(sort_order), -1) + 1 from listing_images where listing_id = :listing_id');
                    $sort->execute(['listing_id' => $listingId]);
                    $pdo->prepare(
                        'insert into listing_images
                         (id, listing_id, owner_id, storage_path, mime_type, width, height, byte_size, sort_order, media_id)
                         values (:id, :listing_id, :owner_id, :storage_path, :mime_type,
                          :width, :height, :byte_size, :sort_order, :media_id)'
                    )->execute([
                        'id' => Uuid::v4(),
                        'listing_id' => $listingId,
                        'owner_id' => $ownerId,
                        'storage_path' => '/media/' . $mediaId,
                        'mime_type' => $processed['mime_type'],
                        'width' => $processed['width'],
                        'height' => $processed['height'],
                        'byte_size' => $processed['byte_size'],
                        'sort_order' => (int) $sort->fetchColumn(),
                        'media_id' => $mediaId,
                    ]);
                    return null;
                }
                if ($purpose === 'message') {
                    return null;
                }
                $old = $pdo->prepare(
                    'select m.id, m.storage_driver, m.storage_key
                     from profiles p left join media_objects m on m.id = p.avatar_media_id
                     where p.user_id = :user_id for update of p'
                );
                $old->execute(['user_id' => $ownerId]);
                $oldRow = $old->fetch(PDO::FETCH_ASSOC);
                $pdo->prepare(
                    'update profiles set avatar_media_id = :media_id, avatar_path = :avatar_path, updated_at = now()
                     where user_id = :user_id'
                )->execute(['media_id' => $mediaId, 'avatar_path' => '/media/' . $mediaId, 'user_id' => $ownerId]);
                return is_array($oldRow) && $oldRow['id'] !== null ? $oldRow : null;
            });
        } catch (Throwable $exception) {
            try {
                $storage->delete($key);
            } catch (Throwable) {
                // Preserve the original persistence/upload exception.
            }
            throw $exception;
        } finally {
            @unlink($processed['path']);
        }

        if (isset($oldMedia) && is_array($oldMedia)) {
            StorageFactory::make((string) $oldMedia['storage_driver'])->delete((string) $oldMedia['storage_key']);
            $this->database->statement('delete from media_objects where id = :id', ['id' => $oldMedia['id']]);
        }
        return [
            'id' => $mediaId,
            'url' => '/media/' . $mediaId,
            'mime_type' => $processed['mime_type'],
            'byte_size' => $processed['byte_size'],
            'width' => $processed['width'],
            'height' => $processed['height'],
        ];
    }

    /** @param array<string, mixed> $user */
    public function remove(string $mediaId, array $user): void
    {
        if (!Uuid::isValid($mediaId)) {
            throw new HttpException(404, 'Görsel bulunamadı.', 'media_not_found');
        }
        $media = $this->database->fetchOne(
            'select id, storage_driver, storage_key, purpose from media_objects where id = :id and owner_id = :owner_id',
            ['id' => $mediaId, 'owner_id' => $user['id']],
        );
        if ($media === null) {
            throw new HttpException(404, 'Kaldırabileceğin görsel bulunamadı.', 'media_not_found');
        }
        if ($media['purpose'] === 'message_attachment' && $this->database->fetchOne(
            'select 1 from message_attachments where media_id=:id',
            ['id' => $mediaId],
        ) !== null) {
            throw new HttpException(409, 'Gönderilmiş mesaj görseli kaldırılamaz.', 'media_in_use');
        }
        $this->database->transaction(function (PDO $pdo) use ($mediaId, $media): void {
            if ($media['purpose'] === 'avatar') {
                $pdo->prepare(
                    'update profiles set avatar_media_id = null, avatar_path = null, updated_at = now()
                     where avatar_media_id = :id'
                )->execute(['id' => $mediaId]);
            }
            $pdo->prepare('delete from media_objects where id = :id')->execute(['id' => $mediaId]);
        });
        StorageFactory::make((string) $media['storage_driver'])->delete((string) $media['storage_key']);
    }

    /** @return array{path: ?string, url: ?string, mime_type: string, byte_size: int, sha256: string} */
    public function resolvePublic(string $mediaId): array
    {
        if (!Uuid::isValid($mediaId)) {
            throw new HttpException(404, 'Görsel bulunamadı.', 'media_not_found');
        }
        $media = $this->database->fetchOne(
            "select m.storage_driver, m.storage_key, m.mime_type, m.byte_size, m.sha256
             from media_objects m
             where m.id = :id and m.visibility = 'public' and (
               exists (
                 select 1 from listing_images i join listings l on l.id = i.listing_id
                 where i.media_id = m.id and l.status = 'active' and (l.expires_at is null or l.expires_at > now())
               )
               or exists (
                 select 1 from profiles p join users u on u.id = p.user_id
                 where p.avatar_media_id = m.id and u.is_suspended = false
               )
             )",
            ['id' => $mediaId],
        );
        if ($media === null) {
            throw new HttpException(404, 'Görsel bulunamadı.', 'media_not_found');
        }
        $storage = StorageFactory::make((string) $media['storage_driver']);
        return [
            'path' => $storage->localPath((string) $media['storage_key']),
            'url' => $storage->temporaryUrl((string) $media['storage_key']),
            'mime_type' => (string) $media['mime_type'],
            'byte_size' => (int) $media['byte_size'],
            'sha256' => (string) $media['sha256'],
        ];
    }

    /** @return array{path: ?string, url: ?string, mime_type: string, byte_size: int, sha256: string} */
    public function resolveForUser(string $mediaId, string $userId): array
    {
        if (!Uuid::isValid($mediaId)) {
            throw new HttpException(404, 'Görsel bulunamadı.', 'media_not_found');
        }
        $media = $this->database->fetchOne(
            "select m.storage_driver,m.storage_key,m.mime_type,m.byte_size,m.sha256
             from media_objects m
             join message_attachments a on a.media_id=m.id
             join messages msg on msg.id=a.message_id and msg.deleted_at is null
             join conversation_members cm on cm.conversation_id=msg.conversation_id and cm.user_id=:user_id
             where m.id=:id and m.visibility='private' and m.purpose='message_attachment'",
            ['id' => $mediaId, 'user_id' => $userId],
        );
        if ($media === null) {
            throw new HttpException(404, 'Görsel bulunamadı.', 'media_not_found');
        }
        $storage = StorageFactory::make((string) $media['storage_driver']);
        return [
            'path' => $storage->localPath((string) $media['storage_key']),
            'url' => $storage->temporaryUrl((string) $media['storage_key']),
            'mime_type' => (string) $media['mime_type'],
            'byte_size' => (int) $media['byte_size'],
            'sha256' => (string) $media['sha256'],
        ];
    }

    /** @param array<string, mixed> $file */
    private function assertUpload(array $file): void
    {
        $error = (int) ($file['error'] ?? UPLOAD_ERR_NO_FILE);
        if ($error !== UPLOAD_ERR_OK) {
            $message = $error === UPLOAD_ERR_INI_SIZE || $error === UPLOAD_ERR_FORM_SIZE
                ? 'Görsel izin verilen boyutu aşıyor.'
                : 'Görsel yüklenemedi.';
            throw new HttpException(422, $message, 'upload_failed');
        }
        $size = (int) ($file['size'] ?? 0);
        $maximum = max(1, Config::int('UPLOAD_MAX_MB', 8)) * 1024 * 1024;
        if ($size < 1 || $size > $maximum) {
            throw new HttpException(422, 'Görsel boyutu geçersiz.', 'invalid_upload_size');
        }
        $tmp = (string) ($file['tmp_name'] ?? '');
        if ($tmp === '' || !is_uploaded_file($tmp)) {
            throw new HttpException(422, 'Geçerli bir yükleme bulunamadı.', 'invalid_upload');
        }
    }
}
