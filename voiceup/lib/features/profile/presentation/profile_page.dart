import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:voiceup/models/profile.dart';
import 'package:voiceup/services/profile_service.dart';

class ProfilePage extends StatefulWidget {
  final String? userId;
  const ProfilePage({super.key, this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ProfileService _profileService = ProfileService();

  Profile? _profile;
  bool _isLoading = true;
  String? _error;

  bool get isCurrentUser => widget.userId == null;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = isCurrentUser
          ? await _profileService.getCurrentProfileModel()
          : await _profileService.getProfileById(widget.userId!);

      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// =========================
  /// CHANGE AVATAR
  /// =========================
  Future<void> _changeAvatar() async {
    if (!isCurrentUser || _profile == null) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    await _profileService.updateAvatar(image.path);

    // 🔥 Clear cache pour forcer le reload
    imageCache.clear();
    imageCache.clearLiveImages();

    await _loadProfile();
  }

  /// =========================
  /// EDIT FIELD
  /// =========================
  Future<void> _editField({
    required String title,
    required String? initialValue,
    required Future<void> Function(String) onSave,
  }) async {
    final controller = TextEditingController(text: initialValue ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Modifier $title'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Enregistrer')),
        ],
      ),
    );

    if (result == true) {
      await onSave(controller.text.trim());
      await _loadProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null || _profile == null) {
      return Scaffold(body: Center(child: Text(_error ?? 'Erreur')));
    }

    final profile = _profile!;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          /// HEADER
          Container(
            padding: const EdgeInsets.only(top: 60, bottom: 30),
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple, Colors.teal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      key: ValueKey(profile.avatarUrl), // 🔥 Fix cache
                      radius: 55,
                      backgroundColor: Colors.white,
                      backgroundImage: profile.avatarUrl != null
                          ? NetworkImage(profile.avatarUrl!)
                          : null,
                      child: profile.avatarUrl == null
                          ? Text(
                        profile.avatarInitial,
                        style: const TextStyle(
                            fontSize: 32, color: Colors.deepPurple),
                      )
                          : null,
                    ),
                    if (isCurrentUser)
                      GestureDetector(
                        onTap: _changeAvatar,
                        child: const CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.black87,
                          child: Icon(Icons.camera_alt,
                              color: Colors.white, size: 18),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(profile.displayNameOrUsername,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                Text(profile.email,
                    style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),

          /// CONTENT
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _card(
                  'Bio',
                  profile.bio ?? 'Aucune bio',
                  isCurrentUser
                      ? () => _editField(
                    title: 'Bio',
                    initialValue: profile.bio,
                    onSave: _profileService.updateBio,
                  )
                      : null,
                ),
                const SizedBox(height: 12),
                _card(
                  'Display Name',
                  profile.displayName ?? '',
                  isCurrentUser
                      ? () => _editField(
                    title: 'Display Name',
                    initialValue: profile.displayName,
                    onSave: _profileService.updateDisplayName,
                  )
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// CARD WIDGET
  Widget _card(String title, String value, VoidCallback? onEdit) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(value),
        ),
        trailing: onEdit != null
            ? IconButton(
          icon: const Icon(Icons.edit, color: Colors.teal),
          onPressed: onEdit,
        )
            : null,
      ),
    );
  }
}
