import 'package:fitbuddy/features/nutrition/data/diet_tip.dart';
import 'package:fitbuddy/features/nutrition/data/meal.dart';

/// Source of diet content and the water log.
abstract class NutritionRepository {
  /// Loads every tip from `assets/data/diet_tips.json`.
  Future<List<DietTip>> loadDietTips();

  /// Loads every meal from `assets/data/meals.json`.
  Future<List<Meal>> loadMeals();

  /// Glasses of water logged on [date].
  Future<int> getWaterGlasses(DateTime date);

  /// Saves the glasses of water logged on [date].
  Future<void> setWaterGlasses(DateTime date, int glasses);
}
