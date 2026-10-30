import 'package:fitbuddy/features/dashboard/data/daily_stats.dart';
import 'package:fitbuddy/features/intelligence/domain/models/journey_recommendation.dart';
import 'package:fitbuddy/features/intelligence/domain/models/user_fitness_preferences.dart';
import 'package:fitbuddy/features/intelligence/domain/models/workout_difficulty_feedback.dart';
import 'package:fitbuddy/features/profile/data/profile.dart';
import 'package:fitbuddy/features/workouts/data/exercise.dart';
import 'package:fitbuddy/features/workouts/data/workout_log.dart';
import 'package:fitbuddy/features/workouts/data/workout_plan.dart';
import 'package:fitbuddy/features/workouts/logic/plan_adapter.dart';

/// Aggregated data context for evaluating adaptive journey recommendations.
class AdaptiveJourneyContext {
  const AdaptiveJourneyContext({
    required this.now,
    required this.preferences,
    required this.profile,
    required this.activePlan,
    required this.workoutLogs,
    required this.recentStats,
    required this.recentFeedback,
    required this.conditionTags,
    required this.exerciseLibrary,
  });

  final DateTime now;
  final UserFitnessPreferences preferences;
  final Profile? profile;
  final WorkoutPlan? activePlan;
  final List<WorkoutLog> workoutLogs;
  final List<DailyStats> recentStats;
  final List<WorkoutDifficultyFeedback> recentFeedback;
  final Set<String> conditionTags;
  final List<Exercise> exerciseLibrary;
}

/// Pure Dart deterministic service for evaluating the user's Adaptive Fitness Journey.
///
/// Implements Scenarios A-E from Phase 2 requirements:
/// - Scenario A: Consistent user -> Gradual progressive overload
/// - Scenario B: Missed several days -> Gentle, manageable habit restart
/// - Scenario C: Too difficult -> Deload, volume reduction, or active recovery
/// - Scenario D: Limited available time -> Scaled workout duration
/// - Scenario E: Equipment changes & medical contraindications -> Safe exercise filtering
abstract final class AdaptivePlanningService {
  static JourneyRecommendation evaluateJourney(AdaptiveJourneyContext context) {
    final now = context.now;
    final prefs = context.preferences;
    final profile = context.profile;
    final plan = context.activePlan;
    final logs = context.workoutLogs;
    final feedbackList = context.recentFeedback;
    final tags = context.conditionTags;
    final library = context.exerciseLibrary;

    // 1. Goal mapping
    final goalRaw = profile?.goal?.toLowerCase() ?? 'general_fitness';
    final goalTitle = _formatGoal(goalRaw);

    // 2. Trailing 7-day logs analysis
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final weekLogs = logs.where((l) => l.completedAt.isAfter(sevenDaysAgo)).toList();
    final completedThisWeek = weekLogs.length;

    // Target sessions per week (default 3 or derived from plan days count)
    final targetSessions = (plan?.days.isNotEmpty ?? false)
        ? plan!.days.length
        : 3;
    final remainingThisWeek = (targetSessions - completedThisWeek).clamp(0, 7);

    // 3. Days since last workout
    final int daysSinceLastWorkout;
    if (logs.isEmpty) {
      daysSinceLastWorkout = 999;
    } else {
      final latest = logs.first.completedAt;
      daysSinceLastWorkout = now.difference(latest).inDays;
    }

    // 4. Consecutive workout days check (fatigue protection)
    final has3ConsecutiveDays = _hasConsecutiveDays(logs, now, 3);

    // 5. Recent feedback evaluation
    final latestFeedback = feedbackList.isNotEmpty ? feedbackList.first : null;
    final isRecentFeedbackTooHard = latestFeedback != null &&
        latestFeedback.rating == WorkoutDifficultyRating.tooHard &&
        now.difference(latestFeedback.completedAt).inDays <= 2;

    // 6. Next workout resolution from plan
    final nextDay = _resolveNextPlanDay(plan, logs);
    final baseWorkoutTitle = nextDay?.name ?? (plan?.title ?? 'Full Body Foundation');
    final planDayId = nextDay?.id;
    final planId = plan?.id;

    // 7. Safety & Contraindication notes via PlanAdapter
    final adaptationNotes = <String>[];
    if (plan != null && tags.isNotEmpty && library.isNotEmpty) {
      final adapted = adaptPlanForConditions(plan, tags.toList(), library);
      for (final note in adapted.notes) {
        adaptationNotes.add(note.message);
      }
    }

    // Equipment notes
    if (prefs.availableEquipment.length == 1 &&
        prefs.availableEquipment.contains('none')) {
      adaptationNotes.add('Plan tuned for bodyweight-only exercises.');
    }

    // Duration preference
    final userDuration = prefs.dailyWorkoutMinutes;

    // -------------------------------------------------------------
    // SCENARIO C / FATIGUE CHECK: 3 consecutive days OR recent "Too Hard" feedback
    // -------------------------------------------------------------
    if (has3ConsecutiveDays) {
      return JourneyRecommendation(
        goalTitle: goalTitle,
        journeyStatus: JourneyStatus.activeRecovery,
        weeklyTargetSessions: targetSessions,
        completedSessionsThisWeek: completedThisWeek,
        remainingSessionsThisWeek: remainingThisWeek,
        recommendedNextWorkoutTitle: 'Restorative Mobility & Light Stretching',
        suggestedDurationMinutes: userDuration < 20 ? userDuration : 20,
        suggestedDifficulty: 'Active Recovery',
        weeklyProgressSummary:
            'Completed $completedThisWeek workout${completedThisWeek == 1 ? '' : 's'} this week. Muscle adaptation occurs during rest.',
        recommendationReason:
            'You completed 3 workout days in a row. Rest and light stretching will help your muscles and connective tissue adapt without overtraining.',
        recommendedPlanDayId: planDayId,
        recommendedPlanId: planId,
        isRecovery: true,
        adaptationNotes: adaptationNotes,
      );
    }

    if (isRecentFeedbackTooHard) {
      return JourneyRecommendation(
        goalTitle: goalTitle,
        journeyStatus: JourneyStatus.activeRecovery,
        weeklyTargetSessions: targetSessions,
        completedSessionsThisWeek: completedThisWeek,
        remainingSessionsThisWeek: remainingThisWeek,
        recommendedNextWorkoutTitle: '$baseWorkoutTitle (Deload Pace)',
        suggestedDurationMinutes: (userDuration * 0.8).round().clamp(10, 45),
        suggestedDifficulty: 'Gentle Recovery / Deload',
        weeklyProgressSummary:
            'Logged $completedThisWeek of $targetSessions sessions this week.',
        recommendationReason:
            'You reported that your previous workout was difficult. Consider a lighter session with reduced volume or slower tempo today.',
        recommendedPlanDayId: planDayId,
        recommendedPlanId: planId,
        isRecovery: true,
        adaptationNotes: adaptationNotes,
      );
    }

    // -------------------------------------------------------------
    // SCENARIO B: Missed several days (>= 4 days elapsed or no history)
    // -------------------------------------------------------------
    if (daysSinceLastWorkout >= 4 && logs.isNotEmpty) {
      final restartDuration = userDuration <= 20 ? userDuration : 15;
      return JourneyRecommendation(
        goalTitle: goalTitle,
        journeyStatus: JourneyStatus.momentumRestart,
        weeklyTargetSessions: targetSessions,
        completedSessionsThisWeek: completedThisWeek,
        remainingSessionsThisWeek: remainingThisWeek,
        recommendedNextWorkoutTitle: '$baseWorkoutTitle (Quick Restart)',
        suggestedDurationMinutes: restartDuration,
        suggestedDifficulty: 'Manageable Restart',
        weeklyProgressSummary:
            'Ready to resume. A brief session rebuilds consistency without soreness.',
        recommendationReason:
            'You haven\'t worked out in a few days. We recommend a gentle, low-pressure restart session to rebuild your rhythm.',
        recommendedPlanDayId: planDayId,
        recommendedPlanId: planId,
        isRecovery: false,
        adaptationNotes: adaptationNotes,
      );
    }

    // -------------------------------------------------------------
    // SCENARIO A: Consistent user with manageable exertion
    // -------------------------------------------------------------
    final isConsistent = completedThisWeek >= 2;
    final isManageable = latestFeedback == null ||
        latestFeedback.rating != WorkoutDifficultyRating.tooHard;

    if (isConsistent && isManageable) {
      final overloadPraise = latestFeedback?.rating == WorkoutDifficultyRating.tooEasy
          ? 'You reported your last session was easy. Ready for a progressive overload step (+1 rep or +2.5 kg).'
          : 'Your last few workouts were consistent. Your next session can include a small progression.';

      return JourneyRecommendation(
        goalTitle: goalTitle,
        journeyStatus: JourneyStatus.progressingSteadily,
        weeklyTargetSessions: targetSessions,
        completedSessionsThisWeek: completedThisWeek,
        remainingSessionsThisWeek: remainingThisWeek,
        recommendedNextWorkoutTitle: baseWorkoutTitle,
        suggestedDurationMinutes: userDuration,
        suggestedDifficulty: 'Progressive Overload',
        weeklyProgressSummary:
            'On track! Completed $completedThisWeek of $targetSessions planned workouts this week.',
        recommendationReason: overloadPraise,
        recommendedPlanDayId: planDayId,
        recommendedPlanId: planId,
        isRecovery: false,
        adaptationNotes: adaptationNotes,
      );
    }

    // -------------------------------------------------------------
    // SCENARIO D & E / DEFAULT: Standard rhythm with user preferences
    // -------------------------------------------------------------
    final status = logs.isEmpty ? JourneyStatus.buildingHabit : JourneyStatus.maintaining;
    final reason = logs.isEmpty
        ? 'Begin your fitness journey with your tailored $userDuration-minute starting session.'
        : 'Tailored for your $userDuration-minute target and available equipment.';

    return JourneyRecommendation(
      goalTitle: goalTitle,
      journeyStatus: status,
      weeklyTargetSessions: targetSessions,
      completedSessionsThisWeek: completedThisWeek,
      remainingSessionsThisWeek: remainingThisWeek,
      recommendedNextWorkoutTitle: baseWorkoutTitle,
      suggestedDurationMinutes: userDuration,
      suggestedDifficulty: 'Consolidate Form',
      weeklyProgressSummary: completedThisWeek == 0
          ? '0 of $targetSessions workouts done this week. Great day to begin!'
          : 'Completed $completedThisWeek of $targetSessions workouts this week.',
      recommendationReason: reason,
      recommendedPlanDayId: planDayId,
      recommendedPlanId: planId,
      isRecovery: false,
      adaptationNotes: adaptationNotes,
    );
  }

  static PlanDay? _resolveNextPlanDay(WorkoutPlan? plan, List<WorkoutLog> logs) {
    if (plan == null || plan.days.isEmpty) return null;
    if (logs.isEmpty) return plan.days.first;

    final lastLog = logs.first;
    final lastDayIndex = plan.days.indexWhere((d) => d.id == lastLog.planDayId);
    if (lastDayIndex >= 0 && lastDayIndex + 1 < plan.days.length) {
      return plan.days[lastDayIndex + 1];
    }
    return plan.days.first;
  }

  static bool _hasConsecutiveDays(
    List<WorkoutLog> logs,
    DateTime now,
    int consecutiveCount,
  ) {
    if (logs.length < consecutiveCount) return false;
    final days = <String>{};
    for (final l in logs) {
      final d = l.completedAt.toLocal();
      days.add('${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
    }

    var consecutive = 0;
    for (var i = 0; i < consecutiveCount + 2; i++) {
      final checkDate = now.subtract(Duration(days: i)).toLocal();
      final key =
          '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
      if (days.contains(key)) {
        consecutive++;
        if (consecutive >= consecutiveCount) return true;
      } else {
        if (i == 0) continue; // today may not be completed yet
        consecutive = 0;
      }
    }
    return false;
  }

  static String _formatGoal(String raw) {
    switch (raw.toLowerCase()) {
      case 'lose_weight':
      case 'lose':
        return 'Weight Management';
      case 'build_muscle':
      case 'muscle':
        return 'Muscle & Strength';
      case 'stay_fit':
      case 'maintain':
        return 'General Fitness & Energy';
      case 'endurance':
        return 'Cardio & Stamina';
      default:
        return 'Healthy Lifestyle';
    }
  }
}

