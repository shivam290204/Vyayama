import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitbuddy/features/intelligence/data/difficulty_feedback_repository.dart';
import 'package:fitbuddy/features/intelligence/domain/models/workout_difficulty_feedback.dart';

void main() {
  group('WorkoutDifficultyFeedback Unit Tests', () {
    test('WorkoutDifficultyRating maps to appropriate RPE values', () {
      expect(WorkoutDifficultyRating.tooEasy.estimatedRpe, 6.0);
      expect(WorkoutDifficultyRating.justRight.estimatedRpe, 7.5);
      expect(WorkoutDifficultyRating.tooHard.estimatedRpe, 9.5);
    });

    test('Json roundtrip preserves all fields', () {
      final feedback = WorkoutDifficultyFeedback(
        id: 'fb_1',
        userId: 'u_test',
        planDayId: 'day_1',
        completedAt: DateTime.utc(2026, 10, 29, 9, 30),
        rating: WorkoutDifficultyRating.tooHard,
        workoutLogId: 'log_123',
        createdAt: DateTime.utc(2026, 10, 29, 9, 35),
      );

      final json = feedback.toJson();
      final restored = WorkoutDifficultyFeedback.fromJson(json);

      expect(restored.id, 'fb_1');
      expect(restored.userId, 'u_test');
      expect(restored.planDayId, 'day_1');
      expect(restored.rating, WorkoutDifficultyRating.tooHard);
      expect(restored.workoutLogId, 'log_123');
    });
  });

  group('SharedPrefsDifficultyFeedbackRepository Tests', () {
    late SharedPreferences prefs;
    late SharedPrefsDifficultyFeedbackRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repo = SharedPrefsDifficultyFeedbackRepository(prefs: prefs);
    });

    test('Records and lists feedback newest first', () async {
      final fb1 = WorkoutDifficultyFeedback(
        id: 'fb_1',
        userId: 'u1',
        planDayId: 'day_1',
        completedAt: DateTime(2026, 10, 27, 10, 0),
        rating: WorkoutDifficultyRating.justRight,
        createdAt: DateTime(2026, 10, 27, 10, 0),
      );
      final fb2 = WorkoutDifficultyFeedback(
        id: 'fb_2',
        userId: 'u1',
        planDayId: 'day_2',
        completedAt: DateTime(2026, 10, 29, 10, 0),
        rating: WorkoutDifficultyRating.tooEasy,
        createdAt: DateTime(2026, 10, 29, 10, 0),
      );

      await repo.recordFeedback(fb1);
      await repo.recordFeedback(fb2);

      final list = await repo.getFeedback('u1');
      expect(list.length, 2);
      expect(list.first.id, 'fb_2'); // newest first
      expect(list.last.id, 'fb_1');
    });

    test('Filters by since date', () async {
      final oldFb = WorkoutDifficultyFeedback(
        id: 'fb_old',
        userId: 'u1',
        planDayId: 'day_1',
        completedAt: DateTime(2026, 10, 10),
        rating: WorkoutDifficultyRating.justRight,
        createdAt: DateTime(2026, 10, 10),
      );
      final recentFb = WorkoutDifficultyFeedback(
        id: 'fb_recent',
        userId: 'u1',
        planDayId: 'day_2',
        completedAt: DateTime(2026, 10, 28),
        rating: WorkoutDifficultyRating.tooHard,
        createdAt: DateTime(2026, 10, 28),
      );

      await repo.recordFeedback(oldFb);
      await repo.recordFeedback(recentFb);

      final filtered = await repo.getFeedback('u1', since: DateTime(2026, 10, 20));
      expect(filtered.length, 1);
      expect(filtered.first.id, 'fb_recent');
    });

    test('Prevents duplicate submissions for the same workout session', () async {
      final fb1 = WorkoutDifficultyFeedback(
        id: 'fb_1',
        userId: 'u1',
        planDayId: 'day_leg',
        workoutLogId: 'log_999',
        completedAt: DateTime(2026, 10, 29, 11, 0),
        rating: WorkoutDifficultyRating.justRight,
        createdAt: DateTime(2026, 10, 29, 11, 0),
      );

      final duplicateFb = WorkoutDifficultyFeedback(
        id: 'fb_duplicate',
        userId: 'u1',
        planDayId: 'day_leg',
        workoutLogId: 'log_999',
        completedAt: DateTime(2026, 10, 29, 11, 1),
        rating: WorkoutDifficultyRating.tooHard,
        createdAt: DateTime(2026, 10, 29, 11, 1),
      );

      await repo.recordFeedback(fb1);
      await repo.recordFeedback(duplicateFb); // should be ignored

      final list = await repo.getFeedback('u1');
      expect(list.length, 1);
      expect(list.first.id, 'fb_1');
      expect(list.first.rating, WorkoutDifficultyRating.justRight);
    });

    test('Feedback is isolated per user ID', () async {
      final fbUser1 = WorkoutDifficultyFeedback(
        id: 'fb_u1',
        userId: 'user_1',
        planDayId: 'day_1',
        completedAt: DateTime(2026, 10, 29),
        rating: WorkoutDifficultyRating.tooEasy,
        createdAt: DateTime(2026, 10, 29),
      );
      final fbUser2 = WorkoutDifficultyFeedback(
        id: 'fb_u2',
        userId: 'user_2',
        planDayId: 'day_1',
        completedAt: DateTime(2026, 10, 29),
        rating: WorkoutDifficultyRating.tooHard,
        createdAt: DateTime(2026, 10, 29),
      );

      await repo.recordFeedback(fbUser1);
      await repo.recordFeedback(fbUser2);

      final listU1 = await repo.getFeedback('user_1');
      final listU2 = await repo.getFeedback('user_2');

      expect(listU1.length, 1);
      expect(listU1.first.rating, WorkoutDifficultyRating.tooEasy);

      expect(listU2.length, 1);
      expect(listU2.first.rating, WorkoutDifficultyRating.tooHard);
    });
  });
}

