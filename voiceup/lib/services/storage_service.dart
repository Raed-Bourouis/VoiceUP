import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

/// Service class for handling file storage operations with Supabase Storage.
/// 
/// This service provides methods for:
/// - Uploading photos to the 'photos' bucket
/// - Uploading voice messages to the 'voice-messages' bucket
/// - Deleting files from storage
/// - Getting signed URLs for private files
class StorageService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Uploads a photo to the 'photos' bucket.
  /// 
  /// [file] - The photo file to upload
  /// [chatId] - The chat ID to organize files
  /// 
  /// Returns the public URL of the uploaded photo.
  /// 
  /// Throws [StorageException] if upload fails.
  Future<String> uploadPhoto(File file, String chatId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('No authenticated user');
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(file.path);
      final fileName = '$chatId/$userId/$timestamp$extension';

      // Upload to photos bucket
      await _supabase.storage.from('photos').upload(
            fileName,
            file,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );

      // Get public URL
      final url = _supabase.storage.from('photos').getPublicUrl(fileName);
      return url;
    } on StorageException catch (e) {
      throw StorageException(e.message);
    } catch (e) {
      throw Exception('Failed to upload photo: $e');
    }
  }

  /// Uploads a voice message to the 'voice-messages' bucket.
  /// 
  /// [file] - The audio file to upload
  /// [chatId] - The chat ID to organize files
  /// 
  /// Returns the public URL of the uploaded voice message.
  /// 
  /// Throws [StorageException] if upload fails.
  Future<String> uploadVoiceMessage(File file, String chatId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('No authenticated user');
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(file.path);
      final fileName = '$chatId/$userId/$timestamp$extension';

      // Upload to voice-messages bucket
      await _supabase.storage.from('voice-messages').upload(
            fileName,
            file,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );

      // Get public URL
      final url = _supabase.storage.from('voice-messages').getPublicUrl(fileName);
      return url;
    } on StorageException catch (e) {
      throw StorageException(e.message);
    } catch (e) {
      throw Exception('Failed to upload voice message: $e');
    }
  }

  /// Deletes a file from storage.
  /// 
  /// [bucket] - The storage bucket name ('photos' or 'voice-messages')
  /// [filePath] - The path to the file in the bucket
  /// 
  /// Throws [StorageException] if deletion fails.
  Future<void> deleteFile(String bucket, String filePath) async {
    try {
      await _supabase.storage.from(bucket).remove([filePath]);
    } on StorageException catch (e) {
      throw StorageException(e.message);
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }

  /// Gets a signed URL for a private file.
  /// 
  /// [bucket] - The storage bucket name
  /// [filePath] - The path to the file in the bucket
  /// [expiresIn] - Duration in seconds for the URL to remain valid (default: 3600)
  /// 
  /// Returns a signed URL that can be used to access the file.
  /// 
  /// Throws [StorageException] if getting URL fails.
  Future<String> getSignedUrl(
    String bucket,
    String filePath, {
    int expiresIn = 3600,
  }) async {
    try {
      final url = await _supabase.storage
          .from(bucket)
          .createSignedUrl(filePath, expiresIn);
      return url;
    } on StorageException catch (e) {
      throw StorageException(e.message);
    } catch (e) {
      throw Exception('Failed to get signed URL: $e');
    }
  }
}
