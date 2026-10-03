import 'package:fitbuddy/features/workouts/logic/default_plan_picker.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  final loseB = makePlan(const [], id: 'loseB', goal: 'lose');
  final gainB = makePlan(const [], id: 'gainB', goal: 'gain');
  final gainI =
      makePlan(const [], id: 'gainI', goal: 'gain', level: 'intermediate');
  final maintainB = makePlan(const [], id: 'maintainB', goal: 'maintain');
  final custom =
      makePlan(const [], id: 'mine', goal: 'gain', isSystem: false);
  final all = [loseB, gainB, gainI, maintainB, custom];

  test('picks the exact goal and level', () {
    expect(pickDefaultPlan(plans: all, goal: 'gain', level: 'intermediate')?.id,
        'gainI');
  });

  test('falls back to the beginner plan for the goal', () {
    expect(pickDefaultPlan(plans: all, goal: 'lose', level: 'intermediate')?.id,
        'loseB');
  });

  test('accepts enum-like values such as Goal.lose', () {
    expect(pickDefaultPlan(plans: all, goal: 'Goal.gain', level: null)?.id,
        'gainB');
  });

  test('defaults to maintain when the goal is unknown', () {
    expect(pickDefaultPlan(plans: all, goal: null, level: null)?.id,
        'maintainB');
  });

  test('never recommends a weight-loss plan to under-18s', () {
    expect(
      pickDefaultPlan(plans: all, goal: 'lose', level: 'beginner', age: 17)?.id,
      'maintainB',
    );
  });

  test('ignores custom plans', () {
    expect(pickDefaultPlan(plans: [custom], goal: 'gain', level: 'beginner'),
        isNull);
  });

  test('returns null when there are no plans', () {
    expect(pickDefaultPlan(plans: const [], goal: 'lose', level: 'beginner'),
        isNull);
  });

  test('falls back to the first system plan when nothing else matches', () {
    final only = makePlan(const [], id: 'x', goal: 'lose', level: 'intermediate');
    expect(pickDefaultPlan(plans: [only], goal: 'gain', level: 'beginner')?.id,
        'x');
  });
}
