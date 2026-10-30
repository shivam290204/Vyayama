import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import 'package:fitbuddy/features/challenges/data/streak_state.dart';
import 'package:fitbuddy/features/challenges/streak_logic.dart';
import 'package:fitbuddy/features/dashboard/data/daily_stats.dart';
import 'package:fitbuddy/features/intelligence/config/intelligence_config.dart';
import 'package:fitbuddy/features/intelligence/domain/models/fitness_insight.dart';
import 'package:fitbuddy/features/nutrition/domain/nutrition_calculator.dart';
import 'package:fitbuddy/features/profile/data/bmi_record.dart';
import 'package:fitbuddy/features/profile/data/profile.dart';
import 'package:fitbuddy/features/schedule/day_key.dart';
import 'package:fitbuddy/features/workouts/data/workout_log.dart';

/// Aggregated, read-only facts delivered to [FitnessInsightsEngine].
@immutable
class InsightsContext {
  const InsightsContext({
    required this.now,
    required this.recentStats,
    required this.workoutLogs,
    required this.streakState,
    this.profile,
    this.conditionTags = const {},
    this.bmiRecords = const [],
    this.scheduledWorkoutDays = 3,
  });

  /// The evaluation instant (injected for deterministic testing).
  final DateTime now;

  /// Recent daily activity stats (typically 14 trailing days, oldest first).
  final List<DailyStats> recentStats;

  /// Historical workout session logs (newest first or arbitrary order).
  final List<WorkoutLog> workoutLogs;

  /// Current user gamification and consistency streak state.
  final StreakState streakState;

  /// The active user profile, if loaded.
  final Profile? profile;

  /// Verified health contraindication tags (e.g. knee, shoulder).
  final Set<String> conditionTags;

  /// Historical weight and BMI measurements.
  final List<BmiRecord> bmiRecords;

  /// Target workout frequency per week (defaults to 3 days).
  final int scheduledWorkoutDays;
}

/// Pure Dart, deterministic insights engine.
///
/// Features:
/// 1. Connects existing workout logs, daily stats, streaks, and health data.
/// 2. Produces factual, transparent, and non-hallucinated fitness insights.
/// 3. Resilient against offline gaps — never fabricates metrics or assumes
///    un-synced records represent user inactivity.
/// 4. 100% offline-ready with zero external API dependencies.
abstract final class FitnessInsightsEngine {
  /// Evaluates all insight rules against [context] and returns ranked insights.
  static List<FitnessInsight> generateInsights(InsightsContext context) {
    if (!IntelligenceConfig.isEnabled) return const [];

    final insights = <FitnessInsight>[];

    // Rule 1: Active Recovery & Rest Advisor (High Priority)
    final recovery = _evaluateActiveRecovery(context);
    if (recovery != null) insights.add(recovery);

    // Rule 2: Streak Milestones & Progress
    final streak = _evaluateStreakProgress(context);
    if (streak != null) insights.add(streak);

    // Rule 3: Weekly Workout Consistency & Summary
    final consistency = _evaluateWeeklyWorkoutConsistency(context);
    if (consistency != null) insights.add(consistency);

    // Rule 4: Trailing Step & Movement Trend (14-day comparison)
    final activity = _evaluateActivityChange(context);
    if (activity != null) insights.add(activity);

    // Rule 5: Habit Time Window & Missed Workout Pattern
    final timing = _evaluateWorkoutPattern(context);
    if (timing != null) insights.add(timing);

    // Rule 6: Weight & Goal Trend Progress (if available)
    final weightTrend = _evaluateWeightGoalTrend(context);
    if (weightTrend != null) insights.add(weightTrend);

    // Sort by priority descending (urgent -> high -> medium -> low)
    insights.sort((a, b) => b.priority.weight.compareTo(a.priority.weight));

    // Cap to maximum visible insights
    if (insights.length > IntelligenceConfig.maxVisibleInsights) {
      return insights.sublist(0, IntelligenceConfig.maxVisibleInsights);
    }
    return insights;
  }

  /// Rule 1: Evaluates consecutive workout strain and recommends recovery.
  static FitnessInsight? _evaluateActiveRecovery(InsightsContext ctx) {
    final today = dayOnly(ctx.now);
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final twoDaysAgo = DateTime(today.year, today.month, today.day - 2);

    final workedOutToday = _hasWorkoutOn(ctx.workoutLogs, today);
    final workedOutYesterday = _hasWorkoutOn(ctx.workoutLogs, yesterday);
    final workedOutTwoDaysAgo = _hasWorkoutOn(ctx.workoutLogs, twoDaysAgo);

    // 3 consecutive days of workouts: advise active recovery
    if (workedOutToday && workedOutYesterday && workedOutTwoDaysAgo) {
      final weight = ctx.profile?.weightKg ?? 70.0;
      final targetGlasses = NutritionCalculator.dailyWaterGlasses(weight);

      return FitnessInsight(
        id: 'insight_recovery_3days_${dayKey(today)}',
        title: 'Active Recovery Recommended',
        message: 'You have logged workouts 3 days in a row! Prioritize light stretching, '
            'mobility, and drink at least $targetGlasses glasses of water to support muscular repair.',
        category: InsightCategory.recovery,
        priority: InsightPriority.urgent,
        actionLabel: 'Recovery Tips',
        actionRoute: '/sleep',
        createdAt: ctx.now,
        supportingData: {
          'consecutiveDays': 3,
          'waterGlasses': targetGlasses,
        },
      );
    }

    // Heavy step output yesterday (> 12,000 steps) with today also active
    if (ctx.recentStats.isNotEmpty) {
      final yesterdayStats = ctx.recentStats.where((s) => isSameDay(s.date, yesterday)).firstOrNull;
      if (yesterdayStats != null && yesterdayStats.steps >= 12000) {
        return FitnessInsight(
          id: 'insight_recovery_steps_${dayKey(today)}',
          title: 'High Movement Output Yesterday',
          message: 'You logged ${yesterdayStats.steps} steps yesterday! Ensure you get quality '
              'sleep tonight so your joints and muscles fully recharge.',
          category: InsightCategory.recovery,
          priority: InsightPriority.medium,
          actionLabel: 'Sleep Settings',
          actionRoute: '/sleep',
          createdAt: ctx.now,
          supportingData: {'yesterdaySteps': yesterdayStats.steps},
        );
      }
    }

    return null;
  }

  /// Rule 2: Evaluates daily streak progress and celebrates milestones.
  static FitnessInsight? _evaluateStreakProgress(InsightsContext ctx) {
    final streak = ctx.streakState.current;
    if (streak <= 0) return null;

    final todayKey = dayKey(ctx.now);

    // Exact milestone check
    if (StreakLogic.milestones.contains(streak)) {
      final bonusXp = StreakLogic.milestoneBonusXp[streak] ?? 0;
      return FitnessInsight(
        id: 'insight_streak_milestone_${streak}_$todayKey',
        title: '$streak-Day Streak Milestone! 🔥',
        message: 'Incredible dedication! You have hit your $streak-day activity milestone. '
            '${bonusXp > 0 ? "You earned a +$bonusXp XP bonus!" : "Keep the momentum going!"}',
        category: InsightCategory.streak,
        priority: InsightPriority.high,
        actionLabel: 'View Badges',
        actionRoute: '/challenges',
        createdAt: ctx.now,
        supportingData: {'streak': streak, 'bonusXp': bonusXp},
      );
    }

    // Upcoming milestone check (within next 3 days)
    final nextMilestone = StreakLogic.milestones.where((m) => m > streak).firstOrNull;
    if (nextMilestone != null) {
      final daysLeft = nextMilestone - streak;
      if (daysLeft <= 3 && daysLeft > 0) {
        return FitnessInsight(
          id: 'insight_streak_upcoming_${nextMilestone}_$todayKey',
          title: '$daysLeft Day${daysLeft == 1 ? "" : "s"} to $nextMilestone-Day Milestone',
          message: 'You are on a $streak-day streak! Just $daysLeft more active day'
              '${daysLeft == 1 ? "" : "s"} to unlock your next milestone badge.',
          category: InsightCategory.streak,
          priority: InsightPriority.medium,
          actionLabel: 'Challenges',
          actionRoute: '/challenges',
          createdAt: ctx.now,
          supportingData: {'currentStreak': streak, 'nextMilestone': nextMilestone, 'daysLeft': daysLeft},
        );
      }
    }

    return null;
  }

  /// Rule 3: Summarizes 7-day workout frequency against target.
  static FitnessInsight? _evaluateWeeklyWorkoutConsistency(InsightsContext ctx) {
    final sevenDaysAgo = ctx.now.subtract(const Duration(days: 7));
    final weekLogs = ctx.workoutLogs.where((l) => !l.completedAt.isBefore(sevenDaysAgo)).toList();

    final completedCount = weekLogs.length;
    final target = ctx.scheduledWorkoutDays > 0 ? ctx.scheduledWorkoutDays : 3;
    final totalMinutes = weekLogs.fold<int>(0, (sum, l) => sum + l.durationMin);
    final totalCalories = weekLogs.fold<int>(0, (sum, l) => sum + l.caloriesBurned);

    final todayKey = dayKey(ctx.now);

    if (completedCount >= target) {
      return FitnessInsight(
        id: 'insight_consistency_met_${completedCount}_$todayKey',
        title: 'Target Hit: $completedCount Workouts This Week',
        message: 'You achieved your weekly training goal with $completedCount session${completedCount == 1 ? "" : "s"} '
            '($totalMinutes min, ~$totalCalories kcal). Your consistency is building lasting fitness habits.',
        category: InsightCategory.consistency,
        priority: InsightPriority.high,
        actionLabel: 'Plan Details',
        actionRoute: '/workouts',
        createdAt: ctx.now,
        supportingData: {
          'completed': completedCount,
          'target': target,
          'totalMinutes': totalMinutes,
          'totalCalories': totalCalories,
        },
      );
    }

    if (completedCount > 0) {
      final remaining = target - completedCount;
      return FitnessInsight(
        id: 'insight_consistency_progress_${completedCount}_$todayKey',
        title: '$completedCount of $target Weekly Workouts Complete',
        message: 'You have logged $completedCount workout${completedCount == 1 ? "" : "s"} ($totalMinutes min active) '
            'this week. $remaining more session${remaining == 1 ? "" : "s"} will complete your weekly plan.',
        category: InsightCategory.consistency,
        priority: InsightPriority.medium,
        actionLabel: 'Start Workout',
        actionRoute: '/workouts',
        createdAt: ctx.now,
        supportingData: {
          'completed': completedCount,
          'target': target,
          'remaining': remaining,
        },
      );
    }

    // 0 workouts in last 7 days: evaluate before assuming lapse
    // Check QA_REPORT: if recent daily stats show active movement, encourage gently
    final hasRecentSteps = ctx.recentStats.any((s) => s.steps >= 4000);
    return FitnessInsight(
      id: 'insight_consistency_restart_$todayKey',
      title: 'Ready to Restart Your Momentum',
      message: hasRecentSteps
          ? 'You have maintained your daily steps! A quick 10-minute training session will rekindle your workout routine.'
          : 'A fresh week is a fresh start. Even a light 10-minute bodyweight session will rebuild your workout momentum.',
      category: InsightCategory.consistency,
      priority: InsightPriority.medium,
      actionLabel: 'Find a Routine',
      actionRoute: '/workouts',
      createdAt: ctx.now,
      supportingData: {'completed': 0, 'target': target},
    );
  }

  /// Rule 4: Compares 7-day trailing steps with prior 7-day steps (14-day stats).
  static FitnessInsight? _evaluateActivityChange(InsightsContext ctx) {
    if (ctx.recentStats.length < 8) return null;

    final sorted = [...ctx.recentStats]..sort((a, b) => a.date.compareTo(b.date));

    // Split into current week (last 7 days) and prior week (previous days)
    final currentWeek = sorted.sublist(math.max(0, sorted.length - 7));
    final priorWeek = sorted.sublist(0, math.max(0, sorted.length - 7));

    if (currentWeek.isEmpty || priorWeek.isEmpty) return null;

    final validCurrent = currentWeek.where((s) => s.steps > 0).toList();
    final validPrior = priorWeek.where((s) => s.steps > 0).toList();

    if (validCurrent.length < 3 || validPrior.length < 3) return null;

    final avgCurrent = validCurrent.fold<int>(0, (sum, s) => sum + s.steps) / validCurrent.length;
    final avgPrior = validPrior.fold<int>(0, (sum, s) => sum + s.steps) / validPrior.length;

    if (avgPrior < 500) return null; // Avoid division by near-zero baseline

    final delta = (avgCurrent - avgPrior) / avgPrior;
    final todayKey = dayKey(ctx.now);

    // Activity up by >= 15%
    if (delta >= IntelligenceConfig.stepChangeThreshold) {
      final pct = (delta * 100).round();
      return FitnessInsight(
        id: 'insight_steps_up_${pct}_$todayKey',
        title: 'Step Average Up +$pct% This Week',
        message: 'You averaged ${avgCurrent.round()} steps/day over the last week compared to '
            '${avgPrior.round()} the week before. Outstanding increase in daily movement!',
        category: InsightCategory.activityChange,
        priority: InsightPriority.high,
        actionLabel: 'View Trends',
        actionRoute: '/dashboard',
        createdAt: ctx.now,
        supportingData: {'avgCurrent': avgCurrent.round(), 'avgPrior': avgPrior.round(), 'pct': pct},
      );
    }

    // Activity dipped by >= 15%
    if (delta <= -IntelligenceConfig.stepChangeThreshold) {
      final pct = (delta.abs() * 100).round();
      return FitnessInsight(
        id: 'insight_steps_down_${pct}_$todayKey',
        title: 'Step Average Down by $pct%',
        message: 'Your average daily steps dipped to ${avgCurrent.round()} compared to '
            '${avgPrior.round()} last week. A short 15-minute evening stroll can help bridge the gap.',
        category: InsightCategory.activityChange,
        priority: InsightPriority.medium,
        actionLabel: 'View Dashboard',
        actionRoute: '/dashboard',
        createdAt: ctx.now,
        supportingData: {'avgCurrent': avgCurrent.round(), 'avgPrior': avgPrior.round(), 'pct': pct},
      );
    }

    return null;
  }

  /// Rule 5: Detects preferred workout time window and nudges if today's window is near.
  static FitnessInsight? _evaluateWorkoutPattern(InsightsContext ctx) {
    if (ctx.workoutLogs.length < 3) return null;

    final today = dayOnly(ctx.now);
    if (_hasWorkoutOn(ctx.workoutLogs, today)) return null; // Already worked out today

    // Count workouts by hour buckets (Morning: 5-11, Afternoon: 12-16, Evening: 17-22)
    var morningCount = 0;
    var afternoonCount = 0;
    var eveningCount = 0;

    for (final log in ctx.workoutLogs) {
      final hour = log.completedAt.toLocal().hour;
      if (hour >= 5 && hour < 12) {
        morningCount++;
      } else if (hour >= 12 && hour < 17) {
        afternoonCount++;
      } else if (hour >= 17 && hour <= 22) {
        eveningCount++;
      }
    }

    final total = ctx.workoutLogs.length;
    String preferredWindow;
    bool isCurrentWindow;

    final currentHour = ctx.now.hour;
    if (morningCount / total >= 0.5) {
      preferredWindow = 'morning';
      isCurrentWindow = currentHour >= 6 && currentHour <= 11;
    } else if (eveningCount / total >= 0.5) {
      preferredWindow = 'evening';
      isCurrentWindow = currentHour >= 16 && currentHour <= 21;
    } else if (afternoonCount / total >= 0.5) {
      preferredWindow = 'afternoon';
      isCurrentWindow = currentHour >= 11 && currentHour <= 16;
    } else {
      return null; // No strong pattern
    }

    if (isCurrentWindow) {
      final todayKey = dayKey(ctx.now);
      return FitnessInsight(
        id: 'insight_timing_window_${preferredWindow}_$todayKey',
        title: 'Your Prime Workout Time',
        message: 'You usually complete workouts in the $preferredWindow. '
            'Your routine is ready whenever you are!',
        category: InsightCategory.workoutPattern,
        priority: InsightPriority.medium,
        actionLabel: 'Start Workout',
        actionRoute: '/workouts',
        createdAt: ctx.now,
        supportingData: {'window': preferredWindow, 'currentHour': currentHour},
      );
    }

    return null;
  }

  /// Rule 6: Evaluates historical weight tracking trends safely.
  static FitnessInsight? _evaluateWeightGoalTrend(InsightsContext ctx) {
    if (ctx.bmiRecords.length < 2) return null;

    final sorted = [...ctx.bmiRecords]..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    final latest = sorted.first;
    final previous = sorted[1];

    final daysBetween = latest.recordedAt.difference(previous.recordedAt).inDays.abs();
    if (daysBetween < 5) return null; // Wait for meaningful spacing

    final weightDelta = latest.weightKg - previous.weightKg;
    final goal = ctx.profile?.goal ?? 'maintain';
    final isMinor = ctx.profile?.age != null && ctx.profile!.age! < 18;

    // Never praise weight loss for minors (per project safety spec 9.1)
    if (isMinor) return null;

    final todayKey = dayKey(ctx.now);

    if (goal == 'lose' && weightDelta <= -0.4) {
      return FitnessInsight(
        id: 'insight_weight_trend_loss_$todayKey',
        title: 'Steady Goal Progress',
        message: 'Your weight has adjusted safely by ${weightDelta.abs().toStringAsFixed(1)} kg '
            'over the past $daysBetween days. Great adherence to your nutrition and activity targets!',
        category: InsightCategory.recommendation,
        priority: InsightPriority.medium,
        actionLabel: 'Nutrition Target',
        actionRoute: '/nutrition',
        createdAt: ctx.now,
        supportingData: {'weightDelta': weightDelta, 'daysBetween': daysBetween},
      );
    }

    return null;
  }

  static bool _hasWorkoutOn(List<WorkoutLog> logs, DateTime day) {
    final target = dayOnly(day);
    return logs.any((l) => isSameDay(dayOnly(l.completedAt.toLocal()), target));
  }
}
