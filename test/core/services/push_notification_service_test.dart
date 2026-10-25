import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitbuddy/core/services/notification_service.dart';
import 'package:fitbuddy/core/services/push_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PushNotificationService.instance.resetForTesting();
  });

  tearDown(() {
    PushNotificationService.instance.resetForTesting();
  });

  group('PushNotificationService Tests', () {
    test('1. Singleton instance is persistent and defaults to uninitialized', () {
      final service = PushNotificationService.instance;
      expect(service, isNotNull);
      expect(service.isInitialized, isFalse);
      expect(service.currentToken, isNull);
    });

    test('2. syncCurrentUserId retains the user identifier', () async {
      final service = PushNotificationService.instance;
      await service.syncCurrentUserId('usr_12345');
      expect(service.currentUserId, equals('usr_12345'));
    });

    test('3. handleForegroundMessage dispatches friend_request payload', () {
      final service = PushNotificationService.instance;
      const message = RemoteMessage(
        messageId: 'msg_fr_01',
        data: {
          'type': 'friend_request',
          'from_name': 'Shivam',
          'request_id': 'req_999',
        },
        notification: RemoteNotification(
          title: 'Friend Request',
          body: 'Shivam sent you a friend request!',
        ),
      );

      // Should execute without errors
      expect(() => service.handleForegroundMessage(message), returnsNormally);
    });

    test('4. handleForegroundMessage dispatches snap payload', () {
      final service = PushNotificationService.instance;
      const message = RemoteMessage(
        messageId: 'msg_snap_01',
        data: {
          'type': 'snap',
          'from_name': 'Athlete',
          'snap_id': 'snap_555',
          'activity_type': 'workout',
        },
        notification: RemoteNotification(
          title: 'New Snap',
          body: 'Athlete sent you a snap (workout)!',
        ),
      );

      expect(() => service.handleForegroundMessage(message), returnsNormally);
    });

    test('5. handleForegroundMessage dispatches streak_at_risk payload', () {
      final service = PushNotificationService.instance;
      const message = RemoteMessage(
        messageId: 'msg_streak_01',
        data: {
          'type': 'streak_at_risk',
          'current': '7',
        },
        notification: RemoteNotification(
          title: 'Your streak is at risk ⏳',
          body: 'Send a snap to keep your 7-day streak.',
        ),
      );

      expect(() => service.handleForegroundMessage(message), returnsNormally);
    });

    test('6. handleNotificationTap broadcasts payload to onNotificationResponse stream', () async {
      final service = PushNotificationService.instance;
      const message = RemoteMessage(
        messageId: 'msg_tap_01',
        data: {
          'type': 'friend_request',
          'request_id': 'req_456',
        },
      );

      final expectation = expectLater(
        NotificationService.instance.onNotificationResponse.stream,
        emits(isA<NotificationResponse>().having(
          (r) => r.payload,
          'payload',
          contains('friend_request'),
        )),
      );

      service.handleNotificationTap(message);
      await expectation;
    });

    test('7. unregisterDeviceToken executes safely when no user is signed in', () async {
      final service = PushNotificationService.instance;
      service.setTokenForTesting('dummy_fcm_token_xyz');

      await expectLater(service.unregisterDeviceToken(), completes);
    });
  });
}
