import 'package:ankara_proje/core/network/api_client.dart';
import 'package:ankara_proje/core/realtime/realtime_client.dart';
import 'package:ankara_proje/features/auth/application/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.read,
    required this.createdAt,
  });

  final int id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool read;
  final DateTime? createdAt;
}

class NotificationInbox {
  const NotificationInbox({required this.items, required this.unreadCount});

  final List<AppNotification> items;
  final int unreadCount;
}

class NotificationClient {
  const NotificationClient(this._client);

  final ApiClient _client;

  Future<NotificationInbox> fetch() async {
    final data = await _client.get('/notifications', query: {'limit': 100});
    return NotificationInbox(
      unreadCount: _int(data['unread_count']),
      items: [
        for (final row in _maps(data['items']))
          AppNotification(
            id: _int(row['id']),
            type: row['type']?.toString() ?? 'system',
            title: row['title']?.toString() ?? 'Bildirim',
            body: row['body']?.toString() ?? '',
            data: row['data'] is Map
                ? Map<String, dynamic>.from(row['data'] as Map)
                : const {},
            read: row['read_at'] != null,
            createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
          ),
      ],
    );
  }

  Future<void> markRead(int id) =>
      _client.post('/notifications/$id/read').then((_) {});

  Future<void> markAllRead() =>
      _client.post('/notifications/read-all').then((_) {});
}

final notificationClientProvider = Provider<NotificationClient>(
  (_) => NotificationClient(apiClient),
);

final notificationInboxProvider = FutureProvider<NotificationInbox>((ref) {
  ref.watch(authStateChangesProvider);
  if (!apiAuthSession.isAuthenticated) {
    return const NotificationInbox(items: [], unreadCount: 0);
  }
  ref.watch(realtimeEventsProvider);
  return ref.watch(notificationClientProvider).fetch();
});

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.map((row) => Map<String, dynamic>.from(row as Map)).toList()
    : const [];

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
