import 'package:flutter/foundation.dart';

import 'package:fitbuddy/features/workouts/data/exercise.dart';
import 'package:fitbuddy/features/workouts/data/workout_plan.dart';
import 'package:fitbuddy/features/workouts/logic/default_plan_picker.dart';
import 'package:fitbuddy/features/workouts/logic/plan_adapter.dart';

/// User profile inputs for workout recommendation.
@immutable
class UserFitnessContext {
  const UserFitnessContext({
    required this.goal,
    required this.level,
    this.conditionTags = const [],
    this.availableEquipment = const ['none', 'dumbbells'],
    this.preferredDaysPerWeek = 3,
    this.age,
    this.bmi,
  });

  final String goal;
  final String level;
  final List<String> conditionTags;
  final List<String> availableEquipment;
  final int preferredDaysPerWeek;
  final int? age;
  final double? bmi;

  bool get isMinor => age != null && age! < 18;
}

/// Detailed multi-factor score breakdown for a plan recommendation.
@immutable
class RecommendationScore {
  const RecommendationScore({
    required this.overallScore,
    required this.goalScore,
    required this.levelScore,
    required this.safetyScore,
    required this.equipmentScore,
    required this.scheduleScore,
    required this.positiveFactors,
    required this.safetyCautions,
  });

  /// Normalized match percentage between 0 and 100.
  final int overallScore;

  /// Goal alignment (0 - 100)
  final int goalScore;

  /// Experience level alignment (0 - 100)
  final int levelScore;

  /// Health and joint safety score (0 - 100)
  final int safetyScore;

  /// Equipment compatibility (0 - 100)
  final int equipmentScore;

  /// Schedule frequency compatibility (0 - 100)
  final int scheduleScore;

  /// User-friendly transparent reasons why this plan matches.
  final List<String> positiveFactors;

  /// Cautions or modifications made to respect contraindications.
  final List<String> safetyCautions;
}

/// Result of evaluating a workout plan for a specific user.
@immutable
class PlanRecommendation {
  const PlanRecommendation({
    required this.plan,
    required this.score,
    required this.explanation,
    required this.adaptations,
  });

  final WorkoutPlan plan;
  final RecommendationScore score;
  final String explanation;
  final List<AdaptationNote> adaptations;

  int get matchPercentage => score.overallScore;
}

/// Pure Dart multi-factor recommendation engine.
///
/// Features:
/// 1. Evaluates goal, fitness level, contraindications, equipment, and age.
/// 2. Transparently explains why plans are selected.
/// 3. Offline-first, deterministic, zero-hallucination.
abstract final class WorkoutRecommendationEngine {
  /// Evaluates and ranks all available plans for the given user context.
  static List<PlanRecommendation> rankPlans({
    required Iterable<WorkoutPlan> plans,
    required List<Exercise> exerciseLibrary,
    required UserFitnessContext context,
  }) {
    final recommendations = <PlanRecommendation>[];

    for (final rawPlan in plans) {
      // Step 1: Adapt the plan for the user's health condition tags
      final adaptation = adaptPlanForConditions(
        rawPlan,
        context.conditionTags,
        exerciseLibrary,
      );
      final adaptedPlan = adaptation.plan;

      // Step 2: Compute multi-factor scores
      final score = _calculateScore(
        rawPlan: rawPlan,
        adaptedPlan: adaptedPlan,
        exerciseLibrary: exerciseLibrary,
        context: context,
        adaptations: adaptation.notes,
      );

      // Step 3: Build human-readable explainability
      final explanation = _buildExplanation(
        plan: adaptedPlan,
        score: score,
        context: context,
        adaptations: adaptation.notes,
      );

      recommendations.add(
        PlanRecommendation(
          plan: adaptedPlan,
          score: score,
          explanation: explanation,
          adaptations: adaptation.notes,
        ),
      );
    }

    // Sort by overall match score descending
    recommendations.sort((a, b) => b.score.overallScore.compareTo(a.score.overallScore));
    return recommendations;
  }

  /// Recommends the single top-ranking plan for a user.
  static PlanRecommendation? recommendTopPlan({
    required Iterable<WorkoutPlan> plans,
    required List<Exercise> exerciseLibrary,
    required UserFitnessContext context,
  }) {
    final ranked = rankPlans(
      plans: plans,
      exerciseLibrary: exerciseLibrary,
      context: context,
    );
    return ranked.isNotEmpty ? ranked.first : null;
  }

  static RecommendationScore _calculateScore({
    required WorkoutPlan rawPlan,
    required WorkoutPlan adaptedPlan,
    required List<Exercise> exerciseLibrary,
    required UserFitnessContext context,
    required List<AdaptationNote> adaptations,
  }) {
    final positives = <String>[];
    final cautions = <String>[];

    // 1. Goal alignment (35% weight)
    var effectiveGoal = normalizeGoal(context.goal);
    if (context.isMinor && effectiveGoal == 'lose') {
      effectiveGoal = 'maintain'; // Under 18 safety rule
    }
    final planGoal = normalizeGoal(rawPlan.goal);
    int goalScore;
    if (planGoal == effectiveGoal) {
      goalScore = 100;
      positives.add('Directly targets your primary goal of ${_goalLabel(effectiveGoal)}');
    } else if (effectiveGoal == 'maintain' || planGoal == 'maintain') {
      goalScore = 70;
      positives.add('Balanced structure supports foundational health and ${_goalLabel(effectiveGoal)}');
    } else {
      goalScore = 40;
    }

    // 2. Experience level alignment (25% weight)
    final userLevel = normalizeLevel(context.level);
    final planLevel = normalizeLevel(rawPlan.level);
    int levelScore;
    if (userLevel == planLevel) {
      levelScore = 100;
      positives.add('Paced specifically for ${userLevel.toUpperCase()} fitness level');
    } else if (userLevel == 'intermediate' && planLevel == 'beginner') {
      levelScore = 80;
      positives.add('Gentler progression provides great active recovery');
    } else {
      levelScore = 50;
      cautions.add('Plan intensity is designed for $planLevel level');
    }

    // 3. Safety and contraindications (20% weight)
    int safetyScore = 100;
    if (adaptations.isNotEmpty) {
      final replacedCount = adaptations.where((a) => a.wasReplaced).length;
      final removedCount = adaptations.where((a) => !a.wasReplaced).length;

      if (removedCount > 0) {
        safetyScore -= (removedCount * 15).clamp(0, 40);
        cautions.add('$removedCount exercise(s) removed to avoid joint/condition stress');
      }
      if (replacedCount > 0) {
        safetyScore -= (replacedCount * 5).clamp(0, 15);
        cautions.add('$replacedCount exercise(s) swapped for safe, low-impact alternatives');
      }
      positives.add('Sanitized against your health conditions');
    } else {
      positives.add('No conflicting exercises with your recorded health profile');
    }
    safetyScore = safetyScore.clamp(20, 100);

    // 4. Equipment availability (10% weight)
    final exerciseMap = {for (final e in exerciseLibrary) e.id: e};
    final equipmentNeeded = <String>{};
    for (final day in adaptedPlan.days) {
      for (final pe in day.exercises) {
        final ex = exerciseMap[pe.exerciseId];
        if (ex != null && ex.equipment.isNotEmpty && ex.equipment.toLowerCase() != 'none') {
          equipmentNeeded.add(ex.equipment.toLowerCase());
        }
      }
    }

    int equipmentScore = 100;
    final availableEq = context.availableEquipment.map((e) => e.toLowerCase()).toSet();
    final missingEq = equipmentNeeded.difference(availableEq);
    if (missingEq.isEmpty) {
      if (equipmentNeeded.isEmpty) {
        positives.add('100% bodyweight workouts requiring zero equipment');
      } else {
        positives.add('Matches your available equipment (${equipmentNeeded.join(', ')})');
      }
    } else {
      equipmentScore = 40;
      cautions.add('Requires gear you may not have: ${missingEq.join(', ')}');
    }

    // 5. Schedule compatibility (10% weight)
    final scheduledDays = adaptedPlan.days.length;
    final dayDiff = (scheduledDays - context.preferredDaysPerWeek).abs();
    int scheduleScore = (100 - (dayDiff * 20)).clamp(30, 100);
    if (dayDiff == 0) {
      positives.add('Perfect $scheduledDays days/week frequency');
    } else {
      positives.add('$scheduledDays active training days per week');
    }

    // Weighted composite score (0 - 100)
    final composite = (goalScore * 0.35) +
        (levelScore * 0.25) +
        (safetyScore * 0.20) +
        (equipmentScore * 0.10) +
        (scheduleScore * 0.10);

    return RecommendationScore(
      overallScore: composite.round().clamp(1, 100),
      goalScore: goalScore,
      levelScore: levelScore,
      safetyScore: safetyScore,
      equipmentScore: equipmentScore,
      scheduleScore: scheduleScore,
      positiveFactors: positives,
      safetyCautions: cautions,
    );
  }

  static String _buildExplanation({
    required WorkoutPlan plan,
    required RecommendationScore score,
    required UserFitnessContext context,
    required List<AdaptationNote> adaptations,
  }) {
    final buf = StringBuffer();
    buf.write('We recommend "${plan.title}" because it has an overall ${score.overallScore}% match with your profile. ');

    if (score.positiveFactors.isNotEmpty) {
      buf.write(score.positiveFactors.first);
      buf.write('. ');
    }

    if (adaptations.isNotEmpty) {
      buf.write('We customized this routine by adapting ${adaptations.length} movement(s) to protect your joints and health conditions. ');
    }

    if (score.safetyCautions.isNotEmpty) {
      buf.write('Note: ${score.safetyCautions.first}.');
    }

    return buf.toString();
  }

  static String _goalLabel(String goal) {
    switch (goal) {
      case 'lose':
        return 'fat loss & conditioning';
      case 'gain':
        return 'strength & muscle development';
      case 'maintain':
      default:
        return 'overall health & consistency';
    }
  }
}
