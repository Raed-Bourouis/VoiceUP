import 'package:flutter/material.dart';
import 'package:voiceup/models/chat.dart';
import 'package:voiceup/models/profile.dart';

/// Widget displaying a chat preview item in the chat list.
/// 
/// Shows:
/// - Chat avatar (user avatar for 1:1, group icon for groups)
/// - Chat name (friend name for 1:1, group name for groups)
/// - Last message preview
/// - Timestamp
/// - Unread count badge
class ChatListItem extends StatelessWidget {
  final Chat chat;
  final Profile? otherUser; // For 1:1 chats, the other user's profile
  final String? lastMessageText;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final VoidCallback onTap;

  const ChatListItem({
    super.key,
    required this.chat,
    this.otherUser,
    this.lastMessageText,
    this.lastMessageTime,
    this.unreadCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = _getDisplayName();
    final avatar = _getAvatar();

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: Colors.deepPurple.shade100,
        backgroundImage: avatar != null ? NetworkImage(avatar) : null,
        child: avatar == null
            ? Text(
                _getInitial(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              )
            : null,
      ),
      title: Text(
        displayName,
        style: TextStyle(
          fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        lastMessageText ?? 'No messages yet',
        style: TextStyle(
          color: unreadCount > 0 ? Colors.black87 : Colors.grey[600],
          fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (lastMessageTime != null)
            Text(
              _formatTime(lastMessageTime!),
              style: TextStyle(
                fontSize: 12,
                color: unreadCount > 0 ? Colors.deepPurple : Colors.grey[600],
                fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          if (unreadCount > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.deepPurple,
                shape: BoxShape.circle,
              ),
              child: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getDisplayName() {
    if (chat.isGroup) {
      return chat.name ?? 'Group Chat';
    } else {
      return otherUser?.displayNameOrUsername ?? 'Unknown User';
    }
  }

  String? _getAvatar() {
    if (chat.isGroup) {
      return chat.avatarUrl;
    } else {
      return otherUser?.avatarUrl;
    }
  }

  String _getInitial() {
    if (chat.isGroup) {
      return (chat.name ?? 'G').substring(0, 1).toUpperCase();
    } else {
      return otherUser?.avatarInitial ?? '?';
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays == 0) {
      // Today: show time
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return _getDayName(time.weekday);
    } else {
      // Show date
      return '${time.day}/${time.month}/${time.year}';
    }
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return '';
    }
  }
}
