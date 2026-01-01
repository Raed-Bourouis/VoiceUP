/// Model representing a chat from the chats table.
/// 
/// This model contains chat information including:
/// - Chat ID
/// - Name (for group chats)
/// - Avatar URL (for group chats)
/// - Whether it's a group chat or 1:1 chat
/// - Creator user ID
/// - Timestamps
class Chat {
  final String id;
  final String? name;
  final String? avatarUrl;
  final bool isGroup;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  Chat({
    required this.id,
    this.name,
    this.avatarUrl,
    required this.isGroup,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a Chat from a Supabase JSON map.
  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id'] as String,
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isGroup: json['is_group'] as bool? ?? false,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Converts this Chat to a JSON map for Supabase.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar_url': avatarUrl,
      'is_group': isGroup,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Creates a copy of this Chat with updated fields.
  Chat copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    bool? isGroup,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Chat(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isGroup: isGroup ?? this.isGroup,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
