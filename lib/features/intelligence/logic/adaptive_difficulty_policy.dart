import 'package:fitbuddy/features/intelligence/domain/interfaces/adaptive_journey_interface.dart';
import 'package:fitbuddy/features/workouts/data/workout_plan.dart';
import 'package:fitbuddy/features/workouts/logic/progression_model_interface.dart';

/// Deterministic, sports-science backed policy for evaluating plan adaptations.
///
/// Implements [IAdaptiveDifficultyPolicy] using [DoubleProgressionModel] principles:
/// 1. High adherence (>=80%) with manageable exertion (RPE <= 7.5) triggers steady progression.
/// 2. High fatigue (RPE >= 9.0 or 'Too Hard' feedback) triggers deload / recovery.
/// 3. Inactivity or lapsed attendance triggers a low-pressure habit restart without penalties.
class AdaptiveDifficultyPolicy implements IAdaptiveDifficultyPolicy {
  const AdaptiveDifficultyPolicy({
    this.progressionModel = const DoubleProgressionModel(),
  });

  final IProgressionModel progressionModel;

  @override
  Future<ProgressionRecommendation> evaluatePlanAdaptation({
    required WorkoutPlan currentPlan,
    required double trailingAdherence,
    required double? averageSessionRpe,
  }) async {
    final rpe = averageSessionRpe ?? 7.5;

    // 1. High fatigue / over-exertion reported
    if (rpe >= 9.0) {
      return const ProgressionRecommendation(
        action: ProgressionAction.regressOrDeload,
        nextLoadKg: 0.0,
        nextTargetReps: 0,
        rationale:
            'Recent workouts were reported as very hard. A lighter recovery session or 10% volume deload helps muscles and tendons adapt safely.',
      );
    }

    // 2. High adherence & manageable exertion -> Progressive Overload
    if (trailingAdherence >= 0.8 && rpe <= 7.5) {
      return const ProgressionRecommendation(
        action: ProgressionAction.increaseLoad,
        nextLoadKg: 2.5,
        nextTargetReps: 1,
        rationale:
            'Strong consistency with manageable exertion. Ready for a gradual progression (+1 rep or +2.5 kg on compound lifts).',
      );
    }

    // 3. Lapsed adherence -> Gentle restart
    if (trailingAdherence < 0.5) {
      return const ProgressionRecommendation(
        action: ProgressionAction.maintain,
        nextLoadKg: 0.0,
        nextTargetReps: 0,
        rationale:
            'Consistency dipped recently. A low-pressure restart workout will rebuild your momentum without overwhelming fatigue.',
      );
    }

    // 4. Steady state maintenance
    return const ProgressionRecommendation(
      action: ProgressionAction.maintain,
      nextLoadKg: 0.0,
      nextTargetReps: 0,
      rationale:
          'Current workout intensity is well matched. Continue consolidating movement form and building weekly rhythm.',
    );
  }
}

