import 'package:fitbuddy/features/nutrition/data/meal.dart';
import 'package:fitbuddy/features/workouts/data/exercise.dart';
import 'package:fitbuddy/features/workouts/data/workout_plan.dart';

/// Transparent explanation and reasoning generator for fitness and nutrition.
///
/// Features:
/// - Explains workout recommendations using exercise science principles.
/// - Explains nutrition and hydration recommendations.
/// - 100% deterministic and offline; never hallucinates exercises or meals.
abstract final class RecommendationExplainer {
  /// Explains why an exercise is placed in a specific sequence slot.
  static String explainExerciseRole({
    required Exercise exercise,
    required int orderIndex,
    required int totalExercises,
  }) {
    final name = exercise.name;
    final group = exercise.muscleGroup.toLowerCase();

    if (orderIndex == 0) {
      return '$name serves as the primary compound or warm-up movement to activate the central nervous system and prepare the $group muscles.';
    }

    if (orderIndex == totalExercises - 1) {
      if (exercise.instructions.any((s) => s.toLowerCase().contains('stretch') || s.toLowerCase().contains('breathe'))) {
        return '$name acts as the cool-down movement to downregulate heart rate and maintain muscle elasticity.';
      }
      return '$name is positioned at the end to finish core stabilization and complete the session.';
    }

    if (group.contains('core') || exercise.id.contains('plank') || exercise.id.contains('bug')) {
      return '$name targets core stability after main compound lifts, avoiding early spinal fatigue.';
    }

    return '$name works as targeted accessory volume for the $group, building strength without excessive systemic fatigue.';
  }

  /// Explains why a meal fits a specific goal and dietary preference.
  static String explainMealSuitability({
    required Meal meal,
    required String goal,
    required String dietType,
  }) {
    final title = meal.name;
    final calories = meal.calories;
    final protein = meal.proteinG;

    switch (goal.toLowerCase()) {
      case 'gain':
        return '$title provides $protein g of muscle-supporting protein and $calories kcal, ideal for fueling hypertrophy and positive nitrogen balance.';
      case 'lose':
        return '$title delivers $protein g of satiating protein at only $calories kcal, supporting lean mass retention during a caloric deficit.';
      case 'maintain':
      default:
        return '$title offers a balanced macronutrient profile ($protein g protein, $calories kcal) for sustained daily energy and recovery.';
    }
  }

  /// Synthesizes transparent overview for an adapted plan.
  static String explainAdaptedPlan({
    required WorkoutPlan plan,
    required List<String> conditions,
  }) {
    if (conditions.isEmpty) {
      return 'This routine is sequenced following standard sports science principles: primary compound lifts first, followed by accessory work and core conditioning.';
    }

    final condList = conditions.join(', ');
    return 'This routine has been personalized to accommodate your profile ($condList). Exercises with high joint shear or excessive compressive force were replaced with safe, joint-friendly equivalents.';
  }
}
