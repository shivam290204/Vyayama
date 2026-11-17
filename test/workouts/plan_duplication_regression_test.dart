import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fitbuddy/features/workouts/data/supabase_workout_repository.dart';
import 'package:fitbuddy/features/workouts/data/workout_plan.dart';

class TestHttpClient extends http.BaseClient {
  TestHttpClient(this.handler);
  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => handler(request);
}

http.StreamedResponse mockResponse(
  http.BaseRequest req,
  String body, {
  int statusCode = 200,
}) {
  final bytes = utf8.encode(body);
  return http.StreamedResponse(
    Stream.value(bytes),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
    contentLength: bytes.length,
    request: req,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  const testUserId = '65655917-62f5-4c33-b592-c8bc158e7ca5';
  const testPlanId = 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d';

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'last_signed_in_user_id': testUserId,
    });
    prefs = await SharedPreferences.getInstance();
  });

  group('Workout Plan Duplication Regression Tests', () {
    test('1. One save creates exactly one plan with stable UUID and mapped exercise ID', () async {
      int rpcCallCount = 0;
      Map<String, dynamic>? capturedPayload;

      final client = SupabaseClient(
        'https://dummy.supabase.co',
        'fake-anon-key',
        httpClient: TestHttpClient((req) async {
          if (req.url.path.contains('/rpc/save_workout_plan')) {
            rpcCallCount++;
            if (req is http.Request) {
              final body = jsonDecode(req.body) as Map<String, dynamic>;
              capturedPayload = body['p_plan'] as Map<String, dynamic>;
            }
            return mockResponse(req, jsonEncode({'status': 'saved', 'id': testPlanId}));
          }
          return mockResponse(req, '[]');
        }),
      );

      final repo = SupabaseWorkoutRepository(client: client);
      final draft = WorkoutPlan(
        id: testPlanId,
        title: 'My First Workout',
        goal: 'gain',
        level: 'beginner',
        days: [
          PlanDay(
            id: 'd1',
            dayNumber: 1,
            name: 'Workout 1',
            exercises: [
              PlanExercise(
                id: 'e1',
                exerciseId: 'ex_bodyweight_squat',
                sortOrder: 0,
                sets: 3,
                reps: 10,
              ),
            ],
          ),
        ],
      );

      final saved = await repo.savePlan(draft);

      expect(rpcCallCount, 1, reason: 'Exactly one RPC call must be made');
      expect(saved.id, testPlanId);
      expect(capturedPayload, isNotNull);
      expect(capturedPayload!['id'], testPlanId);
      expect(capturedPayload!['title'], 'My First Workout');

      // Verify exercise ID is mapped to valid UUID, never raw string
      final days = capturedPayload!['days'] as List;
      expect(days.length, 1);
      final exercises = days[0]['exercises'] as List;
      expect(exercises.length, 1);
      final exerciseId = exercises[0]['exercise_id'].toString();
      expect(
        RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
            .hasMatch(exerciseId),
        isTrue,
        reason: 'exercise_id must be mapped to a valid UUID',
      );
      expect(exerciseId, '5e48e150-9cee-54f0-a5d2-79d7ef5ae7dd');
    });

    test('2. Repeated saves and retries are idempotent and use the exact same plan ID', () async {
      int rpcCallCount = 0;
      final capturedIds = <String>[];

      final client = SupabaseClient(
        'https://dummy.supabase.co',
        'fake-anon-key',
        httpClient: TestHttpClient((req) async {
          if (req.url.path.contains('/rpc/save_workout_plan')) {
            rpcCallCount++;
            if (req is http.Request) {
              final body = jsonDecode(req.body) as Map<String, dynamic>;
              final p = body['p_plan'] as Map<String, dynamic>;
              capturedIds.add(p['id'].toString());
            }
            return mockResponse(req, jsonEncode({'status': 'saved'}));
          }
          return mockResponse(req, '[]');
        }),
      );

      final repo = SupabaseWorkoutRepository(client: client);
      final draft = WorkoutPlan.draft();
      final stableId = draft.id;

      // Save 1st time
      await repo.savePlan(draft.copyWith(title: 'Plan Run 1'));
      // Save 2nd time
      await repo.savePlan(draft.copyWith(title: 'Plan Run 2'));
      // Save 3rd time
      await repo.savePlan(draft.copyWith(title: 'Plan Run 3'));

      expect(rpcCallCount, 3);
      expect(capturedIds.length, 3);
      expect(capturedIds.every((id) => id == stableId), isTrue,
          reason: 'Every save attempt must target the identical plan UUID');
    });

    test('3. Repeated sync does not create duplicate plan IDs', () async {
      final syncedPlanIds = <String>[];
      int rpcAttempts = 0;

      final client = SupabaseClient(
        'https://dummy.supabase.co',
        'fake-anon-key',
        httpClient: TestHttpClient((req) async {
          if (req.url.path.contains('/rpc/save_workout_plan')) {
            rpcAttempts++;
            if (req is http.Request) {
              final body = jsonDecode(req.body) as Map<String, dynamic>;
              final p = body['p_plan'] as Map<String, dynamic>;
              syncedPlanIds.add(p['id'].toString());
            }
            if (rpcAttempts == 1) {
              // Simulate transient network/server timeout on 1st attempt
              return mockResponse(req, 'Transient error', statusCode: 500);
            }
            return mockResponse(req, jsonEncode({'status': 'saved'}));
          }
          if (req.url.path.contains('workout_plans')) {
            return mockResponse(req, '[]');
          }
          return mockResponse(req, '[]');
        }),
      );

      final repo = SupabaseWorkoutRepository(client: client);

      // Seed a pending offline plan
      const offlineLocalId = 'local_1793606481000';
      final offlinePlan = WorkoutPlan(
        id: offlineLocalId,
        title: 'Sync Beast',
        goal: 'gain',
        level: 'intermediate',
        days: const [],
      );

      await prefs.setString(
        'cached_my_plans_$testUserId',
        jsonEncode([offlinePlan.toJson()]),
      );
      await prefs.setStringList(
        'pending_sync_workout_plans_$testUserId',
        [offlineLocalId],
      );

      // Attempt 1: Trigger sync (fails with 500, preserves item in queue)
      await repo.getMyPlans();

      expect(syncedPlanIds.length, 1);
      final firstAssignedUuid = syncedPlanIds.first;
      expect(
        RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
            .hasMatch(firstAssignedUuid),
        isTrue,
      );

      // Verify item remains in pending sync queue for retry
      final queueAfterFail = prefs.getStringList('pending_sync_workout_plans_$testUserId');
      expect(queueAfterFail?.contains(offlineLocalId) ?? false, isTrue);

      // Wait for throttle duration
      await Future<void>.delayed(const Duration(milliseconds: 3200));

      // Attempt 2: Retry sync (succeeds with 200, uses the exact same UUID)
      await repo.getMyPlans();

      expect(syncedPlanIds.length, 2);
      expect(syncedPlanIds[0], syncedPlanIds[1],
          reason: 'Deterministic mapping must yield the identical UUID on retried syncs');

      // Verify queue is now cleared after success
      final queueAfterSuccess = prefs.getStringList('pending_sync_workout_plans_$testUserId');
      expect(queueAfterSuccess?.contains(offlineLocalId) ?? false, isFalse);
    });

    test('4. Failed writes do not corrupt pending queue and permanent errors are not retried indefinitely', () async {
      int failureCalls = 0;

      final client = SupabaseClient(
        'https://dummy.supabase.co',
        'fake-anon-key',
        httpClient: TestHttpClient((req) async {
          if (req.url.path.contains('/rpc/save_workout_plan')) {
            failureCalls++;
            // Return permanent Postgres 22P02 syntax error
            return mockResponse(
              req,
              jsonEncode({
                'code': '22P02',
                'message': 'invalid input syntax for type uuid',
              }),
              statusCode: 400,
            );
          }
          return mockResponse(req, '[]');
        }),
      );

      final repo = SupabaseWorkoutRepository(client: client);

      const badPlanId = 'local_corrupt_123';
      final corruptPlan = WorkoutPlan(
        id: badPlanId,
        title: 'Corrupted Plan',
        days: const [],
      );

      await prefs.setString(
        'cached_my_plans_$testUserId',
        jsonEncode([corruptPlan.toJson()]),
      );
      await prefs.setStringList(
        'pending_sync_workout_plans_$testUserId',
        [badPlanId],
      );

      // Trigger sync
      await repo.getMyPlans();

      expect(failureCalls, 1);
      // Permanent error 22P02 should cause item to be dropped immediately to prevent infinite loops
      final remainingQueue = prefs.getStringList('pending_sync_workout_plans_$testUserId');
      expect(remainingQueue?.contains(badPlanId) ?? false, isFalse,
          reason: 'Permanent error items must be removed from queue');
    });

    test('5. Plan days and exercises preserve bidirectional exercise ID mapping', () async {
      final client = SupabaseClient(
        'https://dummy.supabase.co',
        'fake-anon-key',
        httpClient: TestHttpClient((req) async {
          if (req.url.path.contains('workout_plans')) {
            // Return plan with nested exercise row containing catalog_id
            return mockResponse(
              req,
              jsonEncode([
                {
                  'id': testPlanId,
                  'title': 'Leg Day Hero',
                  'is_system': false,
                  'owner_id': testUserId,
                  'days': [
                    {
                      'id': 'd1',
                      'day_number': 1,
                      'name': 'Day 1',
                      'exercises': [
                        {
                          'id': 'pe1',
                          'exercise_id': '5e48e150-9cee-54f0-a5d2-79d7ef5ae7dd',
                          'sort_order': 0,
                          'sets': 3,
                          'reps': 10,
                          'exercise': {
                            'id': '5e48e150-9cee-54f0-a5d2-79d7ef5ae7dd',
                            'catalog_id': 'ex_bodyweight_squat',
                            'name': 'Bodyweight Squat',
                          },
                        },
                      ],
                    },
                  ],
                }
              ]),
            );
          }
          return mockResponse(req, '[]');
        }),
      );

      final repo = SupabaseWorkoutRepository(client: client);
      final plans = await repo.getMyPlans();

      expect(plans.length, 1);
      final plan = plans.first;
      expect(plan.days.length, 1);
      final ex = plan.days.first.exercises.first;
      // In Flutter client, exerciseId must be mapped back to catalog ID 'ex_bodyweight_squat'
      expect(ex.exerciseId, 'ex_bodyweight_squat',
          reason: 'Client-side plan exercise must preserve catalog ID for UI asset and video lookup');
    });

    test('6. Existing offline plans remain fully recoverable from cache', () async {
      final repo = SupabaseWorkoutRepository(client: null);

      const legacyOfflineId = 'local_99998888';
      final legacyPlan = WorkoutPlan(
        id: legacyOfflineId,
        title: 'Legacy Offline Plan',
        goal: 'lose',
        level: 'beginner',
        days: [
          PlanDay(
            id: 'legacy_d1',
            dayNumber: 2,
            name: 'Cardio Day',
            exercises: [
              PlanExercise(
                id: 'legacy_e1',
                exerciseId: 'ex_march_in_place',
                sortOrder: 0,
                durationSec: 45,
              ),
            ],
          ),
        ],
      );

      await repo.savePlan(legacyPlan);

      final plans = await repo.getMyPlans();
      expect(plans.length, 1);
      expect(plans.first.id, legacyOfflineId);
      expect(plans.first.title, 'Legacy Offline Plan');

      final fetched = await repo.getPlan(legacyOfflineId);
      expect(fetched, isNotNull);
      expect(fetched!.title, 'Legacy Offline Plan');
      expect(fetched.days.first.exercises.first.exerciseId, 'ex_march_in_place');
    });
  });
}
