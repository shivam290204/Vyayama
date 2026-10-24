import 'package:fitbuddy/core/services/step_tracking_service.dart';
import 'package:fitbuddy/features/dashboard/data/local_daily_stats_storage.dart';
import 'package:fitbuddy/features/health_profile/data/meal_reminder_settings.dart';
import 'package:fitbuddy/features/health_profile/data/medicine.dart';
import 'package:fitbuddy/features/health_profile/data/shared_prefs_health_repository.dart';
import 'package:fitbuddy/features/health_profile/data/supabase_health_repository.dart';
import 'package:fitbuddy/features/schedule/day_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offline / Online Matrix & Clock Shift Automated Verification', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      StepTrackingService.instance.resetForTesting();
    });

    test('1. [Step Tracking] 100% Offline Step Counting, Delta Calculation & Local Persistence', () async {
      final service = StepTrackingService.instance;
      final prefs = await SharedPreferences.getInstance();
      final t0 = DateTime(2026, 10, 24, 8, 0); // 8:00 AM

      // Establish initial baseline offline
      await service.processStepReading(10000, eventTime: t0, overridePrefs: prefs);
      expect(service.todaySteps, equals(0));

      // Walk 1,250 steps offline
      final t1 = t0.add(const Duration(minutes: 30));
      await service.processStepReading(11250, eventTime: t1, overridePrefs: prefs);
      expect(service.todaySteps, equals(1250));

      // Verify written to SharedPreferences offline cache without throwing
      final todayStr = dayKey(t0);
      expect(prefs.getInt('today_steps_$todayStr'), equals(1250));
      expect(prefs.getInt('global_last_hardware_steps'), equals(11250));

      // Verify LocalDailyStatsStorage contains the record
      final stats = await LocalDailyStatsStorage.instance.get(t0);
      expect(stats, isNotNull);
      expect(stats!.steps, equals(1250));
    });

    test('2. [Step Tracking] Phone Reboot Simulation (Hardware counter resets to 0)', () async {
      final service = StepTrackingService.instance;
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime(2026, 10, 24, 12, 0);

      // Pre-reboot: User had 3,000 steps (raw counter at 15,000)
      await service.processStepReading(12000, eventTime: now, overridePrefs: prefs);
      await service.processStepReading(15000, eventTime: now.add(const Duration(hours: 1)), overridePrefs: prefs);
      expect(service.todaySteps, equals(3000));

      // Phone reboots! Hardware counter resets to 0, then user walks 450 steps (raw = 450)
      final postRebootTime = now.add(const Duration(hours: 2));
      final stepsAfterReboot = await service.processStepReading(450, eventTime: postRebootTime, overridePrefs: prefs);

      // Total must be 3,000 + 450 = 3,450! No steps lost!
      expect(stepsAfterReboot, equals(3450));
      expect(service.todaySteps, equals(3450));
    });

    test('3. [Step Tracking] Midnight Rollover Simulation (23:59:50 -> 00:00:10)', () async {
      final service = StepTrackingService.instance;
      final prefs = await SharedPreferences.getInstance();

      final day1Time = DateTime(2026, 10, 24, 23, 59, 50);
      final day2Time = DateTime(2026, 10, 25, 0, 0, 10); // 20 seconds later, past midnight

      // Day 1: User has 8,000 steps with raw counter at 28,000
      await service.processStepReading(20000, eventTime: day1Time.subtract(const Duration(hours: 4)), overridePrefs: prefs);
      await service.processStepReading(28000, eventTime: day1Time, overridePrefs: prefs);
      expect(service.todaySteps, equals(8000));

      // User takes 25 steps across midnight (raw counter moves from 28,000 to 28,025)
      final nextDaySteps = await service.processStepReading(28025, eventTime: day2Time, overridePrefs: prefs);

      // Day 2 must start with overnight delta = 25 steps!
      expect(nextDaySteps, equals(25));
      expect(service.todaySteps, equals(25));

      // Yesterday's 8,000 steps must be archived in local storage
      final archivedYesterday = await LocalDailyStatsStorage.instance.get(day1Time);
      expect(archivedYesterday, isNotNull);
      expect(archivedYesterday!.steps, equals(8000));
    });

    test('4. [Health Profile] Medicines and Meals Offline Save, Edit and Load', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPrefsHealthRepository(prefs);

      // 1. Conditions
      await repo.saveSelectedConditionKeys(['knee_pain', 'lower_back']);
      final savedKeys = await repo.getSelectedConditionKeys();
      expect(savedKeys, containsAll(['knee_pain', 'lower_back']));

      // 2. Medicines
      final med = Medicine(
        id: 'med_test_1',
        name: 'Metformin',
        reminderTimes: const [TimeOfDay(hour: 8, minute: 30), TimeOfDay(hour: 20, minute: 0)],
        isActive: true,
      );
      await repo.saveMedicine(med);

      final medList = await repo.listMedicines();
      expect(medList.length, equals(1));
      expect(medList.first.name, equals('Metformin'));
      expect(medList.first.reminderTimes.length, equals(2));

      // Edit medicine
      final updatedMed = med.copyWith(name: 'Metformin 500mg');
      await repo.saveMedicine(updatedMed);
      final editedList = await repo.listMedicines();
      expect(editedList.first.name, equals('Metformin 500mg'));

      // Delete medicine
      await repo.deleteMedicine(med.id);
      final emptyList = await repo.listMedicines();
      expect(emptyList, isEmpty);

      // 3. Meals
      final customMeals = MealReminderSettings.defaults().withSlot(
        MealSlot.breakfast,
        const MealReminder(time: TimeOfDay(hour: 7, minute: 45), enabled: true),
      );
      await repo.saveMealReminders(customMeals);

      final loadedMeals = await repo.getMealReminders();
      expect(loadedMeals.of(MealSlot.breakfast).time.hour, equals(7));
      expect(loadedMeals.of(MealSlot.breakfast).time.minute, equals(45));
    });

    test('5. [Supabase Health Repo] Catches Network Failures Without Corrupting Local Cache', () async {
      final prefs = await SharedPreferences.getInstance();
      // Supabase not configured in test environment -> exercises graceful local fallback
      final repo = SupabaseHealthRepository(prefs: prefs);

      // Save conditions offline
      await repo.saveSelectedConditionKeys(['hypertension']);
      final keys = await repo.getSelectedConditionKeys();
      expect(keys, contains('hypertension'));

      // Save medicine offline
      final med = Medicine(
        id: 'med_offline',
        name: 'Aspirin',
        reminderTimes: const [TimeOfDay(hour: 9, minute: 0)],
        isActive: true,
      );
      final saved = await repo.saveMedicine(med);
      expect(saved.name, equals('Aspirin'));

      final list = await repo.listMedicines();
      expect(list.any((m) => m.name == 'Aspirin'), isTrue);
    });
  });
}
