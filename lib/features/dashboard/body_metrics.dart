import 'package:flutter/foundation.dart';

/// Sex used by the BMR formula. `other` averages male and female.
enum BiologicalSex {
  /// Male formula.
  male,

  /// Female formula.
  female,

  /// Average of both (also used for "prefer not to say").
  other,
}

/// The user's goal (column `profiles.goal`).
enum FitGoal {
  /// Lose weight.
  lose,

  /// Gain weight.
  gain,

  /// Stay as is.
  maintain,
}

/// Body numbers used for calorie estimates. Pure Dart.
@immutable
class BodyMetrics {
  /// Creates the metrics.
  const BodyMetrics({
    required this.sex,
    required this.weightKg,
    required this.heightCm,
    required this.age,
    required this.goal,
    this.isEstimated = false,
    this.isMinor = false,
  });

  /// Neutral values used when the profile is missing or incomplete.
  static const BodyMetrics defaults = BodyMetrics(
    sex: BiologicalSex.other,
    weightKg: 70,
    heightCm: 170,
    age: 30,
    goal: FitGoal.maintain,
    isEstimated: true,
  );

  /// Reads the Profile model from the profile feature.
  ///
  /// Takes `Object?` and reads `gender`, `goal`, `weightKg`, `heightCm` and
  /// `age` defensively, so it works whether `gender` and `goal` are strings
  /// or enums. Missing or implausible numbers fall back to [defaults] and
  /// set [isEstimated].
  factory BodyMetrics.fromProfile(Object? profile) {
    if (profile == null) return defaults;
    final dynamic p = profile;
    final weight = _safe<double>(() => (p.weightKg as num?)?.toDouble());
    final height = _safe<double>(() => (p.heightCm as num?)?.toDouble());
    final age = _safe<int>(() => (p.age as num?)?.toInt());
    final gender = _safe<Object>(() => p.gender as Object?);
    final goal = _safe<Object>(() => p.goal as Object?);

    final okWeight = weight != null && weight >= 20 && weight <= 300;
    final okHeight = height != null && height >= 100 && height <= 250;
    final okAge = age != null && age >= 13 && age <= 100;

    return BodyMetrics(
      sex: parseSex(gender),
      weightKg: okWeight ? weight : defaults.weightKg,
      heightCm: okHeight ? height : defaults.heightCm,
      age: okAge ? age : defaults.age,
      goal: parseGoal(goal),
      isEstimated: !(okWeight && okHeight && okAge),
      isMinor: okAge && age < 18,
    );
  }

  /// Sex for the BMR formula.
  final BiologicalSex sex;

  /// Weight in kilograms.
  final double weightKg;

  /// Height in centimetres.
  final double heightCm;

  /// Age in years.
  final int age;

  /// The user's goal.
  final FitGoal goal;

  /// True when some numbers are defaults, so results are rougher.
  final bool isEstimated;

  /// True when the user is known to be under 18.
  final bool isMinor;

  /// Parses `male`, `female`, an enum, or anything else (to [BiologicalSex.other]).
  static BiologicalSex parseSex(Object? raw) {
    final s = raw?.toString().toLowerCase() ?? '';
    if (s.contains('female')) return BiologicalSex.female;
    if (s.contains('male')) return BiologicalSex.male;
    return BiologicalSex.other;
  }

  /// Parses `lose`, `gain`, `maintain` (strings or enums); default maintain.
  static FitGoal parseGoal(Object? raw) {
    final s = raw?.toString().toLowerCase() ?? '';
    if (s.contains('lose')) return FitGoal.lose;
    if (s.contains('gain')) return FitGoal.gain;
    return FitGoal.maintain;
  }

  static T? _safe<T>(T? Function() read) {
    try {
      return read();
    } catch (_) {
      return null;
    }
  }
}
