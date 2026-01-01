import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:voiceup/models/message.dart';
import 'package:voiceup/features/chat/widgets/voice_player.dart';
import 'package:voiceup/features/chat/widgets/photo_viewer.dart';

/// Widget displaying a message bubble in the chat. 
/// 
/// Handles different message types:
/// - Text messages with proper styling
/// - Photo messages with thumbnail and tap to view
/// - Voice messages with playback controls
/// 
/// Shows sent/received styling with different colors and alignment. 
class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isSent; // Whether the message was sent by current user
  final bool showTimestamp;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isSent,
    this.showTimestamp = true,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal:  8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isSent ? Colors.deepPurple : Colors.grey[300],
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMessageContent(context),
              if (showTimestamp)
                Padding(
                  padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8, top: 4),
                  child: Text(
                    _formatTimestamp(message.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: isSent ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    if (message.isDeleted) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'This message was deleted',
          style: TextStyle(
            color: isSent ? Colors.white70 : Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    try {
      switch (message.messageType) {
        case MessageType.text:
          return _buildTextMessage();
        case MessageType.photo:
          return _buildPhotoMessage(context);
        case MessageType. voice:
          return _buildVoiceMessage();
      }
    } catch (e) {
      // Fallback for any errors
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Unable to load message',
          style: TextStyle(
            color: isSent ? Colors.white70 : Colors.grey[600],
            fontStyle:  FontStyle.italic,
          ),
        ),
      );
    }
  }

  Widget _buildTextMessage() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        message.textContent ?? '',
        style: TextStyle(
          fontSize:  16,
          color: isSent ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildPhotoMessage(BuildContext context) {
    if (message.mediaUrl == null || message.mediaUrl!.isEmpty) {
      return Padding(
        padding: const EdgeInsets. all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image,
              color: isSent ? Colors.white70 : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Photo unavailable',
              style: TextStyle(
                color: isSent ? Colors.white70 : Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PhotoViewer(imageUrl: message.mediaUrl!),
          ),
        );
      },
      child: CachedNetworkImage(
        imageUrl: message.mediaUrl! ,
        width: 200,
        height: 200,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: 200,
          height:  200,
          color: isSent ? Colors.deepPurple[300] : Colors.grey[400],
          child: const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          width: 200,
          height:  200,
          color: isSent ? Colors.deepPurple[300] : Colors.grey[400],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                'Failed to load image',
                style:  TextStyle(
                  color:  Colors.white. withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceMessage() {
    if (message.mediaUrl == null || message.mediaUrl!.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize. min,
          children: [
            Icon(
              Icons.mic_off,
              color: isSent ? Colors.white70 :  Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Voice message unavailable',
              style: TextStyle(
                color: isSent ? Colors.white70 : Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: SizedBox(
        width: 200, // Fixed width for voice messages
        child: VoicePlayer(
          audioUrl: message.mediaUrl!,
          duration: message.mediaDuration ?? 0,
          color: isSent ? Colors.white : Colors.deepPurple,
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      // Today:  show time
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (difference. inDays == 1) {
      return 'Yesterday ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp. year}';
    }
  }
}