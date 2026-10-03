/// Formats minutes like `8 h` or `7 h 30 min`.
String formatSleepMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

/// Friendly label for a profile goal value.
String goalLabel(String? goal) => switch (goal) {
      'lose' => 'Lose weight',
      'gain' => 'Gain weight',
      'maintain' => 'Stay fit',
      _ => 'Not set',
    };
