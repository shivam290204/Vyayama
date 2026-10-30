import 'package:flutter/foundation.dart';
import 'package:fitbuddy/features/workouts/data/workout_plan.dart';
import 'package:fitbuddy/features/workouts/logic/progression_model_interface.dart';

/// Projection forecast for fitness goal attainment.
@immutable
class GoalForecast {
  const GoalForecast({
    required this.goalType,
    required this.targetDescription,
    required this.projectedWeeksToTarget,
    required this.confidenceRating,
    required this.rationale,
    this.milestones = const [],
  });

  final String goalType;
  final String targetDescription;
  final int projectedWeeksToTarget;
  final double confidenceRating; // 0.0 to 1.0
  final String rationale;
  final List<String> milestones;
}

/// Structured weekly fitness review summarizing adherence, intensity, and next steps.
@immutable
class WeeklyFitnessReview {
  const WeeklyFitnessReview({
    required this.weekStartDate,
    required this.weekEndDate,
    required this.completedSessions,
    required this.scheduledSessions,
    required this.totalActiveMinutes,
    required this.totalSteps,
    required this.consistencyScore, // 0 - 100
    required this.adherenceSummary,
    required this.recommendedNextFocus,
    this.celebrations = const [],
    this.areasForImprovement = const [],
  });

  final DateTime weekStartDate;
  final DateTime weekEndDate;
  final int completedSessions;
  final int scheduledSessions;
  final int totalActiveMinutes;
  final int totalSteps;
  final int consistencyScore;
  final String adherenceSummary;
  final String recommendedNextFocus;
  final List<String> celebrations;
  final List<String> areasForImprovement;
}

/// Abstract contract for projecting goal outcomes based on past consistency.
abstract interface class IAdaptivePlanForecaster {
  /// Generates a realistic goal timeline based on historical adherence.
  Future<GoalForecast> forecastGoalProgress({
    required String goal,
    required double weeklyAdherenceRatio,
    required int activeWeeksTracked,
  });
}

/// Abstract contract for generating weekly fitness reviews.
abstract interface class IWeeklyFitnessReviewGenerator {
  /// Synthesizes past 7 days of activity into an actionable, encouraging review.
  Future<WeeklyFitnessReview> generateWeeklyReview({
    required DateTime weekEnding,
  });
}

/// Policy contract for recommending adaptive adjustments to a workout plan.
abstract interface class IAdaptiveDifficultyPolicy {
  /// Evaluates whether a plan should undergo volume or load changes.
  /// Does NOT modify the plan directly in Phase 1; returns recommendations.
  Future<ProgressionRecommendation> evaluatePlanAdaptation({
    required WorkoutPlan currentPlan,
    required double trailingAdherence,
    required double? averageSessionRpe,
  });
}

