import 'dart:math';

import 'package:fitbuddy/features/teams/data/team.dart';
import 'package:fitbuddy/features/teams/data/team_repository.dart';
import 'package:fitbuddy/features/teams/domain/team_goals.dart';

/// In-memory [TeamRepository] with two joinable demo teams
/// (invite codes `WALK42` and `RUN777`).
class MockTeamRepository implements TeamRepository {
  /// Creates the mock.
  MockTeamRepository({
    required String Function() currentUserId,
    required String Function() currentUserName,
    Random? random,
  })  : _currentUserId = currentUserId,
        _currentUserName = currentUserName,
        _random = random ?? Random() {
    _seed();
  }

  final String Function() _currentUserId;
  final String Function() _currentUserName;
  final Random _random;

  final Map<String, Team> _teams = <String, Team>{};
  final Map<String, List<TeamMember>> _members = <String, List<TeamMember>>{};
  final Map<String, double> _levels = <String, double>{};
  int _nextId = 1;

  void _seed() {
    final now = DateTime.now();
    _addSeed(
      Team(
        id: 'team_walkers',
        name: 'Morning Walkers',
        type: TeamType.walking,
        inviteCode: 'WALK42',
        ownerId: 'u_aanya',
        createdAt: now.subtract(const Duration(days: 14)),
      ),
      const <(String, String, double)>[
        ('u_aanya', 'Aanya', 0.9),
        ('u_rohan', 'Rohan', 0.6),
        ('u_meera', 'Meera', 1.1),
        ('u_kabir', 'Kabir', 0.4),
      ],
    );
    _addSeed(
      Team(
        id: 'team_runners',
        name: 'Sunday Runners',
        type: TeamType.running,
        inviteCode: 'RUN777',
        ownerId: 'u_sana',
        createdAt: now.subtract(const Duration(days: 30)),
      ),
      const <(String, String, double)>[
        ('u_sana', 'Sana', 0.8),
        ('u_dev', 'Dev', 0.5),
        ('u_isha', 'Isha', 1.0),
      ],
    );
  }

  void _addSeed(Team team, List<(String, String, double)> people) {
    _teams[team.id] = team;
    _members[team.id] = <TeamMember>[
      for (final p in people)
        TeamMember(
          teamId: team.id,
          userId: p.$1,
          joinedAt: team.createdAt,
          displayName: p.$2,
        ),
    ];
    for (final p in people) {
      _levels[p.$1] = p.$3;
    }
  }

  bool _isMember(String teamId, String userId) =>
      (_members[teamId] ?? const <TeamMember>[]).any((m) => m.userId == userId);

  Team _withCount(Team team) =>
      team.copyWith(memberCount: _members[team.id]?.length ?? 0);

  int _valueFor(String userId, TeamType type, LeaderboardPeriod period) {
    final level = _levels[userId] ?? 0.55;
    final week = (level * TeamGoals.weeklyTargetPerMember(type)).round();
    return period == LeaderboardPeriod.thisWeek ? week : (week * 3.6).round();
  }

  @override
  Future<List<Team>> myTeams() async {
    final me = _currentUserId();
    final list = <Team>[
      for (final team in _teams.values)
        if (_isMember(team.id, me)) _withCount(team),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<Team?> getTeam(String id) async {
    final team = _teams[id];
    if (team == null || !_isMember(id, _currentUserId())) return null;
    return _withCount(team);
  }

  @override
  Future<Team> createTeam({
    required String name,
    required TeamType type,
  }) async {
    final problem = validateTeamName(name);
    if (problem != null) throw TeamException(TeamError.invalidName, problem);

    final used = _teams.values.map((t) => t.inviteCode).toSet();
    var code = generateInviteCode(_random);
    while (used.contains(code)) {
      code = generateInviteCode(_random);
    }

    final me = _currentUserId();
    final team = Team(
      id: 'team_${_nextId++}',
      name: name.trim(),
      type: type,
      inviteCode: code,
      ownerId: me,
      createdAt: DateTime.now(),
    );
    _teams[team.id] = team;
    _members[team.id] = <TeamMember>[
      TeamMember(
        teamId: team.id,
        userId: me,
        joinedAt: team.createdAt,
        displayName: _currentUserName(),
      ),
    ];
    return _withCount(team);
  }

  @override
  Future<Team> joinByCode(String code) async {
    final normalized = normalizeInviteCode(code);
    final matches =
        _teams.values.where((t) => t.inviteCode == normalized).toList();
    if (normalized.length != inviteCodeLength || matches.isEmpty) {
      throw const TeamException(
        TeamError.invalidCode,
        'We could not find a team with that code. Please check it and try '
        'again.',
      );
    }
    final team = matches.first;
    final me = _currentUserId();
    if (_isMember(team.id, me)) {
      throw const TeamException(
        TeamError.alreadyMember,
        'You are already in this team.',
      );
    }
    _members[team.id]!.add(
      TeamMember(
        teamId: team.id,
        userId: me,
        joinedAt: DateTime.now(),
        displayName: _currentUserName(),
      ),
    );
    return _withCount(team);
  }

  @override
  Future<void> leaveTeam(String teamId) async {
    final team = _teams[teamId];
    final me = _currentUserId();
    if (team == null || !_isMember(teamId, me)) {
      throw const TeamException(TeamError.notFound, 'This team was not found.');
    }
    if (team.ownerId == me) {
      throw const TeamException(
        TeamError.ownerCannotLeave,
        'Team owners cannot leave their own team yet.',
      );
    }
    _members[teamId]!.removeWhere((m) => m.userId == me);
  }

  @override
  Future<List<TeamMember>> members(String teamId) async {
    if (!_isMember(teamId, _currentUserId())) return const <TeamMember>[];
    return List<TeamMember>.unmodifiable(_members[teamId]!);
  }

  @override
  Future<List<LeaderboardEntry>> leaderboard(
    String teamId,
    LeaderboardPeriod period,
  ) async {
    final team = _teams[teamId];
    if (team == null || !_isMember(teamId, _currentUserId())) {
      return const <LeaderboardEntry>[];
    }
    return <LeaderboardEntry>[
      for (final m in _members[teamId]!)
        LeaderboardEntry(
          userId: m.userId,
          name: m.displayName.isEmpty ? 'Member' : m.displayName,
          value: _valueFor(m.userId, team.type, period),
        ),
    ];
  }
}
