class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime createdAt;

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['id'] as String,
    conversationId: json['conversation_id'] as String,
    senderId: json['sender_id'] as String,
    body: json['body'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

/// One inbox row: the other reader and the latest message.
class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.otherId,
    required this.lastBody,
    required this.lastSenderId,
    required this.lastMessageAt,
    required this.unread,
    required this.canSend,
  });

  final String id;
  final String otherId;
  final String? lastBody;
  final String? lastSenderId;
  final DateTime? lastMessageAt;
  final bool unread;

  /// False once the mutual follow ended; the history stays readable.
  final bool canSend;

  factory ConversationSummary.fromJson(Map<String, dynamic> json) =>
      ConversationSummary(
        id: json['conversation_id'] as String,
        otherId: json['other_id'] as String,
        lastBody: json['last_body'] as String?,
        lastSenderId: json['last_sender_id'] as String?,
        lastMessageAt: json['last_message_at'] == null
            ? null
            : DateTime.parse(json['last_message_at'] as String),
        unread: json['unread'] as bool? ?? false,
        canSend: json['can_send'] as bool? ?? false,
      );
}
