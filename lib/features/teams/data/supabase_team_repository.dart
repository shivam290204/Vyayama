import 'package:fitbuddy/features/teams/data/team.dart';
import 'package:fitbuddy/features/teams/data/team_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase implementation of [TeamRepository] backed by the `teams` and
/// `team_members` tables, plus the `create_team`, `join_team`, and
/// `team_leaderboard` RPCs.
class SupabaseTeamRepository implements TeamRepository {
  /// Creates the repository with an optional [SupabaseClient].
  SupabaseTeamRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('User not signed in');
    return user.id;
  }

  @override
  Future<List<Team>> myTeams() async {
    try {
      final res = await _client
          .from('teams')
          .select('*, team_members(count)')
          .order('created_at', ascending: false);

      return (res as List).map((r) => _parseTeam(Map<String, dynamic>.from(r))).toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<Team?> getTeam(String id) async {
    try {
      final res = await _client
          .from('teams')
          .select('*, team_members(count)')
          .eq('id', id)
          .maybeSingle();

      if (res == null) return null;
      return _parseTeam(Map<String, dynamic>.from(res));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Team> createTeam({required String name, required TeamType type}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty || trimmedName.length > 60) {
      throw const TeamException(
        TeamError.invalidName,
        'Team name must be between 1 and 60 characters',
      );
    }

    try {
      final res = await _client.rpc(
        'create_team',
        params: {
          'p_name': trimmedName,
          'p_type': type.json,
        },
      );

      final teamId = res.toString();
      final team = await getTeam(teamId);
      if (team == null) {
        throw const TeamException(TeamError.notFound, 'Failed to load created team');
      }
      return team;
    } on PostgrestException catch (e) {
      throw TeamException(TeamError.invalidName, e.message);
    }
  }

  @override
  Future<Team> joinByCode(String code) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) {
      throw const TeamException(TeamError.invalidCode, 'Invalid invite code');
    }

    try {
      final res = await _client.rpc(
        'join_team',
        params: {'p_invite_code': cleanCode},
      );

      final teamId = res.toString();
      final team = await getTeam(teamId);
      if (team == null) {
        throw const TeamException(TeamError.notFound, 'Team not found');
      }
      return team;
    } on PostgrestException catch (e) {
      if (e.code == 'P0002' || e.message.toLowerCase().contains('invalid invite code')) {
        throw const TeamException(
          TeamError.invalidCode,
          'No team matches this invite code',
        );
      }
      throw TeamException(TeamError.invalidCode, e.message);
    }
  }

  @override
  Future<void> leaveTeam(String teamId) async {
    final team = await getTeam(teamId);
    if (team == null) {
      throw const TeamException(TeamError.notFound, 'Team not found');
    }
    if (team.ownerId == _userId) {
      throw const TeamException(
        TeamError.ownerCannotLeave,
        'The owner cannot leave their own team',
      );
    }

    try {
      await _client
          .from('team_members')
          .delete()
          .eq('team_id', teamId)
          .eq('user_id', _userId);
    } on PostgrestException catch (e) {
      throw TeamException(TeamError.notFound, e.message);
    }
  }

  @override
  Future<List<TeamMember>> members(String teamId) async {
    try {
      final res = await _client
          .from('team_members')
          .select('team_id, user_id, joined_at, profiles(name)')
          .eq('team_id', teamId)
          .order('joined_at', ascending: true);

      return (res as List)
          .map((r) => TeamMember.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<LeaderboardEntry>> leaderboard(
    String teamId,
    LeaderboardPeriod period,
  ) async {
    try {
      final team = await getTeam(teamId);
      final type = team?.type ?? TeamType.workout;

      final now = DateTime.now();
      late final DateTime from;
      late final DateTime to;

      if (period == LeaderboardPeriod.thisWeek) {
        final weekday = now.weekday; // 1 = Monday
        from = DateTime(now.year, now.month, now.day).subtract(Duration(days: weekday - 1));
        to = from.add(const Duration(days: 6));
      } else {
        from = DateTime(now.year, now.month, 1);
        to = DateTime(now.year, now.month + 1, 0);
      }

      String formatDate(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      final res = await _client.rpc(
        'team_leaderboard',
        params: {
          'p_team_id': teamId,
          'p_from': formatDate(from),
          'p_to': formatDate(to),
        },
      );

      return (res as List).map((row) {
        final m = Map<String, dynamic>.from(row);
        final val = switch (type) {
          TeamType.walking => (m['steps'] as num?)?.toInt() ?? 0,
          TeamType.running => (m['active_minutes'] as num?)?.toInt() ?? 0,
          TeamType.workout => (m['workouts'] as num?)?.toInt() ?? 0,
        };
        final name = (m['name'] as String?)?.trim();
        final username = (m['username'] as String?)?.trim();
        final displayName = (name != null && name.isNotEmpty)
            ? name
            : ((username != null && username.isNotEmpty) ? username : 'Member');

        return LeaderboardEntry(
          userId: m['user_id'] as String,
          name: displayName,
          value: val,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  static Team _parseTeam(Map<String, dynamic> json) {
    if (json.containsKey('team_members')) {
      final tm = json['team_members'];
      if (tm is List && tm.isNotEmpty) {
        final first = tm.first;
        if (first is Map && first.containsKey('count')) {
          json['member_count'] = first['count'];
        }
      }
    }
    return Team.fromJson(json);
  }
}
