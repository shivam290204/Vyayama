import 'package:fitbuddy/features/teams/data/team.dart';

/// Reasons a team action can fail.
enum TeamError {
  /// The team name is not valid.
  invalidName,

  /// No team matches the invite code.
  invalidCode,

  /// The user is already in the team.
  alreadyMember,

  /// The team does not exist.
  notFound,

  /// The owner cannot leave their own team.
  ownerCannotLeave,
}

/// A friendly, displayable team error.
class TeamException implements Exception {
  /// Creates the exception.
  const TeamException(this.error, this.message);

  /// Machine-readable reason.
  final TeamError error;

  /// Message safe to show to the user.
  final String message;

  @override
  String toString() => 'TeamException($error): $message';
}

/// Data source for teams.
///
/// Antigravity: back this with Supabase tables `teams` and `team_members`.
/// Joining must go through a secure RPC that checks the invite code, and the
/// leaderboard should come from `daily_stats` (steps, active minutes) and
/// `workout_logs` (workout counts) for the team's members.
abstract class TeamRepository {
  /// Teams the current user belongs to.
  Future<List<Team>> myTeams();

  /// A team the user belongs to, or null.
  Future<Team?> getTeam(String id);

  /// Creates a team owned by the current user.
  Future<Team> createTeam({required String name, required TeamType type});

  /// Joins the team with [code]. Throws [TeamException] on failure.
  Future<Team> joinByCode(String code);

  /// Leaves a team. Throws [TeamException] on failure.
  Future<void> leaveTeam(String teamId);

  /// Members of a team the user belongs to.
  Future<List<TeamMember>> members(String teamId);

  /// Scores for every member, in any order and without ranks.
  Future<List<LeaderboardEntry>> leaderboard(
    String teamId,
    LeaderboardPeriod period,
  );
}
