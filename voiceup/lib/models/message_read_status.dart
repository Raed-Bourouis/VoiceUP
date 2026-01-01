/// Model representing a message read status from the message_read_status table.
/// 
/// This model tracks when users read messages including:
/// - Status ID
/// - Message ID
/// - User ID
/// - When they read the message
class MessageReadStatus {
  final String id;
  final String messageId;
  final String userId;
  final DateTime readAt;

  MessageReadStatus({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.readAt,
  });

  /// Creates a MessageReadStatus from a Supabase JSON map.
  factory MessageReadStatus.fromJson(Map<String, dynamic> json) {
    return MessageReadStatus(
      id: json['id'] as String,
      messageId: json['message_id'] as String,
      userId: json['user_id'] as String,
      readAt: DateTime.parse(json['read_at'] as String),
    );
  }

  /// Converts this MessageReadStatus to a JSON map for Supabase.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message_id': messageId,
      'user_id': userId,
      'read_at': readAt.toIso8601String(),
    };
  }

  /// Creates a copy of this MessageReadStatus with updated fields.
  MessageReadStatus copyWith({
    String? id,
    String? messageId,
    String? userId,
    DateTime? readAt,
  }) {
    return MessageReadStatus(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      userId: userId ?? this.userId,
      readAt: readAt ?? this.readAt,
    );
  }
}
