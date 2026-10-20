import 'package:fitbuddy/core/services/step_tracking_service.dart';
import 'package:fitbuddy/features/dashboard/data/daily_stats.dart';
import 'package:fitbuddy/features/dashboard/data/local_daily_stats_storage.dart';
import 'package:fitbuddy/features/schedule/day_key.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StepTrackingService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = StepTrackingService.instance;
    service.resetForTesting();
  });

  group('Offline StepTrackingService Comprehensive Tests', () {
    test('1. Initial sensor reading sets hardware baseline without wiping existing steps', () async {
      final now = DateTime(2026, 10, 20, 10, 0);
      final todayStr = dayKey(now);
      final prefs = await SharedPreferences.getInstance();

      // Suppose user already logged 100 manual steps or had 100 steps
      await prefs.setInt('today_steps_$todayStr', 100);

      // First hardware event from sensor: 50,000 steps cumulative since boot
      final steps = await service.processStepReading(50000, eventTime: now);

      expect(steps, equals(100), reason: 'Existing steps for today must be preserved on baseline establishment');
      expect(prefs.getInt('global_last_hardware_steps'), equals(50000));
      expect(prefs.getString('global_last_hardware_date'), equals(todayStr));
      expect(service.isSensorActive.value, isTrue);
    });

    test('2. Consecutive sensor readings accurately accumulate step deltas', () async {
      final now = DateTime(2026, 10, 20, 10, 5);
      final prefs = await SharedPreferences.getInstance();

      // First baseline reading
      await service.processStepReading(10000, eventTime: now);
      expect(service.todaySteps, equals(0));

      // User takes 15 steps
      await service.processStepReading(10015, eventTime: now.add(const Duration(minutes: 1)));
      expect(service.todaySteps, equals(15));

      // User takes 35 more steps
      await service.processStepReading(10050, eventTime: now.add(const Duration(minutes: 2)));
      expect(service.todaySteps, equals(50));

      // Check persistent cache
      final todayStr = dayKey(now);
      expect(prefs.getInt('today_steps_$todayStr'), equals(50));
    });

    test('3. Large step increases (e.g. 6,540 steps) are counted completely', () async {
      final now = DateTime(2026, 10, 20, 10, 0);
      final prefs = await SharedPreferences.getInstance();

      // Baseline reading at start of walk
      await service.processStepReading(20000, eventTime: now);
      expect(service.todaySteps, equals(0));

      // User walks 6,540 steps while walking outside
      await service.processStepReading(26540, eventTime: now.add(const Duration(hours: 1)));

      expect(service.todaySteps, equals(6540));
      expect(service.todayCalories, equals((6540 * 0.04).round())); // 262 kcal
      expect(service.todayActiveMinutes, equals((6540 / 100).ceil())); // 66 min

      final todayStr = dayKey(now);
      expect(prefs.getInt('today_steps_$todayStr'), equals(6540));
    });

    test('4. App minimized and reopened / resumed reconciles accumulated steps', () async {
      final now = DateTime(2026, 10, 20, 11, 0);

      // App baseline
      await service.processStepReading(30000, eventTime: now);
      expect(service.todaySteps, equals(0));

      // App is paused / minimized (user puts phone in pocket and walks 1,200 steps)
      // Hardware sensor accumulates steps in Android OS
      // When app is reopened, sensor event fires with latest cumulative total
      await service.processStepReading(31200, eventTime: now.add(const Duration(minutes: 20)));

      expect(service.todaySteps, equals(1200));

      // Trigger lifecycle resumed state
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(service.todaySteps, equals(1200));
    });

    test('5. Screen locked during walking accumulates steps accurately', () async {
      final now = DateTime(2026, 10, 20, 14, 0);

      await service.processStepReading(5000, eventTime: now);

      // While screen is locked, hardware sensor counts from 5000 to 8250 (+3250 steps)
      await service.processStepReading(8250, eventTime: now.add(const Duration(minutes: 35)));

      expect(service.todaySteps, equals(3250));
    });

    test('6. Phone reboot (sensor counter resets to 0) preserves earlier day total', () async {
      final now = DateTime(2026, 10, 20, 16, 0);
      final prefs = await SharedPreferences.getInstance();

      // Establish baseline at 40,000 steps
      await service.processStepReading(40000, eventTime: now);

      // Walk 3,000 steps before reboot
      await service.processStepReading(43000, eventTime: now.add(const Duration(minutes: 30)));
      expect(service.todaySteps, equals(3000));

      // Phone reboots! TYPE_STEP_COUNTER resets to 0 upon boot.
      // After reboot, user walks 250 steps (cumulative sensor reading is now 250)
      await service.processStepReading(250, eventTime: now.add(const Duration(hours: 1)));

      // Today's total should be 3,000 + 250 = 3,250 steps!
      expect(service.todaySteps, equals(3250));
      expect(prefs.getInt('global_last_hardware_steps'), equals(250));
    });

    test('7. Midnight rollover archives yesterday stats and starts fresh today', () async {
      final yesterday = DateTime(2026, 10, 20, 23, 50);
      final today = DateTime(2026, 10, 21, 0, 10);
      final yesterdayStr = dayKey(yesterday);
      final todayStr = dayKey(today);
      final prefs = await SharedPreferences.getInstance();

      // User walked 8,000 steps on Oct 20
      await service.processStepReading(50000, eventTime: yesterday);
      await service.processStepReading(58000, eventTime: yesterday);
      expect(service.todaySteps, equals(8000));
      expect(prefs.getInt('today_steps_$yesterdayStr'), equals(8000));

      // Midnight rollover event on Oct 21: user took 50 steps after midnight (sensor raw = 58050)
      await service.processStepReading(58050, eventTime: today);

      // Today's steps should start fresh with only the 50 overnight steps
      expect(service.todaySteps, equals(50));
      expect(prefs.getInt('today_steps_$todayStr'), equals(50));

      // Check that yesterday was archived into LocalDailyStatsStorage
      final archivedYesterday = await LocalDailyStatsStorage.instance.get(yesterday);
      expect(archivedYesterday, isNotNull);
      expect(archivedYesterday!.steps, equals(8000));
      expect(archivedYesterday.calories, equals((8000 * 0.04).round()));
    });

    test('8. Missing sensor data / unavailable hardware does not generate fake steps', () async {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime(2026, 10, 20, 12, 0);
      final todayStr = dayKey(now);

      // User has 500 steps logged
      await prefs.setInt('today_steps_$todayStr', 500);

      // Refresh without hardware sensor
      await service.refresh();

      // Step count must remain exactly what was locally stored, never fake/fabricated
      expect(service.todaySteps, equals(500));
      expect(service.todayCalories, equals(20)); // 500 * 0.04 = 20
      expect(service.todayActiveMinutes, equals(5)); // 500 / 100 = 5
    });

    test('9. Sensor stream errors update isSensorActive and don’t crash app', () async {
      service.isSensorActive.value = true;

      // Simulate a hardware error
      service.handlePedometerError('SENSOR_NOT_AVAILABLE');

      expect(service.isSensorActive.value, isFalse);
    });

    test('10. Duplicate events do not cause duplicate step counts', () async {
      final now = DateTime(2026, 10, 20, 12, 0);

      await service.processStepReading(10000, eventTime: now);
      await service.processStepReading(10200, eventTime: now);
      expect(service.todaySteps, equals(200));

      // Sensor emits same reading again (delta == 0)
      await service.processStepReading(10200, eventTime: now);
      await service.processStepReading(10200, eventTime: now);

      expect(service.todaySteps, equals(200), reason: 'Duplicate events must not increment steps');
    });

    test('11. Offline operation persists data entirely to local device storage', () async {
      final now = DateTime(2026, 10, 20, 15, 0);
      final todayStr = dayKey(now);

      await service.processStepReading(1000, eventTime: now);
      await service.processStepReading(2500, eventTime: now); // +1500 steps

      // Verify stored locally without network
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('today_steps_$todayStr'), equals(1500));

      final localStats = await LocalDailyStatsStorage.instance.get(now);
      expect(localStats, isNotNull);
      expect(localStats!.steps, equals(1500));
    });

    test('12. Restoring daily totals after app restart recovers saved counts', () async {
      final now = DateTime.now();
      final todayStr = dayKey(now);
      final prefs = await SharedPreferences.getInstance();

      // Simulate app was killed earlier today with 4,200 steps recorded
      await prefs.setInt('today_steps_$todayStr', 4200);
      await prefs.setInt('global_last_hardware_steps', 18000);
      await prefs.setString('global_last_hardware_date', todayStr);

      // Re-initialize / start new service instance
      await service.refresh();

      expect(service.todaySteps, equals(4200));
      expect(service.todayCalories, equals((4200 * 0.04).round()));
      expect(service.todayActiveMinutes, equals((4200 / 100).ceil()));

      // Next sensor event adds +300 steps
      await service.processStepReading(18300, eventTime: now);
      expect(service.todaySteps, equals(4500));
    });
  });
}
