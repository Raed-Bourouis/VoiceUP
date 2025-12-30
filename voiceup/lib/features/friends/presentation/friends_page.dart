import 'dart:async';
import 'package:flutter/material.dart';
import 'package:voiceup/services/friendship_service.dart';
import 'package:voiceup/models/profile.dart';
import 'package:voiceup/models/friend_item.dart';
import 'package:voiceup/models/friend_request_item.dart';
import 'package:voiceup/models/friendship.dart';
import 'package:voiceup/features/friends/widgets/friend_list_item.dart';
import 'package:voiceup/features/friends/widgets/friend_request_list_item.dart';
import 'package:voiceup/features/friends/widgets/user_search_result_item.dart';

/// Main Friends page with tabs for Friends, Requests, and Find.
/// 
/// This page provides the full friend management UX including:
/// - Friends list (accepted friendships)
/// - Friend requests (incoming and outgoing)
/// - User search and add friends functionality
class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _friendshipService = FriendshipService();

  // Friends tab state
  List<FriendItem> _friends = [];
  bool _isLoadingFriends = true;
  String? _friendsError;

  // Requests tab state
  List<FriendRequestItem> _incomingRequests = [];
  List<FriendRequestItem> _outgoingRequests = [];
  bool _isLoadingRequests = true;
  String? _requestsError;

  // Search tab state
  final TextEditingController _searchController = TextEditingController();
  List<Profile> _searchResults = [];
  Map<String, FriendshipState> _friendshipStates = {};
  bool _isSearching = false;
  String? _searchError;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadFriends();
    _loadRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onTabChanged() {
    // Reload data when switching tabs
    if (_tabController.index == 0 && !_isLoadingFriends) {
      _loadFriends();
    } else if (_tabController.index == 1 && !_isLoadingRequests) {
      _loadRequests();
    }
  }

  // Friends tab methods

  Future<void> _loadFriends() async {
    setState(() {
      _isLoadingFriends = true;
      _friendsError = null;
    });

    try {
      final friends = await _friendshipService.getFriends();
      if (mounted) {
        setState(() {
          _friends = friends;
          _isLoadingFriends = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _friendsError = e.toString();
          _isLoadingFriends = false;
        });
      }
    }
  }

  Future<void> _handleUnfriend(FriendItem friend) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unfriend'),
        content: Text(
          'Are you sure you want to unfriend ${friend.profile.displayNameOrUsername}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Unfriend'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await _friendshipService.unfriend(friend.friendshipId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unfriended ${friend.profile.displayNameOrUsername}'),
            backgroundColor: Colors.green,
          ),
        );
        _loadFriends();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unfriend: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleMessage(FriendItem friend) {
    // TODO: Implement get_or_create_dm_chat RPC and navigate to chat screen
    // For now, show a placeholder message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Chat with ${friend.profile.displayNameOrUsername} - Coming soon!'),
      ),
    );
  }

  // Requests tab methods

  Future<void> _loadRequests() async {
    setState(() {
      _isLoadingRequests = true;
      _requestsError = null;
    });

    try {
      final incoming = await _friendshipService.getIncomingRequests();
      final outgoing = await _friendshipService.getOutgoingRequests();
      if (mounted) {
        setState(() {
          _incomingRequests = incoming;
          _outgoingRequests = outgoing;
          _isLoadingRequests = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _requestsError = e.toString();
          _isLoadingRequests = false;
        });
      }
    }
  }

  Future<void> _handleAcceptRequest(FriendRequestItem request) async {
    try {
      await _friendshipService.acceptFriendRequest(request.friendshipId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Accepted friend request from ${request.profile.displayNameOrUsername}'),
            backgroundColor: Colors.green,
          ),
        );
        _loadRequests();
        _loadFriends(); // Refresh friends list too
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleRejectRequest(FriendRequestItem request) async {
    try {
      await _friendshipService.rejectFriendRequest(request.friendshipId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rejected friend request from ${request.profile.displayNameOrUsername}'),
          ),
        );
        _loadRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleCancelRequest(FriendRequestItem request) async {
    try {
      await _friendshipService.cancelFriendRequest(request.friendshipId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Canceled friend request to ${request.profile.displayNameOrUsername}'),
          ),
        );
        _loadRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Search tab methods

  void _onSearchChanged(String query) {
    // Debounce search to avoid spamming the backend
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _friendshipStates = {};
        _searchError = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      final results = await _friendshipService.searchUsers(query);
      
      // Get friendship state for each result concurrently
      final states = <String, FriendshipState>{};
      final stateResults = await Future.wait(
        results.map((profile) => _friendshipService.getFriendshipState(profile.id))
      );
      for (int i = 0; i < results.length; i++) {
        states[results[i].id] = stateResults[i];
      }

      if (mounted) {
        setState(() {
          _searchResults = results;
          _friendshipStates = states;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchError = e.toString();
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _handleAddFriend(Profile profile) async {
    try {
      await _friendshipService.sendFriendRequest(profile.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Friend request sent to ${profile.displayNameOrUsername}'),
            backgroundColor: Colors.green,
          ),
        );
        // Update friendship state
        final newState = await _friendshipService.getFriendshipState(profile.id);
        setState(() {
          _friendshipStates[profile.id] = newState;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send friend request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleAcceptFromSearch(Profile profile) async {
    try {
      // Find the friendship ID first
      final incoming = await _friendshipService.getIncomingRequests();
      final request = incoming.firstWhere(
        (r) => r.profile.id == profile.id,
        orElse: () => throw Exception('Request not found'),
      );
      
      await _friendshipService.acceptFriendRequest(request.friendshipId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Accepted friend request from ${profile.displayNameOrUsername}'),
            backgroundColor: Colors.green,
          ),
        );
        // Update friendship state
        final newState = await _friendshipService.getFriendshipState(profile.id);
        setState(() {
          _friendshipStates[profile.id] = newState;
        });
        _loadFriends();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleRejectFromSearch(Profile profile) async {
    try {
      // Find the friendship ID first
      final incoming = await _friendshipService.getIncomingRequests();
      final request = incoming.firstWhere(
        (r) => r.profile.id == profile.id,
        orElse: () => throw Exception('Request not found'),
      );
      
      await _friendshipService.rejectFriendRequest(request.friendshipId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rejected friend request from ${profile.displayNameOrUsername}'),
          ),
        );
        // Update friendship state
        final newState = await _friendshipService.getFriendshipState(profile.id);
        setState(() {
          _friendshipStates[profile.id] = newState;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleCancelFromSearch(Profile profile) async {
    try {
      // Find the friendship ID first
      final outgoing = await _friendshipService.getOutgoingRequests();
      final request = outgoing.firstWhere(
        (r) => r.profile.id == profile.id,
        orElse: () => throw Exception('Request not found'),
      );
      
      await _friendshipService.cancelFriendRequest(request.friendshipId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Canceled friend request to ${profile.displayNameOrUsername}'),
          ),
        );
        // Update friendship state
        final newState = await _friendshipService.getFriendshipState(profile.id);
        setState(() {
          _friendshipStates[profile.id] = newState;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleMessageFromSearch(Profile profile) {
    // TODO: Implement get_or_create_dm_chat RPC and navigate to chat screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Chat with ${profile.displayNameOrUsername} - Coming soon!'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Friends', icon: Icon(Icons.people)),
            Tab(text: 'Requests', icon: Icon(Icons.person_add)),
            Tab(text: 'Find', icon: Icon(Icons.search)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsTab(),
          _buildRequestsTab(),
          _buildSearchTab(),
        ],
      ),
    );
  }

  // Friends tab UI
  Widget _buildFriendsTab() {
    if (_isLoadingFriends) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_friendsError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Failed to load friends',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              _friendsError!,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFriends,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No friends yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Find people to add as friends!',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(2),
              icon: const Icon(Icons.search),
              label: const Text('Find Friends'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFriends,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _friends.length,
        itemBuilder: (context, index) {
          final friend = _friends[index];
          return FriendListItem(
            friend: friend,
            onMessage: () => _handleMessage(friend),
            onUnfriend: () => _handleUnfriend(friend),
          );
        },
      ),
    );
  }

  // Requests tab UI
  Widget _buildRequestsTab() {
    if (_isLoadingRequests) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_requestsError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Failed to load requests',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              _requestsError!,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRequests,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_incomingRequests.isEmpty && _outgoingRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No friend requests',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'No pending requests at the moment',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Incoming requests section
          if (_incomingRequests.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Incoming Requests (${_incomingRequests.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
            ),
            ..._incomingRequests.map((request) => FriendRequestListItem(
                  request: request,
                  onAccept: () => _handleAcceptRequest(request),
                  onReject: () => _handleRejectRequest(request),
                )),
            const SizedBox(height: 16),
          ],
          // Outgoing requests section
          if (_outgoingRequests.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Outgoing Requests (${_outgoingRequests.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
            ),
            ..._outgoingRequests.map((request) => FriendRequestListItem(
                  request: request,
                  onCancel: () => _handleCancelRequest(request),
                )),
          ],
        ],
      ),
    );
  }

  // Search tab UI
  Widget _buildSearchTab() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search by username or email...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchResults = [];
                          _friendshipStates = {};
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        // Search results
        Expanded(
          child: _buildSearchResults(),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Search failed',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              _searchError!,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_searchController.text.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Search for friends',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter a username or email to find people',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final profile = _searchResults[index];
        final friendshipState =
            _friendshipStates[profile.id] ?? FriendshipState.none;

        return UserSearchResultItem(
          profile: profile,
          friendshipState: friendshipState,
          onAddFriend: () => _handleAddFriend(profile),
          onMessage: () => _handleMessageFromSearch(profile),
          onAccept: () => _handleAcceptFromSearch(profile),
          onReject: () => _handleRejectFromSearch(profile),
          onCancel: () => _handleCancelFromSearch(profile),
        );
      },
    );
  }
}
