// lib/features/maps/data/services/real_route_discovery_service.dart

import 'dart:math' as math;
import 'package:fitbuddy/features/maps/data/services/overpass_service.dart';
import 'package:fitbuddy/features/maps/data/services/valhalla_service.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity_type.dart';
import 'package:fitbuddy/features/maps/domain/models/route_filter.dart';
import 'package:fitbuddy/features/maps/domain/models/saved_route.dart';
import 'package:fitbuddy/features/maps/domain/services/route_discovery_engine.dart';
import 'package:latlong2/latlong.dart';

/// Real route discovery using OpenStreetMap data (Overpass) and Valhalla routing.
///
/// Replaces the fake circular routes from [RouteDiscoveryEngine].
/// Returns only routes whose geometry was actually calculated by the Valhalla
/// routing engine from real OSM data.
///
/// If no routes can be calculated (no nearby mapped features, network unavailable,
/// routing service down), returns an empty list — never fake data.
class RealRouteDiscoveryService implements RouteDiscoveryProvider {
  RealRouteDiscoveryService({
    OverpassService? overpass,
    ValhallaService? valhalla,
  })  : _overpass = overpass ?? OverpassService(),
        _valhalla = valhalla ?? ValhallaService();

  final OverpassService _overpass;
  final ValhallaService _valhalla;

  static const int _maxRoutes = 4;
  static const double _searchRadiusMeters = 2500;

  @override
  Future<List<SavedRoute>> discoverRoutes({
    required LatLng center,
    double radiusKm = 10.0,
    RouteFilter? filter,
  }) async {
    final radiusMeters = math.min(radiusKm * 1000, _searchRadiusMeters);

    // 1. Query OSM Overpass for nearby named geographic features
    final places = await _overpass.findNearbyPlaces(
      center: center,
      radiusMeters: radiusMeters,
    );

    if (places.isEmpty) return [];

    // 2. Deduplicate: pick distinct candidate waypoints
    final candidates = _pickCandidateWaypoints(center, places);
    if (candidates.isEmpty) return [];

    // 3. For each candidate waypoint, route from center → waypoint → center (loop)
    final routes = <SavedRoute>[];
    final seenDistances = <double>[];

    for (int i = 0; i < candidates.length && routes.length < _maxRoutes; i++) {
      final place = candidates[i];
      final waypoints = [place.latLng, center];

      final routed = await _valhalla.route(
        origin: center,
        waypoints: waypoints,
      );

      if (routed == null) continue;
      if (routed.distanceMeters < 300) continue; // too short
      if (routed.points.length < 5) continue;

      // Deduplicate routes of very similar distance
      final isDuplicate = seenDistances.any(
        (d) => (d - routed.distanceMeters).abs() < 150,
      );
      if (isDuplicate) continue;
      seenDistances.add(routed.distanceMeters);

      final route = _buildRoute(
        id: 'osm_${place.id}',
        name: place.name,
        place: place,
        routed: routed,
      );
      routes.add(route);
    }

    // 4. Apply filter
    if (filter == null) return routes;
    return routes.where((r) => filter.matches(r)).toList();
  }

  /// Picks up to [_maxRoutes * 2] unique candidate places from Overpass results,
  /// preferring parks over bare paths, and prioritising closer ones.
  List<OverpassPlace> _pickCandidateWaypoints(
    LatLng center,
    List<OverpassPlace> places,
  ) {
    // Sort by distance to center
    final sorted = List<OverpassPlace>.from(places)
      ..sort((a, b) {
        final da = haversineDistance(center, a.latLng);
        final db = haversineDistance(center, b.latLng);
        return da.compareTo(db);
      });

    // Prefer parks first, then trails
    final parks = sorted.where((p) => p.isPark).toList();
    final trails = sorted.where((p) => p.isTrail && !p.isPark).toList();
    final others = sorted.where((p) => !p.isPark && !p.isTrail).toList();

    final merged = [...parks, ...trails, ...others];

    // Remove duplicates by id
    final seen = <int>{};
    return merged.where((p) => seen.add(p.id)).take(_maxRoutes * 2).toList();
  }

  SavedRoute _buildRoute({
    required String id,
    required String name,
    required OverpassPlace place,
    required ValhallaRoute routed,
  }) {
    final gpsPoints = routed.toGpsPoints();

    // Determine activity type from place tags
    final activityType = _inferActivityType(place);

    // Determine surface from place tags
    final surface = _inferSurface(place);

    // Estimate difficulty from distance
    final difficulty = _inferDifficulty(routed.distanceMeters);

    return SavedRoute(
      id: id,
      name: name,
      activityType: activityType,
      distanceMeters: routed.distanceMeters,
      estimatedDurationSeconds: routed.durationSeconds.round(),
      difficulty: difficulty,
      points: gpsPoints,
      elevationGainMeters: 0.0, // Valhalla free tier doesn't return elevation
      surfaceType: surface,
      elevationProfile: RouteElevation.flat,
      description: _buildDescription(place, routed),
      createdAt: DateTime.now(),
    );
  }

  OutdoorActivityType _inferActivityType(OverpassPlace place) {
    final tags = place.tags;
    if (tags['route'] == 'hiking' || tags['sac_scale'] != null) {
      return OutdoorActivityType.hiking;
    }
    if (tags['highway'] == 'track' || tags['surface'] == 'unpaved') {
      return OutdoorActivityType.hiking;
    }
    if (tags['leisure'] == 'park' || tags['leisure'] == 'recreation_ground') {
      return OutdoorActivityType.walking;
    }
    return OutdoorActivityType.walking;
  }

  RouteSurface _inferSurface(OverpassPlace place) {
    final surface = place.tags['surface'] ?? '';
    if (surface == 'asphalt' || surface == 'paved' || surface == 'concrete') {
      return RouteSurface.paved;
    }
    if (surface == 'unpaved' ||
        surface == 'dirt' ||
        surface == 'gravel' ||
        surface == 'ground') {
      return RouteSurface.trail;
    }
    if (place.isPark) return RouteSurface.mixed;
    return RouteSurface.paved;
  }

  RouteDifficulty _inferDifficulty(double distanceMeters) {
    if (distanceMeters < 2000) return RouteDifficulty.easy;
    if (distanceMeters < 5000) return RouteDifficulty.moderate;
    return RouteDifficulty.hard;
  }

  String _buildDescription(OverpassPlace place, ValhallaRoute routed) {
    final km = (routed.distanceMeters / 1000).toStringAsFixed(1);
    final mins = (routed.durationSeconds / 60).round();
    final type = place.isPark ? 'park area' : 'mapped route';
    return 'Route near ${place.name} — a real $type. '
        'Approx. $km km, estimated $mins min walking.';
  }
}
