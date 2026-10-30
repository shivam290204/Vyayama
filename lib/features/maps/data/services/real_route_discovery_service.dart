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
/// Discovers genuine nearby routes along mapped pedestrian paths and parks.
/// Computes actual loops when multiple geographically diverse waypoints are found,
/// and labels out-and-back routes honestly when retraced.
///
/// Propagates network and service errors so the UI can distinguish genuine empty
/// results from connectivity or rate limit failures.
class RealRouteDiscoveryService implements RouteDiscoveryProvider {
  RealRouteDiscoveryService({
    OverpassService? overpass,
    ValhallaService? valhalla,
  })  : _overpass = overpass ?? OverpassService(),
        _valhalla = valhalla ?? ValhallaService();

  final OverpassService _overpass;
  final ValhallaService _valhalla;

  static const int _maxRoutes = 4;
  static const double _maxSearchRadiusMeters = 5000;

  @override
  Future<List<SavedRoute>> discoverRoutes({
    required LatLng center,
    double radiusKm = 10.0,
    RouteFilter? filter,
  }) async {
    final radiusMeters = math.min(radiusKm * 1000, _maxSearchRadiusMeters);

    // 1. Query OSM Overpass for nearby mapped features (parks, trails, paths)
    // OverpassService throws RouteDiscoveryException on 429, 5xx, or network failure
    final places = await _overpass.findNearbyPlaces(
      center: center,
      radiusMeters: radiusMeters,
    );

    if (places.isEmpty) return [];

    // 2. Select candidates prioritized by geographic diversity and feature type
    final candidates = _pickCandidateWaypoints(center, places);
    if (candidates.isEmpty) return [];

    // 3. Generate pedestrian routes (loops or honest out-and-backs)
    final routes = <SavedRoute>[];
    final seenOsmPairs = <String>{};

    for (int i = 0; i < candidates.length && routes.length < _maxRoutes; i++) {
      final p1 = candidates[i];

      // Try finding a complementary second waypoint to create a genuine loop
      final p2 = _findLoopCompanion(center, p1, candidates);

      final pairKey = '${p1.id}:${p2?.id ?? 0}';
      final reversePairKey = '${p2?.id ?? 0}:${p1.id}';
      if (seenOsmPairs.contains(pairKey) ||
          seenOsmPairs.contains(reversePairKey)) {
        continue;
      }

      ValhallaRoute? routed;

      if (p2 != null) {
        // Multi-point loop: Center -> Waypoint 1 -> Waypoint 2 -> Center
        try {
          routed = await _valhalla.route(
            origin: center,
            waypoints: [p1.latLng, p2.latLng, center],
          );
        } catch (_) {
          // Fall back to single waypoint out-and-back
          routed = null;
        }
      }

      routed ??= await _valhalla.route(
        origin: center,
        waypoints: [p1.latLng, center],
      );

      if (routed == null) continue;
      if (routed.distanceMeters < 300) continue;
      if (routed.points.length < 5) continue;

      // Deduplicate using geometric similarity & spatial overlap
      if (_isGeometricDuplicate(routed, routes)) continue;

      // Loop status strictly derived from returned route geometry
      final isLoop = routed.isLoop;
      final routeName = _determineRouteName(p1, p2, isLoop);

      seenOsmPairs.add(pairKey);

      final route = _buildRoute(
        id: 'osm_${p1.id}_${p2?.id ?? 0}',
        name: routeName,
        primaryPlace: p1,
        secondaryPlace: p2,
        routed: routed,
        isLoop: isLoop,
      );
      routes.add(route);
    }

    // 4. Apply user filters
    if (filter == null) return routes;
    return routes.where((r) => filter.matches(r)).toList();
  }

  /// Calculates centroid of a coordinate list.
  LatLng _calculateCentroid(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(0, 0);
    double sumLat = 0;
    double sumLng = 0;
    for (final pt in points) {
      sumLat += pt.latitude;
      sumLng += pt.longitude;
    }
    return LatLng(sumLat / points.length, sumLng / points.length);
  }

  /// Identifies the farthest point from the starting coordinate.
  LatLng _findFarthestPoint(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(0, 0);
    final start = points.first;
    LatLng farthest = start;
    double maxDist = 0;
    for (final pt in points) {
      final d = haversineDistance(start, pt);
      if (d > maxDist) {
        maxDist = d;
        farthest = pt;
      }
    }
    return farthest;
  }

  /// Tests if [candidate] overlaps significantly with an existing route
  /// (nearly identical distance AND occupying the same geographic corridor).
  bool _isGeometricDuplicate(
    ValhallaRoute candidate,
    List<SavedRoute> existingRoutes,
  ) {
    final candidatePoints = candidate.points;
    if (candidatePoints.isEmpty) return false;
    final candidateCentroid = _calculateCentroid(candidatePoints);
    final candidateFarthest = _findFarthestPoint(candidatePoints);

    for (final existing in existingRoutes) {
      final distDiff =
          (existing.distanceMeters - candidate.distanceMeters).abs();
      // Only check spatial overlap if total distances are within 150m
      if (distDiff < 150.0) {
        final existingPoints = existing.points.map((p) => p.toLatLng()).toList();
        final existingCentroid = _calculateCentroid(existingPoints);
        final centroidDist =
            haversineDistance(candidateCentroid, existingCentroid);

        if (centroidDist < 150.0) {
          final existingFarthest = _findFarthestPoint(existingPoints);
          final farthestDist =
              haversineDistance(candidateFarthest, existingFarthest);
          if (farthestDist < 150.0) {
            return true; // Overlapping corridor and nearly identical distance
          }
        }
      }
    }
    return false;
  }

  /// Picks geographically distributed candidates around [center].
  List<OverpassPlace> _pickCandidateWaypoints(
    LatLng center,
    List<OverpassPlace> places,
  ) {
    final sorted = List<OverpassPlace>.from(places)
      ..sort((a, b) {
        final da = haversineDistance(center, a.latLng);
        final db = haversineDistance(center, b.latLng);
        return da.compareTo(db);
      });

    // Prefer named places and parks, followed by mapped trails and footways
    final namedPlaces = sorted.where((p) => p.isNamed).toList();
    final unnamedPlaces = sorted.where((p) => !p.isNamed).toList();

    final ordered = [...namedPlaces, ...unnamedPlaces];
    final seen = <int>{};
    return ordered.where((p) => seen.add(p.id)).take(12).toList();
  }

  /// Finds a second waypoint [p2] separated by an angular divergence of 40°-160°
  /// from [p1] relative to [center] to generate a genuine polygon loop.
  OverpassPlace? _findLoopCompanion(
    LatLng center,
    OverpassPlace p1,
    List<OverpassPlace> pool,
  ) {
    final b1 = _bearing(center, p1.latLng);
    for (final candidate in pool) {
      if (candidate.id == p1.id) continue;
      final b2 = _bearing(center, candidate.latLng);
      final angleDiff = (b1 - b2).abs();
      final normalizedDiff = angleDiff > 180 ? 360 - angleDiff : angleDiff;

      if (normalizedDiff >= 40 && normalizedDiff <= 160) {
        final d1 = haversineDistance(center, p1.latLng);
        final d2 = haversineDistance(center, candidate.latLng);
        // Ensure distance ratio is balanced
        final ratio = d1 > d2 ? d1 / d2 : d2 / d1;
        if (ratio < 3.0) {
          return candidate;
        }
      }
    }
    return null;
  }

  /// Calculates bearing from coordinate [a] to [b] in degrees (0-360).
  double _bearing(LatLng a, LatLng b) {
    final lat1 = a.latitudeInRad;
    final lat2 = b.latitudeInRad;
    final dLon = (b.longitude - a.longitude) * math.pi / 180.0;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final rad = math.atan2(y, x);
    return (rad * 180.0 / math.pi + 360.0) % 360.0;
  }

  String _determineRouteName(
    OverpassPlace p1,
    OverpassPlace? p2,
    bool isLoop,
  ) {
    if (p1.isNamed && p2 != null && p2.isNamed && p1.name != p2.name) {
      return '${p1.name} & ${p2.name} Loop';
    }
    if (p1.isNamed) {
      return isLoop ? '${p1.name} Loop' : '${p1.name} Out & Back';
    }
    return isLoop ? '${p1.name} Loop' : '${p1.name} Out & Back';
  }

  SavedRoute _buildRoute({
    required String id,
    required String name,
    required OverpassPlace primaryPlace,
    required OverpassPlace? secondaryPlace,
    required ValhallaRoute routed,
    required bool isLoop,
  }) {
    final gpsPoints = routed.toGpsPoints();
    final activityType = _inferActivityType(primaryPlace);
    final surface = _inferSurface(primaryPlace);
    final diffResult =
        _inferDifficulty(routed.distanceMeters, primaryPlace);

    return SavedRoute(
      id: id,
      name: name,
      activityType: activityType,
      distanceMeters: routed.distanceMeters,
      estimatedDurationSeconds: routed.durationSeconds.round(),
      difficulty: diffResult.difficulty,
      isDifficultyEstimated: diffResult.isEstimated,
      points: gpsPoints,
      elevationGainMeters: null, // Elevation is omitted unless provided by elevation API
      surfaceType: surface,
      elevationProfile: RouteElevation.unknown,
      description: _buildDescription(primaryPlace, secondaryPlace, routed, isLoop),
      isLoop: isLoop,
      createdAt: DateTime.now(),
    );
  }

  OutdoorActivityType _inferActivityType(OverpassPlace place) {
    if (place.isHikingRoute) {
      return OutdoorActivityType.hiking;
    }
    final sport = place.tags['sport']?.toLowerCase();
    final routeTag = place.tags['route']?.toLowerCase();
    if (sport == 'running' ||
        routeTag == 'running' ||
        place.tags['leisure'] == 'track') {
      return OutdoorActivityType.running;
    }
    return OutdoorActivityType.walking;
  }

  RouteSurface _inferSurface(OverpassPlace place) {
    final surface = place.tags['surface']?.toLowerCase() ?? '';
    if (surface == 'asphalt' || surface == 'paved' || surface == 'concrete') {
      return RouteSurface.paved;
    }
    if (surface == 'unpaved' ||
        surface == 'dirt' ||
        surface == 'gravel' ||
        surface == 'ground' ||
        surface == 'earth') {
      return RouteSurface.trail;
    }
    if (surface == 'fine_gravel' || surface == 'compacted') {
      return RouteSurface.mixed;
    }
    // Do not invent surface information when untagged
    return RouteSurface.unknown;
  }

  ({RouteDifficulty difficulty, bool isEstimated}) _inferDifficulty(
    double distanceMeters,
    OverpassPlace place,
  ) {
    // 1. Check verified OSM SAC hiking scale
    final sacScale = place.tags['sac_scale']?.toLowerCase();
    if (sacScale != null) {
      if (sacScale == 'mountain_hiking' ||
          sacScale == 'demanding_mountain_hiking') {
        return (difficulty: RouteDifficulty.moderate, isEstimated: false);
      }
      if (sacScale == 'alpine_hiking' ||
          sacScale == 'demanding_alpine_hiking') {
        return (difficulty: RouteDifficulty.hard, isEstimated: false);
      }
      return (difficulty: RouteDifficulty.easy, isEstimated: false);
    }

    // 2. Check explicit difficulty tag in OSM
    final osmDifficulty = place.tags['difficulty']?.toLowerCase();
    if (osmDifficulty != null) {
      if (osmDifficulty == 'hard' ||
          osmDifficulty == 'expert' ||
          osmDifficulty == 'advanced') {
        return (difficulty: RouteDifficulty.hard, isEstimated: false);
      }
      if (osmDifficulty == 'moderate' || osmDifficulty == 'intermediate') {
        return (difficulty: RouteDifficulty.moderate, isEstimated: false);
      }
      if (osmDifficulty == 'easy' || osmDifficulty == 'novice') {
        return (difficulty: RouteDifficulty.easy, isEstimated: false);
      }
    }

    // 3. Without explicit terrain classification, clearly mark as estimate
    final RouteDifficulty estimated;
    if (place.isHikingRoute) {
      estimated = distanceMeters > 5000
          ? RouteDifficulty.hard
          : RouteDifficulty.moderate;
    } else if (distanceMeters < 3000) {
      estimated = RouteDifficulty.easy;
    } else if (distanceMeters < 7000) {
      estimated = RouteDifficulty.moderate;
    } else {
      estimated = RouteDifficulty.hard;
    }
    return (difficulty: estimated, isEstimated: true);
  }

  String _buildDescription(
    OverpassPlace p1,
    OverpassPlace? p2,
    ValhallaRoute routed,
    bool isLoop,
  ) {
    final km = (routed.distanceMeters / 1000).toStringAsFixed(1);
    final mins = (routed.durationSeconds / 60).round();
    final typeLabel = isLoop ? 'Loop route' : 'Out-and-back route';

    if (p2 != null) {
      return '$typeLabel traversing ${p1.name} and ${p2.name} along mapped pedestrian paths. '
          'Approx. $km km, est. $mins min.';
    }
    return '$typeLabel around ${p1.name} along mapped walkable ways. '
        'Approx. $km km, est. $mins min.';
  }
}
