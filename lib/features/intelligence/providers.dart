import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitbuddy/features/challenges/data/streak_state.dart';
import 'package:fitbuddy/features/challenges/providers.dart';
import 'package:fitbuddy/features/dashboard/providers.dart';
import 'package:fitbuddy/features/health_profile/providers.dart';
import 'package:fitbuddy/features/intelligence/config/intelligence_config.dart';
import 'package:fitbuddy/features/intelligence/data/difficulty_feedback_repository.dart';
import 'package:fitbuddy/features/intelligence/data/fitness_preferences_repository.dart';
import 'package:fitbuddy/features/intelligence/domain/interfaces/adaptive_journey_interface.dart';
import 'package:fitbuddy/features/intelligence/domain/models/fitness_insight.dart';
import 'package:fitbuddy/features/intelligence/domain/models/journey_recommendation.dart';
import 'package:fitbuddy/features/intelligence/domain/models/user_fitness_preferences.dart';
import 'package:fitbuddy/features/intelligence/domain/models/workout_difficulty_feedback.dart';
import 'package:fitbuddy/features/intelligence/logic/adaptive_difficulty_policy.dart';
import 'package:fitbuddy/features/intelligence/logic/adaptive_planning_service.dart';
import 'package:fitbuddy/features/intelligence/logic/fitness_insights_engine.dart';
import 'package:fitbuddy/features/intelligence/logic/weekly_review_generator.dart';
import 'package:fitbuddy/features/profile/profile_providers.dart';
import 'package:fitbuddy/features/schedule/clock_providers.dart';
import 'package:fitbuddy/features/workouts/providers.dart';

/// Exposes the intelligence feature-flag state (can be overridden in widget tests).
final intelligenceEnabledProvider = Provider<bool>((ref) {
  return IntelligenceConfig.isEnabled;
});

/// Local-first repository provider for user fitness preferences.
final fitnessPreferencesRepositoryProvider =
    Provider<FitnessPreferencesRepository>((ref) {
  return SharedPrefsFitnessPreferencesRepository();
});

/// Local-first repository provider for post-workout difficulty feedback.
final difficultyFeedbackRepositoryProvider =
    Provider<DifficultyFeedbackRepository>((ref) {
  return SharedPrefsDifficultyFeedbackRepository();
});

/// Manages and persists user fitness preferences across app restarts.
class UserFitnessPreferencesNotifier
    extends AsyncNotifier<UserFitnessPreferences> {
  @override
  Future<UserFitnessPreferences> build() async {
    final uid =
        ref.watch(currentProfileProvider).asData?.value?.id ?? 'local_user';
    final repo = ref.watch(fitnessPreferencesRepositoryProvider);
    return repo.getPreferences(uid);
  }

  /// Updates preferences and triggers UI reactivity.
  Future<void> save(UserFitnessPreferences preferences) async {
    final repo = ref.read(fitnessPreferencesRepositoryProvider);
    await repo.savePreferences(preferences);
    state = AsyncData(preferences);
    ref.invalidate(adaptiveJourneyProvider);
  }
}

final userFitnessPreferencesProvider = AsyncNotifierProvider<
    UserFitnessPreferencesNotifier, UserFitnessPreferences>(
  UserFitnessPreferencesNotifier.new,
);

/// Exposes recent difficulty feedback recorded by the active user.
final recentWorkoutFeedbackProvider =
    FutureProvider<List<WorkoutDifficultyFeedback>>((ref) async {
  final uid =
      ref.watch(currentProfileProvider).asData?.value?.id ?? 'local_user';
  final repo = ref.watch(difficultyFeedbackRepositoryProvider);
  final thirtyDaysAgo =
      ref.watch(clockProvider)().subtract(const Duration(days: 30));
  return repo.getFeedback(uid, since: thirtyDaysAgo);
});

/// Provides the sports-science adaptive difficulty policy.
final adaptiveDifficultyPolicyProvider =
    Provider<IAdaptiveDifficultyPolicy>((ref) {
  return const AdaptiveDifficultyPolicy();
});

/// Gathers read-only user metrics and returns a populated [InsightsContext].
final insightsContextProvider = FutureProvider<InsightsContext>((ref) async {
  final now = ref.watch(clockProvider)();
  final isEnabled = ref.watch(intelligenceEnabledProvider);

  if (!isEnabled) {
    return InsightsContext(
      now: now,
      recentStats: const [],
      workoutLogs: const [],
      streakState: StreakState.empty(),
    );
  }

  // 1. Load recent daily stats (14 days, handles offline local buffering)
  final recentStats = await ref.watch(recentStatsProvider.future);

  // 2. Load historical workout logs (reads local outbox if offline)
  final workoutLogRepo = ref.watch(workoutLogRepositoryProvider);
  final thirtyDaysAgo = now.subtract(const Duration(days: 30));
  final logs = await workoutLogRepo.getLogs(since: thirtyDaysAgo);

  // 3. Load streak state from challenges
  final streak =
      ref.watch(challengesProvider).asData?.value.streak ?? StreakState.empty();

  // 4. Load profile
  final profile = ref.watch(currentProfileProvider).asData?.value;

  // 5. Load medical / condition tags
  final conditionTags = ref.watch(selectedConditionTagsProvider).toSet();

  // 6. Load BMI history
  final bmiRecords = ref.watch(bmiHistoryProvider).asData?.value ?? const [];

  return InsightsContext(
    now: now,
    recentStats: recentStats,
    workoutLogs: logs,
    streakState: streak,
    profile: profile,
    conditionTags: conditionTags,
    bmiRecords: bmiRecords,
  );
});

/// Evaluates and surfaces personalized, ranked fitness insights.
///
/// Respects [intelligenceEnabledProvider] — returns empty list if disabled.
final fitnessInsightsProvider =
    FutureProvider<List<FitnessInsight>>((ref) async {
  final isEnabled = ref.watch(intelligenceEnabledProvider);
  if (!isEnabled) return const [];

  final context = await ref.watch(insightsContextProvider.future);
  return FitnessInsightsEngine.generateInsights(context);
});

/// Evaluates the user's Adaptive Fitness Journey and suggests next workout adjustments.
///
/// Returns `null` immediately if [intelligenceEnabledProvider] is false.
final adaptiveJourneyProvider =
    FutureProvider<JourneyRecommendation?>((ref) async {
  final isEnabled = ref.watch(intelligenceEnabledProvider);
  if (!isEnabled) return null;

  final now = ref.watch(clockProvider)();
  final prefs = await ref.watch(userFitnessPreferencesProvider.future);
  final profile = ref.watch(currentProfileProvider).asData?.value;
  final activePlan = ref.watch(defaultPlanProvider).asData?.value;
  final workoutLogRepo = ref.watch(workoutLogRepositoryProvider);
  final logs =
      await workoutLogRepo.getLogs(since: now.subtract(const Duration(days: 30)));
  final recentStats = await ref.watch(recentStatsProvider.future);
  final feedback = await ref.watch(recentWorkoutFeedbackProvider.future);
  final conditionTags = ref.watch(selectedConditionTagsProvider).toSet();
  final exerciseLibrary =
      ref.watch(exerciseLibraryProvider).asData?.value ?? const [];

  final ctx = AdaptiveJourneyContext(
    now: now,
    preferences: prefs,
    profile: profile,
    activePlan: activePlan,
    workoutLogs: logs,
    recentStats: recentStats,
    recentFeedback: feedback,
    conditionTags: conditionTags,
    exerciseLibrary: exerciseLibrary,
  );

  return AdaptivePlanningService.evaluateJourney(ctx);
});

/// Generates a deterministic retrospective weekly fitness review.
final weeklyFitnessReviewProvider =
    FutureProvider<WeeklyFitnessReview?>((ref) async {
  final isEnabled = ref.watch(intelligenceEnabledProvider);
  if (!isEnabled) return null;

  final now = ref.watch(clockProvider)();
  final workoutLogRepo = ref.watch(workoutLogRepositoryProvider);
  final logs =
      await workoutLogRepo.getLogs(since: now.subtract(const Duration(days: 14)));
  final recentStats = await ref.watch(recentStatsProvider.future);
  final feedback = await ref.watch(recentWorkoutFeedbackProvider.future);

  final generator = WeeklyFitnessReviewGenerator(
    workoutLogs: logs,
    recentStats: recentStats,
    recentFeedback: feedback,
    targetWorkoutsPerWeek: 3,
  );

  return generator.generateWeeklyReview(weekEnding: now);
});
