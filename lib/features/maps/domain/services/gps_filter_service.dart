import 'package:fitbuddy/features/maps/domain/models/gps_point.dart';
import 'package:latlong2/latlong.dart';

/// Pure domain logic for GPS coordinate filtering, drift rejection,
/// distance calculation, elevation gain, and pace computation.
class GpsFilterService {
  const GpsFilterService({
    this.maxAllowedAccuracyMeters = 20.0,
    this.minDisplacementMeters = 3.0,
    this.maxRealisticSpeedMps = 12.5, // 45 km/h max for running/hiking
  });

  /// Maximum acceptable horizontal accuracy reported by GPS (in meters).
  final double maxAllowedAccuracyMeters;

  /// Minimum distance required to accept a new coordinate, avoiding stationary jitter.
  final double minDisplacementMeters;

  /// Maximum realistic speed in meters/second to filter out GPS teleports/jumps.
  final double maxRealisticSpeedMps;

  static const Distance _distance = Distance();

  /// Calculates geodesic distance between two points in meters using Haversine/Vincenty.
  double distanceBetween(GpsPoint a, GpsPoint b) {
    return _distance.as(
      LengthUnit.Meter,
      a.toLatLng(),
      b.toLatLng(),
    );
  }

  /// Evaluates whether a new candidate GPS point is valid to append to the active track.
  bool isValidNextPoint(GpsPoint? lastPoint, GpsPoint candidate) {
    // 1. Accuracy check: reject poor accuracy fixes (> 20 meters error)
    if (candidate.accuracy > maxAllowedAccuracyMeters && candidate.accuracy > 0) {
      return false;
    }

    // If it's the very first point, it is valid as long as accuracy is acceptable
    if (lastPoint == null) return true;

    // 2. Reject duplicate timestamps or backward time travel
    final timeDiffMs =
        candidate.timestamp.difference(lastPoint.timestamp).inMilliseconds;
    if (timeDiffMs <= 0) return false;

    // 3. Minimum displacement check: avoid stationary GPS jitter
    final displacement = distanceBetween(lastPoint, candidate);
    if (displacement < minDisplacementMeters) {
      return false;
    }

    // 4. Maximum speed / jump check: reject unrealistic teleport jumps
    final timeDiffSeconds = timeDiffMs / 1000.0;
    final calculatedSpeedMps = displacement / timeDiffSeconds;
    if (calculatedSpeedMps > maxRealisticSpeedMps) {
      return false;
    }

    return true;
  }

  /// Calculates total accumulated distance in meters across a list of GPS points.
  double calculateTotalDistance(List<GpsPoint> points) {
    if (points.length < 2) return 0.0;
    double total = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      total += distanceBetween(points[i], points[i + 1]);
    }
    return total;
  }

  /// Computes positive elevation gain in meters across the track.
  /// Filters out micro-fluctuations (< 2.0 meters) to avoid sensor noise.
  double calculateElevationGain(List<GpsPoint> points) {
    if (points.length < 2) return 0.0;
    double gain = 0.0;
    double lastAltitude = points.first.altitude;

    for (int i = 1; i < points.length; i++) {
      final current = points[i].altitude;
      final diff = current - lastAltitude;
      if (diff >= 2.0) {
        gain += diff;
        lastAltitude = current;
      } else if (diff <= -2.0) {
        lastAltitude = current;
      }
    }
    return gain;
  }

  /// Calculates average pace in seconds per kilometer given total meters and seconds.
  int calculateAveragePaceSeconds(double distanceMeters, int durationSeconds) {
    if (distanceMeters <= 50 || durationSeconds <= 0) return 0;
    final distanceKm = distanceMeters / 1000.0;
    final paceSec = durationSeconds / distanceKm;
    if (paceSec > 3600) return 0; // slower than 60 min/km -> 0
    return paceSec.round();
  }

  /// Calculates speed in km/h given distance meters and duration seconds.
  double calculateAverageSpeedKmh(double distanceMeters, int durationSeconds) {
    if (distanceMeters <= 0 || durationSeconds <= 0) return 0.0;
    final hours = durationSeconds / 3600.0;
    return (distanceMeters / 1000.0) / hours;
  }
}

