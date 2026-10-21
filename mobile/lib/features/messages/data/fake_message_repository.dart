import 'package:ankara_proje/features/messages/domain/conversation.dart';
import 'package:ankara_proje/features/messages/domain/message_repository.dart';

class FakeMessageRepository implements MessageRepository {
  @override
  Future<List<ConversationSummary>> fetchConversations() async => const [];

  @override
  Future<void> sendMessage(
    String conversationId,
    String body, {
    List<MessageImageUpload> attachments = const [],
  }) async {}

  @override
  Future<String> startListingConversation(String listingId) async =>
      'fake-conversation';

  @override
  Stream<List<ChatMessage>> watchMessages(String conversationId) =>
      Stream.value(const []);
}
