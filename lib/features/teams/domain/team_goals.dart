import 'dart:math';

import 'package:fitbuddy/features/teams/data/team.dart';

const String _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// Length of an invite code.
const int inviteCodeLength = 6;

/// Creates a random invite code (no easily confused characters).
String generateInviteCode(Random random) => String.fromCharCodes(
      Iterable<int>.generate(
        inviteCodeLength,
        (_) => _codeAlphabet.codeUnitAt(random.nextInt(_codeAlphabet.length)),
      ),
    );

/// Upper-cases the input and removes spaces, dashes and other symbols.
String normalizeInviteCode(String input) =>
    input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// Returns a friendly problem message, or null when [name] is fine.
String? validateTeamName(String name) {
  final trimmed = name.trim();
  if (trimmed.length < 2) return 'Please enter at least 2 characters';
  if (trimmed.length > 30) return 'Please keep the name under 30 characters';
  return null;
}

/// Formats a number with thousands separators, for example `35,000`.
String formatCount(int value) => value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );

/// Sorts entries (highest first, then by name) and assigns ranks.
/// Equal scores share the same rank.
List<LeaderboardEntry> assignRanks(List<LeaderboardEntry> entries) {
  final sorted = List<LeaderboardEntry>.of(entries)
    ..sort((a, b) {
      final byValue = b.value.compareTo(a.value);
      if (byValue != 0) return byValue;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  final ranked = <LeaderboardEntry>[];
  for (var i = 0; i < sorted.length; i++) {
    final entry = sorted[i];
    final sameAsPrevious = i > 0 && sorted[i - 1].value == entry.value;
    ranked.add(entry.copyWith(rank: sameAsPrevious ? ranked[i - 1].rank : i + 1));
  }
  return ranked;
}

/// Default shared weekly goals. The database has no goal column, so these
/// are client-side defaults.
class TeamGoals {
  const TeamGoals._();

  /// Weekly target for one member.
  static int weeklyTargetPerMember(TeamType type) => switch (type) {
        TeamType.walking => 35000,
        TeamType.running => 90,
        TeamType.workout => 3,
      };

  /// Weekly target for a whole team.
  static int teamWeeklyTarget(TeamType type, int memberCount) =>
      weeklyTargetPerMember(type) * (memberCount < 1 ? 1 : memberCount);

  /// Progress from 0.0 to 1.0.
  static double progress(int total, int target) {
    if (target <= 0) return 0;
    return (total / target).clamp(0.0, 1.0).toDouble();
  }

  /// One-line explanation of what the team is ranked on.
  static String describe(TeamType type) => switch (type) {
        TeamType.walking => 'Teammates are ranked by steps.',
        TeamType.running => 'Teammates are ranked by active minutes.',
        TeamType.workout => 'Teammates are ranked by workouts completed.',
      };
}
