import 'package:fitbuddy/features/nutrition/data/diet_tip.dart';
import 'package:fitbuddy/features/nutrition/data/meal.dart';
import 'package:fitbuddy/features/nutrition/domain/nutrition_calculator.dart';

/// Conditions that change which foods are suggested.
const Set<String> dietRelevantConditions = <String>{
  'diabetes',
  'high_blood_pressure',
  'heart_condition',
};

/// Whether a user following [user] can eat a meal of type [meal].
bool dietTypeAllows(DietType user, DietType meal) => switch (user) {
      DietType.vegan => meal == DietType.vegan,
      DietType.veg => meal != DietType.nonVeg,
      DietType.nonVeg => true,
    };

/// Filters meals by diet type and goal. When [conditionFriendlyOnly] is on,
/// meals must also suit every selected diet-relevant condition.
List<Meal> filterMeals(
  List<Meal> meals, {
  required DietType dietType,
  required NutritionGoal goal,
  required List<String> conditionKeys,
  bool conditionFriendlyOnly = true,
}) {
  final relevant =
      conditionKeys.where(dietRelevantConditions.contains).toList();
  return meals.where((meal) {
    if (!dietTypeAllows(dietType, meal.dietType)) return false;
    if (!meal.goals.contains(goal.name)) return false;
    if (conditionFriendlyOnly && relevant.isNotEmpty) {
      return meal.conditionFriendly.toSet().containsAll(relevant);
    }
    return true;
  }).toList();
}

/// Filters tips of one [category] by diet type, goal and conditions.
/// Condition-specific tips only appear for users with that condition.
List<DietTip> filterTips(
  List<DietTip> tips, {
  required String category,
  required DietType dietType,
  required NutritionGoal goal,
  required List<String> conditionKeys,
}) {
  return tips.where((tip) {
    if (tip.category != category) return false;
    if (tip.goals.isNotEmpty && !tip.goals.contains(goal.name)) return false;
    if (tip.dietTypes.isNotEmpty && !tip.dietTypes.contains(dietType)) {
      return false;
    }
    if (tip.conditions.isNotEmpty &&
        !tip.conditions.any(conditionKeys.contains)) {
      return false;
    }
    return true;
  }).toList();
}
