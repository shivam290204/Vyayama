import 'package:flutter/foundation.dart';

/// Status classification for the user's ongoing adaptive journey.
enum JourneyStatus {
  buildingHabit('Building Habit'),
  progressingSteadily('Progressing Steadily'),
  activeRecovery('Active Recovery'),
  momentumRestart('Gentle Restart'),
  maintaining('Maintaining Rhythm');

  const JourneyStatus(this.label);
  final String label;
}

/// Unified recommendation view model for the Adaptive Fitness Journey.
@immutable
class JourneyRecommendation {
  const JourneyRecommendation({
    required this.goalTitle,
    required this.journeyStatus,
    required this.weeklyTargetSessions,
    required this.completedSessionsThisWeek,
    required this.remainingSessionsThisWeek,
    required this.recommendedNextWorkoutTitle,
    required this.suggestedDurationMinutes,
    required this.suggestedDifficulty,
    required this.weeklyProgressSummary,
    required this.recommendationReason,
    this.recommendedPlanDayId,
    this.recommendedPlanId,
    this.isRecovery = false,
    this.adaptationNotes = const [],
  });

  /// High-level goal (e.g. 'Build Muscle', 'Lose Weight', 'Stay Fit').
  final String goalTitle;

  /// Current fitness journey trajectory status.
  final JourneyStatus journeyStatus;

  /// Target workout sessions for the current week.
  final int weeklyTargetSessions;

  /// Number of sessions completed so far this week.
  final int completedSessionsThisWeek;

  /// Sessions left to complete this week.
  final int remainingSessionsThisWeek;

  /// Title of the recommended next workout (e.g. 'Full Body A - Strength').
  final String recommendedNextWorkoutTitle;

  /// Suggested duration in minutes (aligned with user preferences and recovery state).
  final int suggestedDurationMinutes;

  /// Suggested progression posture (e.g. 'Progressive Overload', 'Consolidate Form', 'Active Recovery').
  final String suggestedDifficulty;

  /// Plain-English summary of current week's progress.
  final String weeklyProgressSummary;

  /// Transparent explanation behind the current recommendation.
  final String recommendationReason;

  /// Plan Day ID if pointing to a specific workout day.
  final String? recommendedPlanDayId;

  /// Workout Plan ID if pointing to a specific plan.
  final String? recommendedPlanId;

  /// True if today's recommendation is restorative / recovery-focused.
  final bool isRecovery;

  /// Any active safety / contraindication notes applied.
  final List<String> adaptationNotes;
}

