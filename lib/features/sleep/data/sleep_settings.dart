import 'package:fitbuddy/features/health_profile/data/time_codec.dart';
import 'package:flutter/material.dart';

/// The user's sleep-related choices.
@immutable
class SleepSettings {
  /// Creates settings. Null work times fall back to the profile.
  const SleepSettings({
    this.workStart,
    this.workEnd,
    this.sleepMinutes,
    this.bedtimeReminderOn = false,
    this.wakeAlarmOn = false,
  });

  /// Reads settings from JSON.
  factory SleepSettings.fromJson(Map<String, dynamic> json) => SleepSettings(
        workStart: timeFromJson(json['work_start']),
        workEnd: timeFromJson(json['work_end']),
        sleepMinutes: (json['sleep_minutes'] as num?)?.toInt(),
        bedtimeReminderOn: (json['bedtime_reminder'] as bool?) ?? false,
        wakeAlarmOn: (json['wake_alarm'] as bool?) ?? false,
      );

  /// Work start override.
  final TimeOfDay? workStart;

  /// Work end override.
  final TimeOfDay? workEnd;

  /// Chosen sleep length in minutes (null means use the suggestion).
  final int? sleepMinutes;

  /// Whether the bedtime (wind-down) reminder is on.
  final bool bedtimeReminderOn;

  /// Whether the alarm-style wake-up reminder is on.
  final bool wakeAlarmOn;

  /// Writes settings to JSON.
  Map<String, dynamic> toJson() {
    final start = workStart;
    final end = workEnd;
    return <String, dynamic>{
      'work_start': start == null ? null : timeToJson(start),
      'work_end': end == null ? null : timeToJson(end),
      'sleep_minutes': sleepMinutes,
      'bedtime_reminder': bedtimeReminderOn,
      'wake_alarm': wakeAlarmOn,
    };
  }

  /// Returns a modified copy.
  SleepSettings copyWith({
    TimeOfDay? workStart,
    TimeOfDay? workEnd,
    int? sleepMinutes,
    bool clearSleepMinutes = false,
    bool? bedtimeReminderOn,
    bool? wakeAlarmOn,
  }) =>
      SleepSettings(
        workStart: workStart ?? this.workStart,
        workEnd: workEnd ?? this.workEnd,
        sleepMinutes:
            clearSleepMinutes ? null : (sleepMinutes ?? this.sleepMinutes),
        bedtimeReminderOn: bedtimeReminderOn ?? this.bedtimeReminderOn,
        wakeAlarmOn: wakeAlarmOn ?? this.wakeAlarmOn,
      );
}
