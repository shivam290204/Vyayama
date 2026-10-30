import 'package:flutter_test/flutter_test.dart';

import 'package:fitbuddy/features/intelligence/domain/models/journey_recommendation.dart';
import 'package:fitbuddy/features/intelligence/domain/models/user_fitness_preferences.dart';
import 'package:fitbuddy/features/intelligence/domain/models/workout_difficulty_feedback.dart';
import 'package:fitbuddy/features/intelligence/logic/adaptive_planning_service.dart';
import 'package:fitbuddy/features/profile/data/profile.dart';
import 'package:fitbuddy/features/workouts/data/exercise.dart';
import 'package:fitbuddy/features/workouts/data/workout_log.dart';
import 'package:fitbuddy/features/workouts/data/workout_plan.dart';

void main() {
  group('AdaptivePlanningService Unit Tests', () {
    final fixedNow = DateTime(2026, 10, 29, 10, 0);

    final mockPlan = WorkoutPlan(
      id: 'plan_1',
      title: 'Full Body Foundations',
      level: 'beginner',
      goal: 'build_muscle',
      days: [
        PlanDay(
          id: 'day_a',
          dayNumber: 1,
          name: 'Full Body Day A',
          exercises: [
            PlanExercise(
              id: 'pe_1',
              exerciseId: 'ex_squat',
              sets: 3,
              reps: 10,
              restSec: 60,
            ),
          ],
        ),
        PlanDay(
          id: 'day_b',
          dayNumber: 3,
          name: 'Full Body Day B',
          exercises: [
            PlanExercise(
              id: 'pe_2',
              exerciseId: 'ex_pushup',
              sets: 3,
              reps: 10,
              restSec: 60,
            ),
          ],
        ),
      ],
    );

    final mockExercises = [
      const Exercise(
        id: 'ex_squat',
        name: 'Bodyweight Squat',
        muscleGroup: 'legs',
        equipment: 'none',
        instructions: ['Stand with feet shoulder-width apart.'],
        commonMistakes: ['Knees caving inward.'],
        contraindications: ['knee'],
        met: 5.0,
      ),
      const Exercise(
        id: 'ex_pushup',
        name: 'Push Up',
        muscleGroup: 'chest',
        equipment: 'none',
        instructions: ['Keep back straight and push up.'],
        commonMistakes: ['Flaring elbows.'],
        contraindications: ['shoulder'],
        met: 4.0,
      ),
    ];

    test('Scenario A: Consistent user with manageable exertion receives Progressive Overload', () {
      final logs = [
        WorkoutLog(
          id: 'l1',
          userId: 'u1',
          planDayId: 'day_a',
          completedAt: fixedNow.subtract(const Duration(days: 1)),
          durationMin: 30,
          caloriesBurned: 180,
        ),
        WorkoutLog(
          id: 'l2',
          userId: 'u1',
          planDayId: 'day_b',
          completedAt: fixedNow.subtract(const Duration(days: 3)),
          durationMin: 30,
          caloriesBurned: 180,
        ),
      ];

      final feedback = [
        WorkoutDifficultyFeedback(
          id: 'f1',
          userId: 'u1',
          planDayId: 'day_a',
          completedAt: fixedNow.subtract(const Duration(days: 1)),
          rating: WorkoutDifficultyRating.justRight,
          createdAt: fixedNow.subtract(const Duration(days: 1)),
        ),
      ];

      final ctx = AdaptiveJourneyContext(
        now: fixedNow,
        preferences: UserFitnessPreferences.defaults(userId: 'u1'),
        profile: const Profile(id: 'u1', goal: 'build_muscle'),
        activePlan: mockPlan,
        workoutLogs: logs,
        recentStats: const [],
        recentFeedback: feedback,
        conditionTags: const {},
        exerciseLibrary: mockExercises,
      );

      final rec = AdaptivePlanningService.evaluateJourney(ctx);

      expect(rec.journeyStatus, JourneyStatus.progressingSteadily);
      expect(rec.suggestedDifficulty, 'Progressive Overload');
      expect(rec.isRecovery, isFalse);
      expect(rec.recommendationReason, contains('consistent'));
      expect(rec.completedSessionsThisWeek, 2);
    });

    test('Scenario B: User misses several days receives Gentle Restart without guilt', () {
      final logs = [
        WorkoutLog(
          id: 'l_old',
          userId: 'u1',
          planDayId: 'day_a',
          completedAt: fixedNow.subtract(const Duration(days: 6)),
          durationMin: 30,
          caloriesBurned: 150,
        ),
      ];

      final ctx = AdaptiveJourneyContext(
        now: fixedNow,
        preferences: UserFitnessPreferences.defaults(userId: 'u1'),
        profile: const Profile(id: 'u1', goal: 'general_fitness'),
        activePlan: mockPlan,
        workoutLogs: logs,
        recentStats: const [],
        recentFeedback: const [],
        conditionTags: const {},
        exerciseLibrary: mockExercises,
      );

      final rec = AdaptivePlanningService.evaluateJourney(ctx);

      expect(rec.journeyStatus, JourneyStatus.momentumRestart);
      expect(rec.suggestedDifficulty, 'Manageable Restart');
      expect(rec.suggestedDurationMinutes, 15); // scaled restart duration
      expect(rec.recommendationReason, contains('gentle, low-pressure restart'));
      expect(rec.recommendationReason, isNot(contains('failed')));
      expect(rec.recommendationReason, isNot(contains('missed')));
    });

    test('Scenario C: Recent Too Hard feedback triggers Deload / Active Recovery', () {
      final logs = [
        WorkoutLog(
          id: 'l1',
          userId: 'u1',
          planDayId: 'day_a',
          completedAt: fixedNow.subtract(const Duration(hours: 18)),
          durationMin: 35,
          caloriesBurned: 220,
        ),
      ];

      final feedback = [
        WorkoutDifficultyFeedback(
          id: 'f_hard',
          userId: 'u1',
          planDayId: 'day_a',
          completedAt: fixedNow.subtract(const Duration(hours: 18)),
          rating: WorkoutDifficultyRating.tooHard,
          createdAt: fixedNow.subtract(const Duration(hours: 18)),
        ),
      ];

      final ctx = AdaptiveJourneyContext(
        now: fixedNow,
        preferences: UserFitnessPreferences.defaults(userId: 'u1'),
        profile: const Profile(id: 'u1', goal: 'build_muscle'),
        activePlan: mockPlan,
        workoutLogs: logs,
        recentStats: const [],
        recentFeedback: feedback,
        conditionTags: const {},
        exerciseLibrary: mockExercises,
      );

      final rec = AdaptivePlanningService.evaluateJourney(ctx);

      expect(rec.journeyStatus, JourneyStatus.activeRecovery);
      expect(rec.isRecovery, isTrue);
      expect(rec.recommendationReason, contains('previous workout was difficult'));
      expect(rec.suggestedDifficulty, contains('Gentle Recovery'));
    });

    test('Scenario D: Respects user-configured daily workout duration', () {
      final shortPrefs = UserFitnessPreferences(
        userId: 'u1',
        dailyWorkoutMinutes: 15,
        availableEquipment: const ['none'],
      );

      final ctx = AdaptiveJourneyContext(
        now: fixedNow,
        preferences: shortPrefs,
        profile: const Profile(id: 'u1', goal: 'maintain'),
        activePlan: mockPlan,
        workoutLogs: const [],
        recentStats: const [],
        recentFeedback: const [],
        conditionTags: const {},
        exerciseLibrary: mockExercises,
      );

      final rec = AdaptivePlanningService.evaluateJourney(ctx);

      expect(rec.suggestedDurationMinutes, 15);
      expect(rec.recommendationReason, contains('15-minute'));
    });

    test('Scenario E: Health contraindications are filtered with PlanAdapter notes', () {
      final ctx = AdaptiveJourneyContext(
        now: fixedNow,
        preferences: UserFitnessPreferences.defaults(userId: 'u1'),
        profile: const Profile(id: 'u1', goal: 'stay_fit'),
        activePlan: mockPlan,
        workoutLogs: const [],
        recentStats: const [],
        recentFeedback: const [],
        conditionTags: const {'knee'}, // contraindicates ex_squat
        exerciseLibrary: mockExercises,
      );

      final rec = AdaptivePlanningService.evaluateJourney(ctx);

      expect(rec.adaptationNotes, isNotEmpty);
      expect(rec.adaptationNotes.any((n) => n.contains('Bodyweight Squat')), isTrue);
    });

    test('3 consecutive workout days triggers Active Recovery regardless of streak', () {
      final logs = [
        WorkoutLog(
          id: 'l1',
          userId: 'u1',
          planDayId: 'day_a',
          completedAt: fixedNow.subtract(const Duration(hours: 2)),
          durationMin: 30,
          caloriesBurned: 180,
        ),
        WorkoutLog(
          id: 'l2',
          userId: 'u1',
          planDayId: 'day_b',
          completedAt: fixedNow.subtract(const Duration(days: 1)),
          durationMin: 30,
          caloriesBurned: 180,
        ),
        WorkoutLog(
          id: 'l3',
          userId: 'u1',
          planDayId: 'day_a',
          completedAt: fixedNow.subtract(const Duration(days: 2)),
          durationMin: 30,
          caloriesBurned: 180,
        ),
      ];

      final ctx = AdaptiveJourneyContext(
        now: fixedNow,
        preferences: UserFitnessPreferences.defaults(userId: 'u1'),
        profile: const Profile(id: 'u1', goal: 'build_muscle'),
        activePlan: mockPlan,
        workoutLogs: logs,
        recentStats: const [],
        recentFeedback: const [],
        conditionTags: const {},
        exerciseLibrary: mockExercises,
      );

      final rec = AdaptivePlanningService.evaluateJourney(ctx);

      expect(rec.journeyStatus, JourneyStatus.activeRecovery);
      expect(rec.isRecovery, isTrue);
      expect(rec.recommendationReason, contains('3 workout days in a row'));
    });
  });
}

