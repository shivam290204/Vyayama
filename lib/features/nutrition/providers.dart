import 'package:fitbuddy/features/health_profile/data/async_value_x.dart';
import 'package:fitbuddy/features/health_profile/data/profile_snapshot.dart';
import 'package:fitbuddy/features/health_profile/providers.dart';
import 'package:fitbuddy/features/nutrition/data/diet_tip.dart';
import 'package:fitbuddy/features/nutrition/data/meal.dart';
import 'package:fitbuddy/features/nutrition/data/mock_nutrition_repository.dart';
import 'package:fitbuddy/features/nutrition/data/nutrition_repository.dart';
import 'package:fitbuddy/features/nutrition/domain/content_filters.dart';
import 'package:fitbuddy/features/nutrition/domain/nutrition_calculator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Repository for tips, meals and the water log.
/// Antigravity: override with a persistent implementation if needed.
final nutritionRepositoryProvider = Provider<NutritionRepository>(
  (ref) => MockNutritionRepository(),
);

/// All diet tips from `assets/data/diet_tips.json`.
final dietTipsProvider = FutureProvider<List<DietTip>>(
  (ref) => ref.watch(nutritionRepositoryProvider).loadDietTips(),
);

/// All meals from `assets/data/meals.json`.
final mealsProvider = FutureProvider<List<Meal>>(
  (ref) => ref.watch(nutritionRepositoryProvider).loadMeals(),
);

/// Selected activity level (default: light).
final activityLevelProvider =
    NotifierProvider<ActivityLevelNotifier, ActivityLevel>(
  ActivityLevelNotifier.new,
);

/// Goal chosen on this screen, or null to use the profile goal.
final goalOverrideProvider =
    NotifierProvider<GoalOverrideNotifier, NutritionGoal?>(
  GoalOverrideNotifier.new,
);

/// Diet type used to filter meals and tips (default: veg).
final dietTypeProvider = NotifierProvider<DietTypeNotifier, DietType>(
  DietTypeNotifier.new,
);

/// Whether meals should be limited to those suited to the user's conditions.
final conditionFriendlyOnlyProvider =
    NotifierProvider<ConditionFriendlyOnlyNotifier, bool>(
  ConditionFriendlyOnlyNotifier.new,
);

/// The requested goal: screen override, then profile goal, then maintain.
final nutritionGoalProvider = Provider<NutritionGoal>((ref) {
  final override = ref.watch(goalOverrideProvider);
  if (override != null) return override;
  final profile = ref.watch(profileSnapshotProvider).dataOrNull;
  return NutritionGoal.tryParse(profile?.goal) ?? NutritionGoal.maintain;
});

/// The goal actually applied (weight loss is never applied under 18).
final effectiveGoalProvider = Provider<NutritionGoal>((ref) {
  final profile = ref.watch(profileSnapshotProvider).dataOrNull;
  return NutritionCalculator.effectiveGoal(
    ref.watch(nutritionGoalProvider),
    profile?.age,
  );
});

/// Calorie estimate, or null when age, height or weight is missing.
final calorieEstimateProvider = Provider<CalorieEstimate?>((ref) {
  final ProfileSnapshot? p = ref.watch(profileSnapshotProvider).dataOrNull;
  if (p == null) return null;
  final weight = p.weightKg;
  final height = p.heightCm;
  final age = p.age;
  if (weight == null || height == null || age == null) return null;
  if (weight <= 0 || height <= 0 || age <= 0) return null;
  return NutritionCalculator.estimate(
    sex: NutritionSex.parse(p.gender),
    weightKg: weight,
    heightCm: height,
    age: age,
    activity: ref.watch(activityLevelProvider),
    goal: ref.watch(nutritionGoalProvider),
  );
});

/// Suggested daily water in glasses (about 250 ml each).
final waterTargetGlassesProvider = Provider<int>((ref) {
  final weight = ref.watch(profileSnapshotProvider).dataOrNull?.weightKg;
  if (weight == null || weight <= 0) return 8;
  return NutritionCalculator.dailyWaterGlasses(weight);
});

/// Selected conditions that affect food choices.
final relevantConditionKeysProvider = Provider<List<String>>((ref) {
  final keys = ref.watch(selectedConditionKeysProvider).dataOrNull ??
      const <String>[];
  return keys.where(dietRelevantConditions.contains).toList();
});

/// Meals filtered by diet type, goal and conditions.
final suggestedMealsProvider = Provider<AsyncValue<List<Meal>>>((ref) {
  final meals = ref.watch(mealsProvider);
  final goal = ref.watch(effectiveGoalProvider);
  final diet = ref.watch(dietTypeProvider);
  final keys = ref.watch(selectedConditionKeysProvider).dataOrNull ??
      const <String>[];
  final onlyFriendly = ref.watch(conditionFriendlyOnlyProvider);
  return meals.whenData(
    (list) => filterMeals(
      list,
      dietType: diet,
      goal: goal,
      conditionKeys: keys,
      conditionFriendlyOnly: onlyFriendly,
    ),
  );
});

/// Tips of one category (for example `eat_more` or `limit`) that fit the user.
final tipsByCategoryProvider =
    Provider.family<AsyncValue<List<DietTip>>, String>((ref, category) {
  final tips = ref.watch(dietTipsProvider);
  final goal = ref.watch(effectiveGoalProvider);
  final diet = ref.watch(dietTypeProvider);
  final keys = ref.watch(selectedConditionKeysProvider).dataOrNull ??
      const <String>[];
  return tips.whenData(
    (list) => filterTips(
      list,
      category: category,
      dietType: diet,
      goal: goal,
      conditionKeys: keys,
    ),
  );
});

/// Today's water glasses.
final waterProvider = AsyncNotifierProvider<WaterNotifier, int>(
  WaterNotifier.new,
);

/// Holds the activity level choice.
class ActivityLevelNotifier extends Notifier<ActivityLevel> {
  @override
  ActivityLevel build() => ActivityLevel.light;

  /// Selects [level].
  void select(ActivityLevel level) => state = level;
}

/// Holds the optional goal override.
class GoalOverrideNotifier extends Notifier<NutritionGoal?> {
  @override
  NutritionGoal? build() => null;

  /// Selects [goal].
  void select(NutritionGoal goal) => state = goal;
}

/// Holds the diet type choice.
class DietTypeNotifier extends Notifier<DietType> {
  @override
  DietType build() => DietType.veg;

  /// Selects [type].
  void select(DietType type) => state = type;
}

/// Holds the "suited to my conditions" switch.
class ConditionFriendlyOnlyNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  /// Turns the filter on or off.
  void set(bool value) => state = value;
}

/// Tracks today's water glasses and persists changes.
class WaterNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() =>
      ref.watch(nutritionRepositoryProvider).getWaterGlasses(DateTime.now());

  /// Adds or removes glasses (never below zero).
  Future<void> change(int delta) async {
    final current = state.dataOrNull ?? 0;
    final next = (current + delta).clamp(0, 30).toInt();
    state = AsyncData<int>(next);
    try {
      await ref
          .read(nutritionRepositoryProvider)
          .setWaterGlasses(DateTime.now(), next);
    } catch (_) {
      state = AsyncData<int>(current);
      rethrow;
    }
  }
}
