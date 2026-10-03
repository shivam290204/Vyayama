import 'package:fitbuddy/features/challenges/badge_catalog.dart';
import 'package:fitbuddy/features/challenges/level_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LevelLogic', () {
    test('xp needed per level', () {
      expect(LevelLogic.xpForLevel(1), 100);
      expect(LevelLogic.xpForLevel(2), 125);
      expect(LevelLogic.xpForLevel(3), 150);
    });
    test('zero xp is level 1 with no progress', () {
      final info = LevelLogic.levelFor(0);
      expect(info.level, 1);
      expect(info.xpIntoLevel, 0);
      expect(info.xpForLevel, 100);
      expect(info.progress, 0);
    });
    test('just below the first level', () {
      final info = LevelLogic.levelFor(99);
      expect(info.level, 1);
      expect(info.xpIntoLevel, 99);
      expect(info.xpToNext, 1);
    });
    test('exactly 100 xp starts level 2', () {
      final info = LevelLogic.levelFor(100);
      expect(info.level, 2);
      expect(info.xpIntoLevel, 0);
      expect(info.xpForLevel, 125);
    });
    test('level 2 to 3 boundary', () {
      expect(LevelLogic.levelFor(224).level, 2);
      expect(LevelLogic.levelFor(224).xpIntoLevel, 124);
      expect(LevelLogic.levelFor(225).level, 3);
      expect(LevelLogic.levelFor(225).xpIntoLevel, 0);
    });
    test('level 3 to 4 boundary', () {
      final info = LevelLogic.levelFor(375);
      expect(info.level, 4);
      expect(info.xpIntoLevel, 0);
      expect(info.xpForLevel, 175);
    });
    test('progress is a fraction', () {
      expect(LevelLogic.levelFor(50).progress, 0.5);
    });
    test('negative xp is treated as zero', () {
      expect(LevelLogic.levelFor(-20).level, 1);
      expect(LevelLogic.levelFor(-20).xpIntoLevel, 0);
    });
    test('large xp terminates with a sensible level', () {
      expect(LevelLogic.levelFor(100000).level, greaterThan(20));
    });
  });

  group('BadgeCatalog', () {
    test('badge ids are unique', () {
      final ids = BadgeCatalog.all.map((b) => b.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids.length, 12);
    });
    test('nothing earned at the start', () {
      expect(BadgeCatalog.earnedIds(const BadgeStats()), isEmpty);
    });
    test('first completion earns first_step', () {
      expect(
        BadgeCatalog.earnedIds(const BadgeStats(totalCompletions: 1)),
        {'first_step'},
      );
    });
    test('streak badges follow the longest streak', () {
      final ids = BadgeCatalog.earnedIds(const BadgeStats(longestStreak: 7));
      expect(ids, containsAll(['streak_3', 'streak_7']));
      expect(ids, isNot(contains('streak_14')));
    });
    test('completion count badges', () {
      final ids =
          BadgeCatalog.earnedIds(const BadgeStats(totalCompletions: 25));
      expect(
        ids,
        containsAll(['first_step', 'challenges_10', 'challenges_25']),
      );
      expect(ids, isNot(contains('challenges_50')));
    });
    test('level badges', () {
      final ids = BadgeCatalog.earnedIds(const BadgeStats(level: 5));
      expect(ids, contains('level_5'));
      expect(ids, isNot(contains('level_10')));
    });
    test('everything earned with big numbers', () {
      final ids = BadgeCatalog.earnedIds(
        const BadgeStats(
          totalCompletions: 100,
          longestStreak: 100,
          level: 10,
        ),
      );
      expect(ids.length, BadgeCatalog.all.length);
    });
  });
}
