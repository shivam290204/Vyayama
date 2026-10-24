import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitbuddy/features/workouts/data/supabase_workout_log_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  const testUserId = 'test_user_workout_log_999';

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'last_signed_in_user_id': testUserId,
    });
    prefs = await SharedPreferences.getInstance();
  });

  group('Fix 3: Offline Workout Log Persistence & Outbox Sync Tests', () {
    test('logWorkout persists completed logs locally to disk when offline', () async {
      final repo = SupabaseWorkoutLogRepository(client: null, prefs: prefs);
      final workoutTime = DateTime(2026, 10, 24, 15, 30);

      final log = await repo.logWorkout(
        planDayId: 'day_upper_body',
        durationMin: 45,
        caloriesBurned: 320,
        completedAt: workoutTime,
      );

      expect(log.id.startsWith('local_'), isTrue,
          reason: 'Offline log must have a local ID prefix');
      expect(log.durationMin, 45);
      expect(log.caloriesBurned, 320);
      expect(log.planDayId, 'day_upper_body');

      // Verify written to SharedPreferences cached logs
      final cachedRaw = prefs.getString('cached_workout_logs_$testUserId');
      expect(cachedRaw, isNotNull,
          reason: 'Workout logs must be written to disk cache');
      final cachedList = jsonDecode(cachedRaw!) as List;
      expect(cachedList.length, 1);
      expect(cachedList.first['duration_min'], 45);
      expect(cachedList.first['calories_burned'], 320);

      // Verify queued in outbox for cloud sync
      final pendingQueue = prefs.getStringList('pending_sync_workout_logs_$testUserId');
      expect(pendingQueue, isNotNull,
          reason: 'Offline workout must be added to sync outbox queue');
      expect(pendingQueue!.length, 1);
    });

    test('getLogs survives app restart by reading persisted logs from disk', () async {
      // First app session: log a workout
      final repo1 = SupabaseWorkoutLogRepository(client: null, prefs: prefs);
      final t1 = DateTime(2026, 10, 23, 10, 0);
      await repo1.logWorkout(
        planDayId: 'leg_day',
        durationMin: 50,
        caloriesBurned: 400,
        completedAt: t1,
      );

      // Simulate app kill & restart: create a new repository instance pointing to the same disk
      final repo2 = SupabaseWorkoutLogRepository(client: null, prefs: prefs);
      final logs = await repo2.getLogs();

      expect(logs.length, 1,
          reason: 'Completed workout logs must NOT be lost on app restart');
      expect(logs.first.planDayId, 'leg_day');
      expect(logs.first.durationMin, 50);
      expect(logs.first.caloriesBurned, 400);
    });

    test('hasWorkoutOn detects workouts completed offline', () async {
      final repo = SupabaseWorkoutLogRepository(client: null, prefs: prefs);
      final workoutDay = DateTime(2026, 10, 24);
      final otherDay = DateTime(2026, 10, 20);

      await repo.logWorkout(
        planDayId: 'core_blast',
        durationMin: 20,
        caloriesBurned: 150,
        completedAt: DateTime(2026, 10, 24, 18, 0),
      );

      final hasToday = await repo.hasWorkoutOn(workoutDay);
      final hasOther = await repo.hasWorkoutOn(otherDay);

      expect(hasToday, isTrue,
          reason: 'hasWorkoutOn must return true for locally completed workouts');
      expect(hasOther, isFalse,
          reason: 'hasWorkoutOn must return false for days with no workouts');
    });
  });
}
