import 'dart:math' as math;
import 'package:fitbuddy/features/maps/data/services/real_route_discovery_service.dart';
import 'package:fitbuddy/features/maps/domain/models/gps_point.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity_type.dart';
import 'package:fitbuddy/features/maps/domain/models/route_filter.dart';
import 'package:fitbuddy/features/maps/domain/models/saved_route.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Abstract contract for discovering outdoor routes.
abstract class RouteDiscoveryProvider {
  Future<List<SavedRoute>> discoverRoutes({
    required LatLng center,
    double radiusKm = 10.0,
    RouteFilter? filter,
  });
}

/// Production route discovery engine.
///
/// Delegates to [RealRouteDiscoveryService] which uses:
///  - OpenStreetMap Overpass API to find real nearby geographic features
///  - Valhalla pedestrian routing to calculate actual walkable paths
///
/// Returns an empty list (never fake data) when no routes can be found.
class RouteDiscoveryEngine implements RouteDiscoveryProvider {
  RouteDiscoveryEngine({RealRouteDiscoveryService? realService})
      : _realService = realService ?? RealRouteDiscoveryService();

  final RealRouteDiscoveryService _realService;

  @override
  Future<List<SavedRoute>> discoverRoutes({
    required LatLng center,
    double radiusKm = 10.0,
    RouteFilter? filter,
  }) {
    return _realService.discoverRoutes(
      center: center,
      radiusKm: radiusKm,
      filter: filter,
    );
  }

  // ---------------------------------------------------------------------------
  // TEST FIXTURES ONLY — not called from production discoverRoutes()
  // ---------------------------------------------------------------------------

  /// Generates synthetic circular routes for unit tests only.
  /// Do NOT call this in production code.
  @visibleForTesting
  List<SavedRoute> generateTestRoutes(LatLng center) {
    return _generateNearbyRoutes(center);
  }

  List<SavedRoute> _generateNearbyRoutes(LatLng center) {
    final now = DateTime.now();
    final loop1Points = _createLoopWaypoints(
      center: center,
      radiusMeters: 280,
      pointCount: 16,
      bearingOffsetDeg: 45,
    );
    final route1 = SavedRoute(
      id: 'test_route_1',
      name: 'Test Loop A',
      activityType: OutdoorActivityType.walking,
      distanceMeters: 1850,
      estimatedDurationSeconds: 1500,
      difficulty: RouteDifficulty.easy,
      points: loop1Points,
      createdAt: now,
    );
    final loop2Points = _createLoopWaypoints(
      center: center,
      radiusMeters: 550,
      pointCount: 22,
      bearingOffsetDeg: 120,
    );
    final route2 = SavedRoute(
      id: 'test_route_2',
      name: 'Test Loop B',
      activityType: OutdoorActivityType.running,
      distanceMeters: 3450,
      estimatedDurationSeconds: 1260,
      difficulty: RouteDifficulty.moderate,
      points: loop2Points,
      createdAt: now,
    );
    return [route1, route2];
  }

  List<GpsPoint> _createLoopWaypoints({
    required LatLng center,
    required double radiusMeters,
    required int pointCount,
    required double bearingOffsetDeg,
  }) {
    final points = <GpsPoint>[];
    const earthRadius = 6378137.0;
    final baseTime = DateTime.now().subtract(const Duration(hours: 1));
    for (int i = 0; i <= pointCount; i++) {
      final angle = (i / pointCount) * 2 * math.pi;
      final wobble = 1.0 + 0.18 * math.sin(angle * 3);
      final r = radiusMeters * wobble;
      final latOffset = (r * math.cos(angle)) / earthRadius;
      final lngOffset =
          (r * math.sin(angle)) / (earthRadius * math.cos(center.latitudeInRad));
      final lat = center.latitude + (latOffset * (180.0 / math.pi));
      final lng = center.longitude + (lngOffset * (180.0 / math.pi));
      points.add(GpsPoint(
        latitude: lat,
        longitude: lng,
        altitude: 50.0 + 20.0 * math.sin(angle * 2),
        accuracy: 5.0,
        speed: 2.8,
        timestamp: baseTime.add(Duration(seconds: i * 30)),
      ));
    }
    return points;
  }
}
