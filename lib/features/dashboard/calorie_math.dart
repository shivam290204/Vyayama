import 'package:fitbuddy/features/dashboard/body_metrics.dart';
import 'package:fitbuddy/features/dashboard/data/daily_stats.dart';
import 'package:flutter/foundation.dart';

/// Resting plus active calories for one day.
@immutable
class CalorieBreakdown {
  /// Creates the breakdown.
  const CalorieBreakdown({
    required this.bmr,
    required this.active,
    required this.activeIsEstimated,
    required this.metricsEstimated,
  });

  /// Resting calories for the full day (BMR).
  final int bmr;

  /// Active calories so far today.
  final int active;

  /// True when [active] was estimated from steps instead of measured.
  final bool activeIsEstimated;

  /// True when body numbers were defaults, so [bmr] is rough.
  final bool metricsEstimated;

  /// BMR plus active calories.
  int get total => bmr + active;
}

/// Calorie formulas from spec section 9.1. Pure Dart. All results are
/// estimates for general wellness, never medical advice.
abstract final class CalorieMath {
  /// Mifflin-St Jeor BMR in kcal per day.
  ///
  /// Male `10w + 6.25h - 5a + 5`, female `10w + 6.25h - 5a - 161`, other the
  /// average of the two (offset -78). Never below 0.
  static double bmr({
    required BiologicalSex sex,
    required double weightKg,
    required double heightCm,
    required int age,
  }) {
    final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    final value = switch (sex) {
      BiologicalSex.male => base + 5,
      BiologicalSex.female => base - 161,
      BiologicalSex.other => base - 78,
    };
    return value < 0 ? 0 : value;
  }

  /// Rough active calories from steps: `steps x kg x 0.0005`.
  static int estimateActiveFromSteps(int steps, double weightKg) =>
      (steps * weightKg * 0.0005).round();

  /// Workout calories: `MET x kg x hours`.
  static int workoutCalories({
    required double met,
    required double weightKg,
    required double minutes,
  }) =>
      (met * weightKg * (minutes / 60)).round();

  /// Builds today's breakdown.
  ///
  /// Uses the measured active energy (`stats.calories`) when available.
  /// Otherwise estimates from steps and adds [workoutKcal].
  static CalorieBreakdown breakdown({
    required DailyStats stats,
    required BodyMetrics metrics,
    int workoutKcal = 0,
  }) {
    final restingKcal = bmr(
      sex: metrics.sex,
      weightKg: metrics.weightKg,
      heightCm: metrics.heightCm,
      age: metrics.age,
    ).round();
    final measured = stats.calories > 0;
    final active = measured
        ? stats.calories
        : estimateActiveFromSteps(stats.steps, metrics.weightKg) + workoutKcal;
    return CalorieBreakdown(
      bmr: restingKcal,
      active: active,
      activeIsEstimated: !measured,
      metricsEstimated: metrics.isEstimated,
    );
  }
}
