import 'package:flutter/foundation.dart';

/// The kind of activity a team focuses on.
enum TeamType {
  /// Running team, ranked by active minutes.
  running('running', 'Running', 'Active minutes', 'min'),

  /// Workout team, ranked by workouts completed.
  workout('workout', 'Workout', 'Workouts completed', 'workouts'),

  /// Walking team, ranked by steps.
  walking('walking', 'Walking', 'Steps', 'steps');

  const TeamType(this.json, this.label, this.metricLabel, this.unit);

  /// Value stored in `teams.type`.
  final String json;

  /// Friendly name.
  final String label;

  /// What the leaderboard measures.
  final String metricLabel;

  /// Short unit shown next to values.
  final String unit;

  /// Parses a database value (unknown values become [workout]).
  static TeamType fromJson(String value) => values.firstWhere(
        (t) => t.json == value,
        orElse: () => TeamType.workout,
      );
}

/// Time window for the leaderboard.
enum LeaderboardPeriod {
  /// Current week.
  thisWeek('This week'),

  /// Current month.
  thisMonth('This month');

  const LeaderboardPeriod(this.label);

  /// Friendly label.
  final String label;
}

/// A team (row of the `teams` table).
@immutable
class Team {
  /// Creates a team.
  const Team({
    required this.id,
    required this.name,
    required this.type,
    required this.inviteCode,
    required this.ownerId,
    required this.createdAt,
    this.memberCount = 0,
  });

  /// Reads a team from JSON (optional `member_count` is a computed extra).
  factory Team.fromJson(Map<String, dynamic> json) => Team(
        id: json['id'] as String,
        name: json['name'] as String,
        type: TeamType.fromJson((json['type'] as String?) ?? 'workout'),
        inviteCode: json['invite_code'] as String,
        ownerId: (json['owner_id'] as String?) ?? '',
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      );

  /// Team id.
  final String id;

  /// Team name.
  final String name;

  /// Team type.
  final TeamType type;

  /// Code friends use to join.
  final String inviteCode;

  /// Owner's user id.
  final String ownerId;

  /// When the team was created.
  final DateTime createdAt;

  /// Number of members (computed, not a column).
  final int memberCount;

  /// Writes the table columns.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'type': type.json,
        'invite_code': inviteCode,
        'owner_id': ownerId,
        'created_at': createdAt.toIso8601String(),
      };

  /// Returns a copy with a different [memberCount].
  Team copyWith({int? memberCount}) => Team(
        id: id,
        name: name,
        type: type,
        inviteCode: inviteCode,
        ownerId: ownerId,
        createdAt: createdAt,
        memberCount: memberCount ?? this.memberCount,
      );
}

/// A team member (row of `team_members`, plus the member's display name).
@immutable
class TeamMember {
  /// Creates a member.
  const TeamMember({
    required this.teamId,
    required this.userId,
    required this.joinedAt,
    this.displayName = '',
  });

  /// Reads a member from JSON. The name may come from a joined `profiles`
  /// object or a `display_name` field.
  factory TeamMember.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'];
    final fromProfile =
        profile is Map<String, dynamic> ? profile['name'] as String? : null;
    final name = fromProfile ?? (json['display_name'] as String?) ?? '';
    return TeamMember(
      teamId: json['team_id'] as String,
      userId: json['user_id'] as String,
      joinedAt: DateTime.tryParse(json['joined_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      displayName: name,
    );
  }

  /// Team id.
  final String teamId;

  /// User id.
  final String userId;

  /// When the user joined.
  final DateTime joinedAt;

  /// Member's name (from `profiles.name`).
  final String displayName;

  /// Writes the table columns.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'team_id': teamId,
        'user_id': userId,
        'joined_at': joinedAt.toIso8601String(),
      };
}

/// One row of a leaderboard.
@immutable
class LeaderboardEntry {
  /// Creates an entry. [rank] is assigned later by `assignRanks`.
  const LeaderboardEntry({
    required this.userId,
    required this.name,
    required this.value,
    this.rank = 0,
  });

  /// User id.
  final String userId;

  /// Display name.
  final String name;

  /// Score for the period (steps, minutes or workouts).
  final int value;

  /// Position, starting at 1 (ties share a rank).
  final int rank;

  /// Returns a copy with a new [rank].
  LeaderboardEntry copyWith({int? rank}) => LeaderboardEntry(
        userId: userId,
        name: name,
        value: value,
        rank: rank ?? this.rank,
      );
}
