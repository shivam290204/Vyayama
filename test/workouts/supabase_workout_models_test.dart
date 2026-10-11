import 'package:fitbuddy/features/dashboard/data/daily_stats.dart';
import 'package:fitbuddy/features/workouts/data/workout_log.dart';
import 'package:fitbuddy/features/workouts/data/workout_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WorkoutPlan DB Schema Serialization', () {
    test('serializes and deserializes plan with days and exercises', () {
      const exercise = PlanExercise(
        id: 'pe-1',
        exerciseId: 'ex-pushup',
        sortOrder: 0,
        sets: 3,
        reps: 12,
        durationSec: null,
        restSec: 60,
      );

      const day = PlanDay(
        id: 'pd-1',
        dayNumber: 1,
        name: 'Chest Day',
        exercises: [exercise],
      );

      const plan = WorkoutPlan(
        id: 'plan-1',
        title: 'Full Body Intro',
        goal: 'gain',
        level: 'beginner',
        isSystem: false,
        ownerId: 'user-42',
        days: [day],
      );

      final json = plan.toJson();
      expect(json['id'], 'plan-1');
      expect(json['title'], 'Full Body Intro');
      expect(json['goal'], 'gain');
      expect(json['level'], 'beginner');
      expect(json['is_system'], false);
      expect(json['owner_id'], 'user-42');
      expect((json['days'] as List).length, 1);

      final deserialized = WorkoutPlan.fromJson(json);
      expect(deserialized.id, plan.id);
      expect(deserialized.title, plan.title);
      expect(deserialized.days.length, 1);
      expect(deserialized.days.first.exercises.length, 1);
      expect(deserialized.days.first.exercises.first.sets, 3);
      expect(deserialized.days.first.exercises.first.reps, 12);
      expect(deserialized.days.first.exercises.first.restSec, 60);
    });

    test('dayForWeekday retrieves the correct day', () {
      const dayMonday = PlanDay(
        id: 'd-1',
        dayNumber: 1,
        name: 'Monday Workout',
        exercises: [],
      );
      const plan = WorkoutPlan(
        id: 'p-1',
        title: 'Split',
        days: [dayMonday],
      );

      expect(plan.dayForWeekday(1)?.name, 'Monday Workout');
      expect(plan.dayForWeekday(2), isNull); // Tuesday rest
    });
  });

  group('WorkoutLog DB Schema Serialization', () {
    test('serializes and deserializes workout log', () {
      final now = DateTime.utc(2026, 10, 11, 10, 30);
      final log = WorkoutLog(
        id: 'log-101',
        userId: 'user-42',
        planDayId: 'pd-1',
        completedAt: now,
        durationMin: 45,
        caloriesBurned: 320,
      );

      final json = log.toJson();
      expect(json['id'], 'log-101');
      expect(json['user_id'], 'user-42');
      expect(json['plan_day_id'], 'pd-1');
      expect(json['duration_min'], 45);
      expect(json['calories_burned'], 320);

      final deserialized = WorkoutLog.fromJson(json);
      expect(deserialized.id, log.id);
      expect(deserialized.userId, log.userId);
      expect(deserialized.durationMin, 45);
      expect(deserialized.caloriesBurned, 320);
      expect(deserialized.completedAt.isAtSameMomentAs(now), true);
    });
  });

  group('DailyStats DB Schema Serialization', () {
    test('serializes and deserializes daily stats', () {
      final date = DateTime(2026, 10, 11);
      final stats = DailyStats(
        id: 'ds-1',
        userId: 'user-42',
        date: date,
        steps: 8500,
        calories: 420,
        activeMinutes: 45,
      );

      final json = stats.toJson();
      expect(json['id'], 'ds-1');
      expect(json['user_id'], 'user-42');
      expect(json['date'], '2026-10-11');
      expect(json['steps'], 8500);
      expect(json['calories'], 420);
      expect(json['active_minutes'], 45);

      final deserialized = DailyStats.fromJson(json);
      expect(deserialized.id, stats.id);
      expect(deserialized.userId, stats.userId);
      expect(deserialized.date.year, 2026);
      expect(deserialized.date.month, 10);
      expect(deserialized.date.day, 11);
      expect(deserialized.steps, 8500);
      expect(deserialized.calories, 420);
      expect(deserialized.activeMinutes, 45);
      expect(deserialized.isEmpty, false);
    });

    test('detects empty stats correctly', () {
      final empty = DailyStats.empty(DateTime(2026, 10, 11));
      expect(empty.isEmpty, true);
    });
  });
}
