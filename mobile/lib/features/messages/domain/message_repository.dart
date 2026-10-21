import 'package:ankara_proje/features/messages/domain/conversation.dart';

abstract interface class MessageRepository {
  Future<String> startListingConversation(String listingId);

  Future<List<ConversationSummary>> fetchConversations();

  Stream<List<ChatMessage>> watchMessages(String conversationId);

  Future<void> sendMessage(
    String conversationId,
    String body, {
    List<MessageImageUpload> attachments = const [],
  });
}
