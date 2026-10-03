import 'package:fitbuddy/features/schedule/data/time_block.dart';
import 'package:fitbuddy/features/schedule/missed_block_detector.dart';
import 'package:flutter_test/flutter_test.dart';

// 2026-01-05 is a Monday (weekday 1); 2026-01-10 is a Saturday (6).
DateTime mon(int h, [int m = 0]) => DateTime(2026, 1, 5, h, m);

const workout = TimeBlock(
  id: 'w',
  userId: 'u',
  type: BlockType.workout,
  title: 'Workout',
  startMinutes: 7 * 60,
);
const meal = TimeBlock(
  id: 'm',
  userId: 'u',
  type: BlockType.meal,
  title: 'Breakfast',
  startMinutes: 8 * 60,
  daysOfWeek: [1, 2, 3, 4, 5],
);
const sleep = TimeBlock(
  id: 's',
  userId: 'u',
  type: BlockType.sleep,
  title: 'Bedtime',
  startMinutes: 22 * 60,
);

BlockCompletion completion(
  String blockId,
  CompletionStatus status, {
  DateTime? date,
}) =>
    BlockCompletion(
      id: 'c-$blockId',
      blockId: blockId,
      userId: 'u',
      date: date ?? DateTime(2026, 1, 5),
      status: status,
    );

void main() {
  const detector = MissedBlockDetector();

  group('statusFor', () {
    test('upcoming before the start time', () {
      expect(detector.statusFor(workout, now: mon(6, 30)), BlockStatus.upcoming);
    });
    test('still upcoming at the start time and inside the grace period', () {
      expect(detector.statusFor(workout, now: mon(7)), BlockStatus.upcoming);
      expect(detector.statusFor(workout, now: mon(7, 14)), BlockStatus.upcoming);
    });
    test('missed once the grace period ends', () {
      expect(detector.statusFor(workout, now: mon(7, 15)), BlockStatus.missed);
      expect(detector.statusFor(workout, now: mon(20)), BlockStatus.missed);
    });
    test('done completion wins over time', () {
      final c = completion('w', CompletionStatus.done);
      expect(
        detector.statusFor(workout, now: mon(20), completion: c),
        BlockStatus.done,
      );
    });
    test('skipped and recorded-missed completions', () {
      expect(
        detector.statusFor(
          workout,
          now: mon(6),
          completion: completion('w', CompletionStatus.skipped),
        ),
        BlockStatus.skipped,
      );
      expect(
        detector.statusFor(
          workout,
          now: mon(6),
          completion: completion('w', CompletionStatus.missed),
        ),
        BlockStatus.missed,
      );
    });
    test('sleep blocks become passed, never missed', () {
      expect(detector.statusFor(sleep, now: mon(21)), BlockStatus.upcoming);
      expect(detector.statusFor(sleep, now: mon(22)), BlockStatus.passed);
      expect(detector.statusFor(sleep, now: mon(23, 59)), BlockStatus.passed);
    });
    test('custom grace period', () {
      const strict = MissedBlockDetector(graceMinutes: 0);
      expect(strict.statusFor(workout, now: mon(7)), BlockStatus.missed);
    });
  });

  group('isScheduledOn', () {
    test('weekday list is respected', () {
      expect(detector.isScheduledOn(meal, DateTime(2026, 1, 5)), isTrue);
      expect(detector.isScheduledOn(meal, DateTime(2026, 1, 10)), isFalse);
    });
    test('inactive blocks are never scheduled', () {
      final off = workout.copyWith(isActive: false);
      expect(detector.isScheduledOn(off, DateTime(2026, 1, 5)), isFalse);
    });
  });

  group('countsAsMissedNow', () {
    test('only missed blocks count', () {
      expect(
        detector.countsAsMissedNow(meal, BlockStatus.upcoming, mon(8)),
        isFalse,
      );
      expect(
        detector.countsAsMissedNow(meal, BlockStatus.done, mon(9)),
        isFalse,
      );
    });
    test('recent missed meal counts, old one does not', () {
      expect(
        detector.countsAsMissedNow(meal, BlockStatus.missed, mon(11)),
        isTrue,
      );
      expect(
        detector.countsAsMissedNow(meal, BlockStatus.missed, mon(13)),
        isFalse,
      );
    });
    test('missed workout counts all day', () {
      expect(
        detector.countsAsMissedNow(workout, BlockStatus.missed, mon(21)),
        isTrue,
      );
    });
    test('sleep blocks never count', () {
      expect(
        detector.countsAsMissedNow(sleep, BlockStatus.missed, mon(23)),
        isFalse,
      );
    });
  });

  group('anyMissedNow', () {
    test('false early in the morning', () {
      expect(
        detector.anyMissedNow(
          blocks: [workout, meal],
          completions: const [],
          now: mon(6),
        ),
        isFalse,
      );
    });
    test('true when the workout was missed', () {
      expect(
        detector.anyMissedNow(
          blocks: [workout],
          completions: const [],
          now: mon(9),
        ),
        isTrue,
      );
    });
    test('false once the workout is done', () {
      expect(
        detector.anyMissedNow(
          blocks: [workout],
          completions: [completion('w', CompletionStatus.done)],
          now: mon(9),
        ),
        isFalse,
      );
    });
    test("yesterday's completion does not count today", () {
      final yesterday = completion(
        'w',
        CompletionStatus.done,
        date: DateTime(2026, 1, 4),
      );
      expect(
        detector.anyMissedNow(
          blocks: [workout],
          completions: [yesterday],
          now: mon(9),
        ),
        isTrue,
      );
    });
    test('blocks not scheduled today are ignored', () {
      expect(
        detector.anyMissedNow(
          blocks: [meal],
          completions: const [],
          now: DateTime(2026, 1, 10, 9),
        ),
        isFalse,
      );
    });
  });

  group('JSON column names', () {
    test('TimeBlock round trip', () {
      final block = TimeBlock.fromJson({
        'id': 'b1',
        'user_id': 'u1',
        'type': 'medicine',
        'title': 'Reminder',
        'start_time': '07:30:00',
        'days_of_week': [3, 1, 2],
        'is_active': false,
      });
      expect(block.startMinutes, 450);
      expect(block.daysOfWeek, [1, 2, 3]);
      expect(block.isActive, isFalse);
      final json = block.toJson();
      expect(json['start_time'], '07:30:00');
      expect(json['type'], 'medicine');
      expect(json['days_of_week'], [1, 2, 3]);
    });
    test('BlockCompletion round trip', () {
      final c = BlockCompletion.fromJson({
        'id': 'c1',
        'block_id': 'b1',
        'user_id': 'u1',
        'date': '2026-01-05',
        'status': 'skipped',
      });
      expect(c.date, DateTime(2026, 1, 5));
      expect(c.status, CompletionStatus.skipped);
      expect(c.toJson()['date'], '2026-01-05');
    });
  });
}
