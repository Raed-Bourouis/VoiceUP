/// Enum representing the status of a friendship.
enum FriendshipStatus {
  /// Friend request is pending
  pending,
  /// Friend request has been accepted
  accepted,
  /// Friend request was rejected
  rejected,
  /// User has been blocked
  blocked;

  /// Creates a FriendshipStatus from a string value.
  static FriendshipStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return FriendshipStatus.pending;
      case 'accepted':
        return FriendshipStatus.accepted;
      case 'rejected':
        return FriendshipStatus.rejected;
      case 'blocked':
        return FriendshipStatus.blocked;
      default:
        throw ArgumentError('Invalid friendship status: $value');
    }
  }

  /// Converts this FriendshipStatus to a string for database storage.
  String toDbString() {
    return name;
  }
}

/// Enum representing the state of friendship between current user and another user.
/// This is computed based on the friendship table rows.
enum FriendshipState {
  /// No friendship relationship exists
  none,
  /// Current user sent a pending friend request to the other user
  pendingOutgoing,
  /// Other user sent a pending friend request to current user
  pendingIncoming,
  /// Friendship is accepted (mutual friends)
  accepted,
  /// User has been blocked
  blocked,
  /// Friend request was rejected
  rejected;
}

/// Model representing a friendship row from the friendships table.
class Friendship {
  final String id;
  final String userId;
  final String friendId;
  final FriendshipStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Friendship({
    required this.id,
    required this.userId,
    required this.friendId,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  /// Creates a Friendship from a Supabase JSON map.
  factory Friendship.fromJson(Map<String, dynamic> json) {
    return Friendship(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      friendId: json['friend_id'] as String,
      status: FriendshipStatus.fromString(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Converts this Friendship to a JSON map for Supabase.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'friend_id': friendId,
      'status': status.toDbString(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
