/// Model representing a user profile from the profiles table.
///
/// This model contains basic user information including:
/// - User ID (matches auth.users.id)
/// - Email address
/// - Optional username
/// - Optional display name
/// - Optional avatar URL
class Profile {
  final String id;
  final String email;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Profile({
    required this.id,
    required this.email,
    this.username,
    this.displayName,
    this.avatarUrl,
    this.createdAt,
    this.updatedAt,
  });

  /// Creates a Profile from a Supabase JSON map.
  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String?,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Converts this Profile to a JSON map for Supabase.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Returns the display name, username, or email (in that order of preference).
  String get displayNameOrUsername => displayName ?? username ?? email;

  /// Returns the first character of the display name for avatar placeholder.
  String get avatarInitial {
    final name = displayName ?? username ?? email;
    if (name.isEmpty) return '?';
    return name.substring(0, 1).toUpperCase();
  }
}
