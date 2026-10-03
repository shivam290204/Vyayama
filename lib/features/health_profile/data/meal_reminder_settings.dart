import 'package:fitbuddy/features/health_profile/data/time_codec.dart';
import 'package:flutter/material.dart';

/// The four meal reminders the user can set.
enum MealSlot {
  /// Morning meal.
  breakfast,

  /// Midday meal.
  lunch,

  /// Light snack.
  snack,

  /// Evening meal.
  dinner;

  /// Friendly label.
  String get label => switch (this) {
        MealSlot.breakfast => 'Breakfast',
        MealSlot.lunch => 'Lunch',
        MealSlot.snack => 'Snack',
        MealSlot.dinner => 'Dinner',
      };
}

/// One meal reminder: a time and an on/off flag.
@immutable
class MealReminder {
  /// Creates a meal reminder.
  const MealReminder({required this.time, this.enabled = true});

  /// Reads a meal reminder from JSON.
  factory MealReminder.fromJson(Map<String, dynamic> json) => MealReminder(
        time: timeFromJson(json['time']) ?? const TimeOfDay(hour: 8, minute: 0),
        enabled: (json['enabled'] as bool?) ?? true,
      );

  /// Reminder time.
  final TimeOfDay time;

  /// Whether the reminder is on.
  final bool enabled;

  /// Writes the reminder to JSON.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'time': timeToJson(time),
        'enabled': enabled,
      };

  /// Returns a modified copy.
  MealReminder copyWith({TimeOfDay? time, bool? enabled}) => MealReminder(
        time: time ?? this.time,
        enabled: enabled ?? this.enabled,
      );
}

/// Reminder times for all four meals.
@immutable
class MealReminderSettings {
  /// Creates settings from a complete slot map.
  const MealReminderSettings(this.slots);

  /// Sensible defaults (8:00, 13:00, 16:30, 19:30).
  factory MealReminderSettings.defaults() =>
      MealReminderSettings(<MealSlot, MealReminder>{
        MealSlot.breakfast:
            const MealReminder(time: TimeOfDay(hour: 8, minute: 0)),
        MealSlot.lunch:
            const MealReminder(time: TimeOfDay(hour: 13, minute: 0)),
        MealSlot.snack:
            const MealReminder(time: TimeOfDay(hour: 16, minute: 30)),
        MealSlot.dinner:
            const MealReminder(time: TimeOfDay(hour: 19, minute: 30)),
      });

  /// Reads settings from JSON, falling back to defaults per meal.
  factory MealReminderSettings.fromJson(Map<String, dynamic> json) {
    final defaults = MealReminderSettings.defaults();
    return MealReminderSettings(<MealSlot, MealReminder>{
      for (final slot in MealSlot.values)
        slot: json[slot.name] is Map<String, dynamic>
            ? MealReminder.fromJson(json[slot.name] as Map<String, dynamic>)
            : defaults.of(slot),
    });
  }

  /// Reminders by meal.
  final Map<MealSlot, MealReminder> slots;

  /// The reminder for [slot].
  MealReminder of(MealSlot slot) => slots[slot]!;

  /// Returns a copy with [slot] replaced.
  MealReminderSettings withSlot(MealSlot slot, MealReminder reminder) =>
      MealReminderSettings(<MealSlot, MealReminder>{...slots, slot: reminder});

  /// Writes settings to JSON.
  Map<String, dynamic> toJson() => <String, dynamic>{
        for (final slot in MealSlot.values) slot.name: of(slot).toJson(),
      };
}
