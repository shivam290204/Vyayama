import 'package:fitbuddy/features/mascot/mascot_mood.dart';
import 'package:fitbuddy/features/mascot/mood_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds inputs at 14:00 (awake) unless overridden.
MoodInputs build({
  DateTime? now,
  bool workoutDone = false,
  bool missed = false,
  int skipped = 0,
  bool milestone = false,
  bool challenge = false,
  bool snapRisk = false,
  int sleepStart = MoodInputs.defaultSleepStartMinutes,
  int wake = MoodInputs.defaultWakeMinutes,
}) {
  return MoodInputs(
    now: now ?? DateTime(2026, 1, 5, 14),
    workoutDoneToday: workoutDone,
    missedBlockNow: missed,
    daysSkippedInARow: skipped,
    streakMilestoneHit: milestone,
    challengeJustCompleted: challenge,
    snapStreakAtRisk: snapRisk,
    sleepStartMinutes: sleepStart,
    wakeMinutes: wake,
  );
}

void main() {
  const engine = MoodEngine();

  group('celebrating', () {
    test('streak milestone', () {
      expect(engine.decide(build(milestone: true)), MascotMood.celebrating);
    });
    test('challenge just completed', () {
      expect(engine.decide(build(challenge: true)), MascotMood.celebrating);
    });
    test('beats every other input', () {
      final all = build(
        milestone: true,
        workoutDone: true,
        skipped: 9,
        snapRisk: true,
        missed: true,
        now: DateTime(2026, 1, 5, 23),
      );
      expect(engine.decide(all), MascotMood.celebrating);
    });
  });

  group('proud', () {
    test('workout done', () {
      expect(engine.decide(build(workoutDone: true)), MascotMood.proud);
    });
    test('beats angry, worried, sad and sleepy', () {
      final i = build(
        workoutDone: true,
        skipped: 5,
        snapRisk: true,
        missed: true,
        now: DateTime(2026, 1, 5, 23),
      );
      expect(engine.decide(i), MascotMood.proud);
    });
  });

  group('angry', () {
    test('three days skipped', () {
      expect(engine.decide(build(skipped: 3)), MascotMood.angry);
    });
    test('many days skipped', () {
      expect(engine.decide(build(skipped: 10)), MascotMood.angry);
    });
    test('two days skipped is not angry', () {
      expect(engine.decide(build(skipped: 2)), MascotMood.happy);
    });
    test('threshold constant is three', () {
      expect(MoodEngine.angryThreshold, 3);
    });
    test('beats worried, sad and sleepy', () {
      final i = build(
        skipped: 4,
        snapRisk: true,
        missed: true,
        now: DateTime(2026, 1, 5, 23),
      );
      expect(engine.decide(i), MascotMood.angry);
    });
  });

  group('worried', () {
    test('snap streak at risk', () {
      expect(engine.decide(build(snapRisk: true)), MascotMood.worried);
    });
    test('beats sad and sleepy', () {
      final i = build(
        snapRisk: true,
        missed: true,
        now: DateTime(2026, 1, 5, 23),
      );
      expect(engine.decide(i), MascotMood.worried);
    });
  });

  group('sad', () {
    test('missed block', () {
      expect(engine.decide(build(missed: true)), MascotMood.sad);
    });
    test('beats sleepy', () {
      final i = build(missed: true, now: DateTime(2026, 1, 5, 23));
      expect(engine.decide(i), MascotMood.sad);
    });
  });

  group('sleepy', () {
    test('late evening', () {
      expect(
        engine.decide(build(now: DateTime(2026, 1, 5, 23, 30))),
        MascotMood.sleepy,
      );
    });
    test('after midnight', () {
      expect(
        engine.decide(build(now: DateTime(2026, 1, 6, 2))),
        MascotMood.sleepy,
      );
    });
    test('window start is inclusive', () {
      expect(
        engine.decide(build(now: DateTime(2026, 1, 5, 22))),
        MascotMood.sleepy,
      );
    });
    test('window end is exclusive', () {
      expect(
        engine.decide(build(now: DateTime(2026, 1, 5, 6))),
        MascotMood.happy,
      );
    });
    test('one minute before wake is still sleepy', () {
      expect(
        engine.decide(build(now: DateTime(2026, 1, 5, 5, 59))),
        MascotMood.sleepy,
      );
    });
    test('custom non-wrapping window', () {
      final nap = build(
        now: DateTime(2026, 1, 5, 14),
        sleepStart: 13 * 60,
        wake: 15 * 60,
      );
      expect(engine.decide(nap), MascotMood.sleepy);
    });
    test('equal start and wake means never sleepy', () {
      final i = build(
        now: DateTime(2026, 1, 5, 23),
        sleepStart: 22 * 60,
        wake: 22 * 60,
      );
      expect(i.isSleepTime, isFalse);
      expect(engine.decide(i), MascotMood.happy);
    });
  });

  group('happy', () {
    test('default during the day', () {
      expect(engine.decide(build()), MascotMood.happy);
    });
    test('morning', () {
      expect(
        engine.decide(build(now: DateTime(2026, 1, 5, 8))),
        MascotMood.happy,
      );
    });
  });

  test('engine never returns neutral', () {
    for (final hour in [0, 3, 7, 12, 18, 23]) {
      for (final skipped in [0, 3]) {
        for (final missed in [false, true]) {
          final mood = engine.decide(
            build(
              now: DateTime(2026, 1, 5, hour),
              skipped: skipped,
              missed: missed,
            ),
          );
          expect(mood, isNot(MascotMood.neutral));
        }
      }
    }
  });

  test('copyWith replaces only the given fields', () {
    final base = build(skipped: 2);
    final changed = base.copyWith(missedBlockNow: true);
    expect(changed.missedBlockNow, isTrue);
    expect(changed.daysSkippedInARow, 2);
    expect(changed.now, base.now);
  });
}
