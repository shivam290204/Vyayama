import 'package:fitbuddy/features/challenges/data/streak_state.dart';
import 'package:fitbuddy/features/challenges/streak_logic.dart';
import 'package:flutter_test/flutter_test.dart';

StreakState state({
  int current = 0,
  int longest = 0,
  DateTime? last,
  int xp = 0,
}) =>
    StreakState(
      userId: 'u',
      current: current,
      longest: longest,
      lastActiveDate: last,
      xp: xp,
    );

void main() {
  group('recordActivity', () {
    test('first ever activity starts the streak at 1', () {
      final u = StreakLogic.recordActivity(
        state(),
        today: DateTime(2026, 1, 5),
        xp: 20,
      );
      expect(u.state.current, 1);
      expect(u.state.longest, 1);
      expect(u.state.lastActiveDate, DateTime(2026, 1, 5));
      expect(u.state.xp, 20);
      expect(u.streakChanged, isTrue);
      expect(u.milestone, isNull);
    });

    test('yesterday increments', () {
      final u = StreakLogic.recordActivity(
        state(current: 4, longest: 4, last: DateTime(2026, 1, 4)),
        today: DateTime(2026, 1, 5),
        xp: 10,
      );
      expect(u.state.current, 5);
      expect(u.state.longest, 5);
      expect(u.streakChanged, isTrue);
    });

    test('same day leaves the streak unchanged but still adds xp', () {
      final before = state(
        current: 4,
        longest: 6,
        last: DateTime(2026, 1, 5),
        xp: 50,
      );
      final u = StreakLogic.recordActivity(
        before,
        today: DateTime(2026, 1, 5, 21, 30),
        xp: 15,
      );
      expect(u.state.current, 4);
      expect(u.state.longest, 6);
      expect(u.state.lastActiveDate, DateTime(2026, 1, 5));
      expect(u.state.xp, 65);
      expect(u.streakChanged, isFalse);
      expect(u.milestone, isNull);
    });

    test('a gap of two or more days restarts at 1 and keeps longest', () {
      final u = StreakLogic.recordActivity(
        state(current: 9, longest: 9, last: DateTime(2026, 1, 3)),
        today: DateTime(2026, 1, 5),
      );
      expect(u.state.current, 1);
      expect(u.state.longest, 9);
      expect(u.state.lastActiveDate, DateTime(2026, 1, 5));
      expect(u.streakChanged, isTrue);
    });

    test('longest follows a growing streak', () {
      final u = StreakLogic.recordActivity(
        state(current: 5, longest: 5, last: DateTime(2026, 1, 4)),
        today: DateTime(2026, 1, 5),
      );
      expect(u.state.longest, 6);
    });

    test('a last active date in the future (travel west) changes nothing', () {
      final before = state(current: 3, longest: 3, last: DateTime(2026, 1, 6));
      final u = StreakLogic.recordActivity(
        before,
        today: DateTime(2026, 1, 5),
        xp: 10,
      );
      expect(u.state.current, 3);
      expect(u.state.lastActiveDate, DateTime(2026, 1, 6));
      expect(u.streakChanged, isFalse);
      expect(u.state.xp, 10);
    });

    test('negative xp is ignored', () {
      final u = StreakLogic.recordActivity(
        state(),
        today: DateTime(2026, 1, 5),
        xp: -5,
      );
      expect(u.state.xp, 0);
      expect(u.xpAwarded, 0);
    });
  });

  group('milestones', () {
    for (final entry in StreakLogic.milestoneBonusXp.entries) {
      test('day ${entry.key} gives a milestone and ${entry.value} bonus xp', () {
        final u = StreakLogic.recordActivity(
          state(
            current: entry.key - 1,
            longest: entry.key - 1,
            last: DateTime(2026, 1, 4),
            xp: 100,
          ),
          today: DateTime(2026, 1, 5),
          xp: 20,
        );
        expect(u.milestone, entry.key);
        expect(u.xpAwarded, 20 + entry.value);
        expect(u.state.xp, 100 + 20 + entry.value);
      });
    }

    test('milestone list and bonus map agree', () {
      expect(
        StreakLogic.milestoneBonusXp.keys.toList()..sort(),
        StreakLogic.milestones,
      );
    });

    test('a non-milestone day has no bonus', () {
      final u = StreakLogic.recordActivity(
        state(current: 4, longest: 4, last: DateTime(2026, 1, 4)),
        today: DateTime(2026, 1, 5),
        xp: 20,
      );
      expect(u.milestone, isNull);
      expect(u.xpAwarded, 20);
    });

    test('same-day activity on a milestone day does not repeat the bonus', () {
      final u = StreakLogic.recordActivity(
        state(current: 7, longest: 7, last: DateTime(2026, 1, 5)),
        today: DateTime(2026, 1, 5),
        xp: 10,
      );
      expect(u.milestone, isNull);
      expect(u.xpAwarded, 10);
    });

    test('restarting at 1 after a break is not a milestone', () {
      final u = StreakLogic.recordActivity(
        state(current: 6, longest: 6, last: DateTime(2026, 1, 1)),
        today: DateTime(2026, 1, 5),
      );
      expect(u.milestone, isNull);
    });
  });

  group('calendar edges', () {
    test('month boundary', () {
      final u = StreakLogic.recordActivity(
        state(current: 2, longest: 2, last: DateTime(2026, 1, 31)),
        today: DateTime(2026, 2, 1),
      );
      expect(u.state.current, 3);
    });
    test('year boundary', () {
      final u = StreakLogic.recordActivity(
        state(current: 2, longest: 2, last: DateTime(2026, 12, 31)),
        today: DateTime(2027, 1, 1),
      );
      expect(u.state.current, 3);
    });
    test('28 February to 1 March in a common year', () {
      final u = StreakLogic.recordActivity(
        state(current: 1, longest: 1, last: DateTime(2026, 2, 28)),
        today: DateTime(2026, 3, 1),
      );
      expect(u.state.current, 2);
    });
    test('leap day', () {
      final a = StreakLogic.recordActivity(
        state(current: 1, longest: 1, last: DateTime(2028, 2, 28)),
        today: DateTime(2028, 2, 29),
      );
      expect(a.state.current, 2);
      final b = StreakLogic.recordActivity(
        a.state,
        today: DateTime(2028, 3, 1),
      );
      expect(b.state.current, 3);
    });
    test('previousDay is not affected by daylight saving dates', () {
      expect(
        StreakLogic.previousDay(DateTime(2026, 3, 9)),
        DateTime(2026, 3, 8),
      );
      expect(
        StreakLogic.previousDay(DateTime(2026, 3, 30)),
        DateTime(2026, 3, 29),
      );
      expect(
        StreakLogic.previousDay(DateTime(2026, 11, 2)),
        DateTime(2026, 11, 1),
      );
      expect(
        StreakLogic.previousDay(DateTime(2026, 1, 1)),
        DateTime(2025, 12, 31),
      );
    });
  });

  group('todayFor (time zones)', () {
    test('no offset uses the date parts of the given time', () {
      expect(
        StreakLogic.todayFor(DateTime(2026, 1, 5, 23, 59)),
        DateTime(2026, 1, 5),
      );
    });
    test('positive offset can move to the next day', () {
      final instant = DateTime.utc(2026, 1, 5, 23, 30);
      expect(
        StreakLogic.todayFor(
          instant,
          utcOffset: const Duration(hours: 5, minutes: 30),
        ),
        DateTime(2026, 1, 6),
      );
    });
    test('negative offset can stay on the same day', () {
      final instant = DateTime.utc(2026, 1, 5, 23, 30);
      expect(
        StreakLogic.todayFor(instant, utcOffset: const Duration(hours: -8)),
        DateTime(2026, 1, 5),
      );
    });
    test('negative offset can move to the previous day', () {
      final instant = DateTime.utc(2026, 1, 5, 3);
      expect(
        StreakLogic.todayFor(instant, utcOffset: const Duration(hours: -8)),
        DateTime(2026, 1, 4),
      );
    });
  });

  group('effectiveCurrent', () {
    final today = DateTime(2026, 1, 5);
    test('no activity yet is 0', () {
      expect(StreakLogic.effectiveCurrent(state(), today), 0);
    });
    test('active today keeps the streak', () {
      expect(
        StreakLogic.effectiveCurrent(
          state(current: 4, last: DateTime(2026, 1, 5)),
          today,
        ),
        4,
      );
    });
    test('active yesterday keeps the streak (still time today)', () {
      expect(
        StreakLogic.effectiveCurrent(
          state(current: 4, last: DateTime(2026, 1, 4)),
          today,
        ),
        4,
      );
    });
    test('two days ago means the streak is broken', () {
      expect(
        StreakLogic.effectiveCurrent(
          state(current: 4, last: DateTime(2026, 1, 3)),
          today,
        ),
        0,
      );
    });
  });

  test('isActiveOn matches the last active day only', () {
    final s = state(current: 1, last: DateTime(2026, 1, 5, 8));
    expect(StreakLogic.isActiveOn(s, DateTime(2026, 1, 5, 23)), isTrue);
    expect(StreakLogic.isActiveOn(s, DateTime(2026, 1, 6)), isFalse);
    expect(StreakLogic.isActiveOn(state(), DateTime(2026, 1, 5)), isFalse);
  });
}
