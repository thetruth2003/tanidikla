<?php

declare(strict_types=1);

namespace App\Notifications;

use App\Core\Database;

final class NotificationService
{
    public function __construct(private readonly Database $database)
    {
    }

    /** @return array{items: list<array<string, mixed>>, unread_count: int} */
    public function list(string $userId, int $limit = 50, int $beforeId = 0): array
    {
        $limit = min(100, max(1, $limit));
        $parameters = ['user_id' => $userId];
        $before = '';
        if ($beforeId > 0) {
            $before = 'and id < :before_id';
            $parameters['before_id'] = $beforeId;
        }
        $items = $this->database->fetchAll(
            "select id, type, title, body, data, read_at, created_at
             from notifications where user_id = :user_id {$before}
             order by id desc limit {$limit}",
            $parameters,
        );
        foreach ($items as &$item) {
            $item['id'] = (int) $item['id'];
            $item['data'] = json_decode((string) $item['data'], true) ?: [];
        }
        unset($item);
        $count = $this->database->fetchOne(
            'select count(*)::int as total from notifications where user_id = :user_id and read_at is null',
            ['user_id' => $userId],
        );
        return ['items' => $items, 'unread_count' => (int) ($count['total'] ?? 0)];
    }

    public function markRead(string $userId, ?int $notificationId = null): int
    {
        if ($notificationId !== null) {
            return $this->database->statement(
                'update notifications set read_at = now() where id = :id and user_id = :user_id and read_at is null',
                ['id' => $notificationId, 'user_id' => $userId],
            )->rowCount();
        }
        return $this->database->statement(
            'update notifications set read_at = now() where user_id = :user_id and read_at is null',
            ['user_id' => $userId],
        )->rowCount();
    }
}
