/// Enum representing the type of message.
enum MessageType {
  /// Text message
  text,
  /// Voice message
  voice,
  /// Photo message
  photo;

  /// Creates a MessageType from a string value.
  static MessageType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'text':
        return MessageType.text;
      case 'voice':
        return MessageType.voice;
      case 'photo':
        return MessageType.photo;
      default:
        throw ArgumentError('Invalid message type: $value');
    }
  }

  /// Converts this MessageType to a string for database storage.
  String toDbString() {
    return name;
  }
}

/// Model representing a message from the messages table.
/// 
/// This model contains message information including:
/// - Message ID
/// - Chat ID
/// - Sender ID
/// - Message type (text, voice, photo)
/// - Content based on type
/// - Timestamps
/// - Deletion status
class Message {
  final String id;
  final String chatId;
  final String senderId;
  final MessageType messageType;
  final String? textContent;
  final String? mediaUrl;
  final int? mediaDuration;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.messageType,
    this.textContent,
    this.mediaUrl,
    this.mediaDuration,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
  });

  /// Creates a Message from a Supabase JSON map.
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      chatId: json['chat_id'] as String,
      senderId: json['sender_id'] as String,
      messageType: MessageType.fromString(json['message_type'] as String),
      textContent: json['text_content'] as String?,
      mediaUrl: json['media_url'] as String?,
      mediaDuration: json['media_duration'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isDeleted: json['is_deleted'] as bool? ?? false,
    );
  }

  /// Converts this Message to a JSON map for Supabase.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chat_id': chatId,
      'sender_id': senderId,
      'message_type': messageType.toDbString(),
      'text_content': textContent,
      'media_url': mediaUrl,
      'media_duration': mediaDuration,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted,
    };
  }

  /// Creates a copy of this Message with updated fields.
  Message copyWith({
    String? id,
    String? chatId,
    String? senderId,
    MessageType? messageType,
    String? textContent,
    String? mediaUrl,
    int? mediaDuration,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return Message(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      messageType: messageType ?? this.messageType,
      textContent: textContent ?? this.textContent,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaDuration: mediaDuration ?? this.mediaDuration,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
