import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voiceup/services/auth_service.dart';
import 'package:voiceup/services/message_service.dart';
import 'package:voiceup/services/chat_service.dart';
import 'package:voiceup/services/storage_service.dart';
import 'package:voiceup/models/chat.dart';
import 'package:voiceup/models/profile.dart';
import 'package:voiceup/models/message.dart';
import 'package:voiceup/features/chat/widgets/message_bubble.dart';
import 'package:voiceup/features/chat/widgets/text_input_bar.dart';
import 'package:intl/intl.dart';

/// Individual chat conversation page. 
/// 
/// Features:
/// - Scrollable message list with pagination
/// - Real-time incoming messages
/// - Send text, photo, and voice messages
/// - Auto-scroll to bottom on new message
/// - Mark messages as read
class ChatDetailPage extends StatefulWidget {
  final Chat chat;
  final Profile?  otherUser; // For 1:1 chats

  const ChatDetailPage({
    super.key,
    required this.chat,
    this.otherUser,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final _authService = AuthService();
  final _messageService = MessageService();
  final _chatService = ChatService();
  final _storageService = StorageService();
  final ScrollController _scrollController = ScrollController();

  List<Message> _messages = [];
  // Cache for signed URLs:  mediaUrl -> signedUrl
  final Map<String, String> _signedUrlCache = {};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  RealtimeChannel? _messagesChannel;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeToMessages();
    _markAsRead();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _messagesChannel?.unsubscribe();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Load more messages when scrolling to the top
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _loadMoreMessages();
      }
    }
  }

  /// Extracts the file path from a Supabase storage URL. 
  String?  _extractFilePath(String url) {
    try {
      final uri = Uri. parse(url);
      final pathSegments = uri.pathSegments;
      
      int bucketIndex = -1;
      for (int i = 0; i < pathSegments.length; i++) {
        if (pathSegments[i] == 'photos' || pathSegments[i] == 'voice-messages') {
          bucketIndex = i;
          break;
        }
      }
      
      if (bucketIndex == -1 || bucketIndex >= pathSegments.length - 1) {
        return null;
      }
      
      return pathSegments. sublist(bucketIndex + 1).join('/');
    } catch (e) {
      return null;
    }
  }

  /// Gets signed URL for a media message.
  Future<String> _getSignedUrl(Message message) async {
    if (message.mediaUrl == null) return '';
    
    if (_signedUrlCache.containsKey(message.mediaUrl)) {
      return _signedUrlCache[message.mediaUrl]!;
    }
    
    try {
      final filePath = _extractFilePath(message.mediaUrl!);
      if (filePath == null) {
        return message.mediaUrl!;
      }
      
      final bucket = message.messageType == MessageType.photo 
          ? 'photos' 
          : 'voice-messages';
      
      final signedUrl = await _storageService.getSignedUrl(
        bucket,
        filePath,
        expiresIn: 3600,
      );
      
      _signedUrlCache[message.mediaUrl! ] = signedUrl;
      
      return signedUrl;
    } catch (e) {
      return message.mediaUrl!;
    }
  }

  /// Processes messages to get signed URLs for media.
  Future<List<Message>> _processMessagesWithSignedUrls(List<Message> messages) async {
    final processedMessages = <Message>[];
    
    for (final message in messages) {
      if (message.mediaUrl != null && 
          (message.messageType == MessageType. photo || 
           message.messageType == MessageType.voice)) {
        final signedUrl = await _getSignedUrl(message);
        processedMessages.add(message.copyWith(mediaUrl: signedUrl));
      } else {
        processedMessages. add(message);
      }
    }
    
    return processedMessages;
  }

  Future<void> _loadMessages() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final messages = await _messageService.getMessages(
        widget.chat.id,
        limit: 50,
      );

      final processedMessages = await _processMessagesWithSignedUrls(messages);

      if (mounted) {
        setState(() {
          // Messages come from API newest first, reverse to have oldest first
          // So _messages[0] is oldest, _messages[length-1] is newest
          _messages = processedMessages.reversed. toList();
          _isLoading = false;
          _hasMore = messages.length >= 50;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
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

  Future<void> _loadMoreMessages() async {
    if (_messages.isEmpty) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final oldestMessage = _messages.first;
      final messages = await _messageService.getMessages(
        widget.chat.id,
        limit: 50,
        beforeId: oldestMessage.id,
      );

      final processedMessages = await _processMessagesWithSignedUrls(messages);

      if (mounted) {
        setState(() {
          _messages.insertAll(0, processedMessages. reversed. toList());
          _isLoadingMore = false;
          _hasMore = messages.length >= 50;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _subscribeToMessages() {
    try {
      _messagesChannel = _messageService.subscribeToMessages(
        widget. chat.id,
        (message) async {
          if (mounted) {
            Message processedMessage = message;
            if (message.mediaUrl != null && 
                (message.messageType == MessageType.photo || 
                 message.messageType == MessageType.voice)) {
              final signedUrl = await _getSignedUrl(message);
              processedMessage = message.copyWith(mediaUrl: signedUrl);
            }
            
            setState(() {
              _messages.add(processedMessage);
            });
            
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToBottom();
            });
            
            _markAsRead();
          }
        },
      );
    } catch (e) {
      // Silently handle subscription errors
    }
  }

  Future<void> _markAsRead() async {
    try {
      await _messageService.markAsRead(widget.chat.id);
    } catch (e) {
      // Silently handle errors
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.minScrollExtent,
        duration:  const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleSendText(String text) async {
    try {
      await _messageService. sendTextMessage(widget.chat.id, text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors. red,
          ),
        );
      }
    }
  }

  Future<void> _handleSendPhoto(File photo) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Uploading photo...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      await _messageService.sendPhotoMessage(widget.chat.id, photo);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger. of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleSendVoice(File audio, int durationSeconds) async {
    try {
      if (mounted) {
        ScaffoldMessenger. of(context).showSnackBar(
          const SnackBar(
            content: Text('Uploading voice message...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      await _messageService.sendVoiceMessage(
        widget.chat.id,
        audio,
        durationSeconds,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send voice message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getChatTitle() {
    if (widget.chat.isGroup) {
      return widget.chat.name ??  'Group Chat';
    } else {
      return widget.otherUser?.displayNameOrUsername ?? 'Chat';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:  AppBar(
        title: Text(_getChatTitle()),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildMessagesList(),
          ),
          TextInputBar(
            onSendText: _handleSendText,
            onSendPhoto: _handleSendPhoto,
            onSendVoice: _handleSendVoice,
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height:  16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMessages,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_messages. isEmpty) {
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
              'No messages yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Send a message to start the conversation! ',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView. builder(
      controller: _scrollController,
      reverse: true, // Show newest at bottom
      padding: const EdgeInsets.all(8),
      itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return const Center(
            child:  Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        // With reverse: true, index 0 is the LAST item in _messages (newest)
        // index 1 is second to last, etc.
        // So to get the actual message:  _messages[_messages.length - 1 - index]
        final messageIndex = _messages.length - 1 - index;
        final message = _messages[messageIndex];
        final currentUserId = _authService.currentUser?.id;
        final isSent = message.senderId == currentUserId;

        // Check if we should show date separator
        final showDateSeparator = _shouldShowDateSeparator(messageIndex);

        return Column(
          children: [
            if (showDateSeparator) _buildDateSeparator(message. createdAt),
            MessageBubble(
              message:  message,
              isSent:  isSent,
            ),
          ],
        );
      },
    );
  }

  /// Determines if a date separator should be shown before the message at [messageIndex].
  /// 
  /// Shows separator if:
  /// - It's the first message (oldest), OR
  /// - The message date is different from the previous message's date
  bool _shouldShowDateSeparator(int messageIndex) {
    // Always show for the first (oldest) message
    if (messageIndex == 0) {
      return true;
    }

    // Compare with the previous message (older message)
    final currentMessage = _messages[messageIndex];
    final previousMessage = _messages[messageIndex - 1];

    final currentDate = DateTime(
      currentMessage.createdAt. year,
      currentMessage.createdAt.month,
      currentMessage.createdAt.day,
    );
    final previousDate = DateTime(
      previousMessage. createdAt.year,
      previousMessage.createdAt.month,
      previousMessage.createdAt.day,
    );

    return ! currentDate.isAtSameMomentAs(previousDate);
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    String dateText;
    if (messageDate.isAtSameMomentAs(today)) {
      dateText = 'Today';
    } else if (messageDate.isAtSameMomentAs(yesterday)) {
      dateText = 'Yesterday';
    } else {
      dateText = DateFormat('MMM dd, yyyy').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius:  BorderRadius.circular(16),
          ),
          child: Text(
            dateText,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}