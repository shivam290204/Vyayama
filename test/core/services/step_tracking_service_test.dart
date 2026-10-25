import 'package:fitbuddy/core/services/step_tracking_service.dart';
import 'package:fitbuddy/core/services/health_service.dart';
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
    HealthService.instance.resetForTesting();
  });

  group('Universal StepTrackingService Comprehensive Tests (17+ Scenarios)',
      () {
    test(
        '1. Initial sensor reading baseline establishment (device booted before today)',
        () async {
      final now = DateTime(2026, 10, 20, 10, 0);
      final todayStr = dayKey(now);
      final prefs = await SharedPreferences.getInstance();

      // Suppose user already logged 100 manual steps or had 100 steps
      await prefs.setInt('today_steps_$todayStr', 100);

      // Device booted 2 days ago (before today)
      final twoDaysAgoMs =
          now.subtract(const Duration(days: 2)).millisecondsSinceEpoch;

      // First hardware event from sensor: 50,000 steps cumulative since boot
      final steps = await service.processStepReading(
        50000,
        eventTime: now,
        overrideBootTimeMs: twoDaysAgoMs,
      );

      expect(steps, equals(100),
          reason:
              'Existing steps for today must be preserved on baseline establishment');
      expect(prefs.getInt('global_last_hardware_steps'), equals(50000));
      expect(prefs.getString('global_last_hardware_date'), equals(todayStr));
      expect(service.isSensorActive.value, isTrue);
    });

    test(
        '2. Initial sensor reading with device booted today recovers raw steps as today steps',
        () async {
      final now = DateTime(2026, 10, 20, 14, 0);
      final prefs = await SharedPreferences.getInstance();

      // Device booted at 8:00 AM today (6 hours ago)
      final bootTimeTodayMs =
          DateTime(2026, 10, 20, 8, 0).millisecondsSinceEpoch;

      // Raw sensor counter is 3,450 (all taken since boot today!)
      final steps = await service.processStepReading(
        3450,
        eventTime: now,
        overrideBootTimeMs: bootTimeTodayMs,
      );

      expect(steps, equals(3450),
          reason:
              'Steps taken since boot today must be recovered on first app launch');
      expect(service.todaySteps, equals(3450));
      final todayStr = dayKey(now);
      expect(prefs.getInt('today_steps_$todayStr'), equals(3450));
      expect(prefs.getInt('global_last_hardware_steps'), equals(3450));
    });

    test('3. Consecutive sensor readings accurately accumulate step deltas',
        () async {
      final now = DateTime(2026, 10, 20, 10, 5);
      final prefs = await SharedPreferences.getInstance();

      // First baseline reading
      await service.processStepReading(10000, eventTime: now);
      expect(service.todaySteps, equals(0));

      // User takes 15 steps
      await service.processStepReading(10015,
          eventTime: now.add(const Duration(minutes: 1)));
      expect(service.todaySteps, equals(15));

      // User takes 35 more steps
      await service.processStepReading(10050,
          eventTime: now.add(const Duration(minutes: 2)));
      expect(service.todaySteps, equals(50));

      // Check persistent cache
      final todayStr = dayKey(now);
      expect(prefs.getInt('today_steps_$todayStr'), equals(50));
    });

    test('4. Large step increases (e.g. 6,540 steps) are counted completely',
        () async {
      final now = DateTime(2026, 10, 20, 10, 0);
      final prefs = await SharedPreferences.getInstance();

      // Baseline reading at start of walk
      await service.processStepReading(20000, eventTime: now);
      expect(service.todaySteps, equals(0));

      // User walks 6,540 steps while walking outside
      await service.processStepReading(26540,
          eventTime: now.add(const Duration(hours: 1)));

      expect(service.todaySteps, equals(6540));
      expect(service.todayCalories, equals((6540 * 0.04).round())); // 262 kcal
      expect(service.todayActiveMinutes, equals((6540 / 100).ceil())); // 66 min

      final todayStr = dayKey(now);
      expect(prefs.getInt('today_steps_$todayStr'), equals(6540));
    });

    test('5. App minimized and reopened / resumed reconciles accumulated steps',
        () async {
      final now = DateTime(2026, 10, 20, 11, 0);

      // App baseline
      await service.processStepReading(30000, eventTime: now);
      expect(service.todaySteps, equals(0));

      // App is paused / minimized (user puts phone in pocket and walks 1,200 steps)
      await service.processStepReading(31200,
          eventTime: now.add(const Duration(minutes: 20)));

      expect(service.todaySteps, equals(1200));

      // Trigger lifecycle resumed state
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(service.todaySteps, equals(1200));
    });

    test('6. Screen locked during walking accumulates steps accurately',
        () async {
      final now = DateTime(2026, 10, 20, 14, 0);

      await service.processStepReading(5000, eventTime: now);

      // While screen is locked, hardware sensor counts from 5000 to 8250 (+3250 steps)
      await service.processStepReading(8250,
          eventTime: now.add(const Duration(minutes: 35)));

      expect(service.todaySteps, equals(3250));
    });

    test(
        '7. Phone reboot (sensor counter resets to 0) preserves earlier day total',
        () async {
      final now = DateTime(2026, 10, 20, 16, 0);
      final prefs = await SharedPreferences.getInstance();

      // Establish baseline at 40,000 steps
      await service.processStepReading(40000, eventTime: now);

      // Walk 3,000 steps before reboot
      await service.processStepReading(43000,
          eventTime: now.add(const Duration(minutes: 30)));
      expect(service.todaySteps, equals(3000));

      // Phone reboots! TYPE_STEP_COUNTER resets to 0 upon boot.
      // After reboot, user walks 250 steps (cumulative sensor reading is now 250)
      await service.processStepReading(250,
          eventTime: now.add(const Duration(hours: 1)));

      // Today's total should be 3,000 + 250 = 3,250 steps!
      expect(service.todaySteps, equals(3250));
      expect(prefs.getInt('global_last_hardware_steps'), equals(250));
    });

    test('8. Midnight rollover archives yesterday stats and starts fresh today',
        () async {
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
      final archivedYesterday =
          await LocalDailyStatsStorage.instance.get(yesterday);
      expect(archivedYesterday, isNotNull);
      expect(archivedYesterday!.steps, equals(8000));
      expect(archivedYesterday.calories, equals((8000 * 0.04).round()));
    });

    test(
        '9. Missing sensor data / unavailable hardware does not generate fake steps',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime(2026, 10, 20, 12, 0);
      final todayStr = dayKey(now);

      // User has 500 steps logged
      await prefs.setInt('today_steps_$todayStr', 500);

      // Refresh without hardware sensor
      await service.refresh(currentTime: now);

      // Step count must remain exactly what was locally stored, never fake/fabricated
      expect(service.todaySteps, equals(500));
      expect(service.todayCalories, equals(20)); // 500 * 0.04 = 20
      expect(service.todayActiveMinutes, equals(5)); // 500 / 100 = 5
    });

    test('10. Sensor stream errors update isSensorActive and don’t crash app',
        () async {
      service.isSensorActive.value = true;

      // Simulate a hardware error
      service.handlePedometerError('SENSOR_NOT_AVAILABLE');

      expect(service.isSensorActive.value, isFalse);
    });

    test('11. Duplicate events do not cause duplicate step counts', () async {
      final now = DateTime(2026, 10, 20, 12, 0);

      await service.processStepReading(10000, eventTime: now);
      await service.processStepReading(10200, eventTime: now);
      expect(service.todaySteps, equals(200));

      // Sensor emits same reading again (delta == 0)
      await service.processStepReading(10200, eventTime: now);
      await service.processStepReading(10200, eventTime: now);

      expect(service.todaySteps, equals(200),
          reason: 'Duplicate events must not increment steps');
    });

    test('12. Offline operation persists data entirely to local device storage',
        () async {
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

    test('13. Restoring daily totals after app restart recovers saved counts',
        () async {
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

    test(
        '14. Rapidly arriving events processed sequentially via FIFO queue without race conditions',
        () async {
      final now = DateTime(2026, 10, 20, 10, 0);

      // Baseline
      await service.queueStepCountForTesting(1000, eventTime: now);

      // Fire 5 rapid events in parallel (simulating hardware burst)
      final futures = [
        service.queueStepCountForTesting(1020,
            eventTime: now.add(const Duration(seconds: 1))),
        service.queueStepCountForTesting(1050,
            eventTime: now.add(const Duration(seconds: 2))),
        service.queueStepCountForTesting(1100,
            eventTime: now.add(const Duration(seconds: 3))),
        service.queueStepCountForTesting(1120,
            eventTime: now.add(const Duration(seconds: 4))),
        service.queueStepCountForTesting(1200,
            eventTime: now.add(const Duration(seconds: 5))),
      ];

      final results = await Future.wait(futures);

      // Last event in queue must resolve with cumulative delta: 1200 - 1000 = 200 steps
      expect(results.last, equals(200));
      expect(service.todaySteps, equals(200));
    });

    test('15. Out-of-order / delayed events discarded safely', () async {
      final now = DateTime(2026, 10, 20, 12, 0);

      await service.processStepReading(5000, eventTime: now);
      await service.processStepReading(5200,
          eventTime: now.add(const Duration(minutes: 5)));
      expect(service.todaySteps, equals(200));

      // Arrives with timestamp before the latest processed event
      await service.processStepReading(5100,
          eventTime: now.add(const Duration(minutes: 2)));

      // Step count unchanged
      expect(service.todaySteps, equals(200));
    });

    test(
        '16. Step detector pulses increment today steps when counter unavailable',
        () async {
      final now = DateTime(2026, 10, 20, 9, 0);

      // 3 detector pulses
      await service.queueDetectorPulseForTesting(eventTime: now);
      await service.queueDetectorPulseForTesting(
          eventTime: now.add(const Duration(seconds: 1)));
      await service.queueDetectorPulseForTesting(
          eventTime: now.add(const Duration(seconds: 2)));

      expect(service.todaySteps, equals(3));
      expect(service.isSensorActive.value, isTrue);
    });

    test('17. Anomalous/corrupt sensor spikes (>20,000 delta) ignored',
        () async {
      final now = DateTime(2026, 10, 20, 10, 0);

      await service.processStepReading(5000, eventTime: now);
      expect(service.todaySteps, equals(0));

      // Hardware glitch returns impossible jump of 100,000 steps in 1 minute
      await service.processStepReading(105000,
          eventTime: now.add(const Duration(minutes: 1)));

      // Glitch must be rejected
      expect(service.todaySteps, equals(0));

      // Legitimate next event of 50 steps accepted
      await service.processStepReading(5050,
          eventTime: now.add(const Duration(minutes: 2)));
      expect(service.todaySteps, equals(50));
    });

    test(
        '18. Reset today steps resets counter back to 0 while preserving hardware baseline',
        () async {
      final now = DateTime.now();

      await service.processStepReading(10000, eventTime: now);
      await service.processStepReading(10500, eventTime: now);
      expect(service.todaySteps, equals(500));

      // Reset
      await service.resetTodaySteps();
      expect(service.todaySteps, equals(0));

      // Next 20 steps
      await service.processStepReading(10520, eventTime: now);
      expect(service.todaySteps, equals(20));
    });

    test('health totals stay separate from phone steps and never add together',
        () async {
      final now = DateTime(2026, 10, 20, 10, 0);
      final prefs = await SharedPreferences.getInstance();
      HealthService.instance.isSupportedOverride = true;
      HealthService.instance.stepsTodayOverride = () async => 7000;
      HealthService.instance.activeCaloriesTodayOverride = () async => 350;

      expect(await service.syncWithHealthService(currentTime: now), isTrue);
      expect(service.todaySteps, 7000);
      expect(service.todayCalories, 350);

      await service.processStepReading(10000, eventTime: now);
      await service.processStepReading(
        11000,
        eventTime: now.add(const Duration(minutes: 10)),
      );

      expect(service.todaySteps, 7000);
      expect(prefs.getInt('today_device_steps_${dayKey(now)}'), 1000);
      expect(prefs.getInt('today_steps_${dayKey(now)}'), 7000);

      HealthService.instance.stepsTodayOverride = () async => 8000;
      expect(await service.syncWithHealthService(currentTime: now), isTrue);
      expect(service.todaySteps, 8000);
      expect(prefs.getInt('today_device_steps_${dayKey(now)}'), 1000);
      expect(prefs.getInt('today_steps_${dayKey(now)}'), 8000);

      await service.processDetectorPulse(
        eventTime: now.add(const Duration(days: 1)),
      );
      expect(service.todaySteps, 1);

      service.resetForTesting();
      final restored = await service.refresh(currentTime: now);
      expect(restored.steps, 8000);
      expect(restored.calories, 350);
    });

    test('refresh does not read health data when sync is disabled', () async {
      var healthReads = 0;
      HealthService.instance.isSupportedOverride = true;
      HealthService.instance.stepsTodayOverride = () async {
        healthReads++;
        return 5000;
      };
      HealthService.instance.activeCaloriesTodayOverride = () async => null;

      await service.refresh(currentTime: DateTime(2026, 10, 20));

      expect(healthReads, 0);
      expect(service.todaySteps, 0);
    });
  });
}
