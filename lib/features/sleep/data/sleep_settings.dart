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
    bool bedtimeReminderOn = false,
    bool wakeAlarmOn = false,
    List<int>? alarmDays,
    String? alarmSound,
    bool vibrate = true,
    int? snoozeMinutes,
  })  : _bedtimeReminderOn = bedtimeReminderOn,
        _wakeAlarmOn = wakeAlarmOn,
        _alarmDays = alarmDays,
        _alarmSound = alarmSound,
        _vibrate = vibrate,
        _snoozeMinutes = snoozeMinutes;

  /// Helper to convert any dynamic JSON value to a safe boolean.
  static bool _toBool(dynamic v, {required bool fallback}) {
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v == 1 || v == '1' || v == 'true') return true;
    if (v == 0 || v == '0' || v == 'false') return false;
    return fallback;
  }

  /// Helper to convert dynamic JSON list to safe `List<int>`.
  static List<int> _toIntList(dynamic v) {
    if (v is List) {
      final result = <int>[];
      for (final item in v) {
        if (item is num) {
          result.add(item.toInt());
        } else if (item is String) {
          final parsed = int.tryParse(item);
          if (parsed != null) result.add(parsed);
        }
      }
      if (result.isNotEmpty) return result;
    }
    return const [1, 2, 3, 4, 5, 6, 7];
  }

  /// Reads settings from JSON.
  factory SleepSettings.fromJson(Map<String, dynamic> json) => SleepSettings(
        workStart: timeFromJson(json['work_start']),
        workEnd: timeFromJson(json['work_end']),
        sleepMinutes: (json['sleep_minutes'] as num?)?.toInt(),
        customBedtime: timeFromJson(json['custom_bedtime']),
        customWakeTime: timeFromJson(json['custom_wake_time']),
        bedtimeReminderOn: _toBool(json['bedtime_reminder'], fallback: false),
        wakeAlarmOn: _toBool(json['wake_alarm'], fallback: false),
        alarmDays: _toIntList(json['alarm_days']),
        alarmSound: (json['alarm_sound'] as String?) ?? 'Gentle Chime',
        vibrate: _toBool(json['vibrate'], fallback: true),
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

  final bool? _bedtimeReminderOn;
  final bool? _wakeAlarmOn;
  final List<int>? _alarmDays;
  final String? _alarmSound;
  final bool? _vibrate;
  final int? _snoozeMinutes;

  /// Whether the bedtime (wind-down) reminder is on.
  bool get bedtimeReminderOn => _bedtimeReminderOn == true;

  /// Whether the alarm-style wake-up reminder is on.
  bool get wakeAlarmOn => _wakeAlarmOn == true;

  /// Weekdays the alarm repeats on (1 = Monday ... 7 = Sunday).
  List<int> get alarmDays => _alarmDays ?? const [1, 2, 3, 4, 5, 6, 7];

  /// Name of the chosen alarm sound.
  String get alarmSound => _alarmSound ?? 'Gentle Chime';

  /// Whether vibration is enabled for the alarm.
  bool get vibrate => _vibrate != false;

  /// Snooze duration in minutes.
  int get snoozeMinutes => _snoozeMinutes ?? 10;

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
