import 'package:fitbuddy/features/challenges/providers.dart';
import 'package:fitbuddy/features/dashboard/providers.dart';
import 'package:fitbuddy/features/mascot/providers.dart';
import 'package:fitbuddy/features/nutrition/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The 3 completion tiers requested:
/// - [nothingDone] -> Sad_Drooped_Head.png (when nothing done)
/// - [fourToFiveDone] -> flex_proud.png (when done 4 to 5 things, not all)
/// - [everythingDone] -> Fire_Determined.png (when everything done)
enum DailyCompletionTier {
  nothingDone,
  fourToFiveDone,
  everythingDone,
}

/// Represents today's wellness and fitness accomplishments.
class DailyCompletionProgress {
  const DailyCompletionProgress({
    required this.completedCount,
    required this.totalCount,
    required this.tier,
    required this.stepsDone,
    required this.caloriesDone,
    required this.activeMinutesDone,
    required this.workoutDone,
    required this.waterDone,
    required this.challengeDone,
  });

  final int completedCount;
  final int totalCount;
  final DailyCompletionTier tier;
  final bool stepsDone;
  final bool caloriesDone;
  final bool activeMinutesDone;
  final bool workoutDone;
  final bool waterDone;
  final bool challengeDone;

  /// Returns the asset path corresponding to the completion tier.
  String get assetPath {
    switch (tier) {
      case DailyCompletionTier.nothingDone:
        return 'assets/images/mascot/Sad_Drooped_Head.png';
      case DailyCompletionTier.fourToFiveDone:
        return 'assets/exercises/flex_proud.png';
      case DailyCompletionTier.everythingDone:
        return 'assets/images/mascot/Fire_Determined.png';
    }
  }

  String get label {
    switch (tier) {
      case DailyCompletionTier.nothingDone:
        return 'Nothing done yet';
      case DailyCompletionTier.fourToFiveDone:
        return '$completedCount of $totalCount completed';
      case DailyCompletionTier.everythingDone:
        return 'All $totalCount completed!';
    }
  }
}

/// Allows manual overriding of the completion tier for testing and preview.
class DailyCompletionTierOverrideNotifier
    extends Notifier<DailyCompletionTier?> {
  @override
  DailyCompletionTier? build() => null;

  void setTier(DailyCompletionTier? tier) => state = tier;

  void cycleNext() {
    switch (state) {
      case null:
        state = DailyCompletionTier.nothingDone;
      case DailyCompletionTier.nothingDone:
        state = DailyCompletionTier.fourToFiveDone;
      case DailyCompletionTier.fourToFiveDone:
        state = DailyCompletionTier.everythingDone;
      case DailyCompletionTier.everythingDone:
        state = null; // Back to auto
    }
  }
}

final dailyCompletionTierOverrideProvider = NotifierProvider<
    DailyCompletionTierOverrideNotifier, DailyCompletionTier?>(
  DailyCompletionTierOverrideNotifier.new,
);

/// Computes today's completed accomplishments and determines the mascot state.
final dailyCompletionProgressProvider =
    Provider<DailyCompletionProgress>((ref) {
  final stats = ref.watch(todayStatsProvider).asData?.value;
  final targets = ref.watch(dailyTargetsProvider);
  final signals = ref.watch(mascotSignalsProvider);
  final water = ref.watch(waterProvider).asData?.value ?? 0;
  final waterTarget = ref.watch(waterTargetGlassesProvider);
  final challengesState = ref.watch(challengesProvider).asData?.value;

  final stepsDone = stats != null && stats.steps >= targets.steps;
  final caloriesDone =
      stats != null && stats.calories >= targets.activeCalories;
  final activeMinutesDone =
      stats != null && stats.activeMinutes >= targets.activeMinutes;
  final workoutDone = signals.workoutDoneToday;
  final waterDone = water >= waterTarget && waterTarget > 0;
  final challengeDone = challengesState?.completedToday ?? false;

  int count = 0;
  if (stepsDone) count++;
  if (caloriesDone) count++;
  if (activeMinutesDone) count++;
  if (workoutDone) count++;
  if (waterDone) count++;
  if (challengeDone) count++;

  const total = 6;
  DailyCompletionTier calculatedTier;
  if (count == 0) {
    calculatedTier = DailyCompletionTier.nothingDone;
  } else if (count >= total) {
    calculatedTier = DailyCompletionTier.everythingDone;
  } else {
    // 1 to 5 done (user specified: flex_proud.png when done 4 to 5 things not all)
    calculatedTier = DailyCompletionTier.fourToFiveDone;
  }

  final override = ref.watch(dailyCompletionTierOverrideProvider);
  final effectiveTier = override ?? calculatedTier;

  return DailyCompletionProgress(
    completedCount: override == null
        ? count
        : (override == DailyCompletionTier.nothingDone
            ? 0
            : (override == DailyCompletionTier.fourToFiveDone ? 4 : total)),
    totalCount: total,
    tier: effectiveTier,
    stepsDone: stepsDone,
    caloriesDone: caloriesDone,
    activeMinutesDone: activeMinutesDone,
    workoutDone: workoutDone,
    waterDone: waterDone,
    challengeDone: challengeDone,
  );
});
