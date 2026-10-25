import 'dart:async';
import 'package:fitbuddy/features/dashboard/data/daily_stats.dart';
import 'package:fitbuddy/features/dashboard/data/local_daily_stats_storage.dart';
import 'package:fitbuddy/features/schedule/day_key.dart';

/// Storage for daily activity numbers.
///
/// Implementations can store local activity or sync it with Supabase.
abstract class DailyStatsRepository {
  /// Stored rows from [from] to [to], both inclusive. Days without a row
  /// may be missing from the result.
  Future<List<DailyStats>> fetchRange(DateTime from, DateTime to);

  /// Saves (inserts or updates) one day.
  Future<void> upsert(DailyStats stats);
}

/// In-memory repository that invents stable demo numbers for any day.
///
/// Numbers depend only on the date, so charts look the same on every run.
/// Today's numbers grow through the day.
class MockDailyStatsRepository implements DailyStatsRepository {
  /// Creates the mock. Pass [clock] in tests.
  MockDailyStatsRepository({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  /// User id used by the mock.
  static const String mockUserId = 'mock-user';

  final DateTime Function() _clock;
  final Map<String, DailyStats> _saved = {};

  @override
  Future<List<DailyStats>> fetchRange(DateTime from, DateTime to) async {
    final end = dayOnly(to);
    final local = await LocalDailyStatsStorage.instance.getRange(from, to);
    final localMap = {for (final r in local) dayKey(r.date): r};

    final result = <DailyStats>[];
    for (var d = dayOnly(from);
        !d.isAfter(end);
        d = DateTime(d.year, d.month, d.day + 1)) {
      final k = dayKey(d);
      result.add(localMap[k] ?? _saved[k] ?? _generate(d));
    }
    return result;
  }

  @override
  Future<void> upsert(DailyStats stats) async {
    _saved[dayKey(stats.date)] = stats.copyWith(userId: mockUserId);
    unawaited(LocalDailyStatsStorage.instance.save(stats));
  }

  DailyStats _generate(DateTime day) {
    final epoch =
        DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/
            Duration.millisecondsPerDay;
    final f1 = ((epoch * 9301 + 49297) % 233280) / 233280;
    final f2 = ((epoch * 4973 + 11213) % 233280) / 233280;
    var steps = 4000 + (f1 * 8000).round();
    var minutes = 10 + (f2 * 50).round();
    var calories = (steps * 0.035 + minutes * 2.5).round();

    final now = _clock();
    if (isSameDay(day, now)) {
      final minutesIntoDay = now.hour * 60 + now.minute;
      final scale = (0.15 + 0.85 * minutesIntoDay / 1440).clamp(0.0, 1.0);
      steps = (steps * scale).round();
      minutes = (minutes * scale).round();
      calories = (calories * scale).round();
    }
    return DailyStats(
      userId: mockUserId,
      date: day,
      steps: steps,
      calories: calories,
      activeMinutes: minutes,
    );
  }
}
