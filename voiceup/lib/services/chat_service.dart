import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voiceup/models/chat.dart';
import 'package:voiceup/models/chat_participant.dart';

/// Service class for handling chat operations with Supabase.
/// 
/// This service provides methods for:
/// - Creating direct (1:1) and group chats
/// - Fetching chats with last message preview
/// - Managing chat participants
/// - Real-time subscriptions to chat updates
class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Gets the current authenticated user's ID.
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Creates or retrieves a direct (1:1) chat with a friend. 
  /// 
  /// [friendId] - The friend's user ID
  /// 
  /// Returns the Chat object (existing or newly created).
  /// 
  /// Throws [PostgrestException] if the database query fails.
  Future<Chat> createDirectChat(String friendId) async {
    try {
      final currentUserId = _currentUserId;
      if (currentUserId == null) {
        throw Exception('No authenticated user');
      }

      // Check if a direct chat already exists between these two users
      final existingChats = await _supabase
          .from('chat_participants')
          .select('chat_id, chats!inner(id, name, avatar_url, is_group, created_by, created_at, updated_at)')
          .eq('user_id', currentUserId);

      // Filter for direct chats with exactly 2 participants including the friend
      for (final row in existingChats) {
        final chatData = row['chats'] as Map<String, dynamic>;
        final isGroup = chatData['is_group'] as bool? ?? false;
        
        if (!isGroup) {
          final chatId = row['chat_id'] as String;
          
          // Check if friend is a participant
          final participants = await _supabase
              .from('chat_participants')
              .select('user_id')
              .eq('chat_id', chatId);
          
          final participantIds = participants.map((p) => p['user_id'] as String).toList();
          
          if (participantIds. length == 2 && 
              participantIds.contains(currentUserId) && 
              participantIds.contains(friendId)) {
            return Chat.fromJson(chatData);
          }
        }
      }

      // Create new chat if none exists
      final chatResponse = await _supabase
          .from('chats')
          .insert({
            'is_group': false,
            'created_by': currentUserId,
          })
          .select()
          .single();

      final chat = Chat.fromJson(chatResponse);

      // Add both users as participants
      await _supabase.from('chat_participants').insert([
        {
          'chat_id': chat. id,
          'user_id': currentUserId,
        },
        {
          'chat_id': chat.id,
          'user_id': friendId,
        },
      ]);

      return chat;
    } on PostgrestException catch (e) {
      throw PostgrestException(message: e.message);
    } catch (e) {
      throw Exception('Failed to create direct chat:  $e');
    }
  }

  /// Creates a group chat with multiple participants.
  /// 
  /// [name] - The name of the group chat
  /// [participantIds] - List of user IDs to add to the group
  /// 
  /// Returns the newly created Chat object.
  /// 
  /// Throws [PostgrestException] if the database query fails.
  Future<Chat> createGroupChat(String name, List<String> participantIds) async {
    try {
      final currentUserId = _currentUserId;
      if (currentUserId == null) {
        throw Exception('No authenticated user');
      }

      // Create the group chat
      final chatResponse = await _supabase
          .from('chats')
          .insert({
            'name': name,
            'is_group': true,
            'created_by': currentUserId,
          })
          .select()
          .single();

      final chat = Chat.fromJson(chatResponse);

      // Add all participants including the creator
      final participants = participantIds.toSet()..add(currentUserId);
      await _supabase. from('chat_participants').insert(
        participants.map((userId) => {
          'chat_id': chat.id,
          'user_id': userId,
        }).toList(),
      );

      return chat;
    } on PostgrestException catch (e) {
      throw PostgrestException(message: e.message);
    } catch (e) {
      throw Exception('Failed to create group chat:  $e');
    }
  }

  /// Gets all chats for the current user.
  /// 
  /// Returns a list of Chat objects sorted by most recent update.
  /// 
  /// Throws [PostgrestException] if the database query fails.
  Future<List<Chat>> getChats() async {
    try {
      final currentUserId = _currentUserId;
      if (currentUserId == null) {
        throw Exception('No authenticated user');
      }

      // Get all chat IDs where the user is a participant
      final participantResponse = await _supabase
          .from('chat_participants')
          .select('chat_id')
          .eq('user_id', currentUserId);

      if (participantResponse.isEmpty) {
        return [];
      }

      // Extract chat IDs
      final chatIds = (participantResponse as List)
          .map((row) => row['chat_id'] as String)
          .toList();

      // Get the actual chats with proper ordering
      final chatsResponse = await _supabase
          .from('chats')
          .select('id, name, avatar_url, is_group, created_by, created_at, updated_at')
          .inFilter('id', chatIds)
          .order('updated_at', ascending: false);

      final chats = <Chat>[];
      for (final chatData in chatsResponse) {
        chats.add(Chat.fromJson(chatData as Map<String, dynamic>));
      }

      return chats;
    } on PostgrestException catch (e) {
      throw PostgrestException(message: e.message);
    } catch (e) {
      throw Exception('Failed to get chats: $e');
    }
  }

  /// Gets a single chat by ID. 
  /// 
  /// [chatId] - The chat ID
  /// 
  /// Returns the Chat object.
  /// 
  /// Throws [PostgrestException] if the database query fails.
  Future<Chat> getChatById(String chatId) async {
    try {
      final response = await _supabase
          .from('chats')
          .select()
          .eq('id', chatId)
          .single();

      return Chat.fromJson(response);
    } on PostgrestException catch (e) {
      throw PostgrestException(message: e.message);
    } catch (e) {
      throw Exception('Failed to get chat: $e');
    }
  }

  /// Gets all participants of a chat. 
  /// 
  /// [chatId] - The chat ID
  /// 
  /// Returns a list of ChatParticipant objects.
  /// 
  /// Throws [PostgrestException] if the database query fails.
  Future<List<ChatParticipant>> getChatParticipants(String chatId) async {
    try {
      final response = await _supabase
          .from('chat_participants')
          .select()
          .eq('chat_id', chatId);

      return (response as List)
          .map((json) => ChatParticipant.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw PostgrestException(message: e.message);
    } catch (e) {
      throw Exception('Failed to get chat participants: $e');
    }
  }

  /// Leaves a group chat.
  /// 
  /// [chatId] - The chat ID
  /// 
  /// Throws [PostgrestException] if the database query fails. 
  Future<void> leaveChat(String chatId) async {
    try {
      final currentUserId = _currentUserId;
      if (currentUserId == null) {
        throw Exception('No authenticated user');
      }

      await _supabase
          . from('chat_participants')
          .delete()
          .eq('chat_id', chatId)
          .eq('user_id', currentUserId);
    } on PostgrestException catch (e) {
      throw PostgrestException(message: e.message);
    } catch (e) {
      throw Exception('Failed to leave chat: $e');
    }
  }

  /// Adds participants to a group chat.
  /// 
  /// [chatId] - The chat ID
  /// [userIds] - List of user IDs to add
  /// 
  /// Throws [PostgrestException] if the database query fails.
  Future<void> addParticipants(String chatId, List<String> userIds) async {
    try {
      await _supabase.from('chat_participants').insert(
        userIds.map((userId) => {
          'chat_id': chatId,
          'user_id': userId,
        }).toList(),
      );
    } on PostgrestException catch (e) {
      throw PostgrestException(message: e. message);
    } catch (e) {
      throw Exception('Failed to add participants: $e');
    }
  }

  /// Subscribes to real-time updates for the current user's chats. 
  /// 
  /// [callback] - Function to call when chats are updated
  /// 
  /// Returns a RealtimeChannel for managing the subscription.
  RealtimeChannel subscribeToChats(Function(List<Chat>) callback) {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw Exception('No authenticated user');
    }

    final channel = _supabase
        .channel('chats:$currentUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chats',
          callback: (payload) async {
            // Reload all chats when any chat changes
            final chats = await getChats();
            callback(chats);
          },
        )
        .subscribe();

    return channel;
  }
}