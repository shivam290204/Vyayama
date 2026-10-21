import 'package:flutter/foundation.dart';

/// Next recommended action in progressive overload.
enum ProgressionAction {
  increaseLoad,
  increaseReps,
  maintain,
  regressOrDeload,
}

/// Recorded signals from an exercise set history.
@immutable
class ProgressionInput {
  const ProgressionInput({
    required this.exerciseId,
    required this.targetRepsMin,
    required this.targetRepsMax,
    required this.targetSets,
    required this.completedRepsPerSet,
    required this.currentLoadKg,
    this.reportedRpe,
    this.consecutiveSuccessSessions = 1,
  });

  final String exerciseId;
  final int targetRepsMin;
  final int targetRepsMax;
  final int targetSets;
  final List<int> completedRepsPerSet;
  final double currentLoadKg;
  final double? reportedRpe;
  final int consecutiveSuccessSessions;
}

/// Overload recommendation evaluated by the progression engine.
@immutable
class ProgressionRecommendation {
  const ProgressionRecommendation({
    required this.action,
    required this.nextLoadKg,
    required this.nextTargetReps,
    required this.rationale,
  });

  final ProgressionAction action;
  final double nextLoadKg;
  final int nextTargetReps;
  final String rationale;
}

/// Abstract contract for progression models.
abstract interface class IProgressionModel {
  ProgressionRecommendation evaluateProgression(ProgressionInput input);
}

/// Standard sports-science Double Progression model.
///
/// Rules:
/// 1. Double Progression Principle: User works within a rep range (e.g. 8-12 reps).
/// 2. If the user hits [targetRepsMax] on ALL sets with controlled form (RPE <= 8),
///    increase weight by 2.5 kg (or ~5%) and reset reps to [targetRepsMin].
/// 3. If reps are within [targetRepsMin, targetRepsMax], increment reps by 1.
/// 4. If user failed to hit [targetRepsMin] on sets or RPE > 9.5, maintain or deload.
class DoubleProgressionModel implements IProgressionModel {
  const DoubleProgressionModel();

  @override
  ProgressionRecommendation evaluateProgression(ProgressionInput input) {
    if (input.completedRepsPerSet.isEmpty) {
      return ProgressionRecommendation(
        action: ProgressionAction.maintain,
        nextLoadKg: input.currentLoadKg,
        nextTargetReps: input.targetRepsMin,
        rationale: 'Baseline session. Establish comfortable form.',
      );
    }

    final allHitMax = input.completedRepsPerSet.every((r) => r >= input.targetRepsMax);
    final allHitMin = input.completedRepsPerSet.every((r) => r >= input.targetRepsMin);
    final rpe = input.reportedRpe ?? 7.0;

    // 1. Ready for weight increase
    if (allHitMax && rpe <= 8.5) {
      final increment = input.currentLoadKg > 0 ? (input.currentLoadKg * 0.05).clamp(1.25, 5.0) : 0.0;
      final roundedWeight = (input.currentLoadKg + increment);
      final cleanWeight = (roundedWeight * 2).round() / 2; // round to nearest 0.5kg

      return ProgressionRecommendation(
        action: ProgressionAction.increaseLoad,
        nextLoadKg: cleanWeight,
        nextTargetReps: input.targetRepsMin,
        rationale: 'Mastered ${input.targetRepsMax} reps across all sets. Increasing load by ${increment.toStringAsFixed(1)} kg and resetting to ${input.targetRepsMin} reps.',
      );
    }

    // 2. Working within rep range
    if (allHitMin) {
      final currentAvgReps = input.completedRepsPerSet.reduce((a, b) => a + b) ~/ input.completedRepsPerSet.length;
      final nextReps = (currentAvgReps + 1).clamp(input.targetRepsMin, input.targetRepsMax);
      return ProgressionRecommendation(
        action: ProgressionAction.increaseReps,
        nextLoadKg: input.currentLoadKg,
        nextTargetReps: nextReps,
        rationale: 'Solid execution. Aim for +1 rep per set next time.',
      );
    }

    // 3. Strugling or high fatigue
    if (rpe >= 9.5) {
      return ProgressionRecommendation(
        action: ProgressionAction.regressOrDeload,
        nextLoadKg: (input.currentLoadKg * 0.9).clamp(0.0, double.infinity),
        nextTargetReps: input.targetRepsMin,
        rationale: 'Exertion was high. A temporary 10% deload allows tendon and muscular recovery.',
      );
    }

    // 4. Standard maintain
    return ProgressionRecommendation(
      action: ProgressionAction.maintain,
      nextLoadKg: input.currentLoadKg,
      nextTargetReps: input.targetRepsMin,
      rationale: 'Continue consolidating form at this weight until all sets hit ${input.targetRepsMin} reps.',
    );
  }
}
