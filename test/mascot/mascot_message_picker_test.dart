import 'package:fitbuddy/features/mascot/data/mascot_message_templates.dart';
import 'package:fitbuddy/features/mascot/mascot_message_picker.dart';
import 'package:fitbuddy/features/mascot/mascot_mood.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const picker = MascotMessagePicker();
  const templates = MascotMessageTemplates({
    'happy': ['Generic {name}'],
    'happy_morning': ['Morning {name}'],
    'sad': ['One {name}', 'Two {name}', 'Three {name}'],
  });
  final morning = DateTime(2026, 1, 5, 8);
  final afternoon = DateTime(2026, 1, 5, 14);

  test('inserts the first name only', () {
    final text = picker.pick(
      templates: templates,
      mood: MascotMood.sad,
      name: 'Asha Verma',
      now: afternoon,
    );
    expect(text, 'One Asha');
  });

  test('falls back to friend when the name is empty or null', () {
    for (final name in [null, '', '   ']) {
      final text = picker.pick(
        templates: templates,
        mood: MascotMood.sad,
        name: name,
        now: afternoon,
      );
      expect(text, 'One friend');
    }
  });

  test('variant cycles through messages and wraps', () {
    String at(int v) => picker.pick(
          templates: templates,
          mood: MascotMood.sad,
          name: 'Sam',
          now: afternoon,
          variant: v,
        );
    expect(at(0), 'One Sam');
    expect(at(1), 'Two Sam');
    expect(at(2), 'Three Sam');
    expect(at(3), 'One Sam');
  });

  test('happy puts the time-of-day greeting first', () {
    final list = picker.candidates(templates, MascotMood.happy, morning);
    expect(list, ['Morning {name}', 'Generic {name}']);
  });

  test('happy without a matching daypart uses generic messages', () {
    final list = picker.candidates(templates, MascotMood.happy, afternoon);
    expect(list, ['Generic {name}']);
  });

  test('missing mood falls back to built-in messages', () {
    final text = picker.pick(
      templates: templates,
      mood: MascotMood.proud,
      name: 'Sam',
      now: afternoon,
    );
    expect(text, contains('Sam'));
    expect(text, isNot(contains('{name}')));
  });

  test('DayPart boundaries', () {
    expect(DayPart.of(DateTime(2026, 1, 5, 4, 59)), DayPart.night);
    expect(DayPart.of(DateTime(2026, 1, 5, 5)), DayPart.morning);
    expect(DayPart.of(DateTime(2026, 1, 5, 12)), DayPart.afternoon);
    expect(DayPart.of(DateTime(2026, 1, 5, 17)), DayPart.evening);
    expect(DayPart.of(DateTime(2026, 1, 5, 21)), DayPart.night);
  });

  test('fromJson parses the moods map', () {
    final parsed = MascotMessageTemplates.fromJson({
      'moods': {
        'sad': ['a', 'b'],
      },
    });
    expect(parsed.forKey('sad'), ['a', 'b']);
    expect(parsed.forKey('angry'), isEmpty);
  });
}
