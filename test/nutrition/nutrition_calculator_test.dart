import 'package:fitbuddy/features/nutrition/domain/nutrition_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('bmr (Mifflin-St Jeor)', () {
    test('male', () {
      final value = NutritionCalculator.bmr(
        sex: NutritionSex.male,
        weightKg: 70,
        heightCm: 175,
        age: 30,
      );
      expect(value, closeTo(1648.75, 0.01));
    });

    test('female', () {
      final value = NutritionCalculator.bmr(
        sex: NutritionSex.female,
        weightKg: 60,
        heightCm: 165,
        age: 25,
      );
      expect(value, closeTo(1345.25, 0.01));
    });

    test('other is the average of male and female', () {
      final value = NutritionCalculator.bmr(
        sex: NutritionSex.other,
        weightKg: 60,
        heightCm: 165,
        age: 25,
      );
      expect(value, closeTo((1511.25 + 1345.25) / 2, 0.01));
    });

    test('rejects non-positive input', () {
      expect(
        () => NutritionCalculator.bmr(
          sex: NutritionSex.male,
          weightKg: 0,
          heightCm: 170,
          age: 30,
        ),
        throwsArgumentError,
      );
    });
  });

  group('tdee', () {
    test('applies the activity factor', () {
      expect(
        NutritionCalculator.tdee(1648.75, ActivityLevel.moderate),
        closeTo(2555.56, 0.01),
      );
      expect(NutritionCalculator.tdee(1000, ActivityLevel.sedentary), 1200);
      expect(NutritionCalculator.tdee(1000, ActivityLevel.light), 1375);
      expect(NutritionCalculator.tdee(1000, ActivityLevel.active), 1725);
    });
  });

  group('estimate', () {
    CalorieEstimate maleEstimate(NutritionGoal goal) =>
        NutritionCalculator.estimate(
          sex: NutritionSex.male,
          weightKg: 70,
          heightCm: 175,
          age: 30,
          activity: ActivityLevel.moderate,
          goal: goal,
        );

    test('lose is about 15% below TDEE and forms a range', () {
      final e = maleEstimate(NutritionGoal.lose);
      expect(e.targetKcal, closeTo(2172, 6));
      expect(e.lowKcal, lessThan(e.targetKcal));
      expect(e.highKcal, greaterThan(e.targetKcal));
      expect(e.floorApplied, isFalse);
      expect(e.weightLossRestricted, isFalse);
    });

    test('gain is about 10% above TDEE', () {
      expect(maleEstimate(NutritionGoal.gain).targetKcal, closeTo(2811, 6));
    });

    test('maintain equals TDEE', () {
      expect(
        maleEstimate(NutritionGoal.maintain).targetKcal,
        closeTo(2555.56, 6),
      );
    });

    test('female floor of 1200 kcal is applied for weight loss', () {
      final e = NutritionCalculator.estimate(
        sex: NutritionSex.female,
        weightKg: 50,
        heightCm: 150,
        age: 50,
        activity: ActivityLevel.sedentary,
        goal: NutritionGoal.lose,
      );
      expect(e.targetKcal, 1200);
      expect(e.lowKcal, greaterThanOrEqualTo(1200));
      expect(e.floorApplied, isTrue);
    });

    test('male floor of 1500 kcal is applied for weight loss', () {
      final e = NutritionCalculator.estimate(
        sex: NutritionSex.male,
        weightKg: 55,
        heightCm: 160,
        age: 60,
        activity: ActivityLevel.sedentary,
        goal: NutritionGoal.lose,
      );
      expect(e.targetKcal, 1500);
      expect(e.floorApplied, isTrue);
    });

    test('floor is not applied for maintain or gain', () {
      final e = NutritionCalculator.estimate(
        sex: NutritionSex.female,
        weightKg: 50,
        heightCm: 150,
        age: 50,
        activity: ActivityLevel.sedentary,
        goal: NutritionGoal.maintain,
      );
      expect(e.floorApplied, isFalse);
      expect(e.targetKcal, lessThan(1300));
    });

    test('weight loss is replaced with maintenance under 18', () {
      final minor = NutritionCalculator.estimate(
        sex: NutritionSex.female,
        weightKg: 60,
        heightCm: 165,
        age: 17,
        activity: ActivityLevel.light,
        goal: NutritionGoal.lose,
      );
      final maintain = NutritionCalculator.estimate(
        sex: NutritionSex.female,
        weightKg: 60,
        heightCm: 165,
        age: 17,
        activity: ActivityLevel.light,
        goal: NutritionGoal.maintain,
      );
      expect(minor.weightLossRestricted, isTrue);
      expect(minor.effectiveGoal, NutritionGoal.maintain);
      expect(minor.targetKcal, maintain.targetKcal);
    });

    test('effectiveGoal only changes lose for minors', () {
      expect(
        NutritionCalculator.effectiveGoal(NutritionGoal.lose, 17),
        NutritionGoal.maintain,
      );
      expect(
        NutritionCalculator.effectiveGoal(NutritionGoal.lose, 18),
        NutritionGoal.lose,
      );
      expect(
        NutritionCalculator.effectiveGoal(NutritionGoal.gain, 15),
        NutritionGoal.gain,
      );
      expect(
        NutritionCalculator.effectiveGoal(NutritionGoal.lose, null),
        NutritionGoal.lose,
      );
    });
  });

  group('macros', () {
    test('lose uses 30/40/30', () {
      final m = NutritionCalculator.macros(
        kcal: 2000,
        goal: NutritionGoal.lose,
      );
      expect(m.proteinG, 150);
      expect(m.carbG, 200);
      expect(m.fatG, 67);
    });

    test('percentages add up to 100 for every goal', () {
      for (final goal in NutritionGoal.values) {
        final m = NutritionCalculator.macros(kcal: 2000, goal: goal);
        expect(m.proteinPct + m.carbPct + m.fatPct, 100);
      }
    });
  });

  group('water', () {
    test('scales with weight', () {
      expect(NutritionCalculator.dailyWaterGlasses(60), 8);
    });

    test('is clamped between 6 and 12 glasses', () {
      expect(NutritionCalculator.dailyWaterGlasses(40), 6);
      expect(NutritionCalculator.dailyWaterGlasses(120), 12);
    });
  });

  group('parsing', () {
    test('sex parsing falls back to other', () {
      expect(NutritionSex.parse('male'), NutritionSex.male);
      expect(NutritionSex.parse('female'), NutritionSex.female);
      expect(NutritionSex.parse('prefer_not'), NutritionSex.other);
      expect(NutritionSex.parse(null), NutritionSex.other);
    });

    test('goal parsing', () {
      expect(NutritionGoal.tryParse('gain'), NutritionGoal.gain);
      expect(NutritionGoal.tryParse('nope'), isNull);
    });
  });
}
