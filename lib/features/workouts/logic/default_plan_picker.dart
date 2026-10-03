import 'package:fitbuddy/features/workouts/data/workout_plan.dart';

/// Maps any goal value (string or enum) to `lose`, `gain` or `maintain`.
String normalizeGoal(Object? raw) {
  final s = raw?.toString().toLowerCase() ?? '';
  if (s.contains('lose')) return 'lose';
  if (s.contains('gain')) return 'gain';
  return 'maintain';
}

/// Maps any level value to `beginner` or `intermediate`.
String normalizeLevel(Object? raw) {
  final s = raw?.toString().toLowerCase() ?? '';
  if (s.contains('inter') || s.contains('advanced')) return 'intermediate';
  return 'beginner';
}

/// Picks the default system plan for a user's goal and fitness level.
///
/// Falls back to the same goal at beginner level, then any plan for the
/// goal, then any beginner plan, then the first system plan. Users under 18
/// never get a weight-loss plan (spec 12). Returns null if there are no
/// system plans.
WorkoutPlan? pickDefaultPlan({
  required Iterable<WorkoutPlan> plans,
  Object? goal,
  Object? level,
  int? age,
}) {
  final system = plans.where((p) => p.isSystem).toList();
  if (system.isEmpty) return null;

  var g = normalizeGoal(goal);
  if (age != null && age < 18 && g == 'lose') g = 'maintain';
  final l = normalizeLevel(level);

  WorkoutPlan? find(bool Function(WorkoutPlan p) test) {
    for (final p in system) {
      if (test(p)) return p;
    }
    return null;
  }

  return find((p) => p.goal == g && p.level == l) ??
      find((p) => p.goal == g && p.level == 'beginner') ??
      find((p) => p.goal == g) ??
      find((p) => p.level == 'beginner') ??
      system.first;
}
