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
    this.customBedtime,
    this.customWakeTime,
    this.bedtimeReminderOn = false,
    this.wakeAlarmOn = false,
    this.alarmDays = const [1, 2, 3, 4, 5, 6, 7],
    this.alarmSound = 'Gentle Chime',
    this.vibrate = true,
    this.snoozeMinutes = 10,
  });

  /// Reads settings from JSON.
  factory SleepSettings.fromJson(Map<String, dynamic> json) => SleepSettings(
        workStart: timeFromJson(json['work_start']),
        workEnd: timeFromJson(json['work_end']),
        sleepMinutes: (json['sleep_minutes'] as num?)?.toInt(),
        customBedtime: timeFromJson(json['custom_bedtime']),
        customWakeTime: timeFromJson(json['custom_wake_time']),
        bedtimeReminderOn: (json['bedtime_reminder'] as bool?) ?? false,
        wakeAlarmOn: (json['wake_alarm'] as bool?) ?? false,
        alarmDays: (json['alarm_days'] as List<dynamic>?)?.cast<int>() ??
            const [1, 2, 3, 4, 5, 6, 7],
        alarmSound: (json['alarm_sound'] as String?) ?? 'Gentle Chime',
        vibrate: (json['vibrate'] as bool?) ?? true,
        snoozeMinutes: (json['snooze_minutes'] as num?)?.toInt() ?? 10,
      );

  /// Work start override.
  final TimeOfDay? workStart;

  /// Work end override.
  final TimeOfDay? workEnd;

  /// Chosen sleep length in minutes (null means use the suggestion).
  final int? sleepMinutes;

  /// Direct custom bedtime if set by user.
  final TimeOfDay? customBedtime;

  /// Direct custom wake-up (alarm) time if set by user.
  final TimeOfDay? customWakeTime;

  /// Whether the bedtime (wind-down) reminder is on.
  final bool bedtimeReminderOn;

  /// Whether the alarm-style wake-up reminder is on.
  final bool wakeAlarmOn;

  /// Weekdays the alarm repeats on (1 = Monday ... 7 = Sunday).
  final List<int> alarmDays;

  /// Name of the chosen alarm sound.
  final String alarmSound;

  /// Whether vibration is enabled for the alarm.
  final bool vibrate;

  /// Snooze duration in minutes.
  final int snoozeMinutes;

  /// Writes settings to JSON.
  Map<String, dynamic> toJson() {
    final start = workStart;
    final end = workEnd;
    final cBed = customBedtime;
    final cWake = customWakeTime;
    return <String, dynamic>{
      'work_start': start == null ? null : timeToJson(start),
      'work_end': end == null ? null : timeToJson(end),
      'sleep_minutes': sleepMinutes,
      'custom_bedtime': cBed == null ? null : timeToJson(cBed),
      'custom_wake_time': cWake == null ? null : timeToJson(cWake),
      'bedtime_reminder': bedtimeReminderOn,
      'wake_alarm': wakeAlarmOn,
      'alarm_days': alarmDays,
      'alarm_sound': alarmSound,
      'vibrate': vibrate,
      'snooze_minutes': snoozeMinutes,
    };
  }

  /// Returns a modified copy.
  SleepSettings copyWith({
    TimeOfDay? workStart,
    TimeOfDay? workEnd,
    int? sleepMinutes,
    bool clearSleepMinutes = false,
    TimeOfDay? customBedtime,
    bool clearCustomBedtime = false,
    TimeOfDay? customWakeTime,
    bool clearCustomWakeTime = false,
    bool? bedtimeReminderOn,
    bool? wakeAlarmOn,
    List<int>? alarmDays,
    String? alarmSound,
    bool? vibrate,
    int? snoozeMinutes,
  }) =>
      SleepSettings(
        workStart: workStart ?? this.workStart,
        workEnd: workEnd ?? this.workEnd,
        sleepMinutes:
            clearSleepMinutes ? null : (sleepMinutes ?? this.sleepMinutes),
        customBedtime: clearCustomBedtime
            ? null
            : (customBedtime ?? this.customBedtime),
        customWakeTime: clearCustomWakeTime
            ? null
            : (customWakeTime ?? this.customWakeTime),
        bedtimeReminderOn: bedtimeReminderOn ?? this.bedtimeReminderOn,
        wakeAlarmOn: wakeAlarmOn ?? this.wakeAlarmOn,
        alarmDays: alarmDays ?? this.alarmDays,
        alarmSound: alarmSound ?? this.alarmSound,
        vibrate: vibrate ?? this.vibrate,
        snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      );
}
