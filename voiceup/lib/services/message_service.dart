import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voiceup/models/message.dart';
import 'package:voiceup/services/storage_service.dart';

/// Service class for handling message operations with Supabase.
///
/// This service provides methods for:
/// - Sending text, photo, and voice messages
/// - Fetching paginated messages
/// - Marking messages as read
/// - Deleting messages
/// - Real-time subscriptions to message updates
class MessageService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final StorageService _storageService = StorageService();

  /// Gets the current authenticated user's ID.
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Sends a text message to a chat.
  ///
  /// [chatId] - The chat ID
  /// [content] - The text content of the message
  ///
  /// Returns the created Message object.
  ///
  /// Throws [PostgrestException] if the database query fails.
  Future<Message> sendTextMessage(String chatId, String content) async {
    try {
      final currentUserId = _currentUserId;
      if (currentUserId == null) {
        throw Exception('No authenticated user');
      }

      final response = await _supabase
          .from('messages')
          .insert({
            'chat_id': chatId,
            'sender_id': currentUserId,
            'message_type': 'text',
            'text_content': content,
          })
          .select()
          .single();

      // Update chat's updated_at timestamp
      await _supabase
          .from('chats')
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('id', chatId);

      return Message.fromJson(response);
    } on PostgrestException catch (e) {
      throw PostgrestException(message: e.message);
    } catch (e) {
      throw Exception('Failed to send text message: $e');
    }
  }

  /// Sends a photo message to a chat.
  ///
  /// [chatId] - The chat ID
  /// [photo] - The photo file to upload and send
  ///
  /// Returns the created Message object.
  ///
  /// Throws [PostgrestException] or [StorageException] if upload or database query fails.
  Future<Message> sendPhotoMessage(String chatId, File photo) async {
    try {
      final currentUserId = _currentUserId;
      if (currentUserId == null) {
        throw Exception('No authenticated user');
      }

      // Upload photo to storage
      final mediaUrl = await _storageService.uploadPhoto(photo, chatId);

      // Create message record
      final response = await _supabase
          .from('messages')
          .insert({
            'chat_id': chatId,
            'sender_id': currentUserId,
            'message_type': 'photo',
            'media_url': mediaUrl,
          })
          .select()
          .single();

      // Update chat's updated_at timestamp
      await _supabase
          .from('chats')
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('id', chatId);

      return Message.fromJson(response);
    } on PostgrestException catch (e) {
      throw PostgrestException(message: e.message);
    } catch (e) {
      throw Exception('Failed to send photo message: $e');
    }
  }

  /// Sends a voice message to a chat.
  ///
  /// [chatId] - The chat ID
  /// [audio] - The audio file to upload and send
  /// [durationSeconds] - The duration of the audio in seconds
  ///
  /// Returns the created Message object.
  ///
  /// Throws [PostgrestException] or [StorageException] if upload or database query fails.
  Future<Message> sendVoiceMessage(
    String chatId,
    File audio,
    int durationSeconds,
  ) async {
    try {
      final currentUserId = _currentUserId;
      if (currentUserId == null) {
        throw Exception('No authenticated user');
      }

      // Upload voice message to storage
      final mediaUrl = await _storageService.uploadVoiceMessage(audio, chatId);

      // Create message record
      final response = await _supabase
          .from('messages')
          .insert({
            'chat_id': chatId,
            'sender_id': currentUserId,
            'message_type': 'voice',
            'media_url': mediaUrl,
            'media_duration': durationSeconds,
          })
          .select()
          .single();

      // Update chat's updated_at timestamp
      await _supabase
          .from('chats')
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('id', chatId);

      return Message.fromJson(response);
    } on PostgrestException catch (e) {
      throw PostgrestException(message: e.message);
    } catch (e) {
      throw Exception('Failed to send voice message: $e');
    }
  }

  /// Gets paginated messages for a chat.
  ///
  /// [chatId] - The chat ID
  /// [limit] - Maximum number of messages to return (default: 50)
  /// [beforeId] - Optional message ID to fetch messages before (for pagination)
  ///
  /// Returns a list of Message objects ordered by creation time (newest first).
  ///
  /// Throws [PostgrestException] if the database query fails.
  Future<List<Message>> getMessages(
    String chatId, {
    int limit = 50,
    String? beforeId,
  }) async {
    try {
      var query = _supabase
          .from('messages')
          .select()
          .eq('chat_id', chatId)
          .eq('is_deleted', false);

      // If beforeId is provided, only get messages created before that message
      if (beforeId != null) {
        final beforeMessage = await _supabase
            .from('messages')
            .select('created_at')
            .eq('id', beforeId)
            .single();

        final beforeTimestamp = beforeMessage['created_at'] as String;
        query = query.lt('created_at', beforeTimestamp);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => Message.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw PostgrestException(message: e.message);
    } catch (e) {
      throw Exception('Failed to get messages: $e');
    }
  }

  /// Soft deletes a message.
  ///
  /// [messageId] - The message ID to delete
  ///
  /// Throws [PostgrestException] if the database query fails.
  Future<void> deleteMessage(String messageId) async {
    try {
      await _supabase
          .from('messages')
          .update({
            'is_deleted': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', messageId);
    } on PostgrestException catch (e) {
      throw PostgrestException(message: e.message);
    } catch (e) {
      throw Exception('Failed to delete message: $e');
    }
  }

  /// Marks all messages in a chat as read for the current user.
  ///
  /// [chatId] - The chat ID
  ///
  /// Throws [PostgrestException] if the database query fails.
  Future<void> markAsRead(String chatId) async {
    try {
      final currentUserId = _currentUserId;
      if (currentUserId == null) {
        throw Exception('No authenticated user');
      }

      // Update last_read_at for the current user in this chat
      await _supabase
          .from('chat_participants')
          .update({'last_read_at': DateTime.now().toIso8601String()})
          .eq('chat_id', chatId)
          .eq('user_id', currentUserId);

      // Get all unread messages in this chat
      final participant = await _supabase
          .from('chat_participants')
          .select('last_read_at')
          .eq('chat_id', chatId)
          .eq('user_id', currentUserId)
          .single();

      final lastReadAt = DateTime.parse(participant['last_read_at'] as String);

      final unreadMessages = await _supabase
          .from('messages')
          .select('id')
          .eq('chat_id', chatId)
          .neq('sender_id', currentUserId)
          .gt('created_at', lastReadAt.toIso8601String());

      // Mark each unread message as read
      if (unreadMessages.isNotEmpty) {
        final messageIds = (unreadMessages as List)
            .map((msg) => msg['id'] as String)
            .toList();

        for (final messageId in messageIds) {
          await _supabase.from('message_read_status').upsert({
            'message_id': messageId,
            'user_id': currentUserId,
          });
        }
      }
    } on PostgrestException catch (e) {
      throw PostgrestException(message: e.message);
    } catch (e) {
      throw Exception('Failed to mark messages as read: $e');
    }
  }

  /// Gets the count of unread messages in a chat.
  ///
  /// [chatId] - The chat ID
  ///
  /// Returns the number of unread messages.
  ///
  /// Throws [PostgrestException] if the database query fails.
  Future<int> getUnreadCount(String chatId) async {
    try {
      final currentUserId = _currentUserId;
      if (currentUserId == null) {
        throw Exception('No authenticated user');
      }

      // Get user's last read timestamp for this chat
      final participant = await _supabase
          .from('chat_participants')
          .select('last_read_at')
          .eq('chat_id', chatId)
          .eq('user_id', currentUserId)
          .maybeSingle();

      if (participant == null) {
        return 0;
      }

      final lastReadAt = DateTime.parse(participant['last_read_at'] as String);

      // Count messages created after last read that aren't from current user
      final response = await _supabase
          .from('messages')
          .select('id')
          .eq('chat_id', chatId)
          .neq('sender_id', currentUserId)
          .eq('is_deleted', false)
          .gt('created_at', lastReadAt.toIso8601String())
          .count();

      return response.count ?? 0;
    } on PostgrestException catch (e) {
      throw PostgrestException(message: e.message);
    } catch (e) {
      throw Exception('Failed to get unread count: $e');
    }
  }

  /// Subscribes to real-time messages in a chat.
  ///
  /// [chatId] - The chat ID to subscribe to
  /// [callback] - Function to call when new messages arrive
  ///
  /// Returns a RealtimeChannel for managing the subscription.
  RealtimeChannel subscribeToMessages(
    String chatId,
    Function(Message) callback,
  ) {
    final channel = _supabase
        .channel('messages:$chatId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: chatId,
          ),
          callback: (payload) {
            final message = Message.fromJson(payload.newRecord);
            callback(message);
          },
        )
        .subscribe();

    return channel;
  }
}
