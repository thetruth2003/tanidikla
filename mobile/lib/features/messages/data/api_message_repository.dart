import 'dart:async';

import 'package:ankara_proje/core/network/api_client.dart';
import 'package:ankara_proje/core/realtime/realtime_client.dart';
import 'package:ankara_proje/features/auth/application/auth_controller.dart';
import 'package:ankara_proje/features/messages/domain/conversation.dart';
import 'package:ankara_proje/features/messages/domain/message_repository.dart';

class ApiMessageRepository implements MessageRepository {
  ApiMessageRepository(
    this._client, {
    this.pollInterval = const Duration(seconds: 3),
  });

  final ApiClient _client;
  final Duration pollInterval;

  @override
  Future<String> startListingConversation(String listingId) async {
    final data = await _client.post(
      '/conversations',
      body: {'listing_id': listingId},
    );
    return data['conversation_id']?.toString() ?? '';
  }

  @override
  Future<List<ConversationSummary>> fetchConversations() async {
    final data = await _client.get('/conversations');
    final userId = apiAuthSession.currentUser?.id;
    return [
      for (final row in _maps(data['items']))
        ConversationSummary(
          id: row['id']?.toString() ?? '',
          listingId: row['listing_id']?.toString() ?? '',
          listingTitle: row['listing_title']?.toString() ?? 'İlan konuşması',
          otherUserName: row['other_user_name']?.toString() ?? 'Kullanıcı',
          lastMessage: row['last_message']?.toString() ?? '',
          updatedAt: DateTime.tryParse(
            row['last_message_at']?.toString() ??
                row['updated_at']?.toString() ??
                '',
          ),
          section: _section(row, userId),
          unreadCount: _int(row['unread_count']),
          otherUserId: row['other_user_id']?.toString() ?? '',
          otherUserAvatar: _absoluteMediaUrl(row['other_user_avatar']),
        ),
    ];
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String conversationId) async* {
    final messages = <int, ChatMessage>{};
    var afterId = 0;
    var hasYielded = false;
    var retryDelay = const Duration(seconds: 1);

    while (true) {
      try {
        var changed = false;
        while (true) {
          final data = await _client.get(
            '/conversations/$conversationId/messages',
            query: {'after_id': afterId},
          );
          final rows = _maps(data['items']);
          for (final row in rows) {
            final message = ChatMessage(
              id: _int(row['id']),
              conversationId: row['conversation_id']?.toString() ?? '',
              senderId: row['sender_id']?.toString() ?? '',
              body: row['body']?.toString() ?? '',
              createdAt:
                  DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                  DateTime.now(),
              attachments: [
                for (final attachment in _maps(row['attachments']))
                  ChatAttachment(
                    id: attachment['media_id']?.toString() ?? '',
                    url: _absoluteMediaUrl(attachment['url']) ?? '',
                  ),
              ],
            );
            if (message.id <= 0) continue;
            messages[message.id] = message;
            if (message.id > afterId) afterId = message.id;
            changed = true;
          }
          if (data['has_more'] != true || rows.isEmpty) break;
        }

        if (changed || !hasYielded) {
          final ordered = messages.values.toList()
            ..sort((left, right) => left.id.compareTo(right.id));
          yield ordered;
          hasYielded = true;
          if (afterId > 0) {
            await _client.post(
              '/conversations/$conversationId/read',
              body: {'message_id': afterId},
            );
          }
        }
        retryDelay = const Duration(seconds: 1);
        await realtimeClient.waitForConversation(conversationId, pollInterval);
      } on ApiException catch (error) {
        if (error.statusCode == 401 || error.statusCode == 403) rethrow;
        await Future<void>.delayed(retryDelay);
        retryDelay = Duration(seconds: (retryDelay.inSeconds * 2).clamp(1, 30));
      } catch (_) {
        await Future<void>.delayed(retryDelay);
        retryDelay = Duration(seconds: (retryDelay.inSeconds * 2).clamp(1, 30));
      }
    }
  }

  @override
  Future<void> sendMessage(
    String conversationId,
    String body, {
    List<MessageImageUpload> attachments = const [],
  }) async {
    final attachmentIds = <String>[];
    for (final attachment in attachments.take(5)) {
      final media = await _client.uploadImage(
        '/uploads/images',
        bytes: attachment.bytes,
        filename: attachment.filename,
        fields: {'purpose': 'message', 'conversation_id': conversationId},
      );
      final id = media['id']?.toString() ?? '';
      if (id.isNotEmpty) attachmentIds.add(id);
    }
    await _client.post(
      '/conversations/$conversationId/messages',
      body: {'body': body.trim(), 'attachment_ids': attachmentIds},
    );
  }
}

String? _absoluteMediaUrl(Object? value) {
  final path = value?.toString() ?? '';
  if (path.isEmpty) return null;
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  return apiClient.baseUrl.replaceFirst(RegExp(r'/api/v1$'), '') +
      (path.startsWith('/') ? path : '/$path');
}

ConversationSection _section(Map<String, dynamic> row, String? userId) {
  final isOwner = row['listing_owner_id']?.toString() == userId;
  final isServiceOffer = row['listing_type']?.toString() == 'service_offer';
  final isReceiving = isServiceOffer ? !isOwner : isOwner;
  return isReceiving
      ? ConversationSection.receivingService
      : ConversationSection.providingService;
}

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.map((row) => Map<String, dynamic>.from(row as Map)).toList()
    : const [];

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
