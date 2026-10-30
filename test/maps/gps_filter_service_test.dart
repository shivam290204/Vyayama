import 'package:fitbuddy/features/maps/domain/models/gps_point.dart';
import 'package:fitbuddy/features/maps/domain/services/gps_filter_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GpsFilterService Comprehensive Unit Tests', () {
    const service = GpsFilterService();

    final t0 = DateTime(2026, 10, 29, 10, 0, 0);

    test('1. Accurately calculates geodesic distance between coordinates', () {
      // 1 degree latitude difference ~ 111.13 km
      final p1 = GpsPoint(latitude: 40.7128, longitude: -74.0060, timestamp: t0);
      final p2 = GpsPoint(latitude: 40.7228, longitude: -74.0060, timestamp: t0.add(const Duration(minutes: 5)));

      final distance = service.distanceBetween(p1, p2);
      expect(distance, greaterThan(1100)); // ~1.11 km
      expect(distance, lessThan(1130));
    });

    test('2. Filters out candidate points with poor horizontal accuracy (> 20m)', () {
      final p1 = GpsPoint(latitude: 40.7128, longitude: -74.0060, timestamp: t0, accuracy: 5.0);
      final inaccurateCandidate = GpsPoint(
        latitude: 40.7135,
        longitude: -74.0060,
        timestamp: t0.add(const Duration(seconds: 10)),
        accuracy: 35.0, // > 20m threshold
      );

      final isValid = service.isValidNextPoint(p1, inaccurateCandidate);
      expect(isValid, isFalse);
    });

    test('3. Rejects stationary GPS drift jitter (< 3m movement)', () {
      final p1 = GpsPoint(latitude: 40.712800, longitude: -74.006000, timestamp: t0, accuracy: 4.0);
      // Extremely small offset ~ 0.5 meters
      final jitterCandidate = GpsPoint(
        latitude: 40.712803,
        longitude: -74.006002,
        timestamp: t0.add(const Duration(seconds: 5)),
        accuracy: 4.0,
      );

      final isValid = service.isValidNextPoint(p1, jitterCandidate);
      expect(isValid, isFalse);
    });

    test('4. Rejects unrealistic teleportation speed jumps (> 45 km/h)', () {
      final p1 = GpsPoint(latitude: 40.7128, longitude: -74.0060, timestamp: t0, accuracy: 5.0);
      // 500 meters away in 2 seconds = 250 m/s = 900 km/h (teleport)
      final teleportCandidate = GpsPoint(
        latitude: 40.7170,
        longitude: -74.0060,
        timestamp: t0.add(const Duration(seconds: 2)),
        accuracy: 5.0,
      );

      final isValid = service.isValidNextPoint(p1, teleportCandidate);
      expect(isValid, isFalse);
    });

    test('5. Rejects duplicate timestamps or backward time travel', () {
      final p1 = GpsPoint(latitude: 40.7128, longitude: -74.0060, timestamp: t0, accuracy: 5.0);
      final duplicateTimeCandidate = GpsPoint(
        latitude: 40.7135,
        longitude: -74.0060,
        timestamp: t0, // same timestamp
        accuracy: 5.0,
      );

      final isValid = service.isValidNextPoint(p1, duplicateTimeCandidate);
      expect(isValid, isFalse);
    });

    test('6. Calculates total accumulated track distance', () {
      final points = [
        GpsPoint(latitude: 40.7128, longitude: -74.0060, timestamp: t0),
        GpsPoint(latitude: 40.7138, longitude: -74.0060, timestamp: t0.add(const Duration(minutes: 1))),
        GpsPoint(latitude: 40.7148, longitude: -74.0060, timestamp: t0.add(const Duration(minutes: 2))),
      ];

      final total = service.calculateTotalDistance(points);
      expect(total, greaterThan(220));
      expect(total, lessThan(230));
    });

    test('7. Calculates elevation gain while suppressing minor noise (< 2m)', () {
      final points = [
        GpsPoint(latitude: 0, longitude: 0, altitude: 100.0, timestamp: t0),
        GpsPoint(latitude: 0, longitude: 0, altitude: 101.0, timestamp: t0), // +1m (noise, ignored)
        GpsPoint(latitude: 0, longitude: 0, altitude: 106.0, timestamp: t0), // +5m (counted)
        GpsPoint(latitude: 0, longitude: 0, altitude: 104.0, timestamp: t0), // -2m
        GpsPoint(latitude: 0, longitude: 0, altitude: 110.0, timestamp: t0), // +6m (counted)
      ];

      final gain = service.calculateElevationGain(points);
      expect(gain, equals(12.0)); // 6.0 + 6.0
    });

    test('8. Calculates average pace and speed correctly', () {
      // 1000 meters in 300 seconds (5 mins) -> pace = 300 sec/km (5:00 min/km), speed = 12.0 km/h
      final paceSec = service.calculateAveragePaceSeconds(1000, 300);
      final speedKmh = service.calculateAverageSpeedKmh(1000, 300);

      expect(paceSec, equals(300));
      expect(speedKmh, closeTo(12.0, 0.01));
    });
  });
}

