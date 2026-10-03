import 'package:flutter/foundation.dart';

/// What a reminder is for.
enum ReminderKind {
  /// Medicine reminder (name and time only).
  medicine,

  /// Meal reminder.
  meal,

  /// Bedtime reminder.
  bedtime,

  /// Alarm-style wake-up reminder.
  wakeAlarm,
}

/// A daily repeating reminder to schedule.
@immutable
class ReminderRequest {
  /// Creates a reminder request.
  const ReminderRequest({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.hour,
    required this.minute,
    this.weekdays = const <int>[1, 2, 3, 4, 5, 6, 7],
    this.exact = false,
    this.alarmStyle = false,
  });

  /// Stable string id. Antigravity maps it to a notification int id.
  final String id;

  /// Reminder category (lets users mute categories in Settings).
  final ReminderKind kind;

  /// Notification title.
  final String title;

  /// Notification body.
  final String body;

  /// Hour, 0 to 23.
  final int hour;

  /// Minute, 0 to 59.
  final int minute;

  /// Days of week (1 = Monday ... 7 = Sunday).
  final List<int> weekdays;

  /// Whether to request exact scheduling.
  final bool exact;

  /// Whether to use a full-screen, alarm-style notification where allowed.
  final bool alarmStyle;
}
