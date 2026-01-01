/// Model representing a chat participant from the chat_participants table.
/// 
/// This model contains information about users in a chat including:
/// - Participant ID
/// - Chat ID
/// - User ID
/// - When they joined
/// - When they last read messages
class ChatParticipant {
  final String id;
  final String chatId;
  final String userId;
  final DateTime joinedAt;
  final DateTime lastReadAt;

  ChatParticipant({
    required this.id,
    required this.chatId,
    required this.userId,
    required this.joinedAt,
    required this.lastReadAt,
  });

  /// Creates a ChatParticipant from a Supabase JSON map.
  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    return ChatParticipant(
      id: json['id'] as String,
      chatId: json['chat_id'] as String,
      userId: json['user_id'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      lastReadAt: DateTime.parse(json['last_read_at'] as String),
    );
  }

  /// Converts this ChatParticipant to a JSON map for Supabase.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chat_id': chatId,
      'user_id': userId,
      'joined_at': joinedAt.toIso8601String(),
      'last_read_at': lastReadAt.toIso8601String(),
    };
  }

  /// Creates a copy of this ChatParticipant with updated fields.
  ChatParticipant copyWith({
    String? id,
    String? chatId,
    String? userId,
    DateTime? joinedAt,
    DateTime? lastReadAt,
  }) {
    return ChatParticipant(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      userId: userId ?? this.userId,
      joinedAt: joinedAt ?? this.joinedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
    );
  }
}
