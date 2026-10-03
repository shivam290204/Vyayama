import 'package:fitbuddy/features/mascot/data/mascot_message_templates.dart';
import 'package:fitbuddy/features/mascot/mascot_mood.dart';

/// Part of the day, used to pick a greeting for the happy mood.
enum DayPart {
  /// 05:00 to 11:59.
  morning,

  /// 12:00 to 16:59.
  afternoon,

  /// 17:00 to 20:59.
  evening,

  /// 21:00 to 04:59.
  night;

  /// Returns the part of day for [time].
  static DayPart of(DateTime time) {
    final h = time.hour;
    if (h >= 5 && h < 12) return DayPart.morning;
    if (h >= 12 && h < 17) return DayPart.afternoon;
    if (h >= 17 && h < 21) return DayPart.evening;
    return DayPart.night;
  }
}

/// Chooses a message for a mood and fills in the user's name. Pure Dart.
class MascotMessagePicker {
  /// Creates the picker.
  const MascotMessagePicker();

  /// Name used when the profile has no name yet.
  static const String fallbackName = 'friend';

  /// First word of [raw], or [fallbackName] when empty.
  String displayName(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) return fallbackName;
    return trimmed.split(RegExp(r'\s+')).first;
  }

  /// All templates that fit [mood] at [now].
  ///
  /// For `happy`, the time-of-day greetings come first, then generic ones.
  List<String> candidates(
    MascotMessageTemplates templates,
    MascotMood mood,
    DateTime now,
  ) {
    if (mood == MascotMood.happy) {
      return [
        ...templates.forKey('happy_${DayPart.of(now).name}'),
        ...templates.forKey('happy'),
      ];
    }
    return templates.forKey(mood.name);
  }

  /// Picks message number [variant] (wrapping around) and inserts the name.
  ///
  /// Increasing [variant] by one always yields a different message when
  /// more than one is available, so "tap for another message" works.
  String pick({
    required MascotMessageTemplates templates,
    required MascotMood mood,
    required String? name,
    required DateTime now,
    int variant = 0,
  }) {
    var list = candidates(templates, mood, now);
    if (list.isEmpty) {
      list = MascotMessageTemplates.fallback.forKey(mood.name);
    }
    final who = displayName(name);
    if (list.isEmpty) return 'Hi $who!';
    final index = variant.abs() % list.length;
    return list[index].replaceAll('{name}', who);
  }
}
