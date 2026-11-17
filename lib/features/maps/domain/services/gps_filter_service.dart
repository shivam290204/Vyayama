import 'package:fitbuddy/features/maps/domain/models/gps_point.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity_type.dart';
import 'package:latlong2/latlong.dart';

/// Pure domain logic for GPS coordinate filtering, drift rejection,
/// distance calculation, elevation gain, and pace computation.
class GpsFilterService {
  const GpsFilterService({
    this.maxAllowedAccuracyMeters = 20.0,
    this.minDisplacementMeters = 3.0,
    this.maxRealisticSpeedMps = 8.5, // ~30.6 km/h max for running
    this.maxAcceptableGapSeconds = 120.0, // 2 minutes threshold for signal gaps
  });

  /// Maximum acceptable horizontal accuracy reported by GPS (in meters).
  /// Preserved at 20.0m to avoid discarding valid outdoor fixes under light foliage.
  final double maxAllowedAccuracyMeters;

  /// Minimum distance required to accept a new coordinate, avoiding stationary jitter.
  final double minDisplacementMeters;

  /// Maximum realistic speed in meters/second to filter out GPS teleports/jumps.
  final double maxRealisticSpeedMps;

  /// Maximum gap in seconds between consecutive fixes before flagging a signal outage.
  final double maxAcceptableGapSeconds;

  static const Distance _distance = Distance();

  /// Constructs a tuned filter profile appropriate for the specific outdoor activity.
  ///
  /// Walking & Hiking: 4.5 m/s (~16.2 km/h) accommodates fast power-walking, steep downhill
  /// hiking, and realistic GPS noise over 3-second intervals while rejecting motor vehicles.
  /// Running: 8.5 m/s (~30.6 km/h) accommodates fast sprinting and noise over 2-second intervals
  /// while rejecting vehicle transit and unrealistic teleportation jumps.
  factory GpsFilterService.forActivity(OutdoorActivityType type) {
    switch (type) {
      case OutdoorActivityType.walking:
      case OutdoorActivityType.hiking:
        return const GpsFilterService(
          maxAllowedAccuracyMeters: 20.0,
          minDisplacementMeters: 3.0,
          maxRealisticSpeedMps: 4.5, // ~16.2 km/h
          maxAcceptableGapSeconds: 120.0,
        );
      case OutdoorActivityType.running:
        return const GpsFilterService(
          maxAllowedAccuracyMeters: 20.0,
          minDisplacementMeters: 3.0,
          maxRealisticSpeedMps: 8.5, // ~30.6 km/h
          maxAcceptableGapSeconds: 90.0,
        );
    }
  }

  /// Calculates geodesic distance between two points in meters using Haversine/Vincenty.
  double distanceBetween(GpsPoint a, GpsPoint b) {
    return _distance.as(
      LengthUnit.Meter,
      a.toLatLng(),
      b.toLatLng(),
    );
  }

  /// Returns true if the time gap between [lastPoint] and [candidate] exceeds [maxAcceptableGapSeconds].
  bool isSignalGap(GpsPoint lastPoint, GpsPoint candidate) {
    final diffSec = candidate.timestamp.difference(lastPoint.timestamp).inMilliseconds / 1000.0;
    return diffSec > maxAcceptableGapSeconds;
  }

  /// Evaluates whether a new candidate GPS point is valid to append to the active track.
  bool isValidNextPoint(
    GpsPoint? lastPoint,
    GpsPoint candidate, {
    bool isResumingFromPause = false,
  }) {
    // 1. Accuracy check: reject poor accuracy fixes (> 20 meters error)
    if (candidate.accuracy > maxAllowedAccuracyMeters && candidate.accuracy > 0) {
      return false;
    }

    // 2. Reject non-finite coordinates or out-of-bounds latitude/longitude
    if (!candidate.latitude.isFinite || !candidate.longitude.isFinite) {
      return false;
    }
    if (candidate.latitude < -90.0 || candidate.latitude > 90.0) return false;
    if (candidate.longitude < -180.0 || candidate.longitude > 180.0) return false;

    // If it's the very first point or establishing a fresh baseline after pause,
    // accept as long as accuracy is valid.
    if (lastPoint == null || isResumingFromPause) return true;

    // 3. Reject duplicate timestamps, backward time travel, or future timestamps
    final timeDiffMs =
        candidate.timestamp.difference(lastPoint.timestamp).inMilliseconds;
    if (timeDiffMs <= 0) return false;

    final now = DateTime.now();
    if (candidate.timestamp.isAfter(now.add(const Duration(minutes: 5)))) {
      return false;
    }

    // 4. Reject exact duplicate coordinates (zero displacement)
    if (candidate.latitude == lastPoint.latitude &&
        candidate.longitude == lastPoint.longitude) {
      return false;
    }

    // 5. Minimum displacement check: avoid stationary GPS jitter
    final displacement = distanceBetween(lastPoint, candidate);
    if (displacement < minDisplacementMeters) {
      return false;
    }

    // 6. Maximum speed / jump check: reject unrealistic teleport jumps
    final timeDiffSeconds = timeDiffMs / 1000.0;
    final calculatedSpeedMps = displacement / timeDiffSeconds;
    if (calculatedSpeedMps > maxRealisticSpeedMps) {
      return false;
    }

    return true;
  }

  /// Calculates total accumulated distance in meters across a list of GPS points.
  ///
  /// Skips displacement across signal gaps exceeding [maxAcceptableGapSeconds]
  /// to avoid accumulating artificial straight-line distance across outages.
  double calculateTotalDistance(List<GpsPoint> points) {
    if (points.length < 2) return 0.0;
    double total = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      if (isSignalGap(points[i], points[i + 1])) {
        continue;
      }
      total += distanceBetween(points[i], points[i + 1]);
    }
    return total;
  }

  /// Splits points into continuous track segments separated by signal gaps.
  ///
  /// Prevents drawing artificial straight lines across missing GPS data while
  /// preserving existing completed route segments on either side of the outage.
  List<List<GpsPoint>> splitIntoSegments(List<GpsPoint> points) {
    if (points.isEmpty) return const [];
    final segments = <List<GpsPoint>>[];
    var currentSegment = <GpsPoint>[points.first];

    for (int i = 1; i < points.length; i++) {
      if (isSignalGap(points[i - 1], points[i])) {
        if (currentSegment.isNotEmpty) {
          segments.add(currentSegment);
        }
        currentSegment = <GpsPoint>[points[i]];
      } else {
        currentSegment.add(points[i]);
      }
    }
    if (currentSegment.isNotEmpty) {
      segments.add(currentSegment);
    }
    return segments;
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
    if (paceSec > 3600 || paceSec < 0) return 0; // slower than 60 min/km -> 0
    return paceSec.round();
  }

  /// Calculates speed in km/h given distance meters and duration seconds.
  double calculateAverageSpeedKmh(double distanceMeters, int durationSeconds) {
    if (distanceMeters <= 0 || durationSeconds <= 0) return 0.0;
    final hours = durationSeconds / 3600.0;
    final speed = (distanceMeters / 1000.0) / hours;
    return speed < 0 ? 0.0 : speed;
  }
}
