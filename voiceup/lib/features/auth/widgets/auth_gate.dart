import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voiceup/features/auth/presentation/auth_page.dart';
import 'package:voiceup/features/chat/presentation/chat_home_page.dart';

/// AuthGate widget that manages navigation based on authentication state.
/// 
/// This widget listens to Supabase auth state changes and automatically
/// navigates between the authentication page and the main app screen
/// based on whether a valid session exists.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Check if we have a session
        final session = Supabase.instance.client.auth.currentSession;

        if (session != null) {
          // User is signed in, show the main app
          return const ChatHomePage();
        } else {
          // No session, show authentication page
          return const AuthPage();
        }
      },
    );
  }
}
