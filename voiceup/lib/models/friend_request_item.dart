import 'package:voiceup/models/profile.dart';

/// Model representing a friend request for display in the requests list.
/// 
/// Combines friendship request data with the requester/receiver's profile information.
class FriendRequestItem {
  final String friendshipId;
  final Profile profile;
  final DateTime requestedAt;
  final bool isIncoming;

  FriendRequestItem({
    required this.friendshipId,
    required this.profile,
    required this.requestedAt,
    required this.isIncoming,
  });

  /// Creates a FriendRequestItem from a Supabase JSON map.
  /// 
  /// Expected JSON structure from a join query:
  /// ```
  /// {
  ///   'id': 'friendship-id',
  ///   'created_at': '2024-01-01T00:00:00Z',
  ///   'profiles': {
  ///     'id': 'user-id',
  ///     'email': 'user@example.com',
  ///     ...
  ///   }
  /// }
  /// ```
  /// 
  /// [isIncoming] should be set by the caller based on query context.
  factory FriendRequestItem.fromJson(
    Map<String, dynamic> json, {
    required bool isIncoming,
  }) {
    return FriendRequestItem(
      friendshipId: json['id'] as String,
      profile: Profile.fromJson(json['profiles'] as Map<String, dynamic>),
      requestedAt: DateTime.parse(json['created_at'] as String),
      isIncoming: isIncoming,
    );
  }
}
