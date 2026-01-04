import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voiceup/features/auth/widgets/auth_gate.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:voiceup/services/notification_service.dart';

/// Main entry point for the VoiceUp Flutter application.
///
/// Initializes Supabase client and runs the app with authentication gate.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  await dotenv.load(fileName: ".env");
  final supabaseUrl = dotenv.env['SUPABASE_URL']!;
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']!;

  // Initialize Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
    // Enable automatic token refresh
    // This ensures the session remains valid by refreshing tokens before they expire
    realtimeClientOptions: const RealtimeClientOptions(eventsPerSecond: 10),
  );

  // Initialize Notifications
  await NotificationService().initialize();

  runApp(const MyApp());
}

/// Main application widget with MaterialApp configuration and auth gate.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoiceUp Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // Use AuthGate to handle authentication routing
      // It will show AuthPage when no session exists
      // and ChatHomePage when user is authenticated
      home: const AuthGate(),
    );
  }
}
