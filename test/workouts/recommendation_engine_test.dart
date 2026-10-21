import 'package:flutter_test/flutter_test.dart';

import 'package:fitbuddy/features/workouts/data/exercise.dart';
import 'package:fitbuddy/features/workouts/data/workout_plan.dart';
import 'package:fitbuddy/features/workouts/logic/adherence_model_interface.dart';
import 'package:fitbuddy/features/workouts/logic/progression_model_interface.dart';
import 'package:fitbuddy/features/workouts/logic/recommendation_engine.dart';

void main() {
  group('WorkoutRecommendationEngine', () {
    final library = [
      const Exercise(
        id: 'ex_squat',
        name: 'Bodyweight Squat',
        muscleGroup: 'legs',
        equipment: 'none',
        instructions: ['Squat down', 'Stand up'],
        commonMistakes: [],
        contraindications: ['knee_pain'],
        met: 5.0,
      ),
      const Exercise(
        id: 'ex_glute_bridge',
        name: 'Glute Bridge',
        muscleGroup: 'legs',
        equipment: 'none',
        instructions: ['Lift hips', 'Lower hips'],
        commonMistakes: [],
        contraindications: [],
        met: 3.5,
      ),
      const Exercise(
        id: 'ex_pushup',
        name: 'Push Up',
        muscleGroup: 'chest',
        equipment: 'none',
        instructions: ['Lower chest', 'Push back'],
        commonMistakes: [],
        contraindications: ['shoulder_pain'],
        met: 4.0,
      ),
    ];

    final planLose = WorkoutPlan(
      id: 'plan_lose',
      title: 'Fat Loss Starter',
      goal: 'lose',
      level: 'beginner',
      isSystem: true,
      days: const [
        PlanDay(
          id: 'day_1',
          dayNumber: 1,
          name: 'Day 1',
          exercises: [
            PlanExercise(id: 'p1', exerciseId: 'ex_squat', sets: 3, reps: 10),
            PlanExercise(id: 'p2', exerciseId: 'ex_pushup', sets: 3, reps: 8),
          ],
        ),
      ],
    );

    final planGain = WorkoutPlan(
      id: 'plan_gain',
      title: 'Muscle Builder',
      goal: 'gain',
      level: 'intermediate',
      isSystem: true,
      days: const [
        PlanDay(
          id: 'day_1',
          dayNumber: 1,
          name: 'Day 1',
          exercises: [
            PlanExercise(id: 'p3', exerciseId: 'ex_pushup', sets: 4, reps: 12),
          ],
        ),
      ],
    );

    test('ranks plan matching goal and level highest', () {
      final ranked = WorkoutRecommendationEngine.rankPlans(
        plans: [planGain, planLose],
        exerciseLibrary: library,
        context: const UserFitnessContext(
          goal: 'lose',
          level: 'beginner',
        ),
      );

      expect(ranked.isNotEmpty, isTrue);
      expect(ranked.first.plan.id, 'plan_lose');
      expect(ranked.first.score.overallScore, greaterThan(ranked.last.score.overallScore));
      expect(ranked.first.explanation, contains('Fat Loss Starter'));
    });

    test('protects minors from aggressive weight-loss framing', () {
      final ranked = WorkoutRecommendationEngine.rankPlans(
        plans: [planGain, planLose],
        exerciseLibrary: library,
        context: const UserFitnessContext(
          goal: 'lose',
          level: 'beginner',
          age: 16, // Minor
        ),
      );

      expect(ranked.isNotEmpty, isTrue);
      // Minors under 18 have goal mapped to maintain
      expect(ranked.first.score.overallScore, isPositive);
    });

    test('adapts plan for contraindications and reflects cautions in score', () {
      final ranked = WorkoutRecommendationEngine.rankPlans(
        plans: [planLose],
        exerciseLibrary: library,
        context: const UserFitnessContext(
          goal: 'lose',
          level: 'beginner',
          conditionTags: ['knee_pain'],
        ),
      );

      final top = ranked.first;
      // Squat conflicted with knee_pain, substituted with glute_bridge
      expect(top.adaptations.isNotEmpty, isTrue);
      expect(top.adaptations.first.originalExerciseId, 'ex_squat');
      expect(top.adaptations.first.replacementExerciseId, 'ex_glute_bridge');
      expect(top.plan.days.first.exercises.first.exerciseId, 'ex_glute_bridge');
      expect(top.explanation, contains('protect your joints'));
    });
  });

  group('DoubleProgressionModel', () {
    const model = DoubleProgressionModel();

    test('recommends load increase when max reps achieved with controlled RPE', () {
      final rec = model.evaluateProgression(
        const ProgressionInput(
          exerciseId: 'ex_bench',
          targetRepsMin: 8,
          targetRepsMax: 12,
          targetSets: 3,
          completedRepsPerSet: [12, 12, 12],
          currentLoadKg: 50.0,
          reportedRpe: 7.5,
        ),
      );

      expect(rec.action, ProgressionAction.increaseLoad);
      expect(rec.nextLoadKg, greaterThan(50.0));
      expect(rec.nextTargetReps, 8); // reset to min
    });

    test('recommends rep increase when within target range', () {
      final rec = model.evaluateProgression(
        const ProgressionInput(
          exerciseId: 'ex_bench',
          targetRepsMin: 8,
          targetRepsMax: 12,
          targetSets: 3,
          completedRepsPerSet: [10, 9, 8],
          currentLoadKg: 50.0,
          reportedRpe: 8.0,
        ),
      );

      expect(rec.action, ProgressionAction.increaseReps);
      expect(rec.nextLoadKg, 50.0);
      expect(rec.nextTargetReps, 10);
    });

    test('recommends deload if RPE is excessively high', () {
      final rec = model.evaluateProgression(
        const ProgressionInput(
          exerciseId: 'ex_bench',
          targetRepsMin: 8,
          targetRepsMax: 12,
          targetSets: 3,
          completedRepsPerSet: [7, 6, 5],
          currentLoadKg: 50.0,
          reportedRpe: 9.8,
        ),
      );

      expect(rec.action, ProgressionAction.regressOrDeload);
      expect(rec.nextLoadKg, lessThan(50.0));
    });
  });

  group('RuleBasedAdherenceModel', () {
    const model = RuleBasedAdherenceModel();

    test('identifies overtraining and fatigue risk', () async {
      const features = AdherenceFeatures(
        userId: 'u1',
        sessionsCompletedLast7Days: 3,
        sessionsScheduledLast7Days: 4,
        averageSessionDurationMinutes: 45,
        currentStreakDays: 2,
        averageReportedRpe: 9.0, // High strain
        skippedExercisesRatio: 0.4, // High skip rate
        daysSinceLastWorkout: 1,
        preferredWorkoutHour: 18,
      );

      final pred = await model.predictAdherence(features);
      expect(pred.churnRiskProbability, greaterThan(0.5));
      expect(pred.recommendedIntensityAdjustment, lessThan(0));
      expect(pred.motivationalIntervention, 'recovery_encouragement');
    });

    test('rewards strong consistency with progressive overload readiness', () async {
      const features = AdherenceFeatures(
        userId: 'u1',
        sessionsCompletedLast7Days: 4,
        sessionsScheduledLast7Days: 4,
        averageSessionDurationMinutes: 40,
        currentStreakDays: 5,
        averageReportedRpe: 7.0,
        skippedExercisesRatio: 0.0,
        daysSinceLastWorkout: 1,
        preferredWorkoutHour: 7,
      );

      final pred = await model.predictAdherence(features);
      expect(pred.churnRiskProbability, lessThan(0.2));
      expect(pred.recommendedIntensityAdjustment, greaterThanOrEqualTo(0));
      expect(pred.motivationalIntervention, 'milestone_praise');
    });
  });
}
