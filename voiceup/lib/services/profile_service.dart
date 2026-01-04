import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';

/// Service class for handling user profile operations with Supabase.
class ProfileService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// ===============================
  /// FETCH CURRENT PROFILE (RAW)
  /// ===============================
  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      return response;
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch profile: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error while fetching profile: $e');
    }
  }

  /// ===============================
  /// FETCH CURRENT PROFILE AS MODEL
  /// ===============================
  Future<Profile?> getCurrentProfileModel() async {
    final data = await getCurrentProfile();
    return data == null ? null : Profile.fromJson(data);
  }

  /// ===============================
  /// FETCH PROFILE BY USER ID
  /// ===============================
  Future<Profile> getProfileById(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      return Profile.fromJson(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch profile: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error while fetching profile: $e');
    }
  }

  /// ===============================
  /// UPDATE PROFILE GENERIC
  /// ===============================
  Future<void> updateCurrentProfile(Map<String, dynamic> updates) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('No authenticated user');

    try {
      await _supabase.from('profiles').update({
        ...updates,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update profile: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error while updating profile: $e');
    }
  }

  /// ===============================
  /// UPDATE BIO
  /// ===============================
  Future<void> updateBio(String bio) async {
    await updateCurrentProfile({'bio': bio});
  }

  /// ===============================
  /// UPDATE DISPLAY NAME
  /// ===============================
  Future<void> updateDisplayName(String displayName) async {
    await updateCurrentProfile({'display_name': displayName});
  }

  /// ===============================
  /// UPDATE USERNAME
  /// ===============================
  Future<void> updateUsername(String username) async {
    await updateCurrentProfile({'username': username});
  }

  /// ===============================
  /// UPDATE AVATAR
  /// ===============================
  Future<void> updateAvatar(String filePath) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("Utilisateur non authentifié");

    final file = File(filePath);
    final bucket = 'avatars';

    // 🔑 Nom de fichier UNIQUE
    final fileName = '$userId-${DateTime.now().millisecondsSinceEpoch}.png';

    try {
      // 1️⃣ Upload vers Supabase Storage
      await _supabase.storage.from(bucket).upload(
        fileName,
        file,
        fileOptions: const FileOptions(
          upsert: true,
          contentType: 'image/png',
        ),
      );

      // 2️⃣ Récupère URL publique
      final publicUrl =
      _supabase.storage.from(bucket).getPublicUrl(fileName);

      // 3️⃣ Met à jour avatar_url
      await updateCurrentProfile({'avatar_url': publicUrl});
    } catch (e) {
      throw Exception('Failed to upload avatar: $e');
    }
  }


  Future<Map<String, dynamic>> ensureProfileExists() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    try {
      // Vérifie si profile existe
      var profile = await getCurrentProfile();

      // Sinon, crée le profil
      if (profile == null) {
        profile = await _supabase.from('profiles').insert({
          'id': user.id,
          'email': user.email,
          'bio': null,
          'display_name': user.email?.split('@')[0],
          'username': user.email?.split('@')[0],
          'avatar_url': null,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).select().single();
      }

      return profile;
    } catch (e) {
      throw Exception('Failed to ensure profile exists: $e');
    }
  }
}
