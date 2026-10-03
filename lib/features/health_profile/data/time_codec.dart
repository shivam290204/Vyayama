import 'package:flutter/material.dart';

/// Formats a time as `HH:mm:00`, matching the Postgres `time` column.
String timeToJson(TimeOfDay time) {
  final h = time.hour.toString().padLeft(2, '0');
  final m = time.minute.toString().padLeft(2, '0');
  return '$h:$m:00';
}

/// Reads a time from a `HH:mm[:ss]` string, a [DateTime] or a [TimeOfDay].
/// Returns null when the value cannot be understood.
TimeOfDay? timeFromJson(Object? value) {
  if (value == null) return null;
  if (value is TimeOfDay) return value;
  if (value is DateTime) {
    return TimeOfDay(hour: value.hour, minute: value.minute);
  }
  final parts = value.toString().split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

/// Minutes since midnight.
int minutesOfDay(TimeOfDay time) => time.hour * 60 + time.minute;

/// Comparator that sorts times from earliest to latest in the day.
int compareTimes(TimeOfDay a, TimeOfDay b) =>
    minutesOfDay(a).compareTo(minutesOfDay(b));
