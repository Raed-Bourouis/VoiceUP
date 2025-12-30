import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voiceup/models/profile.dart';
import 'package:voiceup/models/friendship.dart';
import 'package:voiceup/models/friend_item.dart';
import 'package:voiceup/models/friend_request_item.dart';

/// Service class for handling friendship operations with Supabase.
/// 
/// This service provides methods for:
/// - Searching for users
/// - Managing friend requests (send, accept, reject, cancel)
/// - Managing friendships (unfriend)
/// - Fetching friends and friend requests
class FriendshipService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Gets the current authenticated user's ID.
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Searches for users by username or display name.
  /// 
  /// [query] - Search term to match against username and display_name.
  /// 
  /// Returns a list of matching profiles, excluding the current user.
  /// Performs a case-insensitive search using ILIKE.
  /// 
  /// Throws [PostgrestException] if the database query fails.
  Future<List<Profile>> searchUsers(String query) async {
    try {
      final currentUserId = _currentUserId;
      if (currentUserId == null) {
        throw Exception('No authenticated user');
      }

      if (query.trim().isEmpty) {
        return [];
      }

      final searchPattern = '%${query.trim()}%';
      
      final response = await _supabase
          .from('profiles')
          .select()
          .neq('id', currentUserId)
          .or('username.ilike.$searchPattern,display_name.ilike.$searchPattern,email.ilike.$searchPattern')
          .limit(20);

      return (response as List)
          .map((json) => Profile.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to search users: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred while searching users: $e');
    }
  }

  /// Determines the friendship state between the current user and another user.
  /// 
  /// [otherUserId] - The ID of the other user.
  /// 
  /// Returns the [FriendshipState] representing the relationship.
  /// 
  /// Possible states:
  /// - none: No friendship exists
  /// - pendingOutgoing: Current user sent a pending request
  /// - pendingIncoming: Other user sent a pending request
  /// - accepted: Friendship is accepted (mutual friends)
  /// - blocked: User is blocked
  /// - rejected: Request was rejected
  /// 
  /// Throws [PostgrestException] if the database query fails.
  Future<FriendshipState> getFriendshipState(String otherUserId) async {
    try {
      final currentUserId = _currentUserId;
      if (currentUserId == null) {
        throw Exception('No authenticated user');
      }

      // Query both directions of the friendship
      final response = await _supabase
          .from('friendships')
          .select()
          .or('and(user_id.eq.$currentUserId,friend_id.eq.$otherUserId),and(user_id.eq.$otherUserId,friend_id.eq.$currentUserId)');

      if (response == null || (response as List).isEmpty) {
        return FriendshipState.none;
      }

      // Check for relevant friendship records
      for (final row in response) {
        final friendship = Friendship.fromJson(row as Map<String, dynamic>);
        
        // Check if current user is the initiator
        if (friendship.userId == currentUserId && friendship.friendId == otherUserId) {
          switch (friendship.status) {
            case FriendshipStatus.pending:
              return FriendshipState.pendingOutgoing;
            case FriendshipStatus.accepted:
              return FriendshipState.accepted;
            case FriendshipStatus.rejected:
              return FriendshipState.rejected;
            case FriendshipStatus.blocked:
              return FriendshipState.blocked;
          }
        }
        
        // Check if other user is the initiator
        if (friendship.userId == otherUserId && friendship.friendId == currentUserId) {
          switch (friendship.status) {
            case FriendshipStatus.pending:
              return FriendshipState.pendingIncoming;
            case FriendshipStatus.accepted:
              return FriendshipState.accepted;
            case FriendshipStatus.rejected:
              return FriendshipState.rejected;
            case FriendshipStatus.blocked:
              return FriendshipState.blocked;
          }
        }
      }

      return FriendshipState.none;
    } on PostgrestException catch (e) {
      throw Exception('Failed to get friendship state: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred while getting friendship state: $e');
    }
  }

  /// Sends a friend request to another user.
  /// 
  /// [otherUserId] - The ID of the user to send the friend request to.
  /// 
  /// Inserts a new row in the friendships table with status 'pending'.
  /// The current user is set as user_id and the other user as friend_id.
  /// 
  /// Note: Database CHECK constraint prevents sending requests to self.
  /// 
  /// Throws [PostgrestException] if the database insert fails.
  Future<void> sendFriendRequest(String otherUserId) async {
    try {
      final currentUserId = _currentUserId;
      if (currentUserId == null) {
        throw Exception('No authenticated user');
      }

      if (currentUserId == otherUserId) {
        throw Exception('Cannot send friend request to yourself');
      }

      await _supabase.from('friendships').insert({
        'user_id': currentUserId,
        'friend_id': otherUserId,
        'status': FriendshipStatus.pending.toDbString(),
      });
    } on PostgrestException catch (e) {
      throw Exception('Failed to send friend request: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred while sending friend request: $e');
    }
  }

  /// Accepts an incoming friend request.
  /// 
  /// [friendshipId] - The ID of the friendship row to accept.
  /// 
  /// Updates the friendship status to 'accepted'.
  /// Can only accept requests where current user is the friend_id.
  /// 
  /// Throws [PostgrestException] if the database update fails.
  Future<void> acceptFriendRequest(String friendshipId) async {
    try {
      final currentUserId = _currentUserId;
      if (currentUserId == null) {
        throw Exception('No authenticated user');
      }

      await _supabase
          .from('friendships')
          .update({
            'status': FriendshipStatus.accepted.toDbString(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', friendshipId)
          .eq('friend_id', currentUserId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to accept friend request: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred while accepting friend request: $e');
    }
  }

  /// Rejects an incoming friend request.
  /// 
  /// [friendshipId] - The ID of the friendship row to reject.
  /// 
  /// Deletes the friendship row for rejected requests.
  /// This approach keeps the friendships table clean.
  /// Alternative: Set status to 'rejected' to keep a record.
  /// 
  /// Can only reject requests where current user is the friend_id.
  /// 
  /// Throws [PostgrestException] if the database operation fails.
  Future<void> rejectFriendRequest(String friendshipId) async {
    try {
      final currentUserId = _currentUserId;
      if (currentUserId == null) {
        throw Exception('No authenticated user');
      }

      // Delete the friendship row (clean approach for rejections)
      await _supabase
          .from('friendships')
          .delete()
          .eq('id', friendshipId)
          .eq('friend_id', currentUserId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to reject friend request: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred while rejecting friend request: $e');
    }
  }

  /// Cancels an outgoing friend request.
  /// 
  /// [friendshipId] - The ID of the friendship row to cancel.
  /// 
  /// Deletes the friendship row for canceled requests.
  /// Can only cancel requests where current user is the user_id and status is pending.
  /// 
  /// Throws [PostgrestException] if the database operation fails.
  Future<void> cancelFriendRequest(String friendshipId) async {
    try {
      final currentUserId = _currentUserId;
      if (currentUserId == null) {
        throw Exception('No authenticated user');
      }

      await _supabase
          .from('friendships')
          .delete()
          .eq('id', friendshipId)
          .eq('user_id', currentUserId)
          .eq('status', FriendshipStatus.pending.toDbString());
    } on PostgrestException catch (e) {
      throw Exception('Failed to cancel friend request: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred while canceling friend request: $e');
    }
  }

  /// Unfriends a user (removes an accepted friendship).
  /// 
  /// [friendshipId] - The ID of the friendship row to remove.
  /// 
  /// Deletes the friendship row for unfriending.
  /// This allows users to re-add each other as friends later.
  /// Alternative: Set status to 'rejected' to prevent re-adding.
  /// 
  /// Can only unfriend accepted friendships involving current user.
  /// 
  /// Throws [PostgrestException] if the database operation fails.
  Future<void> unfriend(String friendshipId) async {
    try {
      final currentUserId = _currentUserId;
      if (currentUserId == null) {
        throw Exception('No authenticated user');
      }

      await _supabase
          .from('friendships')
          .delete()
          .eq('id', friendshipId)
          .or('user_id.eq.$currentUserId,friend_id.eq.$currentUserId')
          .eq('status', FriendshipStatus.accepted.toDbString());
    } on PostgrestException catch (e) {
      throw Exception('Failed to unfriend: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred while unfriending: $e');
    }
  }

  /// Gets the list of accepted friends for the current user.
  /// 
  /// Returns a list of [FriendItem] containing friend profile information.
  /// Includes friendships where current user is either user_id or friend_id.
  /// 
  /// Performs a join with the profiles table to get friend information.
  /// 
  /// Throws [PostgrestException] if the database query fails.
  Future<List<FriendItem>> getFriends() async {
    try {
      final currentUserId = _currentUserId;
      if (currentUserId == null) {
        throw Exception('No authenticated user');
      }

      // Query friendships where current user is user_id
      final outgoingResponse = await _supabase
          .from('friendships')
          .select('id, created_at, friend_id, profiles!friendships_friend_id_fkey(*)')
          .eq('user_id', currentUserId)
          .eq('status', FriendshipStatus.accepted.toDbString());

      // Query friendships where current user is friend_id
      final incomingResponse = await _supabase
          .from('friendships')
          .select('id, created_at, user_id, profiles!friendships_user_id_fkey(*)')
          .eq('friend_id', currentUserId)
          .eq('status', FriendshipStatus.accepted.toDbString());

      final friends = <FriendItem>[];

      // Process outgoing friendships
      if (outgoingResponse != null) {
        for (final row in outgoingResponse as List) {
          final json = row as Map<String, dynamic>;
          friends.add(FriendItem.fromJson(json));
        }
      }

      // Process incoming friendships
      if (incomingResponse != null) {
        for (final row in incomingResponse as List) {
          final json = row as Map<String, dynamic>;
          friends.add(FriendItem.fromJson(json));
        }
      }

      return friends;
    } on PostgrestException catch (e) {
      throw Exception('Failed to get friends: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred while getting friends: $e');
    }
  }

  /// Gets the list of incoming friend requests for the current user.
  /// 
  /// Returns a list of [FriendRequestItem] containing requester information.
  /// These are pending requests where current user is the friend_id.
  /// 
  /// Performs a join with the profiles table to get requester information.
  /// 
  /// Throws [PostgrestException] if the database query fails.
  Future<List<FriendRequestItem>> getIncomingRequests() async {
    try {
      final currentUserId = _currentUserId;
      if (currentUserId == null) {
        throw Exception('No authenticated user');
      }

      final response = await _supabase
          .from('friendships')
          .select('id, created_at, user_id, profiles!friendships_user_id_fkey(*)')
          .eq('friend_id', currentUserId)
          .eq('status', FriendshipStatus.pending.toDbString());

      if (response == null) {
        return [];
      }

      return (response as List)
          .map((json) => FriendRequestItem.fromJson(
                json as Map<String, dynamic>,
                isIncoming: true,
              ))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to get incoming requests: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred while getting incoming requests: $e');
    }
  }

  /// Gets the list of outgoing friend requests for the current user.
  /// 
  /// Returns a list of [FriendRequestItem] containing receiver information.
  /// These are pending requests where current user is the user_id.
  /// 
  /// Performs a join with the profiles table to get receiver information.
  /// 
  /// Throws [PostgrestException] if the database query fails.
  Future<List<FriendRequestItem>> getOutgoingRequests() async {
    try {
      final currentUserId = _currentUserId;
      if (currentUserId == null) {
        throw Exception('No authenticated user');
      }

      final response = await _supabase
          .from('friendships')
          .select('id, created_at, friend_id, profiles!friendships_friend_id_fkey(*)')
          .eq('user_id', currentUserId)
          .eq('status', FriendshipStatus.pending.toDbString());

      if (response == null) {
        return [];
      }

      return (response as List)
          .map((json) => FriendRequestItem.fromJson(
                json as Map<String, dynamic>,
                isIncoming: false,
              ))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to get outgoing requests: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred while getting outgoing requests: $e');
    }
  }
}
