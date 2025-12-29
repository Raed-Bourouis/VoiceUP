import 'package:supabase_flutter/supabase_flutter.dart';

/// Service class for handling user profile operations with Supabase.
/// 
/// This service provides methods for fetching and managing user profiles
/// from the 'profiles' table in Supabase.
class ProfileService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetches the profile for the currently authenticated user.
  /// 
  /// Returns a Map containing profile data if found, null otherwise.
  /// The profile is expected to be automatically created by a database trigger
  /// when a new user is created in auth.users.
  /// 
  /// Throws [PostgrestException] if the database query fails.
  Future<Map<String, dynamic>?> getCurrentProfile() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return null;
      }

      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      return response;
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch profile: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred while fetching profile: $e');
    }
  }

  /// Fetches a profile by user ID.
  /// 
  /// [userId] - The unique identifier of the user
  /// 
  /// Returns a Map containing profile data if found, null otherwise.
  /// 
  /// Throws [PostgrestException] if the database query fails.
  Future<Map<String, dynamic>?> getProfileById(String userId) async {
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
      throw Exception('An unexpected error occurred while fetching profile: $e');
    }
  }

  /// Updates the current user's profile.
  /// 
  /// [updates] - Map of field names and values to update
  /// 
  /// Returns the updated profile data.
  /// 
  /// Throws [PostgrestException] if the database update fails.
  Future<Map<String, dynamic>> updateCurrentProfile(
    Map<String, dynamic> updates,
  ) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('No authenticated user');
      }

      final response = await _supabase
          .from('profiles')
          .update(updates)
          .eq('id', userId)
          .select()
          .single();

      return response;
    } on PostgrestException catch (e) {
      throw Exception('Failed to update profile: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred while updating profile: $e');
    }
  }

  /// Ensures a profile exists for the current user.
  /// 
  /// This method can be called after sign-up to verify the profile was created
  /// by the database trigger. If no profile exists, it will be created.
  /// 
  /// Returns the profile data.
  Future<Map<String, dynamic>> ensureProfileExists() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      final userEmail = _supabase.auth.currentUser?.email;
      
      if (userId == null) {
        throw Exception('No authenticated user');
      }

      // Try to fetch existing profile
      var profile = await getCurrentProfile();
      
      // If profile doesn't exist, create it
      if (profile == null) {
        profile = await _supabase
            .from('profiles')
            .insert({
              'id': userId,
              'email': userEmail,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();
      }

      return profile;
    } catch (e) {
      throw Exception('Failed to ensure profile exists: $e');
    }
  }
}
