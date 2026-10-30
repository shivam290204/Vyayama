import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitbuddy/core/services/notification_service.dart';
import 'package:fitbuddy/core/services/step_tracking_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Android Permissions & Policy Compliance Tests', () {
    late String manifestContent;

    setUpAll(() {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue,
          reason: 'AndroidManifest.xml must exist');
      manifestContent = manifestFile.readAsStringSync();
    });

    test('1. AndroidManifest.xml must NOT contain restricted/disallowed permissions', () {
      expect(manifestContent.contains('android.permission.USE_EXACT_ALARM'), isFalse,
          reason: 'USE_EXACT_ALARM must be removed to prevent Play Store rejection');
      expect(manifestContent.contains('android.permission.USE_FULL_SCREEN_INTENT'), isFalse,
          reason: 'USE_FULL_SCREEN_INTENT must be removed per Play Store policy');
      expect(manifestContent.contains('android.permission.READ_MEDIA_AUDIO'), isFalse,
          reason: 'READ_MEDIA_AUDIO must be removed because alarm sounds are bundled in raw resources');
      expect(manifestContent.contains('android.permission.READ_EXTERNAL_STORAGE'), isFalse,
          reason: 'READ_EXTERNAL_STORAGE must be removed as no local file storage is accessed');
      expect(manifestContent.contains('android.permission.READ_CONTACTS'), isFalse,
          reason: 'READ_CONTACTS must not be declared as friends use username search & QR codes');
      expect(manifestContent.contains('android.permission.GET_ACCOUNTS'), isFalse,
          reason: 'GET_ACCOUNTS must not be declared');
      expect(manifestContent.contains('android.permission.RECORD_AUDIO'), isFalse,
          reason: 'RECORD_AUDIO must not be declared as no voice recording features exist');
      expect(manifestContent.contains('android.permission.BLUETOOTH'), isFalse,
          reason: 'BLUETOOTH must not be declared as no nearby/BLE hardware is used');
    });

    test('2. AndroidManifest.xml must retain only compliant, necessary permissions', () {
      final expectedPermissions = [
        'android.permission.INTERNET',
        'android.permission.CAMERA',
        'android.permission.VIBRATE',
        'android.permission.POST_NOTIFICATIONS',
        'android.permission.RECEIVE_BOOT_COMPLETED',
        'android.permission.SCHEDULE_EXACT_ALARM',
        'android.permission.WAKE_LOCK',
        'android.permission.ACTIVITY_RECOGNITION',
        'android.permission.health.READ_STEPS',
        'android.permission.health.READ_ACTIVE_CALORIES_BURNED',
        'android.permission.MODIFY_AUDIO_SETTINGS',
        'android.permission.ACCESS_FINE_LOCATION',
        'android.permission.ACCESS_COARSE_LOCATION',
        'android.permission.FOREGROUND_SERVICE',
        'android.permission.FOREGROUND_SERVICE_LOCATION',
      ];

      for (final perm in expectedPermissions) {
        expect(manifestContent.contains(perm), isTrue,
            reason: 'Manifest should contain $perm');
      }

      final permissionMatches = RegExp(r'<uses-permission\s+android:name="([^"]+)"')
          .allMatches(manifestContent)
          .map((m) => m.group(1))
          .toList();

      expect(permissionMatches.length, equals(15),
          reason: 'Manifest should contain exactly 15 declared permissions including Maps location and foreground service');
    });

    test('3. Audio permissions return true immediately without runtime storage requests', () async {
      final isGranted = await NotificationService.instance.isAudioPermissionGranted();
      expect(isGranted, isTrue,
          reason: 'Bundled audio resources do not require runtime storage/audio permissions');

      final reqResult = await NotificationService.instance.requestAudioPermission();
      expect(reqResult, isTrue,
          reason: 'requestAudioPermission should immediately resolve to true');
    });

    test('4. StepTrackingService graceful fallback when ACTIVITY_RECOGNITION is denied', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StepTrackingService.instance;
      service.resetForTesting();

      // In fallback state (e.g. permission denied)
      service.hasPermission.value = false;
      service.isSensorActive.value = false;

      expect(service.hasPermission.value, isFalse);
      expect(service.isSensorActive.value, isFalse);

      // Manual step entry must work seamlessly without crashing
      await service.setManualSteps(4500);
      expect(service.todaySteps, equals(4500));
      expect(service.todayCalories, equals((4500 * 0.04).round()));
      expect(service.todayActiveMinutes, equals((4500 / 100).ceil()));

      // Subsequent manual adjustment must also work
      await service.setManualSteps(6000);
      expect(service.todaySteps, equals(6000));
      expect(service.isSensorActive.value, isFalse);

      // Adding manual steps increments total cleanly
      await service.addManualSteps(500);
      expect(service.todaySteps, equals(6500));
      expect(service.todayCalories, equals((6500 * 0.04).round()));
    });

    test('5. iOS Info.plist declares only valid, supported usage descriptions', () {
      final plistFile = File('ios/Runner/Info.plist');
      expect(plistFile.existsSync(), isTrue, reason: 'Info.plist must exist');
      final plistContent = plistFile.readAsStringSync();

      // Required descriptions
      expect(plistContent.contains('NSCameraUsageDescription'), isTrue);
      expect(plistContent.contains('NSPhotoLibraryUsageDescription'), isTrue);
      expect(plistContent.contains('NSMotionUsageDescription'), isTrue);
      expect(plistContent.contains('NSHealthShareUsageDescription'), isTrue);
      expect(plistContent.contains('NSHealthUpdateUsageDescription'), isTrue);
      expect(plistContent.contains('NSLocationWhenInUseUsageDescription'), isTrue);
      expect(plistContent.contains('NSLocationAlwaysAndWhenInUseUsageDescription'), isTrue);

      // Disallowed/unneeded descriptions
      expect(plistContent.contains('NSLocationAlwaysUsageDescription'), isFalse);
      expect(plistContent.contains('NSMicrophoneUsageDescription'), isFalse);
      expect(plistContent.contains('NSContactsUsageDescription'), isFalse);
      expect(plistContent.contains('NSBluetoothAlwaysUsageDescription'), isFalse);
    });

    test('6. NotificationService safe fallback modes on unsupported/test harness platforms', () async {
      final isAudioOk = await NotificationService.instance.isAudioPermissionGranted();
      expect(isAudioOk, isTrue);

      final batteryIgnored = await NotificationService.instance.isBatteryOptimizationIgnored();
      expect(batteryIgnored, isTrue);
    });
  });
}
