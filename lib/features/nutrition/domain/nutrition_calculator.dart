/// Biological sex used by the Mifflin-St Jeor formula.
enum NutritionSex {
  /// Male formula.
  male,

  /// Female formula.
  female,

  /// Average of the male and female results.
  other;

  /// Parses `male` / `female`; anything else becomes [other].
  static NutritionSex parse(String? value) => switch (value) {
        'male' => NutritionSex.male,
        'female' => NutritionSex.female,
        _ => NutritionSex.other,
      };
}

/// Weight goal with its calorie adjustment.
enum NutritionGoal {
  /// Lose weight: minus 15%.
  lose(0.85, 'Lose'),

  /// Gain weight: plus 10%.
  gain(1.10, 'Gain'),

  /// Maintain weight: no change.
  maintain(1.0, 'Maintain');

  const NutritionGoal(this.multiplier, this.label);

  /// Multiplier applied to TDEE.
  final double multiplier;

  /// Friendly label.
  final String label;

  /// Parses `lose`, `gain` or `maintain`; returns null otherwise.
  static NutritionGoal? tryParse(String? value) {
    for (final goal in values) {
      if (goal.name == value) return goal;
    }
    return null;
  }
}

/// Activity level with its TDEE factor.
enum ActivityLevel {
  /// Little or no exercise.
  sedentary(1.2, 'Sedentary', 'Little or no exercise'),

  /// Light exercise.
  light(1.375, 'Light', 'Exercise 1 to 3 days a week'),

  /// Moderate exercise.
  moderate(1.55, 'Moderate', 'Exercise 3 to 5 days a week'),

  /// Hard exercise.
  active(1.725, 'Active', 'Hard exercise 6 to 7 days a week');

  const ActivityLevel(this.factor, this.label, this.description);

  /// Multiplier applied to BMR.
  final double factor;

  /// Friendly label.
  final String label;

  /// Short explanation.
  final String description;
}

/// Suggested split of daily calories into macros.
class MacroSplit {
  /// Creates a macro split.
  const MacroSplit({
    required this.proteinPct,
    required this.carbPct,
    required this.fatPct,
    required this.proteinG,
    required this.carbG,
    required this.fatG,
  });

  /// Protein share of calories (percent).
  final int proteinPct;

  /// Carbohydrate share of calories (percent).
  final int carbPct;

  /// Fat share of calories (percent).
  final int fatPct;

  /// Protein in grams.
  final int proteinG;

  /// Carbohydrates in grams.
  final int carbG;

  /// Fat in grams.
  final int fatG;
}

/// Result of a calorie estimate. Always an estimate, never medical advice.
class CalorieEstimate {
  /// Creates an estimate.
  const CalorieEstimate({
    required this.bmr,
    required this.tdee,
    required this.targetKcal,
    required this.lowKcal,
    required this.highKcal,
    required this.effectiveGoal,
    required this.floorApplied,
    required this.weightLossRestricted,
  });

  /// Resting energy (Mifflin-St Jeor).
  final double bmr;

  /// BMR times the activity factor.
  final double tdee;

  /// Central daily target, rounded to 10 kcal.
  final int targetKcal;

  /// Lower end of the range.
  final int lowKcal;

  /// Upper end of the range.
  final int highKcal;

  /// Goal actually applied.
  final NutritionGoal effectiveGoal;

  /// True when the safe minimum replaced a lower number.
  final bool floorApplied;

  /// True when a weight-loss goal was changed to maintenance (under 18).
  final bool weightLossRestricted;
}

/// Pure Dart nutrition maths (spec Sections 9.1 and 9.2).
class NutritionCalculator {
  const NutritionCalculator._();

  /// Safe minimum for weight-loss targets (kcal per day).
  static int safeFloorKcal(NutritionSex sex) => switch (sex) {
        NutritionSex.female => 1200,
        NutritionSex.male => 1500,
        NutritionSex.other => 1350,
      };

  /// Mifflin-St Jeor basal metabolic rate.
  static double bmr({
    required NutritionSex sex,
    required double weightKg,
    required double heightCm,
    required int age,
  }) {
    if (weightKg <= 0 || heightCm <= 0 || age <= 0) {
      throw ArgumentError('weight, height and age must be positive');
    }
    final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    return switch (sex) {
      NutritionSex.male => base + 5,
      NutritionSex.female => base - 161,
      NutritionSex.other => ((base + 5) + (base - 161)) / 2,
    };
  }

  /// Total daily energy expenditure.
  static double tdee(double bmr, ActivityLevel level) => bmr * level.factor;

  /// Weight loss is never applied to users under 18.
  static NutritionGoal effectiveGoal(NutritionGoal goal, int? age) {
    if (goal == NutritionGoal.lose && age != null && age < 18) {
      return NutritionGoal.maintain;
    }
    return goal;
  }

  /// Calorie target as a rounded range, with safe floors.
  static CalorieEstimate estimate({
    required NutritionSex sex,
    required double weightKg,
    required double heightCm,
    required int age,
    required ActivityLevel activity,
    required NutritionGoal goal,
  }) {
    final applied = effectiveGoal(goal, age);
    final restricted = applied != goal;
    final resting = bmr(
      sex: sex,
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
    );
    final total = tdee(resting, activity);

    var raw = total * applied.multiplier;
    var floorApplied = false;
    final floor = safeFloorKcal(sex);
    if (applied == NutritionGoal.lose && raw < floor) {
      raw = floor.toDouble();
      floorApplied = true;
    }

    var low = _round10(raw * 0.95);
    final high = _round10(raw * 1.05);
    if (applied == NutritionGoal.lose && low < floor) low = floor;

    return CalorieEstimate(
      bmr: resting,
      tdee: total,
      targetKcal: _round10(raw),
      lowKcal: low,
      highKcal: high,
      effectiveGoal: applied,
      floorApplied: floorApplied,
      weightLossRestricted: restricted,
    );
  }

  /// A general macro split for [kcal] and [goal].
  static MacroSplit macros({required int kcal, required NutritionGoal goal}) {
    final (protein, carbs, fat) = switch (goal) {
      NutritionGoal.lose => (30, 40, 30),
      NutritionGoal.gain => (25, 50, 25),
      NutritionGoal.maintain => (20, 50, 30),
    };
    return MacroSplit(
      proteinPct: protein,
      carbPct: carbs,
      fatPct: fat,
      proteinG: (kcal * protein / 100 / 4).round(),
      carbG: (kcal * carbs / 100 / 4).round(),
      fatG: (kcal * fat / 100 / 9).round(),
    );
  }

  /// Rough daily water target in 250 ml glasses (between 6 and 12).
  static int dailyWaterGlasses(double weightKg) {
    final glasses = (weightKg * 33 / 250).round();
    return glasses.clamp(6, 12).toInt();
  }

  static int _round10(double value) => (value / 10).round() * 10;
}
