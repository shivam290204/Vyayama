import 'package:flutter_test/flutter_test.dart';
import 'package:fitbuddy/features/profile/logic/bmi_calculator.dart';

void main() {
  group('BmiCalculator', () {
    test('calculates correct BMI for standard adult inputs', () {
      // 70 kg, 175 cm (1.75 m) -> 70 / (1.75^2) = 70 / 3.0625 = 22.857...
      final result = BmiCalculator.calculate(
        weightKg: 70.0,
        heightCm: 175.0,
        age: 25,
      );

      expect(result, isNotNull);
      expect(result!.formattedBmi, '22.9');
      expect(result.category, BmiCategory.normal);
      expect(result.categoryLabel, 'Normal weight');
      expect(result.isMinor, isFalse);
    });

    test('classifies underweight correctly', () {
      // 45 kg, 170 cm -> 45 / (1.7^2) = 15.57
      final result = BmiCalculator.calculate(
        weightKg: 45.0,
        heightCm: 170.0,
        age: 30,
      );

      expect(result, isNotNull);
      expect(result!.category, BmiCategory.underweight);
      expect(result.categoryLabel, 'Underweight');
    });

    test('classifies overweight correctly', () {
      // 80 kg, 170 cm -> 80 / (1.7^2) = 27.68
      final result = BmiCalculator.calculate(
        weightKg: 80.0,
        heightCm: 170.0,
        age: 35,
      );

      expect(result, isNotNull);
      expect(result!.category, BmiCategory.overweight);
      expect(result.categoryLabel, 'Overweight');
    });

    test('classifies obesity correctly', () {
      // 100 kg, 170 cm -> 100 / (1.7^2) = 34.60
      final result = BmiCalculator.calculate(
        weightKg: 100.0,
        heightCm: 170.0,
        age: 40,
      );

      expect(result, isNotNull);
      expect(result!.category, BmiCategory.obesity);
      expect(result.categoryLabel, 'Obesity');
    });

    test('handles pediatric age (< 20) with age-specific reference and no adult categorization', () {
      // 55 kg, 165 cm, age 16
      final result = BmiCalculator.calculate(
        weightKg: 55.0,
        heightCm: 165.0,
        age: 16,
      );

      expect(result, isNotNull);
      expect(result!.isMinor, isTrue);
      expect(result.category, BmiCategory.pediatric);
      expect(result.categoryLabel, 'Age-specific reference');
      expect(result.guidanceText, contains('growth charts'));
      expect(result.guidanceText, contains('does not assign weight categories'));
    });

    test('returns null for null, non-positive, or out-of-bounds inputs', () {
      expect(BmiCalculator.calculate(weightKg: null, heightCm: 170), isNull);
      expect(BmiCalculator.calculate(weightKg: 70, heightCm: null), isNull);
      expect(BmiCalculator.calculate(weightKg: 10, heightCm: 170), isNull); // below min weight
      expect(BmiCalculator.calculate(weightKg: 500, heightCm: 170), isNull); // above max weight
      expect(BmiCalculator.calculate(weightKg: 70, heightCm: 30), isNull); // below min height
      expect(BmiCalculator.calculate(weightKg: 70, heightCm: 300), isNull); // above max height
      expect(BmiCalculator.calculate(weightKg: double.nan, heightCm: 170), isNull);
      expect(BmiCalculator.calculate(weightKg: 70, heightCm: double.nan), isNull);
    });

    test('handles missing age gracefully (defaults to adult classification)', () {
      final result = BmiCalculator.calculate(
        weightKg: 70.0,
        heightCm: 175.0,
        age: null,
      );

      expect(result, isNotNull);
      expect(result!.isMinor, isFalse);
      expect(result.category, BmiCategory.normal);
    });
  });
}
