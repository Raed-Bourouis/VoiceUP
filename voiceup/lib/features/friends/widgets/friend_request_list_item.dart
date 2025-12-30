import 'package:flutter/material.dart';
import 'package:voiceup/models/friend_request_item.dart';

/// Widget displaying a single friend request item.
/// 
/// Shows requester/receiver avatar, display name, and appropriate action buttons.
/// For incoming requests: Accept and Reject buttons.
/// For outgoing requests: Cancel button.
class FriendRequestListItem extends StatelessWidget {
  final FriendRequestItem request;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onCancel;

  const FriendRequestListItem({
    super.key,
    required this.request,
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
          backgroundImage: request.profile.avatarUrl != null
              ? NetworkImage(request.profile.avatarUrl!)
              : null,
          child: request.profile.avatarUrl == null
              ? Text(
                  request.profile.avatarInitial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          request.profile.displayNameOrUsername,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              request.profile.email,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              _getTimeAgo(request.requestedAt),
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ],
        ),
        trailing: request.isIncoming
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Accept button
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    onPressed: onAccept,
                    tooltip: 'Accept',
                  ),
                  // Reject button
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    onPressed: onReject,
                    tooltip: 'Reject',
                  ),
                ],
              )
            : TextButton.icon(
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Cancel'),
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                ),
              ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
