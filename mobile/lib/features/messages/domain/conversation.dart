enum ConversationSection { receivingService, providingService }

class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.otherUserName,
    required this.lastMessage,
    required this.updatedAt,
    required this.section,
    this.unreadCount = 0,
    this.otherUserId = '',
    this.otherUserAvatar,
  });

  final String id;
  final String listingId;
  final String listingTitle;
  final String otherUserName;
  final String lastMessage;
  final DateTime? updatedAt;
  final ConversationSection section;
  final int unreadCount;
  final String otherUserId;
  final String? otherUserAvatar;
}

class ChatAttachment {
  const ChatAttachment({required this.id, required this.url});

  final String id;
  final String url;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.attachments = const [],
  });

  final int id;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final List<ChatAttachment> attachments;
}

class MessageImageUpload {
  const MessageImageUpload({required this.bytes, required this.filename});

  final List<int> bytes;
  final String filename;
}
