import 'package:ankara_proje/core/network/api_client.dart';
import 'package:ankara_proje/core/realtime/realtime_client.dart';
import 'package:ankara_proje/features/auth/application/auth_controller.dart';
import 'package:ankara_proje/features/messages/data/api_message_repository.dart';
import 'package:ankara_proje/features/messages/data/fake_message_repository.dart';
import 'package:ankara_proje/features/messages/domain/conversation.dart';
import 'package:ankara_proje/features/messages/domain/message_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final messageRepositoryProvider = Provider<MessageRepository>(
  (ref) => apiAuthSession.initialized
      ? ApiMessageRepository(apiClient)
      : FakeMessageRepository(),
);

final conversationSummariesProvider = FutureProvider<List<ConversationSummary>>(
  (ref) {
    ref.watch(currentUserIdProvider);
    if (apiAuthSession.isAuthenticated) ref.watch(realtimeEventsProvider);
    return ref.watch(messageRepositoryProvider).fetchConversations();
  },
);

final chatMessagesProvider = StreamProvider.family<List<ChatMessage>, String>((
  ref,
  conversationId,
) {
  return ref.watch(messageRepositoryProvider).watchMessages(conversationId);
});
