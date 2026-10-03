const List<String> _weekdaysShort = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const List<String> _monthsShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Three-letter weekday, for example `Fri`.
String shortWeekday(DateTime d) => _weekdaysShort[d.weekday - 1];

/// Short date, for example `Fri 2 Oct`.
String formatShortDate(DateTime d) =>
    '${shortWeekday(d)} ${d.day} ${_monthsShort[d.month - 1]}';
