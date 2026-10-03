/// A time of day in whole minutes, wrapping around midnight.
///
/// Pure Dart (no Flutter), so planners using it are easy to unit test.
class DayTime implements Comparable<DayTime> {
  const DayTime._(this.minutes);

  /// Creates a time from [hour] and [minute]. Values wrap around midnight.
  factory DayTime(int hour, int minute) =>
      DayTime.fromMinutes(hour * 60 + minute);

  /// Creates a time from minutes since midnight. Values wrap around.
  factory DayTime.fromMinutes(int total) => DayTime._(total % 1440);

  /// Minutes since midnight, from 0 to 1439.
  final int minutes;

  /// Hour, 0 to 23.
  int get hour => minutes ~/ 60;

  /// Minute, 0 to 59.
  int get minute => minutes % 60;

  /// This time plus [value] minutes (wraps past midnight).
  DayTime plusMinutes(int value) => DayTime.fromMinutes(minutes + value);

  /// This time minus [value] minutes (wraps before midnight).
  DayTime minusMinutes(int value) => DayTime.fromMinutes(minutes - value);

  /// Minutes moving forward from this time until [other], from 0 to 1439.
  int minutesUntil(DayTime other) => (other.minutes - minutes) % 1440;

  /// Whether this time is inside [start]..[end], inclusive. The range may
  /// cross midnight (for example 22:00 to 06:00).
  bool isBetween(DayTime start, DayTime end) {
    if (start.minutes <= end.minutes) {
      return minutes >= start.minutes && minutes <= end.minutes;
    }
    return minutes >= start.minutes || minutes <= end.minutes;
  }

  /// Formats like `10:30 PM`.
  String format12h() {
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    final suffix = hour < 12 ? 'AM' : 'PM';
    return '$h12:${minute.toString().padLeft(2, '0')} $suffix';
  }

  @override
  int compareTo(DayTime other) => minutes.compareTo(other.minutes);

  @override
  bool operator ==(Object other) => other is DayTime && other.minutes == minutes;

  @override
  int get hashCode => minutes.hashCode;

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
