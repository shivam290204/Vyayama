import 'package:fitbuddy/features/teams/data/mock_team_repository.dart';
import 'package:fitbuddy/features/teams/data/team.dart';
import 'package:fitbuddy/features/teams/data/team_repository.dart';
import 'package:fitbuddy/features/teams/domain/team_goals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Team Models & Serialization', () {
    test('serializes and deserializes Team', () {
      final now = DateTime.utc(2026, 10, 15, 10, 0);
      final team = Team(
        id: 'team_1',
        name: 'Iron Lifters',
        type: TeamType.workout,
        inviteCode: 'IRON99',
        ownerId: 'u_1',
        createdAt: now,
        memberCount: 5,
      );

      final json = team.toJson();
      expect(json['id'], 'team_1');
      expect(json['name'], 'Iron Lifters');
      expect(json['type'], 'workout');
      expect(json['invite_code'], 'IRON99');
      expect(json['owner_id'], 'u_1');

      final deserialized = Team.fromJson({...json, 'member_count': 5});
      expect(deserialized.id, team.id);
      expect(deserialized.name, team.name);
      expect(deserialized.type, TeamType.workout);
      expect(deserialized.inviteCode, team.inviteCode);
      expect(deserialized.memberCount, 5);
    });

    test('serializes and deserializes TeamMember', () {
      final joined = DateTime.utc(2026, 10, 12);
      final member = TeamMember(
        teamId: 'team_1',
        userId: 'u_2',
        joinedAt: joined,
        displayName: 'Aanya',
      );

      final json = member.toJson();
      expect(json['team_id'], 'team_1');
      expect(json['user_id'], 'u_2');

      final deserialized = TeamMember.fromJson({...json, 'display_name': 'Aanya'});
      expect(deserialized.teamId, member.teamId);
      expect(deserialized.userId, member.userId);
      expect(deserialized.displayName, 'Aanya');
    });

    test('TeamType parsing fallback to workout', () {
      expect(TeamType.fromJson('running'), TeamType.running);
      expect(TeamType.fromJson('walking'), TeamType.walking);
      expect(TeamType.fromJson('unknown_type'), TeamType.workout);
    });
  });

  group('Team Domain & Leaderboard', () {
    test('assignRanks orders by value descending and handles ties', () {
      const entries = [
        LeaderboardEntry(userId: 'u1', name: 'Alice', value: 100),
        LeaderboardEntry(userId: 'u2', name: 'Bob', value: 200),
        LeaderboardEntry(userId: 'u3', name: 'Charlie', value: 200),
        LeaderboardEntry(userId: 'u4', name: 'David', value: 50),
      ];

      final ranked = assignRanks(entries);
      expect(ranked[0].name, 'Bob');
      expect(ranked[0].rank, 1);
      expect(ranked[1].name, 'Charlie');
      expect(ranked[1].rank, 1); // Tie with Bob
      expect(ranked[2].name, 'Alice');
      expect(ranked[2].rank, 3);
      expect(ranked[3].name, 'David');
      expect(ranked[3].rank, 4);
    });

    test('validateTeamName checks length constraints', () {
      expect(validateTeamName(''), isNotNull);
      expect(validateTeamName('A'), isNotNull);
      expect(validateTeamName('Valid Team'), isNull);
      expect(validateTeamName('A' * 35), isNotNull);
    });

    test('normalizeInviteCode cleans punctuation and uppercases', () {
      expect(normalizeInviteCode('walk-42!'), 'WALK42');
      expect(normalizeInviteCode(' run 777 '), 'RUN777');
    });

    test('TeamGoals calculations', () {
      expect(TeamGoals.weeklyTargetPerMember(TeamType.walking), 35000);
      expect(TeamGoals.teamWeeklyTarget(TeamType.walking, 4), 140000);
      expect(TeamGoals.progress(70000, 140000), 0.5);
      expect(TeamGoals.progress(200000, 140000), 1.0);
    });
  });

  group('MockTeamRepository Integration', () {
    late MockTeamRepository repo;

    setUp(() {
      repo = MockTeamRepository(
        currentUserId: () => 'me',
        currentUserName: () => 'Test User',
      );
    });

    test('myTeams returns seeded demo teams', () async {
      final teams = await repo.myTeams();
      expect(teams.length, greaterThanOrEqualTo(2));
    });

    test('createTeam creates and joins new team', () async {
      final created = await repo.createTeam(
        name: 'New Squad',
        type: TeamType.running,
      );
      expect(created.name, 'New Squad');
      expect(created.type, TeamType.running);
      expect(created.ownerId, 'me');

      final members = await repo.members(created.id);
      expect(members.any((m) => m.userId == 'me'), isTrue);
    });

    test('joinByCode throws TeamException on invalid code', () async {
      expect(
        () => repo.joinByCode('INVALID999'),
        throwsA(isA<TeamException>()),
      );
    });
  });
}
