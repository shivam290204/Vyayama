import 'package:fitbuddy/features/dashboard/data/daily_stats.dart';
import 'package:fitbuddy/features/schedule/day_key.dart';

/// Returns exactly one entry per day from [from] to [to] (inclusive),
/// oldest first. Days without a row become empty stats. If [rows] holds
/// several rows for one day, the last one wins.
List<DailyStats> fillMissingDays(
  List<DailyStats> rows, {
  required DateTime from,
  required DateTime to,
  String userId = '',
}) {
  final byDay = {for (final r in rows) dayKey(r.date): r};
  final end = dayOnly(to);
  final result = <DailyStats>[];
  for (var d = dayOnly(from);
      !d.isAfter(end);
      d = DateTime(d.year, d.month, d.day + 1)) {
    result.add(byDay[dayKey(d)] ?? DailyStats.empty(d, userId: userId));
  }
  return result;
}
