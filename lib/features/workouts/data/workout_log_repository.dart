import 'package:fitbuddy/features/workouts/data/workout_log.dart';

/// Records completed workouts (table `workout_logs`).
abstract class WorkoutLogRepository {
  /// Saves a completed workout and returns the stored row.
  Future<WorkoutLog> logWorkout({
    required String planDayId,
    required int durationMin,
    required int caloriesBurned,
    DateTime? completedAt,
  });

  /// Logs, newest first. Only entries on or after [since] when given.
  Future<List<WorkoutLog>> getLogs({DateTime? since});

  /// True if a workout was logged on the local calendar day of [day].
  Future<bool> hasWorkoutOn(DateTime day);
}

/// In-memory log repository.
class MockWorkoutLogRepository implements WorkoutLogRepository {
  final List<WorkoutLog> _logs = [];

  @override
  Future<WorkoutLog> logWorkout({
    required String planDayId,
    required int durationMin,
    required int caloriesBurned,
    DateTime? completedAt,
  }) async {
    final log = WorkoutLog(
      id: 'log_${DateTime.now().microsecondsSinceEpoch}',
      userId: 'mock-user',
      planDayId: planDayId,
      completedAt: completedAt ?? DateTime.now(),
      durationMin: durationMin,
      caloriesBurned: caloriesBurned,
    );
    _logs.insert(0, log);
    return log;
  }

  @override
  Future<List<WorkoutLog>> getLogs({DateTime? since}) async {
    if (since == null) return List.unmodifiable(_logs);
    return List.unmodifiable(
      _logs.where((l) => !l.completedAt.isBefore(since)),
    );
  }

  @override
  Future<bool> hasWorkoutOn(DateTime day) async {
    return _logs.any((l) {
      final d = l.completedAt.toLocal();
      return d.year == day.year && d.month == day.month && d.day == day.day;
    });
  }
}
