import 'package:flutter_test/flutter_test.dart';

import 'package:fitbuddy/features/intelligence/logic/adaptive_difficulty_policy.dart';
import 'package:fitbuddy/features/workouts/data/workout_plan.dart';
import 'package:fitbuddy/features/workouts/logic/progression_model_interface.dart';

void main() {
  group('AdaptiveDifficultyPolicy Unit Tests', () {
    const policy = AdaptiveDifficultyPolicy();
    final dummyPlan = WorkoutPlan(
      id: 'p1',
      title: 'Strength Plan',
      level: 'intermediate',
      goal: 'strength',
      days: const [],
    );

    test('High adherence and manageable RPE triggers Increase Load', () async {
      final rec = await policy.evaluatePlanAdaptation(
        currentPlan: dummyPlan,
        trailingAdherence: 0.85,
        averageSessionRpe: 7.0,
      );

      expect(rec.action, ProgressionAction.increaseLoad);
      expect(rec.nextLoadKg, 2.5);
      expect(rec.rationale, contains('Strong consistency with manageable exertion'));
    });

    test('High fatigue (RPE >= 9.0) triggers Regress or Deload', () async {
      final rec = await policy.evaluatePlanAdaptation(
        currentPlan: dummyPlan,
        trailingAdherence: 0.90,
        averageSessionRpe: 9.5,
      );

      expect(rec.action, ProgressionAction.regressOrDeload);
      expect(rec.rationale, contains('very hard'));
    });

    test('Low adherence (< 50%) suggests gentle habit restart without penalizing load', () async {
      final rec = await policy.evaluatePlanAdaptation(
        currentPlan: dummyPlan,
        trailingAdherence: 0.33,
        averageSessionRpe: 7.0,
      );

      expect(rec.action, ProgressionAction.maintain);
      expect(rec.rationale, contains('restart workout'));
    });

    test('Steady baseline maintains form consolidation', () async {
      final rec = await policy.evaluatePlanAdaptation(
        currentPlan: dummyPlan,
        trailingAdherence: 0.66,
        averageSessionRpe: 7.5,
      );

      expect(rec.action, ProgressionAction.maintain);
      expect(rec.rationale, contains('Continue consolidating movement form'));
    });
  });
}

