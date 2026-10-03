import 'package:flutter/material.dart' show TimeOfDay;

/// Parses a Postgres `time` value such as `07:30:00` (or `07:30`).
TimeOfDay? parseSqlTime(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  final parts = raw.split(':');
  final hour = int.tryParse(parts[0]);
  final minute = parts.length > 1 ? int.tryParse(parts[1]) : 0;
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

String _two(int value) => value.toString().padLeft(2, '0');

/// Formats a [TimeOfDay] as a Postgres `time` value, e.g. `07:30:00`.
String formatSqlTime(TimeOfDay time) => '${_two(time.hour)}:${_two(time.minute)}:00';

/// Formats a [TimeOfDay] as `HH:mm` (used for local preferences).
String formatHm(TimeOfDay time) => '${_two(time.hour)}:${_two(time.minute)}';

extension TimeOfDayMinutes on TimeOfDay {
  /// Minutes since midnight.
  int get totalMinutes => hour * 60 + minute;
}
