import 'dart:async';
import 'dart:math' as math;
import 'package:fitbuddy/features/maps/data/services/nominatim_service.dart';
import 'package:fitbuddy/features/maps/data/services/overpass_service.dart';
import 'package:fitbuddy/features/maps/data/services/route_cache.dart';
import 'package:fitbuddy/features/maps/data/services/route_exceptions.dart';
import 'package:fitbuddy/features/maps/data/services/valhalla_service.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity_type.dart';
import 'package:fitbuddy/features/maps/domain/models/route_filter.dart';
import 'package:fitbuddy/features/maps/domain/models/saved_route.dart';
import 'package:fitbuddy/features/maps/domain/services/connectivity_monitor.dart';
import 'package:fitbuddy/features/maps/domain/services/route_discovery_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Helper result container for a candidate routing attempt.
class _CandidateRouteResult {
  const _CandidateRouteResult({
    required this.route,
    required this.routed,
    required this.pairKey,
  });

  final SavedRoute route;
  final ValhallaRoute routed;
  final String pairKey;
}

/// Real route discovery using OpenStreetMap data (Overpass/Nominatim) and Valhalla routing.
///
/// Features:
/// - Request-generation tracking and stale request rejection.
/// - In-flight duplicate request joining.
/// - Concurrency bounded to max 2 simultaneous Valhalla requests.
/// - Overall 25-second discovery budget.
/// - Graceful candidate failure isolation (one failed candidate does not discard others).
/// - Early exit on service-wide rate limiting or outages.
/// - LRU response caching with isolated geographic area keys.
/// - Privacy-preserving diagnostic logging (no exact GPS coordinates).
class RealRouteDiscoveryService implements RouteDiscoveryProvider {
  RealRouteDiscoveryService({
    OverpassService? overpass,
    ValhallaService? valhalla,
    NominatimService? nominatim,
    RouteCache? cache,
    this.overallTimeout = const Duration(seconds: 25),
    ConnectivityMonitor? connectivityMonitor,
    Future<bool> Function()? isOfflineProbe,
  })  : _overpass = overpass ??
            OverpassService(
              connectivityMonitor: connectivityMonitor,
              isOfflineProbe: isOfflineProbe,
            ),
        _valhalla = valhalla ?? ValhallaService(),
        _nominatim = nominatim ?? NominatimService(),
        _cache = cache ?? RouteCache.instance;

  final OverpassService _overpass;
  final ValhallaService _valhalla;
  final NominatimService _nominatim;
  final RouteCache _cache;
  final Duration overallTimeout;

  static const int _maxRoutes = 4;
  static const int _maxCandidateWaypoints = 8;
  static const double _maxSearchRadiusMeters = 5000;

  /// Global request generation counter.
  int _currentRequestId = 0;

  /// Active request ID. Earlier searches with a lower ID are discarded.
  int _activeRequestId = 0;

  /// Map of in-flight discoveries to deduplicate concurrent identical calls.
  final Map<String, Future<List<SavedRoute>>> _inFlightDiscoveries = {};

  void _cancelGeneration(int? reqId) {
    if (reqId == null || reqId <= 0) return;
    _overpass.cancelActiveRequests(reqId);
    _valhalla.cancelActiveRequests(reqId);
    _nominatim.cancelActiveRequests(reqId);
  }

  /// Cancels all ongoing in-flight HTTP requests and increments the request generation.
  void cancelCurrentDiscovery() {
    final activeId = _activeRequestId;
    _activeRequestId = ++_currentRequestId;
    _cancelGeneration(activeId);
    _overpass.cancelActiveRequests();
    _valhalla.cancelActiveRequests();
    _nominatim.cancelActiveRequests();
  }

  /// Discovers routes progressively, yielding updated route sets as candidate batches resolve.
  Stream<List<SavedRoute>> discoverRoutesProgressive({
    required LatLng center,
    double radiusKm = 10.0,
    RouteFilter? filter,
  }) async* {
    final radiusMeters = math.min(radiusKm * 1000, _maxSearchRadiusMeters);

    final cacheKey = RouteCache.buildAreaKey(
      center: center,
      radiusMeters: radiusMeters,
      activityType: filter?.activityType,
      filter: filter,
    );

    // 1. Check in-memory LRU cache
    final cached = _cache.get<List<SavedRoute>>(cacheKey);
    if (cached != null) {
      yield cached;
      return;
    }

    // 2. Mark new generation and cancel outdated network tasks
    final previousRequestId = _activeRequestId;
    final requestId = ++_currentRequestId;
    _activeRequestId = requestId;
    if (previousRequestId > 0) {
      _cancelGeneration(previousRequestId);
    }

    if (kDebugMode) {
      debugPrint(
        '[RouteDiscovery][req-$requestId] Starting progressive discovery '
        '(radius: ${radiusMeters.round()}m)',
      );
    }

    try {
      // 1. Query OSM Overpass for nearby mapped features
      List<OverpassPlace> places = [];
      Object? overpassFailure;

      try {
        places = await _overpass.findNearbyPlaces(
          center: center,
          radiusMeters: radiusMeters,
          requestId: requestId,
        );
      } catch (e) {
        overpassFailure = e;
      }

      if (requestId != _activeRequestId) return;

      // Fall back to Nominatim place discovery if Overpass failed or found 0 places
      if (places.isEmpty) {
        try {
          final nominatimPlaces = await _nominatim.findNearbyPlaces(
            center: center,
            radiusMeters: radiusMeters,
            requestId: requestId,
          );
          if (nominatimPlaces.isNotEmpty) {
            places = nominatimPlaces;
            overpassFailure = null;
          }
        } catch (nomErr) {
          if (nomErr is RouteRateLimitException) {
            overpassFailure = nomErr;
          }
        }
      }

      if (requestId != _activeRequestId) return;

      if (overpassFailure != null && places.isEmpty) {
        if (overpassFailure is RouteNetworkException &&
            overpassFailure.message.contains('cancelled')) {
          return;
        }
        // Hard-stop errors: propagate immediately without trying the grid fallback.
        // - DeviceOfflineException: device has confirmed no internet connection.
        // - RouteRateLimitException: server explicitly asked us to back off.
        // - RouteNetworkException: connectivity failure (excluding server-specific timeout/unreachable).
        if (overpassFailure is DeviceOfflineException ||
            overpassFailure is RouteRateLimitException ||
            (overpassFailure is RouteNetworkException &&
                overpassFailure is! ServiceTimeoutException &&
                overpassFailure is! ServiceUnreachableException)) {
          _cancelGeneration(requestId);
          throw overpassFailure;
        }
        // Server-side errors (OverpassServiceException, ServiceTimeoutException,
        // ServiceUnreachableException, BadResponseException) are soft errors:
        // proceed to grid-waypoint fallback so Valhalla can calculate real routes.
      }

      // -----------------------------------------------------------------------
      // Grid-waypoint fallback: when neither Overpass nor Nominatim returned
      // any named places (e.g. all Overpass mirrors are timing out from this
      // network), synthesise compass-direction waypoints at multiple distances.
      // Valhalla will route to them along REAL pedestrian paths that actually
      // exist on the map — the waypoints are just hints, not synthetic geometry.
      // -----------------------------------------------------------------------
      if (places.isEmpty) {
        places = _syntheticGridWaypoints(center, radiusMeters);
        if (kDebugMode) {
          debugPrint(
            '[RouteDiscovery][req-$requestId] No OSM places found — '
            'using ${places.length} synthetic grid waypoints as routing hints.',
          );
        }
      }

      if (places.isEmpty) {
        if (overpassFailure != null) {
          _cancelGeneration(requestId);
          if (overpassFailure is RouteDiscoveryException) {
            throw overpassFailure;
          }
          throw OverpassServiceException(
              'Failed to discover routes: $overpassFailure');
        }
        yield const [];
        return;
      }

      // 2. Select candidates prioritized by geographic diversity and feature type (max 8)
      final candidates = _pickCandidateWaypoints(center, places);
      if (candidates.isEmpty) {
        yield const [];
        return;
      }

      // 3. Concurrently route candidates with maximum concurrency of 2
      final routes = <SavedRoute>[];
      final seenOsmPairs = <String>{};

      for (int i = 0; i < candidates.length && routes.length < _maxRoutes; i += 2) {
        if (requestId != _activeRequestId) return;

        final batch = candidates.skip(i).take(2).toList();
        final batchFutures = batch.map((p) => _routeCandidate(
              center: center,
              primary: p,
              pool: candidates,
              seenOsmPairs: seenOsmPairs,
              existingRoutes: routes,
              requestId: requestId,
            ));

        List<_CandidateRouteResult?> batchResults;
        try {
          batchResults = await Future.wait(batchFutures);
        } on RouteDiscoveryException {
          _cancelGeneration(requestId);
          // If some valid routes were already found in earlier batches, preserve them!
          if (routes.isNotEmpty) {
            final filtered = filter != null
                ? routes.where((r) => filter.matches(r)).toList()
                : routes;
            yield List<SavedRoute>.unmodifiable(filtered);
            return;
          }
          rethrow;
        }

        if (requestId != _activeRequestId) return;

        bool newlyAdded = false;
        for (final result in batchResults) {
          if (result != null && routes.length < _maxRoutes) {
            if (!_isGeometricDuplicate(result.routed, routes)) {
              seenOsmPairs.add(result.pairKey);
              routes.add(result.route);
              newlyAdded = true;
            }
          }
        }

        // Progressive publication of route batches as soon as batch completes
        if (newlyAdded) {
          final filtered = filter != null
              ? routes.where((r) => filter.matches(r)).toList()
              : List<SavedRoute>.from(routes);
          yield List<SavedRoute>.unmodifiable(filtered);
        }
      }

      if (routes.isEmpty) {
        yield const [];
      } else {
        final filtered = filter != null
            ? routes.where((r) => filter.matches(r)).toList()
            : routes;
        if (filtered.isNotEmpty) {
          _cache.set(cacheKey, filtered);
        }
      }
    } finally {
      _cancelGeneration(requestId);
    }
  }

  @override
  Future<List<SavedRoute>> discoverRoutes({
    required LatLng center,
    double radiusKm = 10.0,
    RouteFilter? filter,
  }) async {
    final radiusMeters = math.min(radiusKm * 1000, _maxSearchRadiusMeters);

    final cacheKey = RouteCache.buildAreaKey(
      center: center,
      radiusMeters: radiusMeters,
      activityType: filter?.activityType,
      filter: filter,
    );

    // 1. Check in-memory LRU cache
    final cached = _cache.get<List<SavedRoute>>(cacheKey);
    if (cached != null) return cached;

    // 2. Join in-flight identical request if active
    if (_inFlightDiscoveries.containsKey(cacheKey)) {
      return _inFlightDiscoveries[cacheKey]!;
    }

    final completer = Completer<List<SavedRoute>>();
    _inFlightDiscoveries[cacheKey] = completer.future;
    completer.future.ignore();

    final requestId = _currentRequestId + 1;

    try {
      final progressiveStream = discoverRoutesProgressive(
        center: center,
        radiusKm: radiusKm,
        filter: filter,
      );

      List<SavedRoute> lastEmitted = const [];
      await for (final routes in progressiveStream.timeout(
        overallTimeout,
        onTimeout: (sink) {
          _cancelGeneration(requestId);
          sink.addError(const ServiceTimeoutException(
              serviceName: 'Route Discovery',
              message: 'Route discovery timed out waiting for external services.'));
          sink.close();
        },
      )) {
        lastEmitted = routes;
      }

      if (!completer.isCompleted) {
        completer.complete(lastEmitted);
      }
      return lastEmitted;
    } catch (e, st) {
      _cancelGeneration(requestId);
      if (!completer.isCompleted) {
        completer.completeError(e, st);
      }
      rethrow;
    } finally {
      _inFlightDiscoveries.remove(cacheKey);
    }
  }

  /// Calculates a route for a single primary candidate waypoint.
  ///
  /// Isolates failures: returns null if unroutable, without failing the entire batch.
  /// Rethrows service-wide failures (HTTP 429) to halt discovery early.
  Future<_CandidateRouteResult?> _routeCandidate({
    required LatLng center,
    required OverpassPlace primary,
    required List<OverpassPlace> pool,
    required Set<String> seenOsmPairs,
    required List<SavedRoute> existingRoutes,
    required int requestId,
  }) async {
    if (requestId != _activeRequestId) return null;

    final companion = _findLoopCompanion(center, primary, pool);
    ValhallaRoute? routed;
    OverpassPlace? actualSecondary;

    try {
      if (companion != null) {
        // Multi-point loop: Center -> Waypoint 1 -> Waypoint 2 -> Center
        routed = await _valhalla.route(
          origin: center,
          waypoints: [primary.latLng, companion.latLng, center],
          requestId: requestId,
        );
        if (routed != null) {
          actualSecondary = companion;
        }
      }

      // If multi-point was unroutable (null) or companion was null, try single waypoint
      if (routed == null) {
        routed = await _valhalla.route(
          origin: center,
          waypoints: [primary.latLng, center],
          requestId: requestId,
        );
        actualSecondary = null;
      }
    } on RouteDiscoveryException {
      // Service-wide rate limit, outage, or network failure: rethrow so pipeline stops early
      rethrow;
    } catch (e) {
      // Individual candidate failure: log and return null to let other candidates proceed
      if (kDebugMode) {
        debugPrint(
            '[RouteDiscovery][req-$requestId] Candidate ${primary.id} routing failed');
      }
      return null;
    }

    if (routed == null) return null;
    if (routed.distanceMeters < 300) return null;
    if (routed.points.length < 2) return null;

    // Check OSM element pairs
    final pairKey = '${primary.id}:${actualSecondary?.id ?? 0}';
    final reversePairKey = '${actualSecondary?.id ?? 0}:${primary.id}';
    if (seenOsmPairs.contains(pairKey) || seenOsmPairs.contains(reversePairKey)) {
      return null;
    }

    // Check geometric similarity against existing routes
    if (_isGeometricDuplicate(routed, existingRoutes)) {
      return null;
    }

    final isLoop = routed.isLoop;
    final routeName = _determineRouteName(primary, actualSecondary, isLoop);

    final route = _buildRoute(
      id: 'osm_${primary.id}_${actualSecondary?.id ?? 0}',
      name: routeName,
      primaryPlace: primary,
      secondaryPlace: actualSecondary,
      routed: routed,
      isLoop: isLoop,
    );

    return _CandidateRouteResult(
      route: route,
      routed: routed,
      pairKey: pairKey,
    );
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

  /// Generates synthetic compass-direction waypoints when no OSM places were
  /// found (e.g. all Overpass mirrors are unavailable from this network).
  ///
  /// The waypoints are geographic targets — Valhalla routes along REAL
  /// pedestrian paths from the OSM graph to reach them. Distance from 400 m
  /// to the requested radius in steps, at 8 compass headings (N, NE, E, SE,
  /// S, SW, W, NW). Duplicate IDs are avoided using the bearing + distance
  /// as a stable hash.
  List<OverpassPlace> _syntheticGridWaypoints(
    LatLng center,
    double radiusMeters,
  ) {
    const bearings = [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0];
    final distances = <double>[
      (radiusMeters * 0.3).clamp(400, 1000),
      (radiusMeters * 0.6).clamp(600, 2000),
    ];

    final places = <OverpassPlace>[];
    final lat0 = center.latitudeInRad;
    final lon0 = center.longitudeInRad;

    for (final dist in distances) {
      for (final bearing in bearings) {
        final brRad = bearing * math.pi / 180.0;
        final angDist = dist / 6371000.0; // Earth radius in metres
        final lat = math.asin(
          math.sin(lat0) * math.cos(angDist) +
              math.cos(lat0) * math.sin(angDist) * math.cos(brRad),
        );
        final lon = lon0 +
            math.atan2(
              math.sin(brRad) * math.sin(angDist) * math.cos(lat0),
              math.cos(angDist) - math.sin(lat0) * math.sin(lat),
            );

        final latDeg = lat * 180.0 / math.pi;
        final lonDeg = lon * 180.0 / math.pi;
        if (!latDeg.isFinite || !lonDeg.isFinite) continue;

        final id = bearing.toInt() * 10000 + dist.toInt();
        final label = _bearingLabel(bearing);
        places.add(OverpassPlace(
          id: id,
          name: '$label Walk',
          lat: latDeg,
          lon: lonDeg,
          tags: const {'highway': 'footway'},
          isNamed: false,
        ));
      }
    }
    return places;
  }

  String _bearingLabel(double bearing) {
    if (bearing < 22.5 || bearing >= 337.5) return 'North';
    if (bearing < 67.5) return 'North-East';
    if (bearing < 112.5) return 'East';
    if (bearing < 157.5) return 'South-East';
    if (bearing < 202.5) return 'South';
    if (bearing < 247.5) return 'South-West';
    if (bearing < 292.5) return 'West';
    return 'North-West';
  }

  /// Picks geographically distributed candidates around [center] (bounded to max 8).
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
    return ordered.where((p) => seen.add(p.id)).take(_maxCandidateWaypoints).toList();
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
    // For named places (from Overpass/Nominatim), use the place name.
    // For synthetic grid waypoints (isNamed=false, name="North Walk" etc.)
    // use a direction-based label that makes sense to the user.
    if (p1.isNamed) {
      if (isLoop) {
        if (p2 != null && p2.isNamed && p1.name != p2.name) {
          return '${p1.name} & ${p2.name} Loop';
        }
        return '${p1.name} Loop';
      } else {
        if (p2 != null && p2.isNamed && p1.name != p2.name) {
          return '${p1.name} & ${p2.name} Out & Back';
        }
        return '${p1.name} Out & Back';
      }
    } else {
      // Synthetic grid waypoint — label by direction + route type
      final dir = p1.name.replaceAll(' Walk', '');
      return isLoop ? '$dir Loop' : '$dir Route';
    }
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
      elevationGainMeters: null,
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
    return RouteSurface.unknown;
  }

  ({RouteDifficulty difficulty, bool isEstimated}) _inferDifficulty(
    double distanceMeters,
    OverpassPlace place,
  ) {
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

    // Named place from Overpass/Nominatim
    if (p1.isNamed) {
      if (p2 != null && p2.isNamed) {
        return '$typeLabel traversing ${p1.name} and ${p2.name} along mapped pedestrian paths. '
            'Approx. $km km, est. $mins min.';
      }
      return '$typeLabel around ${p1.name} along mapped walkable ways. '
          'Approx. $km km, est. $mins min.';
    }

    // Synthetic grid waypoint — direction-based description
    final dir = p1.name.replaceAll(' Walk', '');
    return '$typeLabel heading $dir from your location along real pedestrian paths. '
        'Approx. $km km, est. $mins min.';
  }
}
