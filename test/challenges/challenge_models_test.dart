import 'dart:convert';
import 'dart:io';

import 'package:fitbuddy/features/challenges/data/challenge.dart';
import 'package:fitbuddy/features/challenges/data/challenge_completion.dart';
import 'package:fitbuddy/features/challenges/data/challenge_repository.dart';
import 'package:fitbuddy/features/challenges/data/streak_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Challenge', () {
    test('fromJson and toJson use the database column names', () {
      final c = Challenge.fromJson({
        'id': 'c1',
        'title': 'Drink 8 glasses of water',
        'description': 'Sip through the day.',
        'type': 'water',
        'target_value': 8,
        'xp': 15,
      });
      expect(c.type, ChallengeType.water);
      expect(c.targetValue, 8);
      expect(c.xp, 15);
      final json = c.toJson();
      expect(json['type'], 'water');
      expect(json['target_value'], 8);
      expect(json['xp'], 15);
    });

    test('missing fields fall back to sensible defaults', () {
      final c = Challenge.fromJson({'id': 'c2', 'title': 'Stretch'});
      expect(c.type, ChallengeType.checkoff);
      expect(c.targetValue, 1);
      expect(c.xp, 10);
      expect(c.description, isEmpty);
    });

    test('progress helpers', () {
      const c = Challenge(
        id: 'c3',
        title: 'Squats',
        type: ChallengeType.reps,
        targetValue: 20,
      );
      expect(c.fractionFor(0), 0);
      expect(c.fractionFor(5), 0.25);
      expect(c.fractionFor(40), 1);
      expect(c.isCompleteAt(19), isFalse);
      expect(c.isCompleteAt(20), isTrue);
    });

    test('auto tracked types', () {
      expect(ChallengeType.steps.isAutoTracked, isTrue);
      expect(ChallengeType.activeMinutes.isAutoTracked, isTrue);
      expect(ChallengeType.workout.isAutoTracked, isTrue);
      expect(ChallengeType.reps.isAutoTracked, isFalse);
      expect(ChallengeType.water.isAutoTracked, isFalse);
    });
  });

  group('ChallengeCompletion and StreakState JSON', () {
    test('completion round trip', () {
      final c = ChallengeCompletion.fromJson({
        'id': 'cc1',
        'user_id': 'u1',
        'challenge_id': 'c1',
        'date': '2026-01-05',
      });
      expect(c.date, DateTime(2026, 1, 5));
      expect(c.toJson()['challenge_id'], 'c1');
      expect(c.toJson()['date'], '2026-01-05');
    });

    test('streak round trip with a null last_active_date', () {
      final s = StreakState.fromJson({
        'user_id': 'u1',
        'current': 0,
        'longest': 0,
        'last_active_date': null,
        'xp': 0,
      });
      expect(s.lastActiveDate, isNull);
      expect(s.toJson()['last_active_date'], isNull);
    });

    test('streak round trip with a date', () {
      final s = StreakState.fromJson({
        'user_id': 'u1',
        'current': 4,
        'longest': 9,
        'last_active_date': '2026-01-04',
        'xp': 120,
      });
      expect(s.lastActiveDate, DateTime(2026, 1, 4));
      expect(StreakState.fromJson(s.toJson()), s);
    });
  });

  group('challenges.json asset', () {
    final raw = File('assets/data/challenges.json').readAsStringSync();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final entries = (decoded['challenges'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final validTypes = ChallengeType.values.map((t) => t.dbValue).toSet();

    test('has at least 30 challenges', () {
      expect(entries.length, greaterThanOrEqualTo(30));
    });
    test('ids are unique and titles are not empty', () {
      final ids = entries.map((e) => e['id'] as String).toList();
      expect(ids.toSet().length, ids.length);
      for (final e in entries) {
        expect((e['title'] as String).trim(), isNotEmpty);
      }
    });
    test('types, targets and xp are valid', () {
      for (final e in entries) {
        expect(validTypes, contains(e['type']), reason: '${e['id']} type');
        expect(e['target_value'] as int, greaterThan(0), reason: '${e['id']}');
        expect(e['xp'] as int, greaterThan(0), reason: '${e['id']}');
      }
    });
    test('every entry parses into a Challenge', () {
      for (final e in entries) {
        final c = Challenge.fromJson(e);
        expect(c.toJson()['type'], e['type']);
      }
    });
  });

  group('MockChallengeRepository', () {
    final catalog = [
      for (var i = 1; i <= 5; i++)
        Challenge(
          id: 'ch-00$i',
          title: 'Challenge $i',
          type: ChallengeType.checkoff,
          targetValue: 1,
          xp: 10,
        ),
    ];
    final today = DateTime(2026, 1, 10, 15);

    MockChallengeRepository build({bool seed = true}) =>
        MockChallengeRepository(
          catalog: () async => catalog,
          clock: () => today,
          seedDemoHistory: seed,
        );

    test('seeds three previous days and a streak of 3', () async {
      final repo = build();
      final completions = await repo.fetchCompletions();
      expect(completions.length, 3);
      expect(completions.first.date, DateTime(2026, 1, 9));
      final streak = await repo.fetchStreak();
      expect(streak.current, 3);
      expect(streak.lastActiveDate, DateTime(2026, 1, 9));
      expect(streak.xp, 70);
    });

    test('can start empty', () async {
      final repo = build(seed: false);
      expect(await repo.fetchCompletions(), isEmpty);
      expect((await repo.fetchStreak()).current, 0);
    });

    test('only one completion per day', () async {
      final repo = build(seed: false);
      final first = await repo.addCompletion(
        challengeId: 'ch-001',
        day: DateTime(2026, 1, 10),
      );
      final second = await repo.addCompletion(
        challengeId: 'ch-002',
        day: DateTime(2026, 1, 10, 22),
      );
      expect(second.id, first.id);
      expect((await repo.fetchCompletions()).length, 1);
    });

    test('progress is stored per challenge and day and never negative', () async {
      final repo = build(seed: false);
      final day = DateTime(2026, 1, 10);
      expect(await repo.getProgress('ch-001', day), 0);
      await repo.setProgress('ch-001', day, 12);
      expect(await repo.getProgress('ch-001', day), 12);
      expect(await repo.getProgress('ch-001', DateTime(2026, 1, 11)), 0);
      await repo.setProgress('ch-001', day, -3);
      expect(await repo.getProgress('ch-001', day), 0);
    });

    test('saved streak is returned', () async {
      final repo = build(seed: false);
      const s = StreakState(userId: 'u', current: 2, longest: 2, xp: 30);
      await repo.saveStreak(s);
      expect(await repo.fetchStreak(), s);
    });
  });
}
