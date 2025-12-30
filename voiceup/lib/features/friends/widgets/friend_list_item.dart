import 'package:flutter/material.dart';
import 'package:voiceup/models/friend_item.dart';

/// Widget displaying a single friend item in the friends list.
/// 
/// Shows friend avatar, display name, and action buttons (Message, Unfriend).
class FriendListItem extends StatelessWidget {
  final FriendItem friend;
  final VoidCallback onMessage;
  final VoidCallback onUnfriend;

  const FriendListItem({
    super.key,
    required this.friend,
    required this.onMessage,
    required this.onUnfriend,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.deepPurple,
          backgroundImage: friend.profile.avatarUrl != null
              ? NetworkImage(friend.profile.avatarUrl!)
              : null,
          child: friend.profile.avatarUrl == null
              ? Text(
                  friend.profile.avatarInitial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          friend.profile.displayNameOrUsername,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          friend.profile.email,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Message button
            IconButton(
              icon: const Icon(Icons.message, color: Colors.deepPurple),
              onPressed: onMessage,
              tooltip: 'Message',
            ),
            // Unfriend menu
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'unfriend') {
                  onUnfriend();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'unfriend',
                  child: Row(
                    children: [
                      Icon(Icons.person_remove, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Unfriend', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
