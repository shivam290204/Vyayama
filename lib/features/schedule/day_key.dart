/// Strips the time from [d], keeping the local calendar day.
DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Formats [d] as `yyyy-MM-dd` (the Postgres `date` format).
String dayKey(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';
}

/// Parses `yyyy-MM-dd` (extra characters after the date are ignored).
DateTime parseDayKey(String value) {
  final parts = value.substring(0, 10).split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

/// Whether [a] and [b] fall on the same local calendar day.
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

const List<String> _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const List<String> _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Formats [d] like "Friday, 2 October".
String formatLongDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';
