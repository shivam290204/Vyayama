import 'dart:async';
import 'dart:convert';

import 'package:fitbuddy/features/challenges/data/supabase_challenge_repository.dart';
import 'package:fitbuddy/features/workouts/data/supabase_workout_repository.dart';
import 'package:fitbuddy/features/workouts/data/workout_plan.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _HangingHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // Simulate a stalled network socket that never responds.
    return Completer<http.StreamedResponse>().future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testUserId = '65655917-62f5-4c33-b592-c8bc158e7ca5';

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'last_signed_in_user_id': testUserId,
    });
  });

  test('SupabaseWorkoutRepository falls back to bundled assets and cache on timeout',
      () async {
    final client = SupabaseClient(
      'https://dummy.supabase.co',
      'fake-anon-key',
      httpClient: _HangingHttpClient(),
    );
    final prefs = await SharedPreferences.getInstance();
    const cachedPlan = WorkoutPlan(
      id: 'local_cached_1',
      title: 'Cached Upper Body',
      goal: 'build_muscle',
      level: 'beginner',
      days: [],
      isSystem: false,
    );
    await prefs.setString(
      'cached_my_plans_$testUserId',
      jsonEncode([cachedPlan.toJson()]),
    );

    final repo = SupabaseWorkoutRepository(client: client);

    final results = await Future.wait([
      repo.getExercises(),
      repo.getSystemPlans(),
      repo.getMyPlans(),
    ]);

    final exercises = results[0] as List;
    final systemPlans = results[1] as List;
    final myPlans = results[2] as List<WorkoutPlan>;

    expect(exercises, isNotEmpty);
    expect(systemPlans, isNotEmpty);
    expect(myPlans.map((p) => p.id), contains('local_cached_1'));
  });

  test('SupabaseChallengeRepository falls back to bundled challenges on timeout',
      () async {
    final client = SupabaseClient(
      'https://dummy.supabase.co',
      'fake-anon-key',
      httpClient: _HangingHttpClient(),
    );
    final prefs = await SharedPreferences.getInstance();
    final repo = SupabaseChallengeRepository(client: client, prefs: prefs);

    final challenges = await repo.fetchChallenges();
    expect(challenges, isNotEmpty);
  });
}
