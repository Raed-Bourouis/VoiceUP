import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('🔔 Background message:  ${message.messageId}');
}

/// Service class for handling push notifications. 
/// 
/// This service provides methods for:
/// - Initializing Firebase Cloud Messaging
/// - Handling foreground and background notifications
/// - Managing FCM tokens
/// - Storing tokens in Supabase for targeting
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Initialize the notification service.
  /// Call this in main() after Firebase. initializeApp()
  Future<void> initialize() async {
    // Set up background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permissions
    await _requestPermissions();

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Set up foreground message handler
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from a notification
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // Get and save FCM token
    await saveFcmToken();

    // Listen for token refresh
    _fcm.onTokenRefresh.listen((token) {
      _saveFcmTokenToDatabase(token);
    });
  }

  /// Request notification permissions from the user.
  Future<void> _requestPermissions() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('🔔 Notification permission:  ${settings.authorizationStatus}');

    // For iOS, set foreground presentation options
    if (Platform.isIOS) {
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  /// Initialize local notifications for foreground display.
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        _handleLocalNotificationTap(response);
      },
    );

    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      'high_importance_channel',
      'Chat Messages',
      description: 'Notifications for new chat messages',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Handle foreground messages by showing local notification.
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('🔔 Foreground message: ${message.messageId}');
    debugPrint('🔔 Title: ${message.notification?.title}');
    debugPrint('🔔 Body: ${message. notification?.body}');
    debugPrint('🔔 Data: ${message.data}');

    final notification = message.notification;
    if (notification == null) return;

    // Don't show notification if user is currently in the chat
    final chatId = message.data['chat_id'];
    if (chatId != null && _currentChatId == chatId) {
      debugPrint('🔔 User is in this chat, not showing notification');
      return;
    }

    // Show local notification
    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'Chat Messages',
          channelDescription: 'Notifications for new chat messages',
          importance:  Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  /// Handle notification tap when app is in background.
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('🔔 Notification tapped: ${message.data}');
    
    final chatId = message.data['chat_id'];
    if (chatId != null) {
      // Navigate to chat - you'll need to implement this based on your navigation
      _navigateToChat(chatId);
    }
  }

  /// Handle local notification tap.
  void _handleLocalNotificationTap(NotificationResponse response) {
    debugPrint('🔔 Local notification tapped: ${response.payload}');
    
    if (response.payload != null) {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      final chatId = data['chat_id'];
      if (chatId != null) {
        _navigateToChat(chatId);
      }
    }
  }

  /// Get and save FCM token to database.
  Future<void> saveFcmToken() async {
    final token = await _fcm.getToken();
    if (token != null) {
      debugPrint('🔔 FCM Token:  $token');
      await _saveFcmTokenToDatabase(token);
    }
  }

  /// Save FCM token to Supabase for push notification targeting.
  Future<void> _saveFcmTokenToDatabase(String token) async {
    try {
      final userId = _supabase.auth.currentUser?. id;
      if (userId == null) {
        debugPrint('🔔 No user logged in, skipping token save');
        return;
      }

      await _supabase.from('user_push_tokens').upsert({
        'user_id': userId,
        'fcm_token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id, platform');

      debugPrint('🔔 FCM token saved to database');
    } catch (e) {
      debugPrint('🔔 Failed to save FCM token: $e');
    }
  }

  /// Delete FCM token from database (call on logout).
  Future<void> deleteToken() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from('user_push_tokens')
          .delete()
          .eq('user_id', userId)
          .eq('platform', Platform.isIOS ? 'ios' : 'android');

      await _fcm.deleteToken();
      debugPrint('🔔 FCM token deleted');
    } catch (e) {
      debugPrint('🔔 Failed to delete FCM token: $e');
    }
  }

  // Track current chat to avoid showing notifications for active chat
  String?  _currentChatId;

  /// Set the current chat ID (call when entering a chat).
  void setCurrentChat(String?  chatId) {
    _currentChatId = chatId;
  }

  /// Navigate to a specific chat.
  /// Implement this based on your navigation setup.
  void _navigateToChat(String chatId) {
    // You'll need to implement this based on your navigation
    // Option 1: Using a global navigator key
    // Option 2: Using a stream/callback
    // Option 3: Using a state management solution
    debugPrint('🔔 Navigate to chat: $chatId');
    
    // Example using a callback (set this from your app):
    if (onNavigateToChat != null) {
      onNavigateToChat!(chatId);
    }
  }

  /// Callback for navigation - set this from your app.
  Function(String chatId)? onNavigateToChat;
}