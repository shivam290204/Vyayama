import 'package:flutter_test/flutter_test.dart';

import 'package:fitbuddy/features/challenges/data/streak_state.dart';
import 'package:fitbuddy/features/dashboard/data/daily_stats.dart';
import 'package:fitbuddy/features/intelligence/domain/models/fitness_insight.dart';
import 'package:fitbuddy/features/intelligence/logic/fitness_insights_engine.dart';
import 'package:fitbuddy/features/profile/data/bmi_record.dart';
import 'package:fitbuddy/features/profile/data/profile.dart';
import 'package:fitbuddy/features/workouts/data/workout_log.dart';

void main() {
  group('FitnessInsightsEngine Unit Tests', () {
    final fixedNow = DateTime(2026, 10, 29, 10, 0); // 10:00 AM on Oct 29, 2026

    test('Empty context returns safe baseline insights without exceptions', () {
      final ctx = InsightsContext(
        now: fixedNow,
        recentStats: const [],
        workoutLogs: const [],
        streakState: const StreakState(userId: 'u1', current: 0, longest: 0),
      );

      final insights = FitnessInsightsEngine.generateInsights(ctx);

      expect(insights, isNotEmpty);
      expect(insights.any((i) => i.category == InsightCategory.consistency), isTrue);
      final consistency = insights.firstWhere((i) => i.category == InsightCategory.consistency);
      expect(consistency.title, contains('Ready to Restart Your Momentum'));
    });

    test('3 consecutive workout days triggers Urgent Active Recovery recommendation', () {
      final today = DateTime(2026, 10, 29, 9, 30);
      final yesterday = DateTime(2026, 10, 28, 9, 30);
      final twoDaysAgo = DateTime(2026, 10, 27, 9, 30);

      final logs = [
        WorkoutLog(
          id: 'w1',
          userId: 'u1',
          planDayId: 'd1',
          completedAt: today,
          durationMin: 35,
          caloriesBurned: 220,
        ),
        WorkoutLog(
          id: 'w2',
          userId: 'u1',
          planDayId: 'd2',
          completedAt: yesterday,
          durationMin: 40,
          caloriesBurned: 250,
        ),
        WorkoutLog(
          id: 'w3',
          userId: 'u1',
          planDayId: 'd3',
          completedAt: twoDaysAgo,
          durationMin: 30,
          caloriesBurned: 190,
        ),
      ];

      final ctx = InsightsContext(
        now: fixedNow,
        recentStats: const [],
        workoutLogs: logs,
        streakState: const StreakState(userId: 'u1', current: 3, longest: 5),
        profile: const Profile(id: 'u1', weightKg: 75.0),
      );

      final insights = FitnessInsightsEngine.generateInsights(ctx);

      expect(insights.any((i) => i.category == InsightCategory.recovery), isTrue);
      final recovery = insights.firstWhere((i) => i.category == InsightCategory.recovery);
      expect(recovery.priority, equals(InsightPriority.urgent));
      expect(recovery.title, equals('Active Recovery Recommended'));
      expect(recovery.message, contains('3 days in a row'));
      expect(recovery.message, contains('10 glasses of water')); // 75kg * 33 / 250 = 9.9 -> 10
      expect(recovery.actionRoute, equals('/sleep'));
    });

    test('Exact streak milestone triggers celebration with XP bonus', () {
      final ctx = InsightsContext(
        now: fixedNow,
        recentStats: const [],
        workoutLogs: const [],
        streakState: const StreakState(userId: 'u1', current: 7, longest: 7),
      );

      final insights = FitnessInsightsEngine.generateInsights(ctx);

      expect(insights.any((i) => i.category == InsightCategory.streak), isTrue);
      final streak = insights.firstWhere((i) => i.category == InsightCategory.streak);
      expect(streak.priority, equals(InsightPriority.high));
      expect(streak.title, equals('7-Day Streak Milestone! 🔥'));
      expect(streak.message, contains('+20 XP bonus'));
    });

    test('Upcoming streak milestone generates countdown encouragement', () {
      final ctx = InsightsContext(
        now: fixedNow,
        recentStats: const [],
        workoutLogs: const [],
        streakState: const StreakState(userId: 'u1', current: 5, longest: 5), // Next milestone is 7
      );

      final insights = FitnessInsightsEngine.generateInsights(ctx);

      expect(insights.any((i) => i.category == InsightCategory.streak), isTrue);
      final streak = insights.firstWhere((i) => i.category == InsightCategory.streak);
      expect(streak.title, equals('2 Days to 7-Day Milestone'));
      expect(streak.message, contains('Just 2 more active days'));
    });

    test('Weekly workout target achievement awards High Priority praise', () {
      final weekLogs = [
        WorkoutLog(
          id: 'w1',
          userId: 'u1',
          planDayId: 'd1',
          completedAt: DateTime(2026, 10, 28, 8, 0),
          durationMin: 30,
          caloriesBurned: 200,
        ),
        WorkoutLog(
          id: 'w2',
          userId: 'u1',
          planDayId: 'd2',
          completedAt: DateTime(2026, 10, 26, 8, 0),
          durationMin: 35,
          caloriesBurned: 240,
        ),
        WorkoutLog(
          id: 'w3',
          userId: 'u1',
          planDayId: 'd3',
          completedAt: DateTime(2026, 10, 24, 8, 0),
          durationMin: 40,
          caloriesBurned: 260,
        ),
      ];

      final ctx = InsightsContext(
        now: fixedNow,
        recentStats: const [],
        workoutLogs: weekLogs,
        streakState: const StreakState(userId: 'u1', current: 3, longest: 3),
        scheduledWorkoutDays: 3,
      );

      final insights = FitnessInsightsEngine.generateInsights(ctx);

      final consistency = insights.firstWhere((i) => i.category == InsightCategory.consistency);
      expect(consistency.priority, equals(InsightPriority.high));
      expect(consistency.title, equals('Target Hit: 3 Workouts This Week'));
      expect(consistency.message, contains('105 min'));
      expect(consistency.message, contains('~700 kcal'));
    });

    test('Activity change detects +15% step surge across 14 days', () {
      final stats = <DailyStats>[
        // Prior week (Days 1 to 7) average 5,000 steps
        for (var i = 13; i >= 7; i--)
          DailyStats(date: fixedNow.subtract(Duration(days: i)), steps: 5000),
        // Current week (Days 0 to 6) average 7,000 steps (+40%)
        for (var i = 6; i >= 0; i--)
          DailyStats(date: fixedNow.subtract(Duration(days: i)), steps: 7000),
      ];

      final ctx = InsightsContext(
        now: fixedNow,
        recentStats: stats,
        workoutLogs: const [],
        streakState: const StreakState(userId: 'u1', current: 4, longest: 4),
      );

      final insights = FitnessInsightsEngine.generateInsights(ctx);

      expect(insights.any((i) => i.category == InsightCategory.activityChange), isTrue);
      final activity = insights.firstWhere((i) => i.category == InsightCategory.activityChange);
      expect(activity.title, equals('Step Average Up +40% This Week'));
      expect(activity.priority, equals(InsightPriority.high));
      expect(activity.message, contains('averaged 7000 steps/day'));
    });

    test('Activity change detects -15% step decrease and provides constructive advice', () {
      final stats = <DailyStats>[
        // Prior week average 8,000 steps
        for (var i = 13; i >= 7; i--)
          DailyStats(date: fixedNow.subtract(Duration(days: i)), steps: 8000),
        // Current week average 6,000 steps (-25%)
        for (var i = 6; i >= 0; i--)
          DailyStats(date: fixedNow.subtract(Duration(days: i)), steps: 6000),
      ];

      final ctx = InsightsContext(
        now: fixedNow,
        recentStats: stats,
        workoutLogs: const [],
        streakState: const StreakState(userId: 'u1', current: 1, longest: 10),
      );

      final insights = FitnessInsightsEngine.generateInsights(ctx);

      final activity = insights.firstWhere((i) => i.category == InsightCategory.activityChange);
      expect(activity.title, equals('Step Average Down by 25%'));
      expect(activity.priority, equals(InsightPriority.medium));
      expect(activity.message, contains('15-minute evening stroll'));
    });

    test('Preferred workout timing detects morning habit and prompts user during morning window', () {
      final morningLogs = [
        WorkoutLog(
          id: 'w1',
          userId: 'u1',
          planDayId: 'd1',
          completedAt: DateTime(2026, 10, 26, 8, 30), // 8:30 AM
          durationMin: 30,
          caloriesBurned: 150,
        ),
        WorkoutLog(
          id: 'w2',
          userId: 'u1',
          planDayId: 'd2',
          completedAt: DateTime(2026, 10, 24, 7, 45), // 7:45 AM
          durationMin: 30,
          caloriesBurned: 150,
        ),
        WorkoutLog(
          id: 'w3',
          userId: 'u1',
          planDayId: 'd3',
          completedAt: DateTime(2026, 10, 22, 8, 15), // 8:15 AM
          durationMin: 30,
          caloriesBurned: 150,
        ),
      ];

      final ctx = InsightsContext(
        now: DateTime(2026, 10, 29, 9, 0), // 9:00 AM (morning window)
        recentStats: const [],
        workoutLogs: morningLogs,
        streakState: const StreakState(userId: 'u1', current: 2, longest: 5),
      );

      final insights = FitnessInsightsEngine.generateInsights(ctx);

      expect(insights.any((i) => i.category == InsightCategory.workoutPattern), isTrue);
      final timing = insights.firstWhere((i) => i.category == InsightCategory.workoutPattern);
      expect(timing.title, equals('Your Prime Workout Time'));
      expect(timing.message, contains('usually complete workouts in the morning'));
    });

    test('Weight loss progress is praised for adults but strictly omitted for minors', () {
      final bmiAdult = [
        BmiRecord(
          id: 'b1',
          userId: 'u1',
          weightKg: 78.5,
          heightCm: 175.0,
          bmi: 25.6,
          recordedAt: fixedNow,
        ),
        BmiRecord(
          id: 'b2',
          userId: 'u1',
          weightKg: 79.5, // Was 79.5kg 10 days ago (-1.0kg)
          heightCm: 175.0,
          bmi: 26.0,
          recordedAt: fixedNow.subtract(const Duration(days: 10)),
        ),
      ];

      // 1. Adult user (age 28)
      final adultCtx = InsightsContext(
        now: fixedNow,
        recentStats: const [],
        workoutLogs: const [],
        streakState: const StreakState(userId: 'u1', current: 0, longest: 0),
        profile: const Profile(id: 'u1', age: 28, goal: 'lose'),
        bmiRecords: bmiAdult,
      );

      final adultInsights = FitnessInsightsEngine.generateInsights(adultCtx);
      expect(adultInsights.any((i) => i.category == InsightCategory.recommendation), isTrue);
      final rec = adultInsights.firstWhere((i) => i.category == InsightCategory.recommendation);
      expect(rec.title, equals('Steady Goal Progress'));
      expect(rec.message, contains('adjusted safely by 1.0 kg'));

      // 2. Minor user (age 16) - Under 18 safety rule
      final minorCtx = InsightsContext(
        now: fixedNow,
        recentStats: const [],
        workoutLogs: const [],
        streakState: const StreakState(userId: 'u1', current: 0, longest: 0),
        profile: const Profile(id: 'u2', age: 16, goal: 'lose'),
        bmiRecords: bmiAdult,
      );

      final minorInsights = FitnessInsightsEngine.generateInsights(minorCtx);
      expect(minorInsights.any((i) => i.category == InsightCategory.recommendation), isFalse);
    });

    test('Offline data resilience: user with 0 synced workouts but active daily steps is not falsely marked lapsed', () {
      // User with 0 workout logs (e.g. gym basement offline sync delay), but 7,500 daily steps
      final ctx = InsightsContext(
        now: fixedNow,
        recentStats: [
          DailyStats(date: fixedNow, steps: 7500),
          DailyStats(date: fixedNow.subtract(const Duration(days: 1)), steps: 8200),
        ],
        workoutLogs: const [],
        streakState: const StreakState(userId: 'u1', current: 0, longest: 4),
      );

      final insights = FitnessInsightsEngine.generateInsights(ctx);
      final consistency = insights.firstWhere((i) => i.category == InsightCategory.consistency);

      expect(consistency.message, contains('You have maintained your daily steps!'));
      expect(consistency.message, isNot(contains('You missed')));
    });
  });
}
