import 'dart:async';

import 'package:fitbuddy/features/challenges/challenges_state.dart';
import 'package:fitbuddy/features/challenges/daily_challenge_picker.dart';
import 'package:fitbuddy/features/challenges/data/challenge.dart';
import 'package:fitbuddy/features/challenges/data/challenge_repository.dart';
import 'package:fitbuddy/features/challenges/streak_logic.dart';
import 'package:fitbuddy/features/dashboard/providers.dart';
import 'package:fitbuddy/features/mascot/providers.dart';
import 'package:fitbuddy/features/schedule/clock_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitbuddy/core/services/shared_prefs_provider.dart';
import 'package:fitbuddy/features/challenges/data/supabase_challenge_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// XP for the first workout of a day (counts as a streak activity).
const int workoutActivityXp = 20;

/// Challenge storage. Swapped in the Supabase implementation.
final challengeRepositoryProvider = Provider<ChallengeRepository>(
  (ref) => SupabaseChallengeRepository(
    client: Supabase.instance.client,
    prefs: ref.watch(sharedPreferencesProvider),
  ),
);

/// All challenges available for the daily rotation.
final challengeCatalogProvider = FutureProvider<List<Challenge>>(
  (ref) => ref.watch(challengeRepositoryProvider).fetchChallenges(),
);

/// Today's challenge, picked deterministically from the date.
final todayChallengeProvider = Provider<AsyncValue<Challenge?>>((ref) {
  final catalog = ref.watch(challengeCatalogProvider);
  final today = ref.watch(todayProvider);
  return catalog.whenData(
    (list) => const DailyChallengePicker().pickFor(list, today),
  );
});

/// How much one tap on "+" adds for [challenge].
int progressStepFor(Challenge challenge) =>
    challenge.type == ChallengeType.reps && challenge.targetValue > 10 ? 5 : 1;

/// User-tapped progress for today's challenge (reps, water, count, checkoff).
class ManualProgressNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    final challenge = ref.watch(todayChallengeProvider).asData?.value;
    final today = ref.watch(todayProvider);
    if (challenge == null) return 0;
    return ref
        .watch(challengeRepositoryProvider)
        .getProgress(challenge.id, today);
  }

  /// Adds [delta] (may be negative), keeping the value between 0 and the target.
  Future<void> change(int delta) async {
    final challenge = ref.read(todayChallengeProvider).asData?.value;
    if (challenge == null) return;
    final current = state.asData?.value ?? 0;
    final next = (current + delta).clamp(0, challenge.targetValue).toInt();
    await ref
        .read(challengeRepositoryProvider)
        .setProgress(challenge.id, ref.read(todayProvider), next);
    state = AsyncData(next);
  }
}

/// Manually tracked progress for today.
final manualProgressProvider =
    AsyncNotifierProvider<ManualProgressNotifier, int>(
  ManualProgressNotifier.new,
);

/// Progress toward today's challenge, from the right source for its type.
final todayProgressProvider = Provider<int>((ref) {
  final challenge = ref.watch(todayChallengeProvider).asData?.value;
  if (challenge == null) return 0;
  switch (challenge.type) {
    case ChallengeType.steps:
      return ref.watch(todayStatsProvider).asData?.value.steps ?? 0;
    case ChallengeType.activeMinutes:
      return ref.watch(todayStatsProvider).asData?.value.activeMinutes ?? 0;
    case ChallengeType.workout:
      return ref.watch(mascotSignalsProvider).workoutDoneToday ? 1 : 0;
    case ChallengeType.reps:
    case ChallengeType.water:
    case ChallengeType.count:
    case ChallengeType.checkoff:
      return ref.watch(manualProgressProvider).asData?.value ?? 0;
  }
});

/// Streak, XP, completions and rewards. Completes today's challenge
/// automatically when progress reaches the target.
class ChallengesNotifier extends AsyncNotifier<ChallengesState> {
  bool _busy = false;
  bool _disposed = false;

  @override
  Future<ChallengesState> build() async {
    ref.onDispose(() => _disposed = true);
    final repo = ref.watch(challengeRepositoryProvider);
    final today = ref.watch(todayProvider);
    ref.listen<int>(todayProgressProvider, (_, __) => _maybeAutoComplete());
    final completions = await repo.fetchCompletions();
    final streak = await repo.fetchStreak();
    // Re-check once the loaded state is in place.
    unawaited(Future<void>.delayed(Duration.zero, _maybeAutoComplete));
    return ChallengesState(
      completions: completions,
      streak: streak,
      today: today,
    );
  }

  void _maybeAutoComplete() {
    if (_disposed) return;
    final current = state.asData?.value;
    if (current == null || current.completedToday) return;
    final challenge = ref.read(todayChallengeProvider).asData?.value;
    if (challenge == null) return;
    if (challenge.isCompleteAt(ref.read(todayProgressProvider))) {
      unawaited(complete());
    }
  }

  /// Completes today's challenge: saves it, updates streak and XP, and makes
  /// the mascot celebrate. Does nothing if it is already done.
  Future<void> complete() async {
    if (_busy) return;
    final current = state.asData?.value;
    final challenge = ref.read(todayChallengeProvider).asData?.value;
    if (current == null || challenge == null || current.completedToday) return;
    _busy = true;
    try {
      final repo = ref.read(challengeRepositoryProvider);
      await repo.addCompletion(challengeId: challenge.id, day: current.today);
      final update = StreakLogic.recordActivity(
        current.streak,
        today: current.today,
        xp: challenge.xp,
      );
      await repo.saveStreak(update.state);
      final completions = await repo.fetchCompletions();
      if (_disposed) return;
      state = AsyncData(
        current.copyWith(
          completions: completions,
          streak: update.state,
          lastReward: ChallengeReward(
            xp: update.xpAwarded,
            milestone: update.milestone,
          ),
        ),
      );
      final mascot = ref.read(mascotSignalsProvider.notifier);
      mascot.celebrateChallenge();
      if (update.milestone != null) mascot.celebrateMilestone();
    } finally {
      _busy = false;
    }
  }

  /// Records a finished workout as an activity day (spec 9.4).
  ///
  /// XP is only awarded for the first activity of the day.
  Future<void> recordWorkoutActivity() async {
    final current = await future;
    final repo = ref.read(challengeRepositoryProvider);
    final update = StreakLogic.recordActivity(
      current.streak,
      today: current.today,
      xp: current.activeToday ? 0 : workoutActivityXp,
    );
    if (update.state == current.streak) return;
    await repo.saveStreak(update.state);
    if (_disposed) return;
    state = AsyncData(current.copyWith(streak: update.state));
    if (update.milestone != null) {
      ref.read(mascotSignalsProvider.notifier).celebrateMilestone();
    }
  }
}

/// Challenge streak, XP, level and history.
final challengesProvider =
    AsyncNotifierProvider<ChallengesNotifier, ChallengesState>(
  ChallengesNotifier.new,
);

/// Completions joined with their challenge, newest first.
final completionHistoryProvider = Provider<List<CompletionEntry>>((ref) {
  final completions = ref.watch(challengesProvider).asData?.value.completions ??
      const [];
  final catalog =
      ref.watch(challengeCatalogProvider).asData?.value ?? const <Challenge>[];
  final byId = {for (final c in catalog) c.id: c};
  return [
    for (final c in completions)
      CompletionEntry(completion: c, challenge: byId[c.challengeId]),
  ];
});
