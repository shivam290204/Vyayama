import 'package:fitbuddy/features/health_profile/data/async_value_x.dart';
import 'package:fitbuddy/features/health_profile/providers.dart';
import 'package:fitbuddy/features/teams/data/invite_sharer.dart';
import 'package:fitbuddy/features/teams/data/mock_team_repository.dart';
import 'package:fitbuddy/features/teams/data/team.dart';
import 'package:fitbuddy/features/teams/data/team_repository.dart';
import 'package:fitbuddy/features/teams/domain/team_goals.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Id of the signed-in user (falls back to `me` while the profile loads).
final teamsCurrentUserIdProvider = Provider<String>((ref) {
  final id = ref.watch(profileSnapshotProvider).dataOrNull?.id;
  return (id == null || id.isEmpty) ? 'me' : id;
});

/// Display name of the signed-in user.
final teamsCurrentUserNameProvider = Provider<String>((ref) {
  final name = ref.watch(profileSnapshotProvider).dataOrNull?.name;
  return (name == null || name.trim().isEmpty) ? 'You' : name.trim();
});

/// Team data source.
/// Antigravity: override with a Supabase-backed implementation.
final teamRepositoryProvider = Provider<TeamRepository>(
  (ref) => MockTeamRepository(
    currentUserId: () => ref.read(teamsCurrentUserIdProvider),
    currentUserName: () => ref.read(teamsCurrentUserNameProvider),
  ),
);

/// Shares invite text. Antigravity: override with a `share_plus` version.
final inviteSharerProvider = Provider<InviteSharer>(
  (ref) => ClipboardInviteSharer(),
);

/// The teams the user belongs to, with create, join and leave actions.
final myTeamsProvider = AsyncNotifierProvider<MyTeamsNotifier, List<Team>>(
  MyTeamsNotifier.new,
);

/// One team (null when it does not exist or the user is not a member).
final teamProvider = FutureProvider.autoDispose.family<Team?, String>(
  (ref, id) => ref.watch(teamRepositoryProvider).getTeam(id),
);

/// Members of a team.
final teamMembersProvider =
    FutureProvider.autoDispose.family<List<TeamMember>, String>(
  (ref, teamId) => ref.watch(teamRepositoryProvider).members(teamId),
);

/// Which leaderboard to load.
typedef LeaderboardQuery = ({String teamId, LeaderboardPeriod period});

/// Ranked leaderboard for a team and period.
final teamLeaderboardProvider = FutureProvider.autoDispose
    .family<List<LeaderboardEntry>, LeaderboardQuery>((ref, query) async {
  final entries = await ref
      .watch(teamRepositoryProvider)
      .leaderboard(query.teamId, query.period);
  return assignRanks(entries);
});

/// Holds the user's teams and refreshes related data after changes.
class MyTeamsNotifier extends AsyncNotifier<List<Team>> {
  @override
  Future<List<Team>> build() => ref.watch(teamRepositoryProvider).myTeams();

  /// Creates a team and returns it.
  Future<Team> create({required String name, required TeamType type}) async {
    final repo = ref.read(teamRepositoryProvider);
    final team = await repo.createTeam(name: name, type: type);
    await _refresh();
    return team;
  }

  /// Joins a team by invite code and returns it.
  Future<Team> join(String code) async {
    final repo = ref.read(teamRepositoryProvider);
    final team = await repo.joinByCode(code);
    await _refresh();
    return team;
  }

  /// Leaves a team.
  Future<void> leave(String teamId) async {
    await ref.read(teamRepositoryProvider).leaveTeam(teamId);
    await _refresh();
  }

  Future<void> _refresh() async {
    ref
      ..invalidate(teamProvider)
      ..invalidate(teamMembersProvider)
      ..invalidate(teamLeaderboardProvider);
    state = AsyncData<List<Team>>(
      await ref.read(teamRepositoryProvider).myTeams(),
    );
  }
}
