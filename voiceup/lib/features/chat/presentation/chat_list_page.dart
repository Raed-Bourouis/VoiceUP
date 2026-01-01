import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voiceup/services/auth_service.dart';
import 'package:voiceup/services/chat_service.dart';
import 'package:voiceup/services/message_service.dart';
import 'package:voiceup/services/profile_service.dart';
import 'package:voiceup/models/chat.dart';
import 'package:voiceup/models/profile.dart';
import 'package:voiceup/models/message.dart';
import 'package:voiceup/features/chat/widgets/chat_list_item.dart';
import 'package:voiceup/features/chat/presentation/chat_detail_page.dart';
import 'package:voiceup/features/friends/presentation/friends_page.dart';

/// Main chat list page showing all user's conversations.
/// 
/// Features:
/// - List of all chats sorted by last message time
/// - Real-time updates for new messages
/// - Pull-to-refresh
/// - Navigate to chat details on tap
/// - FAB to start new chat
class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final _authService = AuthService();
  final _chatService = ChatService();
  final _messageService = MessageService();
  final _profileService = ProfileService();

  List<Chat> _chats = [];
  Map<String, Profile> _otherUserProfiles = {}; // For 1:1 chats
  Map<String, String> _lastMessages = {}; // chatId -> last message text
  Map<String, DateTime> _lastMessageTimes = {}; // chatId -> last message time
  Map<String, int> _unreadCounts = {}; // chatId -> unread count
  bool _isLoading = true;
  String? _error;
  RealtimeChannel? _chatsChannel;

  @override
  void initState() {
    super.initState();
    _loadChats();
    _subscribeToChats();
  }

  @override
  void dispose() {
    _chatsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadChats() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final chats = await _chatService.getChats();

      // Load additional data for each chat
      for (final chat in chats) {
        // For 1:1 chats, get the other user's profile
        if (!chat.isGroup) {
          final participants = await _chatService.getChatParticipants(chat.id);
          final currentUserId = _authService.currentUser?.id;
          final otherUserId = participants
              .firstWhere((p) => p.userId != currentUserId)
              .userId;

          try {
            final profile = await _profileService.getProfileById(otherUserId);
            _otherUserProfiles[chat.id] = profile;
          } catch (e) {
            // Profile not found, skip
          }
        }

        // Get last message
        final messages = await _messageService.getMessages(chat.id, limit: 1);
        if (messages.isNotEmpty) {
          final lastMessage = messages.first;
          _lastMessageTimes[chat.id] = lastMessage.createdAt;
          
          // Format last message text based on type
          if (lastMessage.messageType == MessageType.text) {
            _lastMessages[chat.id] = lastMessage.textContent ?? '';
          } else if (lastMessage.messageType == MessageType.photo) {
            _lastMessages[chat.id] = '📷 Photo';
          } else if (lastMessage.messageType == MessageType.voice) {
            _lastMessages[chat.id] = '🎤 Voice message';
          }
        }

        // Get unread count
        final unreadCount = await _messageService.getUnreadCount(chat.id);
        _unreadCounts[chat.id] = unreadCount;
      }

      // Sort chats by last message time
      chats.sort((a, b) {
        final timeA = _lastMessageTimes[a.id] ?? a.updatedAt;
        final timeB = _lastMessageTimes[b.id] ?? b.updatedAt;
        return timeB.compareTo(timeA);
      });

      if (mounted) {
        setState(() {
          _chats = chats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _subscribeToChats() {
    try {
      _chatsChannel = _chatService.subscribeToChats((chats) {
        // Reload chats when updates occur
        _loadChats();
      });
    } catch (e) {
      // Silently handle subscription errors
    }
  }

  Future<void> _handleSignOut() async {
    try {
      await _authService.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sign out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToFriends() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FriendsPage()),
    );
  }

  void _navigateToChat(Chat chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailPage(
          chat: chat,
          otherUser: _otherUserProfiles[chat.id],
        ),
      ),
    ).then((_) {
      // Reload chats when returning from chat detail
      _loadChats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VoiceUp Chat'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: _navigateToFriends,
            tooltip: 'Friends',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleSignOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToFriends,
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add_comment, color: Colors.white),
        tooltip: 'New Chat',
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadChats,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_chats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No chats yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a conversation with your friends!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _navigateToFriends,
              icon: const Icon(Icons.people),
              label: const Text('Go to Friends'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadChats,
      child: ListView.builder(
        itemCount: _chats.length,
        itemBuilder: (context, index) {
          final chat = _chats[index];
          return ChatListItem(
            chat: chat,
            otherUser: _otherUserProfiles[chat.id],
            lastMessageText: _lastMessages[chat.id],
            lastMessageTime: _lastMessageTimes[chat.id],
            unreadCount: _unreadCounts[chat.id] ?? 0,
            onTap: () => _navigateToChat(chat),
          );
        },
      ),
    );
  }
}
