import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitbuddy/features/workouts/data/supabase_workout_repository.dart';
import 'package:fitbuddy/features/workouts/data/workout_plan.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late SupabaseWorkoutRepository repo;
  const testUserId = 'test_user_offline_123';

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'last_signed_in_user_id': testUserId,
    });
    prefs = await SharedPreferences.getInstance();
    repo = SupabaseWorkoutRepository(client: null);
  });

  group('Fix 2: Plan Builder Offline Capability & Local Cache Sync Tests', () {
    test('savePlan creates and caches custom plan locally when offline', () async {
      final draft = WorkoutPlan(
        id: 'draft_123456789',
        title: 'My Offline Beast Mode',
        goal: 'gain',
        level: 'intermediate',
        days: [
          PlanDay(
            id: 'draft_d1',
            dayNumber: 1,
            name: 'Chest & Triceps',
            exercises: [
              PlanExercise(
                id: 'draft_e1',
                exerciseId: 'push_up',
                sortOrder: 0,
                sets: 4,
                reps: 12,
                restSec: 60,
              ),
            ],
          ),
        ],
      );

      final savedPlan = await repo.savePlan(draft);

      expect(savedPlan.id.startsWith('local_'), isTrue,
          reason: 'Offline saved plan must have local persistent ID');
      expect(savedPlan.title, 'My Offline Beast Mode');
      expect(savedPlan.days.length, 1);
      expect(savedPlan.days.first.exercises.length, 1);
      expect(savedPlan.days.first.exercises.first.exerciseId, 'push_up');

      // Verify cached in SharedPreferences
      final cachedRaw = prefs.getString('cached_my_plans_$testUserId');
      expect(cachedRaw, isNotNull);
      final cachedList = jsonDecode(cachedRaw!) as List;
      expect(cachedList.length, 1);
      expect(cachedList.first['title'], 'My Offline Beast Mode');

      // Verify enqueued into pending sync queue
      final pendingQueue = prefs.getStringList('pending_sync_workout_plans_$testUserId');
      expect(pendingQueue, isNotNull);
      expect(pendingQueue!.contains(savedPlan.id), isTrue,
          reason: 'Offline plan must be enqueued for background sync');
    });

    test('getMyPlans retrieves offline cached plans when client is offline', () async {
      final plan = WorkoutPlan(
        id: 'local_99999',
        title: 'Morning Mobility',
        goal: 'maintain',
        level: 'beginner',
        days: const [],
      );
      await repo.savePlan(plan);

      final plans = await repo.getMyPlans();

      expect(plans.length, 1);
      expect(plans.first.title, 'Morning Mobility');
      expect(plans.first.id, 'local_99999');
    });

    test('getPlan retrieves offline plan by id', () async {
      final plan = WorkoutPlan(
        id: 'local_88888',
        title: 'Leg Day Blast',
        goal: 'strength',
        level: 'advanced',
        days: const [],
      );
      await repo.savePlan(plan);

      final fetched = await repo.getPlan('local_88888');
      expect(fetched, isNotNull);
      expect(fetched!.title, 'Leg Day Blast');
    });

    test('deletePlan removes plan from local cache and sync queue', () async {
      final plan = WorkoutPlan(
        id: 'local_77777',
        title: 'To Be Deleted',
        days: const [],
      );
      await repo.savePlan(plan);

      var queue = prefs.getStringList('pending_sync_workout_plans_$testUserId');
      expect(queue?.contains('local_77777'), isTrue);

      await repo.deletePlan('local_77777');

      final cachedList = await repo.getMyPlans();
      expect(cachedList.any((p) => p.id == 'local_77777'), isFalse);

      queue = prefs.getStringList('pending_sync_workout_plans_$testUserId');
      expect(queue?.contains('local_77777') ?? false, isFalse,
          reason: 'Deleted plan must be removed from sync queue');
    });
  });
}
