import 'package:fitbuddy/features/nutrition/data/diet_tip.dart';
import 'package:fitbuddy/features/nutrition/data/meal.dart';
import 'package:fitbuddy/features/nutrition/domain/content_filters.dart';
import 'package:fitbuddy/features/nutrition/domain/nutrition_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

Meal _meal(
  String id,
  DietType diet, {
  List<String> goals = const <String>['maintain'],
  List<String> friendly = const <String>[],
}) =>
    Meal(
      id: id,
      name: id,
      mealType: MealType.lunch,
      dietType: diet,
      goals: goals,
      calories: 400,
      proteinG: 10,
      conditionFriendly: friendly,
    );

void main() {
  final meals = <Meal>[
    _meal('veg', DietType.veg),
    _meal('vegan', DietType.vegan),
    _meal('nonveg', DietType.nonVeg),
    _meal('lose-only', DietType.vegan, goals: <String>['lose']),
    _meal(
      'diabetes-ok',
      DietType.vegan,
      friendly: <String>['diabetes', 'high_blood_pressure'],
    ),
  ];

  List<String> ids(List<Meal> list) => list.map((m) => m.id).toList();

  group('filterMeals', () {
    test('vegan users only see vegan meals', () {
      final result = filterMeals(
        meals,
        dietType: DietType.vegan,
        goal: NutritionGoal.maintain,
        conditionKeys: const <String>[],
      );
      expect(ids(result), <String>['vegan', 'diabetes-ok']);
    });

    test('veg users see veg and vegan but never non-veg', () {
      final result = filterMeals(
        meals,
        dietType: DietType.veg,
        goal: NutritionGoal.maintain,
        conditionKeys: const <String>[],
      );
      expect(ids(result), isNot(contains('nonveg')));
      expect(ids(result), containsAll(<String>['veg', 'vegan']));
    });

    test('non-veg users see everything for the goal', () {
      final result = filterMeals(
        meals,
        dietType: DietType.nonVeg,
        goal: NutritionGoal.maintain,
        conditionKeys: const <String>[],
      );
      expect(ids(result), contains('nonveg'));
      expect(ids(result), isNot(contains('lose-only')));
    });

    test('goal filter works', () {
      final result = filterMeals(
        meals,
        dietType: DietType.vegan,
        goal: NutritionGoal.lose,
        conditionKeys: const <String>[],
      );
      expect(ids(result), <String>['lose-only']);
    });

    test('conditions keep only suitable meals', () {
      final result = filterMeals(
        meals,
        dietType: DietType.vegan,
        goal: NutritionGoal.maintain,
        conditionKeys: const <String>['diabetes', 'high_blood_pressure'],
      );
      expect(ids(result), <String>['diabetes-ok']);
    });

    test('conditions can be switched off', () {
      final result = filterMeals(
        meals,
        dietType: DietType.vegan,
        goal: NutritionGoal.maintain,
        conditionKeys: const <String>['diabetes'],
        conditionFriendlyOnly: false,
      );
      expect(ids(result), <String>['vegan', 'diabetes-ok']);
    });

    test('non-diet conditions such as knee pain are ignored', () {
      final result = filterMeals(
        meals,
        dietType: DietType.vegan,
        goal: NutritionGoal.maintain,
        conditionKeys: const <String>['knee_pain'],
      );
      expect(ids(result), <String>['vegan', 'diabetes-ok']);
    });
  });

  group('filterTips', () {
    const tips = <DietTip>[
      DietTip(id: 'a', category: 'eat_more', title: 'A', body: 'a'),
      DietTip(
        id: 'b',
        category: 'eat_more',
        title: 'B',
        body: 'b',
        dietTypes: <DietType>[DietType.nonVeg],
      ),
      DietTip(
        id: 'c',
        category: 'eat_more',
        title: 'C',
        body: 'c',
        goals: <String>['gain'],
      ),
      DietTip(
        id: 'd',
        category: 'eat_more',
        title: 'D',
        body: 'd',
        conditions: <String>['diabetes'],
      ),
      DietTip(id: 'e', category: 'limit', title: 'E', body: 'e'),
    ];

    List<String> run(DietType diet, NutritionGoal goal, List<String> keys) =>
        filterTips(
          tips,
          category: 'eat_more',
          dietType: diet,
          goal: goal,
          conditionKeys: keys,
        ).map((t) => t.id).toList();

    test('only the requested category is returned', () {
      expect(run(DietType.nonVeg, NutritionGoal.gain, <String>['diabetes']),
          isNot(contains('e')));
    });

    test('diet-specific tips are hidden from other diets', () {
      expect(run(DietType.vegan, NutritionGoal.maintain, <String>[]),
          <String>['a']);
    });

    test('goal-specific tips need the matching goal', () {
      expect(run(DietType.veg, NutritionGoal.gain, <String>[]),
          <String>['a', 'c']);
    });

    test('condition tips only show for users with that condition', () {
      expect(run(DietType.veg, NutritionGoal.maintain, <String>['diabetes']),
          <String>['a', 'd']);
    });
  });
}
