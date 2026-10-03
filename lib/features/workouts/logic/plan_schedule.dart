import 'dart:math' as math;

import 'package:fitbuddy/features/workouts/data/workout_plan.dart';

/// Rough duration of a day in minutes (about 3 seconds per rep plus rests).
int estimateDayMinutes(PlanDay day) {
  if (day.exercises.isEmpty) return 0;
  var seconds = 0;
  for (final pe in day.exercises) {
    final sets = pe.setCount;
    final work = pe.isTimed ? (pe.durationSec ?? 0) : (pe.reps ?? 10) * 3;
    seconds += sets * (work + pe.restSec);
  }
  return math.max(1, (seconds / 60).ceil());
}

/// Today's workout day, or the next upcoming one, or null if the plan is empty.
PlanDay? nextWorkoutDay(WorkoutPlan plan, {DateTime? from}) {
  if (plan.days.isEmpty) return null;
  final start = (from ?? DateTime.now()).weekday;
  for (var offset = 0; offset < 7; offset++) {
    final weekday = ((start - 1 + offset) % 7) + 1;
    final day = plan.dayForWeekday(weekday);
    if (day != null) return day;
  }
  return plan.days.first;
}
