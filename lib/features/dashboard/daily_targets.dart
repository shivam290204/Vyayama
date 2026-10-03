import 'package:fitbuddy/features/dashboard/body_metrics.dart';
import 'package:flutter/foundation.dart';

/// Daily goals for the progress rings, adjusted by the user's goal.
@immutable
class DailyTargets {
  /// Creates targets.
  const DailyTargets({
    required this.steps,
    required this.activeMinutes,
    required this.activeCalories,
  });

  /// Targets for [goal]. Users under 18 never get the weight-loss targets.
  factory DailyTargets.forGoal(FitGoal goal, {bool isMinor = false}) {
    final effective = isMinor && goal == FitGoal.lose ? FitGoal.maintain : goal;
    return switch (effective) {
      FitGoal.lose => const DailyTargets(
          steps: 10000,
          activeMinutes: 45,
          activeCalories: 450,
        ),
      FitGoal.gain => const DailyTargets(
          steps: 6000,
          activeMinutes: 30,
          activeCalories: 250,
        ),
      FitGoal.maintain => const DailyTargets(
          steps: defaultSteps,
          activeMinutes: 30,
          activeCalories: 300,
        ),
    };
  }

  /// Default daily step target (spec 5.3).
  static const int defaultSteps = 8000;

  /// Daily steps.
  final int steps;

  /// Daily active minutes.
  final int activeMinutes;

  /// Daily active calories.
  final int activeCalories;
}
