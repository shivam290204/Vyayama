import 'package:fitbuddy/features/dashboard/daily_targets.dart';
import 'package:fitbuddy/features/dashboard/data/daily_stats.dart';
import 'package:fitbuddy/features/schedule/day_key.dart';
import 'package:flutter/foundation.dart';

/// Represents a single day cell in the monthly activity calendar grid.
@immutable
class CalendarDayModel {
  const CalendarDayModel({
    required this.date,
    required this.isCurrentMonth,
    required this.isToday,
    required this.isFuture,
    this.stats,
    this.stepProgress = 0.0,
    this.activeMinutesProgress = 0.0,
    this.calorieProgress = 0.0,
    this.isTargetAchieved = false,
  });

  /// The local calendar date for this cell.
  final DateTime date;

  /// Whether this day belongs to the currently selected month.
  final bool isCurrentMonth;

  /// Whether this date is today.
  final bool isToday;

  /// Whether this date is in the future.
  final bool isFuture;

  /// Stored activity statistics for this day, if any.
  final DailyStats? stats;

  /// Step progress clamped between 0.0 and 1.0 (visually capped at 100%).
  final double stepProgress;

  /// Active minutes progress clamped between 0.0 and 1.0.
  final double activeMinutesProgress;

  /// Calories progress clamped between 0.0 and 1.0.
  final double calorieProgress;

  /// Whether the primary daily step target was achieved on this day.
  final bool isTargetAchieved;

  /// Actual steps walked.
  int get steps => stats?.steps ?? 0;

  /// Actual active minutes.
  int get activeMinutes => stats?.activeMinutes ?? 0;

  /// Actual calories burned.
  int get calories => stats?.calories ?? 0;

  /// Whether any real activity was recorded on this day.
  bool get hasActivity => stats != null && !stats!.isEmpty;
}

/// Aggregated activity totals and day-by-day map for a specific month.
@immutable
class MonthlyActivitySummary {
  const MonthlyActivitySummary({
    required this.month,
    required this.targetDaysAchieved,
    required this.totalDaysEvaluated,
    required this.totalDaysInMonth,
    required this.totalSteps,
    required this.totalActiveMinutes,
    required this.totalCalories,
    required this.dailyMap,
  });

  /// An empty summary for a month with no data.
  factory MonthlyActivitySummary.empty(DateTime month) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    return MonthlyActivitySummary(
      month: DateTime(month.year, month.month, 1),
      targetDaysAchieved: 0,
      totalDaysEvaluated: 0,
      totalDaysInMonth: daysInMonth,
      totalSteps: 0,
      totalActiveMinutes: 0,
      totalCalories: 0,
      dailyMap: const {},
    );
  }

  /// The month (year and month, normalized to 1st of month).
  final DateTime month;

  /// Number of days in the month where the daily step target was reached.
  final int targetDaysAchieved;

  /// Number of days up to today (or total days for past months) evaluated.
  final int totalDaysEvaluated;

  /// Total days in this month (28, 29, 30, or 31).
  final int totalDaysInMonth;

  /// Cumulative steps walked across the month.
  final int totalSteps;

  /// Cumulative active minutes across the month.
  final int totalActiveMinutes;

  /// Cumulative calories burned across the month.
  final int totalCalories;

  /// Map of `dayKey(date)` -> `DailyStats` for O(1) day lookups.
  final Map<String, DailyStats> dailyMap;

  /// Retrieves stats for a specific date, or null if no record exists.
  DailyStats? statsForDate(DateTime date) => dailyMap[dayKey(date)];
}

/// Pure deterministic logic and mathematical calculations for the monthly activity calendar.
abstract final class MonthlyActivityLogic {
  /// Returns the first day of the given month: `DateTime(year, month, 1)`.
  static DateTime startOfMonth(DateTime month) =>
      DateTime(month.year, month.month, 1);

  /// Returns the last day of the given month, accurately handling leap years and 28-31 day variations.
  static DateTime endOfMonth(DateTime month) =>
      DateTime(month.year, month.month + 1, 0);

  /// Advances by one month.
  static DateTime nextMonth(DateTime month) =>
      DateTime(month.year, month.month + 1, 1);

  /// Moves back by one month.
  static DateTime previousMonth(DateTime month) =>
      DateTime(month.year, month.month - 1, 1);

  /// Computes monthly aggregates from a list of daily stats rows.
  static MonthlyActivitySummary computeSummary({
    required List<DailyStats> rows,
    required DateTime month,
    required DailyTargets targets,
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    final map = <String, DailyStats>{};
    for (final r in rows) {
      if (r.date.year == month.year && r.date.month == month.month) {
        map[dayKey(r.date)] = r;
      }
    }

    var totalSteps = 0;
    var totalActiveMinutes = 0;
    var totalCalories = 0;
    var targetDaysAchieved = 0;

    // Calculate days evaluated: for current month, evaluate up to today; for past months, all days; for future, 0.
    int evaluatedDays = 0;
    final isCurrentMonth = month.year == now.year && month.month == now.month;
    final isPastMonth = month.year < now.year ||
        (month.year == now.year && month.month < now.month);

    if (isPastMonth) {
      evaluatedDays = daysInMonth;
    } else if (isCurrentMonth) {
      evaluatedDays = now.day.clamp(1, daysInMonth);
    } else {
      evaluatedDays = 0;
    }

    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final key = dayKey(date);
      final stats = map[key];

      if (stats != null) {
        totalSteps += stats.steps;
        totalActiveMinutes += stats.activeMinutes;
        totalCalories += stats.calories;

        if (targets.steps > 0 && stats.steps >= targets.steps) {
          targetDaysAchieved++;
        }
      }
    }

    return MonthlyActivitySummary(
      month: DateTime(month.year, month.month, 1),
      targetDaysAchieved: targetDaysAchieved,
      totalDaysEvaluated: evaluatedDays,
      totalDaysInMonth: daysInMonth,
      totalSteps: totalSteps,
      totalActiveMinutes: totalActiveMinutes,
      totalCalories: totalCalories,
      dailyMap: map,
    );
  }

  /// Generates the complete 7-column calendar grid (typically 35 or 42 cells)
  /// starting on [firstDayOfWeek] (defaults to Sunday: `DateTime.sunday` == 7).
  static List<CalendarDayModel> generateGrid({
    required DateTime month,
    required Map<String, DailyStats> dailyMap,
    required DailyTargets targets,
    DateTime? today,
    int firstDayOfWeek = DateTime.sunday,
  }) {
    final now = today ?? DateTime.now();
    final todayDay = dayOnly(now);
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final lastOfMonth = DateTime(month.year, month.month + 1, 0);

    // Weekday in Dart: Monday = 1 ... Sunday = 7
    // Calculate how many leading days from previous month are needed
    final firstWeekday = firstOfMonth.weekday; // 1 to 7
    final leadingDays = (firstWeekday - firstDayOfWeek + 7) % 7;

    final grid = <CalendarDayModel>[];

    // 1. Previous month trailing days
    final prevMonthEnd = DateTime(month.year, month.month, 0);
    for (var i = leadingDays - 1; i >= 0; i--) {
      final date = DateTime(prevMonthEnd.year, prevMonthEnd.month, prevMonthEnd.day - i);
      final stats = dailyMap[dayKey(date)];
      grid.add(_createDayModel(
        date: date,
        isCurrentMonth: false,
        todayDay: todayDay,
        stats: stats,
        targets: targets,
      ));
    }

    // 2. Current month days
    for (var day = 1; day <= lastOfMonth.day; day++) {
      final date = DateTime(month.year, month.month, day);
      final stats = dailyMap[dayKey(date)];
      grid.add(_createDayModel(
        date: date,
        isCurrentMonth: true,
        todayDay: todayDay,
        stats: stats,
        targets: targets,
      ));
    }

    // 3. Next month leading days to complete full 7-day rows (up to 35 or 42 cells)
    final trailingDays = (7 - (grid.length % 7)) % 7;
    for (var day = 1; day <= trailingDays; day++) {
      final date = DateTime(month.year, month.month + 1, day);
      final stats = dailyMap[dayKey(date)];
      grid.add(_createDayModel(
        date: date,
        isCurrentMonth: false,
        todayDay: todayDay,
        stats: stats,
        targets: targets,
      ));
    }

    return grid;
  }

  static CalendarDayModel _createDayModel({
    required DateTime date,
    required bool isCurrentMonth,
    required DateTime todayDay,
    required DailyStats? stats,
    required DailyTargets targets,
  }) {
    final dayNormalized = dayOnly(date);
    final isToday = isSameDay(dayNormalized, todayDay);
    final isFuture = dayNormalized.isAfter(todayDay);

    double stepProgress = 0.0;
    double activeMinutesProgress = 0.0;
    double calorieProgress = 0.0;
    bool isTargetAchieved = false;

    if (stats != null && !isFuture) {
      if (targets.steps > 0) {
        stepProgress = (stats.steps / targets.steps).clamp(0.0, 1.0);
        isTargetAchieved = stats.steps >= targets.steps;
      }
      if (targets.activeMinutes > 0) {
        activeMinutesProgress = (stats.activeMinutes / targets.activeMinutes).clamp(0.0, 1.0);
      }
      if (targets.activeCalories > 0) {
        calorieProgress = (stats.calories / targets.activeCalories).clamp(0.0, 1.0);
      }
    }

    return CalendarDayModel(
      date: date,
      isCurrentMonth: isCurrentMonth,
      isToday: isToday,
      isFuture: isFuture,
      stats: isFuture ? null : stats,
      stepProgress: stepProgress,
      activeMinutesProgress: activeMinutesProgress,
      calorieProgress: calorieProgress,
      isTargetAchieved: isTargetAchieved,
    );
  }
}
