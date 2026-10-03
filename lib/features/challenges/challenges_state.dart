import 'package:fitbuddy/features/challenges/badge_catalog.dart';
import 'package:fitbuddy/features/challenges/data/challenge.dart';
import 'package:fitbuddy/features/challenges/data/challenge_completion.dart';
import 'package:fitbuddy/features/challenges/data/streak_state.dart';
import 'package:fitbuddy/features/challenges/level_logic.dart';
import 'package:fitbuddy/features/challenges/streak_logic.dart';
import 'package:fitbuddy/features/schedule/day_key.dart';
import 'package:flutter/foundation.dart';

/// What the user just earned by completing a challenge.
///
/// Deliberately has no `==`: every reward is a new event.
@immutable
class ChallengeReward {
  /// Creates a reward.
  const ChallengeReward({required this.xp, this.milestone});

  /// XP awarded, including any milestone bonus.
  final int xp;

  /// Streak length reached if it is a milestone day.
  final int? milestone;
}

/// A completion joined with its challenge (null if it is no longer listed).
@immutable
class CompletionEntry {
  /// Creates an entry.
  const CompletionEntry({required this.completion, required this.challenge});

  /// The completion row.
  final ChallengeCompletion completion;

  /// The challenge that was completed, if still in the catalog.
  final Challenge? challenge;
}

/// Everything the challenges screens need, computed from stored rows.
@immutable
class ChallengesState {
  /// Creates the state.
  const ChallengesState({
    required this.completions,
    required this.streak,
    required this.today,
    this.lastReward,
  });

  /// All completions, newest first.
  final List<ChallengeCompletion> completions;

  /// Stored streak and XP.
  final StreakState streak;

  /// The local calendar day this state was built for.
  final DateTime today;

  /// Reward from the most recent completion in this session.
  final ChallengeReward? lastReward;

  /// Whether today's challenge is done.
  bool get completedToday => completions.any((c) => isSameDay(c.date, today));

  /// Number of challenges completed so far.
  int get totalCompletions => completions.length;

  /// Streak to display (0 if it is already broken).
  int get currentStreak => StreakLogic.effectiveCurrent(streak, today);

  /// Whether a workout or challenge was already recorded today.
  bool get activeToday => StreakLogic.isActiveOn(streak, today);

  /// Level and progress from total XP.
  LevelInfo get level => LevelLogic.levelFor(streak.xp);

  /// Ids of earned badges.
  Set<String> get earnedBadgeIds => BadgeCatalog.earnedIds(
        BadgeStats(
          totalCompletions: totalCompletions,
          longestStreak: streak.longest,
          level: level.level,
        ),
      );

  /// Returns a copy with the given fields replaced.
  ChallengesState copyWith({
    List<ChallengeCompletion>? completions,
    StreakState? streak,
    DateTime? today,
    ChallengeReward? lastReward,
  }) {
    return ChallengesState(
      completions: completions ?? this.completions,
      streak: streak ?? this.streak,
      today: today ?? this.today,
      lastReward: lastReward ?? this.lastReward,
    );
  }
}
