import 'package:fitbuddy/features/sleep/domain/day_time.dart';
import 'package:fitbuddy/features/sleep/domain/sleep_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DayTime', () {
    test('wraps forward past midnight', () {
      expect(DayTime(23, 30).plusMinutes(90), DayTime(1, 0));
    });

    test('wraps backward before midnight', () {
      expect(DayTime(0, 30).minusMinutes(60), DayTime(23, 30));
    });

    test('fromMinutes normalises any value', () {
      expect(DayTime.fromMinutes(-1), DayTime(23, 59));
      expect(DayTime.fromMinutes(1440), DayTime(0, 0));
      expect(DayTime.fromMinutes(1500), DayTime(1, 0));
    });

    test('minutesUntil crosses midnight', () {
      expect(DayTime(22, 0).minutesUntil(DayTime(6, 0)), 480);
      expect(DayTime(6, 0).minutesUntil(DayTime(22, 0)), 960);
      expect(DayTime(7, 0).minutesUntil(DayTime(7, 0)), 0);
    });

    test('isBetween handles normal and midnight-crossing ranges', () {
      expect(DayTime(10, 0).isBetween(DayTime(9, 0), DayTime(17, 0)), isTrue);
      expect(DayTime(9, 0).isBetween(DayTime(9, 0), DayTime(17, 0)), isTrue);
      expect(DayTime(18, 0).isBetween(DayTime(9, 0), DayTime(17, 0)), isFalse);
      expect(DayTime(23, 0).isBetween(DayTime(22, 0), DayTime(6, 0)), isTrue);
      expect(DayTime(3, 0).isBetween(DayTime(22, 0), DayTime(6, 0)), isTrue);
      expect(DayTime(12, 0).isBetween(DayTime(22, 0), DayTime(6, 0)), isFalse);
    });

    test('formats in 12-hour and 24-hour styles', () {
      expect(DayTime(0, 5).format12h(), '12:05 AM');
      expect(DayTime(12, 0).format12h(), '12:00 PM');
      expect(DayTime(13, 30).format12h(), '1:30 PM');
      expect(DayTime(23, 59).format12h(), '11:59 PM');
      expect(DayTime(7, 5).toString(), '07:05');
    });

    test('equality is by minutes', () {
      expect(DayTime(7, 0), DayTime.fromMinutes(420));
      expect(DayTime(7, 0).hashCode, DayTime.fromMinutes(420).hashCode);
    });
  });

  group('SleepPlanner day shift', () {
    test('9 to 5 with an 8 hour default crosses midnight', () {
      final plan = SleepPlanner.plan(
        workStart: DayTime(9, 0),
        workEnd: DayTime(17, 0),
        goal: 'maintain',
      );
      expect(plan.wakeTime, DayTime(7, 30));
      expect(plan.bedtime, DayTime(23, 30));
      expect(plan.sleepMinutes, 480);
      expect(plan.windDownStart, DayTime(22, 30));
      expect(plan.isNightShift, isFalse);
      expect(plan.warnings, isEmpty);
    });

    test('lose and unknown goals use 8 hours', () {
      for (final goal in <String?>['lose', null]) {
        final plan = SleepPlanner.plan(
          workStart: DayTime(9, 0),
          workEnd: DayTime(17, 0),
          goal: goal,
        );
        expect(plan.bedtime, DayTime(23, 30));
      }
    });

    test('gain goal uses 8.5 hours', () {
      final plan = SleepPlanner.plan(
        workStart: DayTime(9, 0),
        workEnd: DayTime(17, 0),
        goal: 'gain',
      );
      expect(plan.sleepMinutes, 510);
      expect(plan.bedtime, DayTime(23, 0));
    });

    test('early start gives an early evening bedtime', () {
      final plan = SleepPlanner.plan(
        workStart: DayTime(6, 0),
        workEnd: DayTime(15, 0),
      );
      expect(plan.wakeTime, DayTime(4, 30));
      expect(plan.bedtime, DayTime(20, 30));
      expect(plan.warnings, isEmpty);
    });

    test('wind-down start crosses midnight backwards', () {
      final plan = SleepPlanner.plan(
        workStart: DayTime(10, 0),
        workEnd: DayTime(18, 0),
      );
      expect(plan.bedtime, DayTime(0, 30));
      expect(plan.windDownStart, DayTime(23, 30));
      expect(plan.warnings, isEmpty);
    });

    test('missing work start falls back to a 7:00 wake time', () {
      final plan = SleepPlanner.plan();
      expect(plan.wakeTime, DayTime(7, 0));
      expect(plan.bedtime, DayTime(23, 0));
      expect(plan.warnings, isEmpty);
    });

    test('late work end raises a short-evening warning', () {
      final plan = SleepPlanner.plan(
        workStart: DayTime(9, 0),
        workEnd: DayTime(22, 0),
      );
      expect(plan.bedtime, DayTime(23, 30));
      expect(plan.warnings, <SleepWarning>[SleepWarning.shortEvening]);
    });

    test('bedtime inside work hours raises a warning', () {
      final plan = SleepPlanner.plan(
        workStart: DayTime(6, 0),
        workEnd: DayTime(23, 0),
      );
      expect(plan.bedtime, DayTime(20, 30));
      expect(plan.warnings, <SleepWarning>[SleepWarning.bedtimeDuringWork]);
    });

    test('bedtime plus duration always equals wake time', () {
      for (var minutes = 0; minutes < 1440; minutes += 15) {
        final plan = SleepPlanner.plan(
          workStart: DayTime.fromMinutes(minutes),
        );
        expect(
          plan.bedtime.plusMinutes(plan.sleepMinutes),
          plan.wakeTime,
          reason: 'work start ${DayTime.fromMinutes(minutes)}',
        );
      }
    });
  });

  group('SleepPlanner sleep length', () {
    DayTime bedtimeFor(int minutes) => SleepPlanner.plan(
          workStart: DayTime(9, 0),
          workEnd: DayTime(17, 0),
          sleepMinutes: minutes,
        ).bedtime;

    test('is clamped to 9 hours', () {
      expect(
        SleepPlanner.plan(
          workStart: DayTime(9, 0),
          workEnd: DayTime(17, 0),
          sleepMinutes: 600,
        ).sleepMinutes,
        540,
      );
      expect(bedtimeFor(600), DayTime(22, 30));
    });

    test('is clamped to 7 hours', () {
      expect(
        SleepPlanner.plan(
          workStart: DayTime(9, 0),
          workEnd: DayTime(17, 0),
          sleepMinutes: 300,
        ).sleepMinutes,
        420,
      );
      expect(bedtimeFor(300), DayTime(0, 30));
    });

    test('a valid custom length is respected', () {
      expect(bedtimeFor(450), DayTime(0, 0));
    });

    test('default lengths per goal', () {
      expect(SleepPlanner.defaultSleepMinutes('gain'), 510);
      expect(SleepPlanner.defaultSleepMinutes('lose'), 480);
      expect(SleepPlanner.defaultSleepMinutes('maintain'), 480);
      expect(SleepPlanner.defaultSleepMinutes(null), 480);
    });
  });

  group('SleepPlanner night shift', () {
    test('22:00 to 06:00 sleeps in the daytime', () {
      final plan = SleepPlanner.plan(
        workStart: DayTime(22, 0),
        workEnd: DayTime(6, 0),
      );
      expect(plan.isNightShift, isTrue);
      expect(plan.bedtime, DayTime(7, 0));
      expect(plan.wakeTime, DayTime(15, 0));
      expect(plan.sleepMinutes, 480);
      expect(plan.windDownStart, DayTime(6, 0));
      expect(plan.warnings, isEmpty);
    });

    test('a long shift shortens sleep without a warning at 7.5 hours', () {
      final plan = SleepPlanner.plan(
        workStart: DayTime(20, 0),
        workEnd: DayTime(10, 0),
      );
      expect(plan.bedtime, DayTime(11, 0));
      expect(plan.sleepMinutes, 450);
      expect(plan.wakeTime, DayTime(18, 30));
      expect(plan.warnings, isEmpty);
    });

    test('a very long shift raises a short-sleep warning', () {
      final plan = SleepPlanner.plan(
        workStart: DayTime(21, 0),
        workEnd: DayTime(13, 0),
      );
      expect(plan.bedtime, DayTime(14, 0));
      expect(plan.sleepMinutes, 330);
      expect(plan.wakeTime, DayTime(19, 30));
      expect(plan.warnings, <SleepWarning>[SleepWarning.shortSleep]);
    });
  });
}
