import 'dart:async';
import 'package:flutter/material.dart';
import 'package:voiceup/models/profile.dart';
import 'package:voiceup/models/friendship.dart';

/// Widget displaying a single user search result.
/// 
/// Shows user avatar, display name, and appropriate action based on friendship state.
class UserSearchResultItem extends StatelessWidget {
  final Profile profile;
  final FriendshipState friendshipState;
  final VoidCallback? onAddFriend;
  final VoidCallback? onMessage;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onCancel;

  const UserSearchResultItem({
    super.key,
    required this.profile,
    required this.friendshipState,
    this.onAddFriend,
    this.onMessage,
    this.onAccept,
    this.onReject,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.deepPurple,
          backgroundImage:
              profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
          child: profile.avatarUrl == null
              ? Text(
                  profile.avatarInitial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          profile.displayNameOrUsername,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          profile.email,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        trailing: _buildActionButton(context),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    switch (friendshipState) {
      case FriendshipState.none:
        return ElevatedButton.icon(
          onPressed: onAddFriend,
          icon: const Icon(Icons.person_add, size: 16),
          label: const Text('Add'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
        );

      case FriendshipState.pendingOutgoing:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(
              label: const Text('Pending', style: TextStyle(fontSize: 12)),
              avatar: const Icon(Icons.schedule, size: 16),
              backgroundColor: Colors.orange[100],
            ),
            if (onCancel != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: onCancel,
                tooltip: 'Cancel',
                color: Colors.grey[600],
              ),
          ],
        );

      case FriendshipState.pendingIncoming:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green),
              onPressed: onAccept,
              tooltip: 'Accept',
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.red),
              onPressed: onReject,
              tooltip: 'Reject',
            ),
          ],
        );

      case FriendshipState.accepted:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(
              label: const Text('Friends', style: TextStyle(fontSize: 12)),
              avatar: const Icon(Icons.check, size: 16),
              backgroundColor: Colors.green[100],
            ),
            if (onMessage != null)
              IconButton(
                icon: const Icon(Icons.message, color: Colors.deepPurple),
                onPressed: onMessage,
                tooltip: 'Message',
              ),
          ],
        );

      case FriendshipState.rejected:
      case FriendshipState.blocked:
        return Chip(
          label: const Text('Unavailable', style: TextStyle(fontSize: 12)),
          backgroundColor: Colors.grey[300],
        );
    }
  }
}
