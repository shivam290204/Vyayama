import 'package:flutter/foundation.dart';

/// Standard adult BMI categories as recognized by WHO and CDC.
enum BmiCategory {
  underweight,
  normal,
  overweight,
  obesity,
  pediatric,
  unclassified,
}

/// Structured outcome of a BMI calculation.
@immutable
class BmiResult {
  const BmiResult({
    required this.bmi,
    required this.category,
    required this.categoryLabel,
    required this.isMinor,
    required this.guidanceText,
  });

  /// The raw calculated BMI.
  final double bmi;

  /// Clinical category for display and styling.
  final BmiCategory category;

  /// Human-friendly classification label.
  final String categoryLabel;

  /// True if age is specified and under 20 years old.
  final bool isMinor;

  /// Clear, evidence-based contextual guidance explaining BMI limitations.
  final String guidanceText;

  /// Formatted string rounded to 1 decimal place (e.g. "22.5").
  String get formattedBmi => bmi.toStringAsFixed(1);
}

/// Pure Dart BMI calculation engine.
///
/// Implements standard Quetelet formula:
///   BMI = weight (kg) / [height (m)]^2
///
/// Fully offline, deterministic, and includes age-specific pediatric handling.
abstract final class BmiCalculator {
  /// Minimum and maximum plausible physical human bounds for sanity filtering.
  static const double minHeightCm = 50.0;
  static const double maxHeightCm = 280.0;
  static const double minWeightKg = 15.0;
  static const double maxWeightKg = 400.0;

  /// Adult BMI classification thresholds.
  static const double normalMin = 18.5;
  static const double overweightMin = 25.0;
  static const double obesityMin = 30.0;

  /// Calculates BMI from [weightKg], [heightCm], and optional [age].
  ///
  /// Returns `null` if any input is missing, non-positive, or outside sensible bounds.
  static BmiResult? calculate({
    required double? weightKg,
    required double? heightCm,
    int? age,
  }) {
    if (weightKg == null || heightCm == null) return null;
    if (weightKg.isNaN || heightCm.isNaN) return null;
    if (weightKg < minWeightKg || weightKg > maxWeightKg) return null;
    if (heightCm < minHeightCm || heightCm > maxHeightCm) return null;

    final heightM = heightCm / 100.0;
    final bmi = weightKg / (heightM * heightM);

    if (bmi <= 0 || bmi.isInfinite || bmi.isNaN) return null;

    final isMinor = age != null && age < 20;

    if (isMinor) {
      // Under 20: adult classifications must NOT be assigned.
      // Clinical pediatric percentiles require CDC/WHO growth charts.
      return BmiResult(
        bmi: bmi,
        category: BmiCategory.pediatric,
        categoryLabel: 'Age-specific reference',
        isMinor: true,
        guidanceText:
            'For children and teenagers under 20, BMI is evaluated relative to age '
            'and sex growth charts (percentiles). Adult categories do not apply. '
            'Vyayama does not assign weight categories or recommend weight loss to minors. '
            'Please consult a pediatrician for health evaluation.',
      );
    }

    // Adult classification (age 20+ or unrecorded age)
    final BmiCategory category;
    final String label;
    final String guidance;

    if (bmi < normalMin) {
      category = BmiCategory.underweight;
      label = 'Underweight';
      guidance =
          'BMI below 18.5 indicates lower body mass relative to height. '
          'BMI is a screening metric, not a direct measure of body fat, muscle mass, '
          'or health. Consistent nutrient-dense nourishment and strength exercises '
          'can support healthy tissue.';
    } else if (bmi < overweightMin) {
      category = BmiCategory.normal;
      label = 'Normal weight';
      guidance =
          'BMI between 18.5 and 24.9 is within the standard adult healthy range. '
          'Maintaining regular physical activity and balanced nutrition supports '
          'vitality and metabolic health.';
    } else if (bmi < obesityMin) {
      category = BmiCategory.overweight;
      label = 'Overweight';
      guidance =
          'BMI between 25.0 and 29.9 indicates higher mass relative to height. '
          'Note that muscular individuals or athletes may register as overweight '
          'because BMI does not distinguish between muscle and fat. Focus on '
          'consistency, cardiorespiratory endurance, and whole foods.';
    } else {
      category = BmiCategory.obesity;
      label = 'Obesity';
      guidance =
          'BMI of 30.0 or higher. BMI serves as an initial screening indicator '
          'rather than a medical diagnosis. Gradual, sustainable activity habits '
          'and personalized guidance from a qualified healthcare professional '
          'are recommended.';
    }

    return BmiResult(
      bmi: bmi,
      category: category,
      categoryLabel: label,
      isMinor: false,
      guidanceText: guidance,
    );
  }
}
