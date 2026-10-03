import 'package:flutter/foundation.dart';

/// A badge the user can earn.
@immutable
class ChallengeBadge {
  /// Creates a badge.
  const ChallengeBadge({
    required this.id,
    required this.title,
    required this.description,
  });

  /// Stable id (the UI maps ids to icons).
  final String id;

  /// Short name.
  final String title;

  /// How to earn it.
  final String description;
}

/// Numbers that decide which badges are earned.
@immutable
class BadgeStats {
  /// Creates the stats.
  const BadgeStats({
    this.totalCompletions = 0,
    this.longestStreak = 0,
    this.level = 1,
  });

  /// Daily challenges completed so far.
  final int totalCompletions;

  /// Longest daily streak ever.
  final int longestStreak;

  /// Current XP level.
  final int level;
}

/// All badges and the rules for earning them. Pure Dart.
abstract final class BadgeCatalog {
  static final List<(ChallengeBadge, bool Function(BadgeStats))> _rules = [
    (
      const ChallengeBadge(
        id: 'first_step',
        title: 'First step',
        description: 'Complete your first daily challenge.',
      ),
      (s) => s.totalCompletions >= 1,
    ),
    (
      const ChallengeBadge(
        id: 'streak_3',
        title: '3-day streak',
        description: 'Be active 3 days in a row.',
      ),
      (s) => s.longestStreak >= 3,
    ),
    (
      const ChallengeBadge(
        id: 'streak_7',
        title: 'One week',
        description: 'Be active 7 days in a row.',
      ),
      (s) => s.longestStreak >= 7,
    ),
    (
      const ChallengeBadge(
        id: 'streak_14',
        title: 'Two weeks',
        description: 'Be active 14 days in a row.',
      ),
      (s) => s.longestStreak >= 14,
    ),
    (
      const ChallengeBadge(
        id: 'streak_30',
        title: '30-day streak',
        description: 'Be active 30 days in a row.',
      ),
      (s) => s.longestStreak >= 30,
    ),
    (
      const ChallengeBadge(
        id: 'streak_50',
        title: '50-day streak',
        description: 'Be active 50 days in a row.',
      ),
      (s) => s.longestStreak >= 50,
    ),
    (
      const ChallengeBadge(
        id: 'streak_100',
        title: '100-day streak',
        description: 'Be active 100 days in a row.',
      ),
      (s) => s.longestStreak >= 100,
    ),
    (
      const ChallengeBadge(
        id: 'challenges_10',
        title: '10 challenges',
        description: 'Complete 10 daily challenges.',
      ),
      (s) => s.totalCompletions >= 10,
    ),
    (
      const ChallengeBadge(
        id: 'challenges_25',
        title: '25 challenges',
        description: 'Complete 25 daily challenges.',
      ),
      (s) => s.totalCompletions >= 25,
    ),
    (
      const ChallengeBadge(
        id: 'challenges_50',
        title: '50 challenges',
        description: 'Complete 50 daily challenges.',
      ),
      (s) => s.totalCompletions >= 50,
    ),
    (
      const ChallengeBadge(
        id: 'level_5',
        title: 'Level 5',
        description: 'Reach level 5.',
      ),
      (s) => s.level >= 5,
    ),
    (
      const ChallengeBadge(
        id: 'level_10',
        title: 'Level 10',
        description: 'Reach level 10.',
      ),
      (s) => s.level >= 10,
    ),
  ];

  /// Every badge, in display order.
  static List<ChallengeBadge> get all =>
      List<ChallengeBadge>.unmodifiable([for (final r in _rules) r.$1]);

  /// Ids of the badges earned with [stats].
  static Set<String> earnedIds(BadgeStats stats) => {
        for (final r in _rules)
          if (r.$2(stats)) r.$1.id,
      };
}
