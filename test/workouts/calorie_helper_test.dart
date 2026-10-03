import 'package:fitbuddy/features/workouts/logic/calorie_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('estimateCalories', () {
    test('uses MET x weight x hours', () {
      expect(
        estimateCalories(met: 5, weightKg: 70, durationMinutes: 30),
        closeTo(175, 0.001),
      );
    });

    test('one hour at MET 8 for 60 kg is 480', () {
      expect(
        estimateCalories(met: 8, weightKg: 60, durationMinutes: 60),
        closeTo(480, 0.001),
      );
    });

    test('returns 0 for non-positive inputs', () {
      expect(estimateCalories(met: 0, weightKg: 70, durationMinutes: 30), 0);
      expect(estimateCalories(met: 5, weightKg: 0, durationMinutes: 30), 0);
      expect(estimateCalories(met: 5, weightKg: 70, durationMinutes: 0), 0);
    });
  });

  group('estimateSessionCalories', () {
    test('adds each exercise at its own MET plus rest at rest MET', () {
      final kcal = estimateSessionCalories(
        activeSegments: const [
          (met: 6.0, seconds: 600), // 6 * 60 * 1/6 h = 60
          (met: 3.0, seconds: 300), // 3 * 60 * 1/12 h = 15
        ],
        restSeconds: 600, // 1.5 * 60 * 1/6 h = 15
        weightKg: 60,
      );
      expect(kcal, 90);
    });

    test('is 0 for an empty session', () {
      expect(
        estimateSessionCalories(
          activeSegments: const [],
          restSeconds: 0,
          weightKg: 70,
        ),
        0,
      );
    });
  });
}
