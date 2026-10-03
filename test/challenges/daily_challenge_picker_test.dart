import 'package:fitbuddy/features/challenges/daily_challenge_picker.dart';
import 'package:fitbuddy/features/challenges/data/challenge.dart';
import 'package:flutter_test/flutter_test.dart';

List<Challenge> make(int n) => [
      for (var i = 1; i <= n; i++)
        Challenge(
          id: 'ch-${i.toString().padLeft(3, '0')}',
          title: 'Challenge $i',
          type: ChallengeType.checkoff,
          targetValue: 1,
        ),
    ];

void main() {
  const picker = DailyChallengePicker();

  test('empty list gives null', () {
    expect(picker.pickFor(const [], DateTime(2026, 1, 5)), isNull);
  });

  test('same date gives the same challenge at any time of day', () {
    final list = make(7);
    final morning = picker.pickFor(list, DateTime(2026, 1, 5, 6));
    final night = picker.pickFor(list, DateTime(2026, 1, 5, 23, 59));
    expect(morning!.id, night!.id);
  });

  test('list order does not change the pick', () {
    final list = make(7);
    final shuffled = [list[3], list[0], list[6], list[2], list[5], list[1], list[4]];
    for (var d = 1; d <= 20; d++) {
      final day = DateTime(2026, 1, d);
      expect(
        picker.pickFor(list, day)!.id,
        picker.pickFor(shuffled, day)!.id,
      );
    }
  });

  test('consecutive days give different challenges', () {
    final list = make(5);
    for (var d = 1; d < 30; d++) {
      final a = picker.pickFor(list, DateTime(2026, 1, d))!;
      final b = picker.pickFor(list, DateTime(2026, 1, d + 1))!;
      expect(a.id, isNot(b.id));
    }
  });

  test('cycles through every challenge before repeating', () {
    final list = make(6);
    final seen = <String>{
      for (var d = 0; d < 6; d++)
        picker.pickFor(list, DateTime(2026, 3, 1 + d))!.id,
    };
    expect(seen.length, 6);
    expect(
      picker.pickFor(list, DateTime(2026, 3, 1))!.id,
      picker.pickFor(list, DateTime(2026, 3, 7))!.id,
    );
  });

  test('epochDay counts calendar days', () {
    expect(picker.epochDay(DateTime(1970, 1, 1)), 0);
    expect(picker.epochDay(DateTime(1970, 1, 2, 23, 59)), 1);
    expect(picker.epochDay(DateTime(1969, 12, 31)), -1);
  });

  test('dates before 1970 still pick a valid challenge', () {
    final list = make(5);
    final c = picker.pickFor(list, DateTime(1969, 12, 31));
    expect(c, isNotNull);
    expect(c!.id, 'ch-005');
  });

  test('single challenge is always picked', () {
    final list = make(1);
    expect(picker.pickFor(list, DateTime(2026, 5, 5))!.id, 'ch-001');
  });
}
