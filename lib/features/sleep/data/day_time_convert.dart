import 'package:fitbuddy/features/sleep/domain/day_time.dart';
import 'package:flutter/material.dart';

/// Converts a Flutter [TimeOfDay] to a pure Dart [DayTime].
extension TimeOfDayToDayTime on TimeOfDay {
  /// The same time as a [DayTime].
  DayTime toDayTime() => DayTime(hour, minute);
}

/// Converts a pure Dart [DayTime] to a Flutter [TimeOfDay].
extension DayTimeToTimeOfDay on DayTime {
  /// The same time as a [TimeOfDay].
  TimeOfDay toTimeOfDay() => TimeOfDay(hour: hour, minute: minute);
}
