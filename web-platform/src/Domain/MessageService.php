<?php

declare(strict_types=1);

namespace App\Domain;

use App\Core\Config;
use App\Core\Database;
use App\Core\HttpException;
use App\Security\ContentPolicy;
use App\Support\Uuid;
use PDO;

final class MessageService
{
    public function __construct(private readonly Database $database)
    {
    }

    public function startConversation(string $listingId, string $userId, ?string $listingItemId = null): string
    {
        if (!Uuid::isValid($listingId)) {
            throw new HttpException(422, 'Geçerli bir ilan kimliği gerekli.', 'validation_failed');
        }

        if ($listingItemId !== null && !Uuid::isValid($listingItemId)) {
            throw new HttpException(422, 'Geçerli bir hizmet kalemi gerekli.', 'validation_failed');
        }
        return $this->database->transaction(function (PDO $pdo) use ($listingId, $userId, $listingItemId): string {
            $statement = $pdo->prepare(
                "select owner_id from listings where id = :id and status = 'active'
                 and (expires_at is null or expires_at > now()) for update"
            );
            $statement->execute(['id' => $listingId]);
            $listing = $statement->fetch();
            if ($listing === false) {
                throw new HttpException(404, 'Aktif ilan bulunamadı.', 'listing_not_found');
            }
            $ownerId = (string) $listing['owner_id'];
            if ($ownerId === $userId) {
                throw new HttpException(422, 'Kendi ilanınla konuşma başlatamazsın.', 'own_listing_conversation');
            }
            if ($listingItemId !== null) {
                $item=$pdo->prepare('select 1 from listing_items where id=:item and listing_id=:listing and is_active and deleted_at is null');
                $item->execute(['item'=>$listingItemId,'listing'=>$listingId]);
                if ($item->fetchColumn()===false) throw new HttpException(404,'Aktif hizmet kalemi bulunamadı.','listing_item_not_found');
            }
            $blocked = $pdo->prepare(
                'select 1 from user_blocks
                 where (blocker_id = :user_id and blocked_user_id = :owner_id)
                    or (blocker_id = :owner_id_reverse and blocked_user_id = :user_id_reverse)
                 limit 1'
            );
            $blocked->execute([
                'user_id' => $userId,
                'owner_id' => $ownerId,
                'owner_id_reverse' => $ownerId,
                'user_id_reverse' => $userId,
            ]);
            if ($blocked->fetchColumn() !== false) {
                throw new HttpException(403, 'Bu kullanıcıyla mesajlaşamazsın.', 'user_blocked');
            }

            $existing = $pdo->prepare(
                'select c.id from conversations c
                 where c.listing_id = :listing_id and c.listing_item_id is not distinct from :listing_item_id
                   and exists (select 1 from conversation_members m where m.conversation_id = c.id and m.user_id = :user_id)
                   and exists (select 1 from conversation_members m where m.conversation_id = c.id and m.user_id = :owner_id)
                 limit 1'
            );
            $existing->execute(['listing_id' => $listingId, 'listing_item_id'=>$listingItemId, 'user_id' => $userId, 'owner_id' => $ownerId]);
            $conversationId = $existing->fetchColumn();
            if (is_string($conversationId) && $conversationId !== '') {
                return $conversationId;
            }

            $conversationId = Uuid::v4();
            $pdo->prepare('insert into conversations (id, listing_id, listing_item_id) values (:id, :listing_id, :listing_item_id)')
                ->execute(['id' => $conversationId, 'listing_id' => $listingId, 'listing_item_id'=>$listingItemId]);
            $member = $pdo->prepare('insert into conversation_members (conversation_id, user_id) values (:conversation_id, :user_id)');
            $member->execute(['conversation_id' => $conversationId, 'user_id' => $userId]);
            $member->execute(['conversation_id' => $conversationId, 'user_id' => $ownerId]);
            return $conversationId;
        });
    }

    /** @return list<array<string, mixed>> */
    public function conversations(string $userId): array
    {
        return $this->database->fetchAll(
            "select c.id, c.listing_id, c.listing_item_id, c.engagement_id,
                    coalesce(selected_item.title,li.title) as listing_title,
                    selected_item.title as service_item_title, c.updated_at,
                    l.owner_id as listing_owner_id, l.listing_type,
                    case
                      when (l.owner_id = :section_user_id and l.listing_type = 'service_offer')
                        or (l.owner_id <> :section_user_id_other and l.listing_type = 'service_request')
                      then 'provide'
                      else 'receive'
                    end as conversation_section,
                    other.user_id as other_user_id, op.display_name as other_user_name,
                    op.avatar_path as other_user_avatar,
                    lm.id as last_message_id, lm.body as last_message, lm.created_at as last_message_at,
                    (select count(*)::int from messages unread
                     where unread.conversation_id = c.id and unread.deleted_at is null
                       and unread.sender_id <> :unread_user_id
                       and unread.id > coalesce(mine.last_read_message_id, 0)) as unread_count
             from conversation_members mine
             join conversations c on c.id = mine.conversation_id
             left join listings l on l.id = c.listing_id
             join conversation_members other on other.conversation_id = c.id and other.user_id <> :user_id
             join profiles op on op.user_id = other.user_id
             left join lateral (
               select title from listing_items where listing_id = c.listing_id order by page_index limit 1
             ) li on true
             left join listing_items selected_item on selected_item.id=c.listing_item_id
             left join lateral (
               select id, body, created_at from messages where conversation_id = c.id and deleted_at is null order by id desc limit 1
             ) lm on true
             where mine.user_id = :user_id_filter
             order by coalesce(lm.created_at, c.created_at) desc",
            [
                'user_id' => $userId,
                'user_id_filter' => $userId,
                'unread_user_id' => $userId,
                'section_user_id' => $userId,
                'section_user_id_other' => $userId,
            ],
        );
    }

    /** @return list<array<string, mixed>> */
    public function messages(string $conversationId, string $userId, int $afterId = 0): array
    {
        if (!Uuid::isValid($conversationId)) {
            throw new HttpException(404, 'Konuşma bulunamadı.', 'conversation_not_found');
        }
        $this->assertMember($conversationId, $userId);
        $rows = $this->database->fetchAll(
            'select id, conversation_id, sender_id, body, created_at, edited_at
             from messages where conversation_id = :conversation_id and id > :after_id and deleted_at is null
             order by id asc limit 200',
            ['conversation_id' => $conversationId, 'after_id' => max(0, $afterId)],
        );
        return $this->withAttachments($rows);
    }

    /** @return array<string, mixed> */
    public function send(string $conversationId, string $userId, string $body, array $attachmentIds = []): array
    {
        if (!Uuid::isValid($conversationId)) {
            throw new HttpException(404, 'Konuşma bulunamadı.', 'conversation_not_found');
        }
        $body = trim($body);
        $attachmentIds = array_values(array_unique(array_filter(
            array_map(static fn (mixed $id): string => (string) $id, $attachmentIds),
            static fn (string $id): bool => Uuid::isValid($id),
        )));
        if (count($attachmentIds) > 5) {
            throw new HttpException(422, 'Bir mesajda en fazla 5 görsel olabilir.', 'validation_failed');
        }
        if (($body === '' && $attachmentIds === []) || mb_strlen($body) > 4000) {
            throw new HttpException(422, 'Mesaj yaz veya en az bir görsel ekle.', 'validation_failed');
        }
        if ($body !== '') ContentPolicy::assertAcceptable($body, 'Mesaj');

        $message = $this->database->transaction(function (PDO $pdo) use ($conversationId, $userId, $body, $attachmentIds): array {
            $membership = $pdo->prepare(
                'select 1 from conversation_members where conversation_id = :conversation_id and user_id = :user_id'
            );
            $membership->execute(['conversation_id' => $conversationId, 'user_id' => $userId]);
            if ($membership->fetchColumn() === false) {
                throw new HttpException(403, 'Bu konuşmaya erişemezsin.', 'conversation_forbidden');
            }
            $blocked = $pdo->prepare(
                'select 1
                 from conversation_members other
                 join user_blocks b on
                   (b.blocker_id = :sender_id and b.blocked_user_id = other.user_id)
                   or (b.blocker_id = other.user_id and b.blocked_user_id = :sender_id_reverse)
                 where other.conversation_id = :conversation_id and other.user_id <> :member_id
                 limit 1'
            );
            $blocked->execute([
                'sender_id' => $userId,
                'sender_id_reverse' => $userId,
                'conversation_id' => $conversationId,
                'member_id' => $userId,
            ]);
            if ($blocked->fetchColumn() !== false) {
                throw new HttpException(403, 'Bu kullanıcıyla mesajlaşamazsın.', 'user_blocked');
            }

            $insert = $pdo->prepare(
                'insert into messages (conversation_id, sender_id, body)
                 values (:conversation_id, :sender_id, :body)
                 returning id, conversation_id, sender_id, body, created_at, edited_at'
            );
            $insert->execute([
                'conversation_id' => $conversationId,
                'sender_id' => $userId,
                'body' => $body,
            ]);
            $row = $insert->fetch(PDO::FETCH_ASSOC);
            if ($row === false) {
                throw new HttpException(500, 'Mesaj gönderilemedi.', 'message_failed');
            }

            if ($attachmentIds !== []) {
                $attach = $pdo->prepare(
                    "insert into message_attachments(id,message_id,media_id)
                     select :id,:message_id,m.id from media_objects m
                     where m.id=:media_id and m.owner_id=:owner_id
                       and m.purpose='message_attachment' and m.visibility='private'
                       and not exists(select 1 from message_attachments existing where existing.media_id=m.id)"
                );
                foreach ($attachmentIds as $mediaId) {
                    $attach->execute([
                        'id' => Uuid::v4(),
                        'message_id' => $row['id'],
                        'media_id' => $mediaId,
                        'owner_id' => $userId,
                    ]);
                    if ($attach->rowCount() !== 1) {
                        throw new HttpException(422, 'Mesaj görseli geçersiz veya daha önce kullanılmış.', 'invalid_message_attachment');
                    }
                }
            }

            $pdo->prepare('update conversations set updated_at = now() where id = :id')
                ->execute(['id' => $conversationId]);

            $sender = $pdo->prepare('select display_name from profiles where user_id = :user_id');
            $sender->execute(['user_id' => $userId]);
            $senderName = (string) ($sender->fetchColumn() ?: 'Bir kullanıcı');
            $recipients = $pdo->prepare(
                'select cm.user_id, u.email, p.message_email_notifications
                 from conversation_members cm
                 join users u on u.id = cm.user_id
                 join profiles p on p.user_id = cm.user_id
                 where cm.conversation_id = :conversation_id and cm.user_id <> :sender_id'
            );
            $recipients->execute(['conversation_id' => $conversationId, 'sender_id' => $userId]);
            $notificationInsert = $pdo->prepare(
                "insert into notifications (user_id, type, title, body, data)
                 values (:user_id, 'message', :title, :body, cast(:data as jsonb)) returning id"
            );
            $outboxInsert = $pdo->prepare(
                "insert into realtime_outbox (channel, event_type, payload)
                 values (:channel, :event_type, cast(:payload as jsonb))"
            );
            $emailInsert = $pdo->prepare(
                'insert into email_queue (recipient, subject, html_body, text_body)
                 values (:recipient, :subject, :html_body, :text_body)'
            );
            while (($recipient = $recipients->fetch(PDO::FETCH_ASSOC)) !== false) {
                $recipientId = (string) $recipient['user_id'];
                $notificationData = [
                    'conversation_id' => $conversationId,
                    'message_id' => (int) $row['id'],
                    'sender_id' => $userId,
                ];
                $notificationInsert->execute([
                    'user_id' => $recipientId,
                    'title' => $senderName . ' sana mesaj gönderdi',
                    'body' => mb_substr($body !== '' ? $body : 'Bir fotoğraf gönderdi.', 0, 180),
                    'data' => json_encode($notificationData, JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE),
                ]);
                $notificationId = (int) $notificationInsert->fetchColumn();
                $outboxInsert->execute([
                    'channel' => 'user:' . $recipientId,
                    'event_type' => 'notification.created',
                    'payload' => json_encode([
                        'notification_id' => $notificationId,
                        'type' => 'message',
                        ...$notificationData,
                    ], JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE),
                ]);
                if (Config::bool('MAIL_ENABLED') && (bool) $recipient['message_email_notifications']) {
                    $conversationUrl = rtrim(Config::string('APP_URL'), '/') . '/mesajlar?conversation=' . rawurlencode($conversationId);
                    $preview = mb_substr($body !== '' ? $body : 'Bir fotoğraf gönderdi.', 0, 180);
                    $emailInsert->execute([
                        'recipient' => mb_strtolower((string) $recipient['email']),
                        'subject' => $senderName . ' sana yeni bir mesaj gönderdi',
                        'html_body' => '<p><strong>' . htmlspecialchars($senderName, ENT_QUOTES) . '</strong> sana yeni bir mesaj gönderdi.</p><p>' . htmlspecialchars($preview, ENT_QUOTES) . '</p><p><a href="' . htmlspecialchars($conversationUrl, ENT_QUOTES) . '">Mesajı aç</a></p>',
                        'text_body' => $senderName . " sana yeni bir mesaj gönderdi:\n" . $preview . "\n" . $conversationUrl,
                    ]);
                }
            }
            $outboxInsert->execute([
                'channel' => 'conversation:' . $conversationId,
                'event_type' => 'message.created',
                'payload' => json_encode($row, JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE),
            ]);
            return $row;
        });
        return $this->withAttachments([$message])[0];
    }

    public function markRead(string $conversationId, string $userId, ?int $messageId = null): int
    {
        if (!Uuid::isValid($conversationId)) {
            throw new HttpException(404, 'Konuşma bulunamadı.', 'conversation_not_found');
        }
        $this->assertMember($conversationId, $userId);
        if ($messageId === null || $messageId < 1) {
            $latest = $this->database->fetchOne(
                'select max(id)::bigint as id from messages where conversation_id = :conversation_id and deleted_at is null',
                ['conversation_id' => $conversationId],
            );
            $messageId = isset($latest['id']) ? (int) $latest['id'] : 0;
        }
        if ($messageId > 0) {
            $this->database->statement(
                'update conversation_members set last_read_message_id = greatest(coalesce(last_read_message_id, 0), :message_id)
                 where conversation_id = :conversation_id and user_id = :user_id',
                ['message_id' => $messageId, 'conversation_id' => $conversationId, 'user_id' => $userId],
            );
            $this->database->statement(
                "update notifications set read_at = now()
                 where user_id = :user_id and type = 'message' and read_at is null
                   and data ->> 'conversation_id' = :conversation_id
                   and coalesce((data ->> 'message_id')::bigint, 0) <= :message_id",
                ['user_id' => $userId, 'conversation_id' => $conversationId, 'message_id' => $messageId],
            );
        }
        return $messageId;
    }

    private function assertMember(string $conversationId, string $userId): void
    {
        if ($this->database->fetchOne(
            'select 1 from conversation_members where conversation_id = :conversation_id and user_id = :user_id',
            ['conversation_id' => $conversationId, 'user_id' => $userId],
        ) === null) {
            throw new HttpException(403, 'Bu konuşmaya erişemezsin.', 'conversation_forbidden');
        }
    }

    /** @param list<array<string, mixed>> $messages @return list<array<string, mixed>> */
    private function withAttachments(array $messages): array
    {
        if ($messages === []) return [];
        $placeholders = [];
        $parameters = [];
        foreach ($messages as $index => $message) {
            $key = 'message_' . $index;
            $placeholders[] = ':' . $key;
            $parameters[$key] = (int) $message['id'];
        }
        $attachments = $this->database->fetchAll(
            'select a.message_id,m.id as media_id,m.mime_type,m.width,m.height,m.byte_size
             from message_attachments a join media_objects m on m.id=a.media_id
             where a.message_id in (' . implode(',', $placeholders) . ')
             order by a.created_at',
            $parameters,
        );
        $byMessage = [];
        foreach ($attachments as $attachment) {
            $messageId = (string) $attachment['message_id'];
            $attachment['url'] = '/media/' . $attachment['media_id'];
            $attachment['width'] = (int) $attachment['width'];
            $attachment['height'] = (int) $attachment['height'];
            $attachment['byte_size'] = (int) $attachment['byte_size'];
            $byMessage[$messageId][] = $attachment;
        }
        foreach ($messages as &$message) {
            $message['attachments'] = $byMessage[(string) $message['id']] ?? [];
        }
        unset($message);
        return $messages;
    }
}
