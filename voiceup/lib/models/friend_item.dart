import 'package:voiceup/models/profile.dart';

/// Model representing a friend for display in the friends list.
/// 
/// Combines friendship data with the friend's profile information.
class FriendItem {
  final String friendshipId;
  final Profile profile;
  final DateTime friendsSince;

  FriendItem({
    required this.friendshipId,
    required this.profile,
    required this.friendsSince,
  });

  /// Creates a FriendItem from a Supabase JSON map.
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
  factory FriendItem.fromJson(Map<String, dynamic> json) {
    return FriendItem(
      friendshipId: json['id'] as String,
      profile: Profile.fromJson(json['profiles'] as Map<String, dynamic>),
      friendsSince: DateTime.parse(json['created_at'] as String),
    );
  }
}
