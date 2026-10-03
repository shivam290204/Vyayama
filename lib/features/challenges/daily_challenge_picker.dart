import 'package:fitbuddy/features/challenges/data/challenge.dart';

/// Picks the daily challenge deterministically from the date. Pure Dart.
///
/// The list is sorted by id first, so every device picks the same
/// challenge for the same date whatever order the list was loaded in.
class DailyChallengePicker {
  /// Creates the picker.
  const DailyChallengePicker();

  /// Whole days between 1970-01-01 and the calendar day of [day].
  int epochDay(DateTime day) =>
      DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;

  /// The challenge for [day], or null when [all] is empty.
  Challenge? pickFor(List<Challenge> all, DateTime day) {
    if (all.isEmpty) return null;
    final sorted = [...all]..sort((a, b) => a.id.compareTo(b.id));
    return sorted[epochDay(day) % sorted.length];
  }
}
