import 'package:flutter_test/flutter_test.dart';

import 'package:fitbuddy/features/dashboard/data/daily_stats.dart';
import 'package:fitbuddy/features/intelligence/domain/models/workout_difficulty_feedback.dart';
import 'package:fitbuddy/features/intelligence/logic/weekly_review_generator.dart';
import 'package:fitbuddy/features/workouts/data/workout_log.dart';

void main() {
  group('WeeklyFitnessReviewGenerator Unit Tests', () {
    final fixedEnding = DateTime(2026, 10, 29, 20, 0);

    test('3 of 3 sessions completed yields 100% consistency and celebration', () async {
      final logs = [
        WorkoutLog(
          id: 'l1',
          userId: 'u1',
          planDayId: 'd1',
          completedAt: fixedEnding.subtract(const Duration(days: 1)),
          durationMin: 30,
          caloriesBurned: 180,
        ),
        WorkoutLog(
          id: 'l2',
          userId: 'u1',
          planDayId: 'd2',
          completedAt: fixedEnding.subtract(const Duration(days: 3)),
          durationMin: 35,
          caloriesBurned: 210,
        ),
        WorkoutLog(
          id: 'l3',
          userId: 'u1',
          planDayId: 'd3',
          completedAt: fixedEnding.subtract(const Duration(days: 5)),
          durationMin: 30,
          caloriesBurned: 190,
        ),
      ];

      final stats = [
        DailyStats(date: fixedEnding.subtract(const Duration(days: 1)), steps: 8000, activeMinutes: 40),
        DailyStats(date: fixedEnding.subtract(const Duration(days: 2)), steps: 9000, activeMinutes: 45),
        DailyStats(date: fixedEnding.subtract(const Duration(days: 3)), steps: 8500, activeMinutes: 35),
        DailyStats(date: fixedEnding.subtract(const Duration(days: 4)), steps: 10000, activeMinutes: 50),
        DailyStats(date: fixedEnding.subtract(const Duration(days: 5)), steps: 7500, activeMinutes: 30),
      ];

      final generator = WeeklyFitnessReviewGenerator(
        workoutLogs: logs,
        recentStats: stats,
        targetWorkoutsPerWeek: 3,
      );

      final review = await generator.generateWeeklyReview(weekEnding: fixedEnding);

      expect(review.completedSessions, 3);
      expect(review.scheduledSessions, 3);
      expect(review.consistencyScore, 100);
      expect(review.totalActiveMinutes, 95); // 30+35+30
      expect(review.totalSteps, 43000);
      expect(review.celebrations.any((c) => c.contains('Hit your weekly target')), isTrue);
      expect(review.celebrations.any((c) => c.contains('43000 total steps')), isTrue);
      expect(review.recommendedNextFocus, contains('Progressive Overload'));
    });

    test('Missed sessions highlighted gently in growth opportunities', () async {
      final logs = [
        WorkoutLog(
          id: 'l1',
          userId: 'u1',
          planDayId: 'd1',
          completedAt: fixedEnding.subtract(const Duration(days: 2)),
          durationMin: 20,
          caloriesBurned: 120,
        ),
      ];

      final generator = WeeklyFitnessReviewGenerator(
        workoutLogs: logs,
        recentStats: const [],
        targetWorkoutsPerWeek: 3,
      );

      final review = await generator.generateWeeklyReview(weekEnding: fixedEnding);

      expect(review.completedSessions, 1);
      expect(review.consistencyScore, 33);
      expect(review.areasForImprovement.any((a) => a.contains('Missed 2 scheduled workouts')), isTrue);
      expect(review.recommendedNextFocus, contains('Habit Rebuild'));
    });

    test('Too Hard feedback steers focus to Active Recovery', () async {
      final logs = [
        WorkoutLog(
          id: 'l1',
          userId: 'u1',
          planDayId: 'd1',
          completedAt: fixedEnding.subtract(const Duration(days: 1)),
          durationMin: 45,
          caloriesBurned: 300,
        ),
      ];

      final feedback = [
        WorkoutDifficultyFeedback(
          id: 'fb1',
          userId: 'u1',
          planDayId: 'd1',
          completedAt: fixedEnding.subtract(const Duration(days: 1)),
          rating: WorkoutDifficultyRating.tooHard,
          createdAt: fixedEnding.subtract(const Duration(days: 1)),
        ),
      ];

      final generator = WeeklyFitnessReviewGenerator(
        workoutLogs: logs,
        recentStats: const [],
        recentFeedback: feedback,
        targetWorkoutsPerWeek: 3,
      );

      final review = await generator.generateWeeklyReview(weekEnding: fixedEnding);

      expect(review.areasForImprovement.any((a) => a.contains('felt too hard')), isTrue);
      expect(review.recommendedNextFocus, contains('Active Recovery'));
    });

    test('Zero workouts handled safely without crashes or division by zero', () async {
      final generator = const WeeklyFitnessReviewGenerator(
        workoutLogs: [],
        recentStats: [],
        targetWorkoutsPerWeek: 3,
      );

      final review = await generator.generateWeeklyReview(weekEnding: fixedEnding);

      expect(review.completedSessions, 0);
      expect(review.consistencyScore, 0);
      expect(review.totalActiveMinutes, 0);
      expect(review.totalSteps, 0);
      expect(review.recommendedNextFocus, contains('Habit Rebuild'));
    });
  });
}

