import 'package:fitbuddy/features/workouts/data/workout_plan.dart';
import 'package:fitbuddy/features/workouts/logic/plan_editing.dart';
import 'package:fitbuddy/features/workouts/logic/plan_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  test('addDay uses the first free weekday and stops at seven', () {
    var plan = WorkoutPlan.draft();
    plan = plan.addDay().addDay();
    expect(plan.days.map((d) => d.dayNumber), [1, 2]);
    plan = plan.removeDay(plan.days.first.id).addDay();
    expect(plan.days.map((d) => d.dayNumber), [1, 2]);
    for (var i = 0; i < 10; i++) {
      plan = plan.addDay();
    }
    expect(plan.days.length, kMaxPlanDays);
  });

  test('setDayNumber refuses a weekday that is already used', () {
    final plan = WorkoutPlan.draft().addDay().addDay();
    final moved = plan.setDayNumber(plan.days[1].id, 1);
    expect(moved.days.map((d) => d.dayNumber), [1, 2]);
    final ok = plan.setDayNumber(plan.days[1].id, 5);
    expect(ok.days.map((d) => d.dayNumber), [1, 5]);
  });

  test('addExercise, reorder and remove keep sort order contiguous', () {
    var plan = WorkoutPlan.draft().addDay();
    final dayId = plan.days.single.id;
    plan = plan
        .addExercise(dayId, ex('a', 'legs'))
        .addExercise(dayId, ex('b', 'chest'))
        .addExercise(dayId, ex('c', 'back'));
    plan = plan.reorderExercise(dayId, 0, 3); // drag first item to the end
    expect(plan.days.single.exercises.map((e) => e.exerciseId), ['b', 'c', 'a']);
    expect(plan.days.single.exercises.map((e) => e.sortOrder), [0, 1, 2]);
    plan = plan.removeExercise(dayId, plan.days.single.exercises.first.id);
    expect(plan.days.single.exercises.map((e) => e.sortOrder), [0, 1]);
  });

  test('cardio and stretching default to timed exercises', () {
    var plan = WorkoutPlan.draft().addDay();
    plan = plan.addExercise(plan.days.single.id, ex('walk', 'cardio'));
    final added = plan.days.single.exercises.single;
    expect(added.isTimed, isTrue);
    expect(added.reps, isNull);
  });

  test('validationError explains what is missing', () {
    var plan = WorkoutPlan.draft();
    expect(plan.validationError, contains('name'));
    plan = plan.copyWith(title: 'Mine');
    expect(plan.validationError, contains('day'));
    plan = plan.addDay();
    expect(plan.validationError, contains('exercise'));
    plan = plan.addExercise(plan.days.single.id, ex('a', 'legs'));
    expect(plan.validationError, isNull);
  });

  test('nextWorkoutDay returns today or the next scheduled day', () {
    final plan = makePlan([
      [pe('a', 'a')], // Monday
      [pe('b', 'b')], // Tuesday
    ]);
    final wednesday = DateTime(2026, 9, 30); // a Wednesday
    expect(nextWorkoutDay(plan, from: wednesday)?.dayNumber, 1);
    final tuesday = DateTime(2026, 9, 29);
    expect(nextWorkoutDay(plan, from: tuesday)?.dayNumber, 2);
  });
}
