import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Service class for handling authentication operations with Supabase.
/// 
/// This service provides methods for:
/// - Email/password sign-up and sign-in
/// - Google OAuth authentication
/// - Session management and sign-out
class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Signs up a new user with email and password.
  /// 
  /// [email] - User's email address
  /// [password] - User's password
  /// [username] - Optional username for the user profile
  /// 
  /// Throws [AuthException] if sign-up fails.
  /// 
  /// Returns [AuthResponse] containing session and user data.
  Future<AuthResponse> signUpWithEmail(
    String email,
    String password, {
    String? username,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: username != null ? {'username': username} : null,
      );
      return response;
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw AuthException('An unexpected error occurred during sign-up');
    }
  }

  /// Signs in an existing user with email and password.
  /// 
  /// [email] - User's email address
  /// [password] - User's password
  /// 
  /// Throws [AuthException] if sign-in fails.
  /// 
  /// Returns [AuthResponse] containing session and user data.
  Future<AuthResponse> signInWithEmail(
    String email,
    String password,
  ) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw AuthException('An unexpected error occurred during sign-in');
    }
  }

  /// Signs in with Google OAuth using the browser flow.
  /// 
  /// This method opens a browser window for Google authentication.
  /// Configure the redirect URL in your Supabase project settings.
  /// 
  /// Throws [AuthException] if OAuth sign-in fails.
  /// 
  /// Returns true if the OAuth flow was initiated successfully.
  Future<bool> signInWithGoogleOAuth() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'voiceup://login-callback',
      );
      return true;
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw AuthException('An unexpected error occurred during Google sign-in');
    }
  }

  /// Signs in with Google using native Google Sign-In flow.
  /// 
  /// This method uses the google_sign_in package to authenticate
  /// and then exchanges the ID token with Supabase.
  /// 
  /// Throws [AuthException] if native Google sign-in fails.
  /// 
  /// Returns [AuthResponse] containing session and user data.
  Future<AuthResponse> signInWithGoogleNative() async {
    try {
      // Initialize Google Sign-In
      // TODO: Configure these in your environment or configuration file
      const webClientId = String.fromEnvironment(
        'GOOGLE_WEB_CLIENT_ID',
        defaultValue: '', // Replace with your Google Web Client ID
      );
      const iosClientId = String.fromEnvironment(
        'GOOGLE_IOS_CLIENT_ID', 
        defaultValue: '', // Replace with your Google iOS Client ID
      );

      if (webClientId.isEmpty || iosClientId.isEmpty) {
        throw AuthException(
          'Google client IDs not configured. Please set GOOGLE_WEB_CLIENT_ID and GOOGLE_IOS_CLIENT_ID.',
        );
      }

      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: iosClientId,
        serverClientId: webClientId,
      );

      // Trigger the Google Sign-In flow
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw AuthException('Google sign-in was cancelled');
      }

      // Obtain the auth details from the request
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw AuthException('Failed to get ID token from Google');
      }

      // Sign in to Supabase with the Google credentials
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      return response;
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw AuthException('An unexpected error occurred during native Google sign-in: $e');
    }
  }

  /// Signs out the current user.
  /// 
  /// Clears the current session and removes stored credentials.
  /// 
  /// Throws [AuthException] if sign-out fails.
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw AuthException('An unexpected error occurred during sign-out');
    }
  }

  /// Gets the current user session.
  /// 
  /// Returns [Session] if user is authenticated, null otherwise.
  Session? get currentSession => _supabase.auth.currentSession;

  /// Gets the current authenticated user.
  /// 
  /// Returns [User] if user is authenticated, null otherwise.
  User? get currentUser => _supabase.auth.currentUser;

  /// Stream of authentication state changes.
  /// 
  /// Emits events when user signs in, signs out, or session is updated.
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
}
