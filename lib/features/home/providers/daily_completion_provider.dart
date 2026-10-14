import 'dart:math' as math;
import 'package:fitbuddy/features/challenges/providers.dart';
import 'package:fitbuddy/features/dashboard/providers.dart';
import 'package:fitbuddy/features/mascot/providers.dart';
import 'package:fitbuddy/features/nutrition/providers.dart';
import 'package:fitbuddy/features/schedule/data/time_block.dart';
import 'package:fitbuddy/features/schedule/providers.dart';
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
        return 'assets/images/mascot/flex_proud.png';
      case DailyCompletionTier.everythingDone:
        return 'assets/images/mascot/Fire_Determined.png';
    }
  }

  String get label {
    switch (tier) {
      case DailyCompletionTier.nothingDone:
        return completedCount == 0 ? 'Nothing done yet' : '$completedCount of $totalCount completed';
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
        state = DailyCompletionTier.fourToFiveDone;
      case DailyCompletionTier.fourToFiveDone:
        state = DailyCompletionTier.everythingDone;
      case DailyCompletionTier.everythingDone:
        state = DailyCompletionTier.nothingDone;
      case DailyCompletionTier.nothingDone:
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

  // Track Daily Schedule items (from today's schedule and completions)
  final scheduleAsync = ref.watch(todayScheduleProvider);
  final scheduleEntries =
      scheduleAsync.asData?.value ?? const <TimeBlockEntry>[];
  final completions =
      ref.watch(todayCompletionsProvider).asData?.value ?? const <BlockCompletion>[];

  final actionableTasks = scheduleEntries
      .where((e) => e.block.type.needsCompletion)
      .toList();
  final scheduleDoneFromEntries =
      actionableTasks.where((e) => e.status == BlockStatus.done).length;
  final scheduleDoneFromCompletions =
      completions.where((c) => c.status == CompletionStatus.done).length;
  final scheduleDone =
      math.max(scheduleDoneFromEntries, scheduleDoneFromCompletions);
  final totalScheduleTasks =
      actionableTasks.isNotEmpty ? actionableTasks.length : 6;

  final stepsDone =
      stats != null && targets.steps > 0 && stats.steps >= targets.steps;
  final caloriesDone =
      stats != null && stats.calories >= targets.activeCalories;
  final activeMinutesDone =
      stats != null && stats.activeMinutes >= targets.activeMinutes;
  final workoutDone = signals.workoutDoneToday;
  final waterDone = water >= waterTarget && waterTarget > 0;
  final challengeDone = challengesState?.completedToday ?? false;

  int generalGoalsCount = 0;
  if (stepsDone) generalGoalsCount++;
  if (caloriesDone) generalGoalsCount++;
  if (activeMinutesDone) generalGoalsCount++;
  if (workoutDone) generalGoalsCount++;
  if (waterDone) generalGoalsCount++;
  if (challengeDone) generalGoalsCount++;

  final total = totalScheduleTasks;
  final rawCount = math.max(scheduleDone, generalGoalsCount);
  final count = rawCount.clamp(0, total);

  // Requirements:
  // - After completing 4 daily schedule tasks (4 or 5) -> flex_proud.png
  // - After completing 6 tasks OR daily walking steps -> Fire_Determined.png
  // - Otherwise (less than 4 tasks and steps not done) -> Sad_Drooped_Head.png
  DailyCompletionTier calculatedTier;
  if (count >= 6 || stepsDone) {
    calculatedTier = DailyCompletionTier.everythingDone;
  } else if (count >= 4) {
    calculatedTier = DailyCompletionTier.fourToFiveDone;
  } else {
    calculatedTier = DailyCompletionTier.nothingDone;
  }

  final override = ref.watch(dailyCompletionTierOverrideProvider);
  final effectiveTier = override ?? calculatedTier;

  return DailyCompletionProgress(
    completedCount: override == null
        ? count
        : (override == DailyCompletionTier.nothingDone
            ? (count < 4 ? count : 0)
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
