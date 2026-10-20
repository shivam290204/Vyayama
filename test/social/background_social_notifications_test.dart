import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitbuddy/core/services/background_sync_service.dart';
import 'package:fitbuddy/core/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Background Social Notifications Tests', () {
    test('NotificationService exposes socialNotificationChannelId', () {
      expect(
        NotificationService.socialNotificationChannelId,
        equals('vyayama_social_v1'),
      );
    });

    test('BackgroundSyncService manages current user ID synchronization',
        () async {
      final service = BackgroundSyncService.instance;

      await service.syncCurrentUserId('user-athlete-123');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('last_signed_in_user_id'), equals('user-athlete-123'));

      await service.clearUser();
      expect(prefs.getString('last_signed_in_user_id'), isNull);
    });

    test('BackgroundSyncService marks items as notified and bounds history',
        () async {
      final service = BackgroundSyncService.instance;

      await service.markAsNotified('req_101');
      await service.markAsNotified('snap_202');

      final prefs = await SharedPreferences.getInstance();
      var list = prefs.getStringList('notified_social_ids');
      expect(list, containsAll(['req_101', 'snap_202']));

      // Adding duplicate should not produce redundant entry
      await service.markAsNotified('req_101');
      list = prefs.getStringList('notified_social_ids');
      expect(list?.where((id) => id == 'req_101').length, equals(1));

      // Test bound to 200 items
      for (int i = 0; i < 250; i++) {
        await service.markAsNotified('item_$i');
      }
      list = prefs.getStringList('notified_social_ids');
      expect(list!.length, lessThanOrEqualTo(200));
      expect(list.contains('item_249'), isTrue);
    });

    test('showFriendRequestNotification and showSnapNotification execute cleanly',
        () async {
      final notif = NotificationService.instance;

      expect(
        () => notif.showFriendRequestNotification(
          senderName: 'Alex Runner',
          requestId: 'test-req-123',
        ),
        returnsNormally,
      );

      expect(
        () => notif.showSnapNotification(
          senderName: 'Sarah Fit',
          snapId: 'test-snap-456',
          activityType: 'Running',
        ),
        returnsNormally,
      );
    });

    test('scheduleOnAppClosed executes safely without throwing', () async {
      final service = BackgroundSyncService.instance;
      expect(() => service.scheduleOnAppClosed(), returnsNormally);
    });
  });
}
