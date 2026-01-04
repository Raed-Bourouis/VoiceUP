import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service class for handling push notifications using Firebase Cloud Messaging.
/// 
/// This service provides:
/// - Firebase initialization and FCM token management
/// - Notification permission requests
/// - Foreground notification display using flutter_local_notifications
/// - Background notification handling
/// - Notification tap handling for navigation
/// - Current chat tracking to suppress notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Stream controller for notification tap events
  final StreamController<Map<String, dynamic>> _notificationTapController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of notification tap events for navigation
  Stream<Map<String, dynamic>> get onNotificationTap =>
      _notificationTapController.stream;

  /// Current chat ID to suppress notifications for active conversation
  String? _currentChatId;

  bool _isInitialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Request notification permissions
      await _requestPermissions();

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Listen for foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification taps when app is in background/terminated
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was opened from a notification
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen(_handleTokenRefresh);

      _isInitialized = true;
      debugPrint('NotificationService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
    }
  }

  /// Request notification permissions from the user
  Future<void> _requestPermissions() async {
    try {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('Notification permission status: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
  }

  /// Initialize flutter_local_notifications for foreground notifications
  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'chat_messages',
        'Chat Messages',
        description: 'Notifications for new chat messages',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  /// Handle foreground messages and display local notification
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Received foreground message: ${message.messageId}');

    final chatId = message.data['chat_id'] as String?;

    // Suppress notification if user is currently viewing this chat
    if (chatId != null && chatId == _currentChatId) {
      debugPrint('Suppressing notification for active chat: $chatId');
      return;
    }

    // Display local notification
    final notification = message.notification;
    if (notification != null) {
      await _showLocalNotification(
        title: notification.title ?? 'New Message',
        body: notification.body ?? '',
        payload: message.data,
      );
    }
  }

  /// Show a local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    required Map<String, dynamic> payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'chat_messages',
      'Chat Messages',
      channelDescription: 'Notifications for new chat messages',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      payload['message_id']?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title,
      body,
      details,
      payload: _encodePayload(payload),
    );
  }

  /// Handle notification tap when app is opened from background/terminated state
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.messageId}');
    final data = message.data;
    if (data.isNotEmpty) {
      _notificationTapController.add(data);
    }
  }

  /// Handle local notification tap
  void _onLocalNotificationTap(NotificationResponse response) {
    debugPrint('Local notification tapped: ${response.payload}');
    if (response.payload != null) {
      final data = _decodePayload(response.payload!);
      _notificationTapController.add(data);
    }
  }

  /// Encode payload to string for local notifications
  String _encodePayload(Map<String, dynamic> payload) {
    return payload.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
        .join('&');
  }

  /// Decode payload string from local notifications
  Map<String, dynamic> _decodePayload(String payload) {
    final parts = payload.split('&');
    final map = <String, dynamic>{};
    for (final part in parts) {
      final separatorIndex = part.indexOf('=');
      if (separatorIndex >= 0 && separatorIndex < part.length - 1) {
        final key = Uri.decodeComponent(part.substring(0, separatorIndex));
        final value = Uri.decodeComponent(part.substring(separatorIndex + 1));
        map[key] = value;
      }
    }
    return map;
  }

  /// Handle FCM token refresh
  Future<void> _handleTokenRefresh(String token) async {
    debugPrint('FCM token refreshed: $token');
    await _saveTokenToDatabase(token);
  }

  /// Save FCM token to Supabase after successful login
  Future<void> saveTokenAfterLogin() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _saveTokenToDatabase(token);
        debugPrint('FCM token saved after login: $token');
      }
    } catch (e) {
      debugPrint('Error saving token after login: $e');
    }
  }

  /// Save FCM token to database
  Future<void> _saveTokenToDatabase(String token) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('Cannot save token: user not authenticated');
        return;
      }

      final platform = _getPlatformString();

      // Upsert token (insert or update if exists)
      await _supabase.from('user_push_tokens').upsert(
        {
          'user_id': userId,
          'fcm_token': token,
          'platform': platform,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id,platform',
      );

      debugPrint('FCM token saved to database for user: $userId');
    } catch (e) {
      debugPrint('Error saving token to database: $e');
    }
  }

  /// Delete FCM token from database on logout
  Future<void> deleteTokenOnLogout() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('Cannot delete token: user not authenticated');
        return;
      }

      final platform = _getPlatformString();

      // Delete token for this device
      await _supabase
          .from('user_push_tokens')
          .delete()
          .eq('user_id', userId)
          .eq('platform', platform);

      debugPrint('FCM token deleted from database for user: $userId');
    } catch (e) {
      debugPrint('Error deleting token from database: $e');
    }
  }

  /// Set the current chat ID to suppress notifications
  void setCurrentChat(String chatId) {
    _currentChatId = chatId;
    debugPrint('Current chat set to: $chatId');
  }

  /// Clear the current chat ID
  void clearCurrentChat() {
    _currentChatId = null;
    debugPrint('Current chat cleared');
  }

  /// Dispose resources
  void dispose() {
    _notificationTapController.close();
  }

  /// Get current platform as string
  String _getPlatformString() {
    if (Platform.isAndroid) {
      return 'android';
    } else if (Platform.isIOS) {
      return 'ios';
    } else {
      return 'web';
    }
  }
}
