import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fitbuddy/core/constants/env.dart';
import 'package:fitbuddy/core/services/notification_service.dart';

/// Top-level background message handler for FCM.
/// Must be annotated with [pragma] to be discoverable by Flutter runtime.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message received: ${message.messageId} (data: ${message.data})');
}

/// Service managing Firebase Cloud Messaging (FCM) registration, device token sync with
/// Supabase `device_tokens`, and incoming notification dispatch.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  @visibleForTesting
  bool isFirebaseAvailable = true;

  String? _currentToken;
  String? get currentToken => _currentToken;

  String? _currentUserId;
  String? get currentUserId => _currentUserId;

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _messageOpenedSub;

  /// Initializes Firebase and FCM handlers.
  /// Gracefully degrades if running in tests, unsupported platforms, or if credentials are not configured.
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      debugPrint('PushNotificationService: FCM push notifications only supported on Android & iOS.');
      return;
    }

    if (!isFirebaseAvailable) return;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await requestPermission();

      _currentToken = await FirebaseMessaging.instance.getToken();
      if (_currentToken != null && _currentUserId != null) {
        await _syncTokenToSupabase(_currentToken!, _currentUserId!);
      }

      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        _currentToken = newToken;
        if (_currentUserId != null) {
          await _syncTokenToSupabase(newToken, _currentUserId!);
        }
      });

      _foregroundSub?.cancel();
      _foregroundSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        handleForegroundMessage(message);
      });

      _messageOpenedSub?.cancel();
      _messageOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        handleNotificationTap(message);
      });

      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        handleNotificationTap(initialMessage);
      }

      _isInitialized = true;
      debugPrint('PushNotificationService initialized successfully with FCM token: $_currentToken');
    } catch (e) {
      debugPrint('PushNotificationService initialization note (graceful fallback): $e');
    }
  }

  /// Requests notification permission from the operating system (e.g. Android 13+).
  Future<bool> requestPermission() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint('PushNotificationService permission request note: $e');
      return false;
    }
  }

  /// Synchronizes current user ID and updates the token mapping in Supabase.
  Future<void> syncCurrentUserId(String userId) async {
    _currentUserId = userId;
    if (_currentToken != null && userId.isNotEmpty && userId != 'u-me') {
      await _syncTokenToSupabase(_currentToken!, userId);
    }
  }

  /// Saves or refreshes the FCM device token in Supabase `device_tokens` table.
  Future<void> _syncTokenToSupabase(String token, String userId) async {
    if (!Env.isSupabaseConfigured) return;

    try {
      final client = Supabase.instance.client;
      final platform = Platform.isIOS ? 'ios' : 'android';

      await client.from('device_tokens').upsert(
        {
          'user_id': userId,
          'token': token,
          'platform': platform,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id,token',
      );
      debugPrint('Device FCM token synchronized with Supabase for user $userId');
    } catch (e) {
      debugPrint('Failed to sync device token to Supabase: $e');
    }
  }

  /// Unregisters the current device token from Supabase upon logout.
  Future<void> unregisterDeviceToken() async {
    if (!Env.isSupabaseConfigured || _currentToken == null) return;

    try {
      await Supabase.instance.client
          .from('device_tokens')
          .delete()
          .eq('token', _currentToken!);
      debugPrint('Device FCM token successfully deleted from Supabase.');
    } catch (e) {
      debugPrint('Failed to unregister device token: $e');
    }
  }

  /// Handles incoming FCM notification while the application is in the foreground.
  void handleForegroundMessage(RemoteMessage message) {
    debugPrint('FCM foreground message received: ${message.messageId}');

    final data = message.data;
    final type = data['type'] as String?;
    final title = message.notification?.title ?? 'Vyayama Notification';
    final body = message.notification?.body ?? '';

    if (type == 'friend_request') {
      final senderName = data['from_name'] ?? data['sender_name'] ?? 'A friend';
      final requestId = data['request_id'] ?? data['id'] ?? 'req_${DateTime.now().millisecondsSinceEpoch}';
      NotificationService.instance.showFriendRequestNotification(
        senderName: senderName,
        requestId: requestId,
      );
    } else if (type == 'snap') {
      final senderName = data['from_name'] ?? data['sender_name'] ?? 'A friend';
      final snapId = data['snap_id'] ?? data['id'] ?? 'snap_${DateTime.now().millisecondsSinceEpoch}';
      final activity = data['activity_type'] ?? data['activity'];
      NotificationService.instance.showSnapNotification(
        senderName: senderName,
        snapId: snapId,
        activityType: activity,
      );
    } else if (type == 'streak_at_risk' ||
        type == 'streak_completed' ||
        type == 'streak_milestone' ||
        type == 'your_turn') {
      NotificationService.instance.showStreakNotification(
        title: title,
        body: body,
        data: data,
      );
    } else {
      // General social notification fallback
      NotificationService.instance.showStreakNotification(
        title: title,
        body: body,
        data: data,
      );
    }
  }

  /// Dispatches tapped push notification payload to the application router stream.
  void handleNotificationTap(RemoteMessage message) {
    debugPrint('Push notification tapped: ${message.messageId} (data: ${message.data})');
    final payload = jsonEncode(message.data);
    NotificationService.instance.onNotificationResponse.add(
      NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: payload,
      ),
    );
  }

  @visibleForTesting
  void setTokenForTesting(String? token) {
    _currentToken = token;
  }

  @visibleForTesting
  void resetForTesting() {
    _isInitialized = false;
    _currentToken = null;
    _currentUserId = null;
    isFirebaseAvailable = true;
    _tokenRefreshSub?.cancel();
    _foregroundSub?.cancel();
    _messageOpenedSub?.cancel();
  }
}
