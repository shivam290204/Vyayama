import 'package:fitbuddy/features/dashboard/body_metrics.dart';
import 'package:fitbuddy/features/dashboard/calorie_math.dart';
import 'package:fitbuddy/features/dashboard/daily_targets.dart';
import 'package:fitbuddy/features/dashboard/data/daily_stats.dart';
import 'package:fitbuddy/features/dashboard/data/daily_stats_repository.dart';
import 'package:fitbuddy/features/dashboard/stats_range.dart';
import 'package:fitbuddy/features/profile/profile_providers.dart';
import 'package:fitbuddy/features/schedule/clock_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How many days (including today) the dashboard loads.
const int recentStatsDays = 14;

/// Daily stats storage. Antigravity swaps in Supabase plus Health data here.
final dailyStatsRepositoryProvider = Provider<DailyStatsRepository>(
  (ref) => MockDailyStatsRepository(clock: ref.watch(clockProvider)),
);

/// The last 14 days, one entry per day, oldest first (today is last).
/// Invalidate this provider to refresh (pull-to-refresh, app resume).
final recentStatsProvider = FutureProvider<List<DailyStats>>((ref) async {
  final today = ref.watch(todayProvider);
  final repo = ref.watch(dailyStatsRepositoryProvider);
  final from = DateTime(today.year, today.month, today.day - (recentStatsDays - 1));
  final rows = await repo.fetchRange(from, today);
  return fillMissingDays(rows, from: from, to: today);
});

/// Today's stats.
final todayStatsProvider = Provider<AsyncValue<DailyStats>>(
  (ref) => ref.watch(recentStatsProvider).whenData((days) => days.last),
);

/// The last 7 days including today, oldest first.
final weekStatsProvider = Provider<AsyncValue<List<DailyStats>>>(
  (ref) => ref.watch(recentStatsProvider).whenData(
        (days) => days.sublist(days.length > 7 ? days.length - 7 : 0),
      ),
);

/// The last 14 days, newest first.
final statsHistoryProvider = Provider<AsyncValue<List<DailyStats>>>(
  (ref) => ref
      .watch(recentStatsProvider)
      .whenData((days) => days.reversed.toList()),
);

/// Body numbers from the profile, with safe fallbacks.
final bodyMetricsProvider = Provider<BodyMetrics>((ref) {
  final profile = ref.watch(currentProfileProvider).asData?.value;
  return BodyMetrics.fromProfile(profile);
});

/// Daily targets adjusted by the user's goal.
final dailyTargetsProvider = Provider<DailyTargets>((ref) {
  final metrics = ref.watch(bodyMetricsProvider);
  return DailyTargets.forGoal(metrics.goal, isMinor: metrics.isMinor);
});

/// Today's BMR versus active calories.
final calorieBreakdownProvider = Provider<AsyncValue<CalorieBreakdown>>((ref) {
  final metrics = ref.watch(bodyMetricsProvider);
  return ref.watch(todayStatsProvider).whenData(
        (stats) => CalorieMath.breakdown(stats: stats, metrics: metrics),
      );
});
