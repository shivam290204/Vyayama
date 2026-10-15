import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  test('timezone initialization matches local offset', () {
    tz.initializeTimeZones();
    final now = DateTime.now();
    final offsetMs = now.timeZoneOffset.inMilliseconds;
    
    tz.Location? matched;
    for (final location in tz.timeZoneDatabase.locations.values) {
      if (location.currentTimeZone.offset == offsetMs) {
        matched = location;
        break;
      }
    }
    
    expect(matched, isNotNull);
    tz.setLocalLocation(matched!);
    
    final tzNow = tz.TZDateTime.now(tz.local);
    expect(tzNow.hour, equals(now.hour));
    expect(tzNow.minute, equals(now.minute));
  });
}
