import 'dart:math' as math;
import 'package:fitbuddy/features/maps/domain/models/gps_point.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity_type.dart';
import 'package:fitbuddy/features/maps/domain/models/route_filter.dart';
import 'package:fitbuddy/features/maps/domain/models/saved_route.dart';
import 'package:latlong2/latlong.dart';

/// Abstract contract for discovering or generating outdoor routes.
abstract class RouteDiscoveryProvider {
  Future<List<SavedRoute>> discoverRoutes({
    required LatLng center,
    double radiusKm = 10.0,
    RouteFilter? filter,
  });
}

/// Offline-first Route Discovery Engine that provides synthesized local circuits
/// and suggested trails around any geographic coordinate.
///
/// NOTE: In this version, discovered routes are synthesized offline circuits
/// calculated relative to the user's GPS center point. They serve as sample/suggested
/// local routes. An external routing engine (e.g. OSRM, Valhalla) or geocoding
/// service can be integrated via [RouteDiscoveryProvider].
class RouteDiscoveryEngine implements RouteDiscoveryProvider {
  const RouteDiscoveryEngine();

  @override
  Future<List<SavedRoute>> discoverRoutes({
    required LatLng center,
    double radiusKm = 10.0,
    RouteFilter? filter,
  }) async {
    // Generate suggested geographic circuits centered around the target coordinate
    final rawRoutes = _generateNearbyRoutes(center);

    if (filter == null) return rawRoutes;
    return rawRoutes.where((r) => filter.matches(r)).toList();
  }

  List<SavedRoute> _generateNearbyRoutes(LatLng center) {
    final now = DateTime.now();

    // 1. Short Beginner Park Loop (~1.8 km)
    final loop1Points = _createLoopWaypoints(
      center: center,
      radiusMeters: 280,
      pointCount: 16,
      bearingOffsetDeg: 45,
    );
    final route1 = SavedRoute(
      id: 'route_discovery_1',
      name: 'Greenway Park Circuit',
      activityType: OutdoorActivityType.walking,
      distanceMeters: 1850,
      estimatedDurationSeconds: 1500, // ~25 min
      difficulty: RouteDifficulty.easy,
      points: loop1Points,
      elevationGainMeters: 14.0,
      surfaceType: RouteSurface.paved,
      elevationProfile: RouteElevation.flat,
      description: 'Pleasant, paved walking and running loop through local greenway with water fountains.',
      createdAt: now.subtract(const Duration(days: 3)),
    );

    // 2. 3.4 km Riverside / Neighborhood Jog
    final loop2Points = _createLoopWaypoints(
      center: center,
      radiusMeters: 550,
      pointCount: 22,
      bearingOffsetDeg: 120,
    );
    final route2 = SavedRoute(
      id: 'route_discovery_2',
      name: 'Sunlight Waterfront Trail',
      activityType: OutdoorActivityType.running,
      distanceMeters: 3450,
      estimatedDurationSeconds: 1260, // ~21 min run
      difficulty: RouteDifficulty.moderate,
      points: loop2Points,
      elevationGainMeters: 38.0,
      surfaceType: RouteSurface.mixed,
      elevationProfile: RouteElevation.moderate,
      description: 'Scenic mixed-surface route offering scenic waterfront views and gentle rolling hills.',
      createdAt: now.subtract(const Duration(days: 5)),
    );

    // 3. 5.2 km Pine Forest Nature Loop
    final loop3Points = _createLoopWaypoints(
      center: center,
      radiusMeters: 850,
      pointCount: 28,
      bearingOffsetDeg: 260,
    );
    final route3 = SavedRoute(
      id: 'route_discovery_3',
      name: 'Pine Hill Woodland Trail',
      activityType: OutdoorActivityType.hiking,
      distanceMeters: 5200,
      estimatedDurationSeconds: 3900, // ~65 min hike
      difficulty: RouteDifficulty.hard,
      points: loop3Points,
      elevationGainMeters: 112.0,
      surfaceType: RouteSurface.trail,
      elevationProfile: RouteElevation.hilly,
      description: 'Challenging unpaved trail with steady climbs, rocky paths, and tree-lined shade.',
      createdAt: now.subtract(const Duration(days: 10)),
    );

    // 4. 10.0 km Endurance City Perimeter
    final loop4Points = _createLoopWaypoints(
      center: center,
      radiusMeters: 1600,
      pointCount: 36,
      bearingOffsetDeg: 0,
    );
    final route4 = SavedRoute(
      id: 'route_discovery_4',
      name: 'Metropolitan Perimeter Run',
      activityType: OutdoorActivityType.running,
      distanceMeters: 10100,
      estimatedDurationSeconds: 3400, // ~56 min run
      difficulty: RouteDifficulty.hard,
      points: loop4Points,
      elevationGainMeters: 62.0,
      surfaceType: RouteSurface.paved,
      elevationProfile: RouteElevation.moderate,
      description: 'Long distance perimeter endurance course with wide pedestrian pavements and clear crossings.',
      createdAt: now.subtract(const Duration(days: 14)),
    );

    return [route1, route2, route3, route4];
  }

  /// Helper creating circular/elliptical GPS waypoints around a center point
  List<GpsPoint> _createLoopWaypoints({
    required LatLng center,
    required double radiusMeters,
    required int pointCount,
    required double bearingOffsetDeg,
  }) {
    final points = <GpsPoint>[];
    const earthRadius = 6378137.0; // meters

    final baseTime = DateTime.now().subtract(const Duration(hours: 1));

    for (int i = 0; i <= pointCount; i++) {
      final angle = (i / pointCount) * 2 * math.pi;
      // Introduce subtle natural curvature
      final wobble = 1.0 + 0.18 * math.sin(angle * 3);
      final r = radiusMeters * wobble;

      final latOffset = (r * math.cos(angle)) / earthRadius;
      final lngOffset =
          (r * math.sin(angle)) / (earthRadius * math.cos(center.latitudeInRad));

      final lat = center.latitude + (latOffset * (180.0 / math.pi));
      final lng = center.longitude + (lngOffset * (180.0 / math.pi));

      // Altitude with gentle undulation
      final alt = 50.0 + 20.0 * math.sin(angle * 2);

      points.add(
        GpsPoint(
          latitude: lat,
          longitude: lng,
          altitude: alt,
          accuracy: 5.0,
          speed: 2.8,
          timestamp: baseTime.add(Duration(seconds: i * 30)),
        ),
      );
    }
    return points;
  }
}

