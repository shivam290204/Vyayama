import 'dart:async';
import 'package:fitbuddy/core/constants/env.dart';
import 'package:fitbuddy/core/services/step_tracking_service.dart';
import 'package:fitbuddy/features/dashboard/body_metrics.dart';
import 'package:fitbuddy/features/dashboard/calorie_math.dart';
import 'package:fitbuddy/features/dashboard/daily_targets.dart';
import 'package:fitbuddy/features/dashboard/data/daily_stats.dart';
import 'package:fitbuddy/features/dashboard/data/daily_stats_repository.dart';
import 'package:fitbuddy/features/dashboard/data/supabase_daily_stats_repository.dart';
import 'package:fitbuddy/features/dashboard/stats_range.dart';
import 'package:fitbuddy/features/profile/profile_providers.dart';
import 'package:fitbuddy/features/schedule/clock_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How many days (including today) the dashboard loads.
const int recentStatsDays = 14;

/// Daily stats storage. Uses Supabase when configured, falling back to mock.
final dailyStatsRepositoryProvider = Provider<DailyStatsRepository>((ref) {
  if (Env.isSupabaseConfigured) {
    return SupabaseDailyStatsRepository();
  }
  return MockDailyStatsRepository(clock: ref.watch(clockProvider));
});

/// Live step updates stream from hardware sensors.
final liveStepStatsProvider = StreamProvider<DailyStats>((ref) {
  return StepTrackingService.instance.statsStream;
});

/// The last 14 days, one entry per day, oldest first (today is last).
/// Invalidate this provider to refresh (pull-to-refresh, app resume).
final recentStatsProvider = FutureProvider<List<DailyStats>>((ref) async {
  final today = ref.watch(todayProvider);
  final repo = ref.watch(dailyStatsRepositoryProvider);
  final from = DateTime(today.year, today.month, today.day - (recentStatsDays - 1));
  final rows = await repo.fetchRange(from, today);
  final days = fillMissingDays(rows, from: from, to: today);

  // Merge today's live hardware step tracking numbers
  final liveToday = StepTrackingService.instance.getTodayStats();
  if (days.isNotEmpty && liveToday.steps > 0) {
    final last = days.last;
    final mergedSteps = liveToday.steps > last.steps ? liveToday.steps : last.steps;
    final mergedCalories = liveToday.calories > last.calories ? liveToday.calories : last.calories;
    final mergedMinutes = liveToday.activeMinutes > last.activeMinutes ? liveToday.activeMinutes : last.activeMinutes;
    final updatedToday = last.copyWith(
      steps: mergedSteps,
      calories: mergedCalories,
      activeMinutes: mergedMinutes,
    );
    days[days.length - 1] = updatedToday;
    unawaited(repo.upsert(updatedToday));
  }
  return days;
});

/// Today's stats (merges latest repository numbers with live hardware steps).
final todayStatsProvider = Provider<AsyncValue<DailyStats>>((ref) {
  final recent = ref.watch(recentStatsProvider);
  final live = ref.watch(liveStepStatsProvider).asData?.value;
  return recent.whenData((days) {
    final today = days.last;
    if (live == null) return today;
    final maxSteps = live.steps > today.steps ? live.steps : today.steps;
    final maxCalories = live.calories > today.calories ? live.calories : today.calories;
    final maxMinutes = live.activeMinutes > today.activeMinutes ? live.activeMinutes : today.activeMinutes;
    return today.copyWith(
      steps: maxSteps,
      calories: maxCalories,
      activeMinutes: maxMinutes,
    );
  });
});

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
