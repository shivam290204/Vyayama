import 'package:fitbuddy/features/workouts/logic/plan_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  final squat = ex('squat', 'legs', contra: ['knee'], met: 5);
  final calf = ex('calf', 'legs', met: 3);
  final raise = ex('raise', 'legs', equipment: 'mat', met: 2.5);
  final pushup = ex('pushup', 'chest', contra: ['wrist']);

  group('adaptPlanForConditions', () {
    test('returns the plan untouched when there are no condition tags', () {
      final plan = makePlan([
        [pe('a', 'squat')],
      ]);
      final result = adaptPlanForConditions(plan, const [], [squat, calf]);
      expect(result.plan, same(plan));
      expect(result.notes, isEmpty);
      expect(result.hasChanges, isFalse);
    });

    test('swaps in a safe exercise from the same group, same equipment first',
        () {
      final plan = makePlan([
        [pe('a', 'squat', sets: 4, reps: 12)],
      ]);
      final result = adaptPlanForConditions(plan, ['knee'], [squat, raise, calf]);
      final first = result.plan.days.first.exercises.first;
      expect(first.exerciseId, 'calf'); // equipment "none" beats "mat"
      expect(first.sets, 4);
      expect(first.reps, 12);
      expect(result.notes.single.wasReplaced, isTrue);
      expect(result.notes.single.replacementExerciseId, 'calf');
    });

    test('never picks an exercise that is already in the same day', () {
      final plan = makePlan([
        [pe('a', 'squat'), pe('b', 'calf')],
      ]);
      final result = adaptPlanForConditions(plan, ['knee'], [squat, raise, calf]);
      final ids = result.plan.days.first.exercises.map((e) => e.exerciseId);
      expect(ids, ['raise', 'calf']);
    });

    test('removes the exercise and explains why when nothing safe exists', () {
      final lunge = ex('lunge', 'legs', contra: ['knee']);
      final plan = makePlan([
        [pe('a', 'squat'), pe('b', 'pushup')],
      ]);
      final result =
          adaptPlanForConditions(plan, ['knee'], [squat, lunge, pushup]);
      final exercises = result.plan.days.first.exercises;
      expect(exercises.map((e) => e.exerciseId), ['pushup']);
      expect(exercises.first.sortOrder, 0);
      final note = result.notes.single;
      expect(note.wasReplaced, isFalse);
      expect(note.message, contains('Removed squat'));
    });

    test('does not borrow exercises from another muscle group', () {
      final plan = makePlan([
        [pe('a', 'squat')],
      ]);
      final result = adaptPlanForConditions(plan, ['knee'], [squat, pushup]);
      expect(result.plan.days.first.exercises, isEmpty);
    });

    test('matches tags case-insensitively and ignores whitespace', () {
      final plan = makePlan([
        [pe('a', 'squat')],
      ]);
      final result = adaptPlanForConditions(plan, [' KNEE '], [squat, calf]);
      expect(result.plan.days.first.exercises.single.exerciseId, 'calf');
    });

    test('leaves exercises that are not in the library alone', () {
      final plan = makePlan([
        [pe('a', 'mystery')],
      ]);
      final result = adaptPlanForConditions(plan, ['knee'], [squat]);
      expect(result.plan.days.first.exercises.single.exerciseId, 'mystery');
      expect(result.notes, isEmpty);
    });
  });
}
