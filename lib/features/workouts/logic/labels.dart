import 'package:fitbuddy/features/workouts/data/workout_plan.dart';

/// "lower_back" -> "Lower back".
String prettyLabel(String raw) {
  final s = raw.replaceAll('_', ' ').trim();
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Full weekday name for 1 (Monday) to 7 (Sunday).
String weekdayName(int weekday) {
  final i = weekday < 1 ? 0 : (weekday > 7 ? 6 : weekday - 1);
  return _weekdays[i];
}

String weekdayShort(int weekday) => weekdayName(weekday).substring(0, 3);

String weekdayInitial(int weekday) => weekdayName(weekday).substring(0, 1);

/// Friendly goal name.
String goalLabel(String? goal) => switch (goal) {
      'lose' => 'Weight loss',
      'gain' => 'Weight gain',
      _ => 'Stay fit',
    };

/// Seconds as m:ss.
String formatClock(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// "3 × 10 reps", "2 × 45 sec", "1 × 10 min".
String prescriptionLabel(PlanExercise pe) {
  final sets = pe.setCount;
  if (pe.isTimed) {
    final d = pe.durationSec ?? 0;
    final unit = (d >= 120 && d % 60 == 0) ? '${d ~/ 60} min' : '$d sec';
    return '$sets × $unit';
  }
  final reps = pe.reps;
  return reps == null ? '$sets sets' : '$sets × $reps reps';
}
