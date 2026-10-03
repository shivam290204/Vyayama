import 'package:fitbuddy/features/snap_streaks/data/snap_streak.dart';
import 'package:fitbuddy/features/snap_streaks/data/snap_streak_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

SnapStreak base({String tz = 'UTC'}) =>
    SnapStreak(id: 's', userA: 'a', userB: 'b', timezone: tz);

StreakUpdate send(
  SnapStreak s,
  StreakSide side,
  DateTime now, {
  bool verified = true,
  bool story = false,
}) =>
    SnapStreakCalculator.applySnap(
      streak: s,
      sender: side,
      nowUtc: now,
      verified: verified,
      isStory: story,
    );

void main() {
  setUpAll(SnapStreakCalculator.ensureTimezones);

  final day1 = DateTime.utc(2026, 10, 1, 9);
  final day2 = DateTime.utc(2026, 10, 2, 9);
  final day4 = DateTime.utc(2026, 10, 4, 9);

  group('first snap', () {
    test('records the sender side and nudges the friend', () {
      final r = send(base(), StreakSide.a, day1);
      expect(r.event, StreakEvent.nudgeFriend);
      expect(r.streak.lastASnapDate, DateTime.utc(2026, 10, 1));
      expect(r.streak.lastBSnapDate, isNull);
      expect(r.streak.current, 0);
    });
  });

  group('both snaps on the same day', () {
    test('completes the day and starts the streak at 1', () {
      final a = send(base(), StreakSide.a, day1).streak;
      final r = send(a, StreakSide.b, day1.add(const Duration(hours: 3)));
      expect(r.event, StreakEvent.completed);
      expect(r.streak.current, 1);
      expect(r.streak.longest, 1);
      expect(r.streak.lastCompletedDate, DateTime.utc(2026, 10, 1));
    });

    test('a third snap the same day does not double count', () {
      var s = send(base(), StreakSide.a, day1).streak;
      s = send(s, StreakSide.b, day1).streak;
      final r = send(s, StreakSide.a, day1.add(const Duration(hours: 2)));
      expect(r.event, StreakEvent.alreadyCompleted);
      expect(r.streak.current, 1);
    });
  });

  group('one-sided day', () {
    test('same person sending twice never completes', () {
      var s = send(base(), StreakSide.a, day1).streak;
      final r = send(s, StreakSide.a, day1.add(const Duration(hours: 5)));
      expect(r.event, StreakEvent.nudgeFriend);
      expect(r.streak.current, 0);
    });

    test('A on day 1 and B on day 2 is not a completed day', () {
      final s = send(base(), StreakSide.a, day1).streak;
      final r = send(s, StreakSide.b, day2);
      expect(r.event, StreakEvent.nudgeFriend);
      expect(r.streak.current, 0);
    });
  });

  group('day rollover', () {
    test('consecutive days increase the streak', () {
      var s = send(base(), StreakSide.a, day1).streak;
      s = send(s, StreakSide.b, day1).streak;
      s = send(s, StreakSide.b, day2).streak;
      final r = send(s, StreakSide.a, day2);
      expect(r.streak.current, 2);
      expect(r.streak.longest, 2);
    });

    test('skipping a day restarts at 1 but keeps longest', () {
      var s = send(base(), StreakSide.a, day1).streak;
      s = send(s, StreakSide.b, day1).streak;
      s = send(s, StreakSide.b, day2).streak;
      s = send(s, StreakSide.a, day2).streak;
      s = send(s, StreakSide.a, day4).streak;
      final r = send(s, StreakSide.b, day4);
      expect(r.streak.current, 1);
      expect(r.streak.longest, 2);
    });
  });

  group('timezone edge cases', () {
    test('localDate follows the pair timezone', () {
      final t = DateTime.utc(2026, 10, 1, 19); // 00:30 on Oct 2 in Kolkata
      expect(SnapStreakCalculator.localDate(t, 'UTC'), DateTime.utc(2026, 10, 1));
      expect(SnapStreakCalculator.localDate(t, 'Asia/Kolkata'),
          DateTime.utc(2026, 10, 2));
    });

    test('snaps either side of local midnight are different days', () {
      final s0 = base(tz: 'Asia/Kolkata');
      final a = send(s0, StreakSide.a, DateTime.utc(2026, 10, 1, 18)); // 23:30
      final r = send(a.streak, StreakSide.b, DateTime.utc(2026, 10, 1, 19)); // 00:30
      expect(r.event, StreakEvent.nudgeFriend);
      expect(r.streak.current, 0);
    });

    test('same UTC hours can still be one local day elsewhere', () {
      final s0 = base(tz: 'America/Los_Angeles');
      final a = send(s0, StreakSide.a, DateTime.utc(2026, 10, 2, 6, 59)); // Oct 1
      final r = send(a.streak, StreakSide.b, DateTime.utc(2026, 10, 2, 5));
      expect(r.event, StreakEvent.completed);
      expect(r.streak.lastCompletedDate, DateTime.utc(2026, 10, 1));
    });

    test('unknown timezone falls back to UTC', () {
      expect(SnapStreakCalculator.localDate(day1, 'Mars/Olympus'),
          DateTime.utc(2026, 10, 1));
    });

    test('timeLeftToday counts to local midnight', () {
      expect(
        SnapStreakCalculator.timeLeftToday(DateTime.utc(2026, 10, 1, 20), 'UTC'),
        const Duration(hours: 4),
      );
      expect(
        SnapStreakCalculator.timeLeftToday(
            DateTime.utc(2026, 10, 1, 18), 'Asia/Kolkata'), // 23:30 IST
        const Duration(minutes: 30),
      );
    });
  });

  group('reset after a missed day', () {
    SnapStreak live() => base().copyWith(
          current: 6,
          longest: 6,
          lastCompletedDate: DateTime.utc(2026, 10, 1),
        );

    test('still alive the next day', () {
      expect(SnapStreakCalculator.expireIfMissed(live(), day2).current, 6);
    });

    test('resets once a full day has passed', () {
      final r = SnapStreakCalculator.expireIfMissed(live(), day4);
      expect(r.current, 0);
      expect(r.longest, 6);
    });

    test('effectiveCurrent is 0 two days later', () {
      expect(SnapStreakCalculator.effectiveCurrent(
          live(), DateTime.utc(2026, 10, 3, 1)), 0);
    });
  });

  group('milestones', () {
    for (final m in SnapStreakCalculator.milestones) {
      test('day $m is a milestone', () {
        final s = base().copyWith(
          current: m - 1,
          longest: m - 1,
          lastCompletedDate: DateTime.utc(2026, 10, 1),
          lastASnapDate: DateTime.utc(2026, 10, 2),
        );
        final r = send(s, StreakSide.b, day2);
        expect(r.event, StreakEvent.completed);
        expect(r.streak.current, m);
        expect(r.milestone, m);
      });
    }

    test('non milestone days report none', () {
      final s = base().copyWith(
        current: 3,
        longest: 3,
        lastCompletedDate: DateTime.utc(2026, 10, 1),
        lastASnapDate: DateTime.utc(2026, 10, 2),
      );
      expect(send(s, StreakSide.b, day2).milestone, isNull);
    });
  });

  group('rejected snaps do not count', () {
    test('rejected snap changes nothing', () {
      final r = send(base(), StreakSide.a, day1, verified: false);
      expect(r.event, StreakEvent.ignored);
      expect(r.streak.lastASnapDate, isNull);
    });

    test('a rejected reply does not complete the day', () {
      final a = send(base(), StreakSide.a, day1).streak;
      final r = send(a, StreakSide.b, day1, verified: false);
      expect(r.streak.current, 0);
      expect(r.streak.lastBSnapDate, isNull);
    });

    test('Friends Feed posts never count', () {
      final r = send(base(), StreakSide.a, day1, story: true);
      expect(r.event, StreakEvent.ignored);
    });
  });

  group('status', () {
    final today = DateTime.utc(2026, 10, 2);
    final yesterday = DateTime.utc(2026, 10, 1);
    final noon = DateTime.utc(2026, 10, 2, 12);

    SnapStreak s({DateTime? a, DateTime? b, int cur = 3, DateTime? done}) =>
        base().copyWith(
          current: cur,
          longest: cur,
          lastASnapDate: a,
          lastBSnapDate: b,
          lastCompletedDate: done ?? yesterday,
        );

    test('no streak', () {
      expect(SnapStreakCalculator.statusFor(null, 'a', noon), PairStatus.none);
    });
    test('your turn', () {
      expect(SnapStreakCalculator.statusFor(s(b: today), 'a', noon),
          PairStatus.yourTurn);
    });
    test('waiting for friend', () {
      expect(SnapStreakCalculator.statusFor(s(a: today), 'a', noon),
          PairStatus.waitingOnFriend);
    });
    test('completed today', () {
      expect(
          SnapStreakCalculator.statusFor(
              s(a: today, b: today, done: today), 'a', noon),
          PairStatus.completedToday);
    });
    test('at risk in the last 4 hours', () {
      final late = DateTime.utc(2026, 10, 2, 21);
      expect(SnapStreakCalculator.statusFor(s(b: today), 'a', late),
          PairStatus.atRisk);
      expect(SnapStreakCalculator.isAtRisk(s(), late), isTrue);
    });
    test('not at risk once complete', () {
      final late = DateTime.utc(2026, 10, 2, 21);
      expect(
          SnapStreakCalculator.isAtRisk(
              s(a: today, b: today, done: today), late),
          isFalse);
    });
    test('broken streak', () {
      final broken = base().copyWith(
          current: 0, longest: 4, lastCompletedDate: DateTime.utc(2026, 9, 20));
      expect(SnapStreakCalculator.statusFor(broken, 'a', noon),
          PairStatus.broken);
    });
    test('friendSentIAmNot drives the worried mood', () {
      expect(SnapStreakCalculator.friendSentIAmNot(s(b: today), 'a', noon), isTrue);
      expect(SnapStreakCalculator.friendSentIAmNot(s(a: today), 'a', noon), isFalse);
    });
    test('completedDays lists the current run', () {
      final days = SnapStreakCalculator.completedDays(
          s(cur: 3, done: yesterday), noon);
      expect(days.length, 3);
      expect(days.first, yesterday);
    });
  });
}
