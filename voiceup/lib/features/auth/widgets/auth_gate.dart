import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voiceup/features/auth/presentation/auth_page.dart';
import 'package:voiceup/features/chat/presentation/chat_list_page.dart';
import 'package:voiceup/services/notification_service.dart';

/// AuthGate widget that manages navigation based on authentication state.
///
/// This widget listens to Supabase auth state changes and automatically
/// navigates between the authentication page and the main app screen
/// based on whether a valid session exists.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();}


class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    _setupAuthListener();
  }

    void _setupAuthListener() {
    Supabase.instance.client. auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      if (event == AuthChangeEvent.signedIn && session != null) {
        // Save FCM token when user signs in
        debugPrint('🔔 User signed in, saving FCM token.. .');
        await NotificationService().saveFcmToken();
      }
    });

    // Also save token if user is already signed in
    if (Supabase.instance.client. auth.currentUser != null) {
      NotificationService().saveFcmToken();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Check if we have a session
        final session = Supabase.instance.client.auth.currentSession;

        if (session != null) {
          // User is signed in, show the main app
          return const ChatListPage();
        } else {
          // No session, show authentication page
          return const AuthPage();
        }
      },
    );
  }
}
