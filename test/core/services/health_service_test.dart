import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitbuddy/core/services/health_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    HealthService.instance.resetForTesting();
  });

  tearDown(() {
    HealthService.instance.resetForTesting();
  });

  group('HealthService Permission State Regression Tests', () {
    test('1. All requested permissions granted: requestPermissions returns true', () async {
      HealthService.instance.isSupportedOverride = true;
      HealthService.instance.requestAuthorizationOverride = true;
      HealthService.instance.hasPermissionsOverride = true;

      final result = await HealthService.instance.requestPermissions();
      expect(result, isTrue);
    });

    test('2. Permission denied during prompt: requestPermissions returns false', () async {
      HealthService.instance.isSupportedOverride = true;
      HealthService.instance.requestAuthorizationOverride = false;
      HealthService.instance.hasPermissionsOverride = false;

      final result = await HealthService.instance.requestPermissions();
      expect(result, isFalse);
    });

    test('3. Permission verification returns false after requestAuthorization returns true: requestPermissions returns false', () async {
      HealthService.instance.isSupportedOverride = true;
      // The authorization prompt contract completed (true), but post-request actual permissions check is false
      HealthService.instance.requestAuthorizationOverride = true;
      HealthService.instance.hasPermissionsOverride = false;

      final result = await HealthService.instance.requestPermissions();
      expect(result, isFalse, reason: 'Must explicitly verify actual granted permissions and return false');
    });

    test('4. Permission verification throws an exception: caught safely and returns false', () async {
      HealthService.instance.isSupportedOverride = true;
      HealthService.instance.requestAuthorizationOverride = true;
      HealthService.instance.hasPermissionsError = Exception('Health Connect service disconnected');

      final result = await HealthService.instance.requestPermissions();
      expect(result, isFalse, reason: 'Must catch permission verification exceptions and return false without crashing');
    });

    test('4b. Permission verification throws uncaught exception: requestPermissions catches safely and returns false', () async {
      HealthService.instance.isSupportedOverride = true;
      HealthService.instance.requestAuthorizationOverride = true;
      HealthService.instance.hasPermissionsUncaughtError = Exception('IPC transport breakdown');

      final result = await HealthService.instance.requestPermissions();
      expect(result, isFalse, reason: 'Must catch uncaught permission verification exceptions and return false without crashing');
    });

    test('5. Do not treat saved local preference as proof of granted permissions when revoked', () async {
      SharedPreferences.setMockInitialValues({
        HealthService.kHealthSyncEnabledKey: true,
      });

      HealthService.instance.isSupportedOverride = true;
      HealthService.instance.hasPermissionsOverride = false; // Permissions revoked in system settings

      // Local preference in SharedPreferences is true
      final syncEnabled = await HealthService.instance.isSyncEnabled();
      expect(syncEnabled, isTrue);

      // But actual permissions must report false
      final hasPerm = await HealthService.instance.hasPermissions();
      expect(hasPerm, isFalse, reason: 'Saved local preference must never be treated as proof of granted permissions');
    });

    test('6. hasPermissions exception returns false rather than falling back to isSyncEnabled', () async {
      SharedPreferences.setMockInitialValues({
        HealthService.kHealthSyncEnabledKey: true,
      });

      HealthService.instance.isSupportedOverride = true;
      HealthService.instance.hasPermissionsError = Exception('MethodChannel missing');

      final hasPerm = await HealthService.instance.hasPermissions();
      expect(hasPerm, isFalse, reason: 'Exception during hasPermissions must return false, not isSyncEnabled()');
    });
  });
}
