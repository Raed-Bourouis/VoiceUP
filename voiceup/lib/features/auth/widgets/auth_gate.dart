import 'dart:async';
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
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _notificationService = NotificationService();
  Session? _previousSession;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _previousSession = Supabase.instance.client.auth.currentSession;
    
    // If already logged in, save token
    if (_previousSession != null) {
      _notificationService.saveTokenAfterLogin();
    }

    // Listen to auth state changes
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      _handleAuthStateChange(event.session);
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _handleAuthStateChange(Session? session) {
    // User just logged in
    if (session != null && _previousSession == null) {
      _notificationService.saveTokenAfterLogin();
    }
    // User just logged out
    else if (session == null && _previousSession != null) {
      _notificationService.deleteTokenOnLogout();
    }
    
    _previousSession = session;
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
