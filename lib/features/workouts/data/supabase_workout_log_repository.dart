import 'package:fitbuddy/features/workouts/data/workout_log.dart';
import 'package:fitbuddy/features/workouts/data/workout_log_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase implementation of [WorkoutLogRepository] backed by `workout_logs`.
class SupabaseWorkoutLogRepository implements WorkoutLogRepository {
  SupabaseWorkoutLogRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('User not signed in');
    return user.id;
  }

  @override
  Future<WorkoutLog> logWorkout({
    required String planDayId,
    required int durationMin,
    required int caloriesBurned,
    DateTime? completedAt,
  }) async {
    final time = (completedAt ?? DateTime.now()).toUtc();
    final res = await _client.from('workout_logs').insert({
      'user_id': _userId,
      'plan_day_id': planDayId.isEmpty ? null : planDayId,
      'completed_at': time.toIso8601String(),
      'duration_min': durationMin,
      'calories_burned': caloriesBurned,
    }).select().single();

    return WorkoutLog.fromJson(Map<String, dynamic>.from(res));
  }

  @override
  Future<List<WorkoutLog>> getLogs({DateTime? since}) async {
    try {
      var query = _client.from('workout_logs').select().eq('user_id', _userId);
      if (since != null) {
        query = query.gte('completed_at', since.toUtc().toIso8601String());
      }
      final res = await query.order('completed_at', ascending: false);
      return (res as List)
          .map((row) => WorkoutLog.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<bool> hasWorkoutOn(DateTime day) async {
    try {
      final start = DateTime(day.year, day.month, day.day).toUtc().toIso8601String();
      final end =
          DateTime(day.year, day.month, day.day, 23, 59, 59, 999).toUtc().toIso8601String();

      final res = await _client
          .from('workout_logs')
          .select('id')
          .eq('user_id', _userId)
          .gte('completed_at', start)
          .lte('completed_at', end)
          .limit(1);

      return (res as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
